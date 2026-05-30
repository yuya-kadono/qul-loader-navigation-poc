### 9-3. TransitionManager の公開状態と API

```qml
// Mediator/TransitionManager.qml (singleton)
pragma Singleton
import QtQuick
import Constants            // ScreenId, ViewId, NavDirection, ViewLifecycle を使う

QtObject {
    // direction / lifecycle 列挙値は NavDirection / ViewLifecycle 専用 singleton に分離している (§5-2 と同じ
    // 「QUL enum 構文で QtObject 内に enum 宣言」のパターン)。TransitionManager は import して
    // NavDirection.Next / ViewLifecycle.Idle のように参照する。

    // ---- 進行状態 ----
    property int state: ViewLifecycle.Idle   // Idle / InProgress (= entering or leaving 中)

    // ---- Screen スロット (Main.qml がバインドする) ----
    property string screenSourceA: ""
    property string screenSourceB: ""
    property bool   screenAIsCurrent: true

    // ---- View スロット (各 Screen 内 ViewLoader がバインド) ----
    // スロット別に状態を持つが、view からは ID キー lookup で参照する (9-4)
    property string viewSlotASource: ""
    property string viewSlotBSource: ""
    property int    viewSlotAViewId: 0    // 現在 slot A にロードされる view の ID (0 = unset)
    property int    viewSlotBViewId: 0
    property int    viewSlotALifecycle: ViewLifecycle.Idle
    property int    viewSlotBLifecycle: ViewLifecycle.Idle
    property int    viewSlotADirection:  NavDirection.Next
    property int    viewSlotBDirection:  NavDirection.Next
    property int    viewSlotAPartnerId:  0  // Enter 中なら fromId、Leave 中なら toId
    property int    viewSlotBPartnerId:  0
    property bool   viewAIsCurrent: true

    // ---- View 用 ID キー lookup (view が自身の状態を取得する) ----
    function lifecycleOf(viewId) {
        if (viewSlotAViewId === viewId) return viewSlotALifecycle
        if (viewSlotBViewId === viewId) return viewSlotBLifecycle
        return ViewLifecycle.Idle
    }
    function directionOf(viewId) {
        if (viewSlotAViewId === viewId) return viewSlotADirection
        if (viewSlotBViewId === viewId) return viewSlotBDirection
        return NavDirection.Next
    }
    function partnerOf(viewId) {
        if (viewSlotAViewId === viewId) return viewSlotAPartnerId
        if (viewSlotBViewId === viewId) return viewSlotBPartnerId
        return 0
    }

    // ---- View からの完了報告 ----
    function reportEnterComplete(viewId) { /* manager が待ち合わせを進める */ }
    function reportLeaveComplete(viewId) { /* 同上 */ }

    // ---- Orchestration API (Mediator から呼ぶ) ----
    function startTransition(toViewId, direction) { /* §9-3-1 参照 */ }
    function abortCurrentTransition() { /* 進行中をキャンセル、entering 即確定 */ }

    // ---- 完了通知 (signal の代わりに property-token 方式 §8-3) ----
    property int    finishedGen: 0        // 1 ずつ増える「世代カウンタ」
    property int    lastFinishedViewId: 0 // 直近完了した遷移先 (ViewId enum 値)
}
```

`KeyDispatcher.enabled` の制御は `state` に連動して TransitionManager 側で行う（§8-3 / §9-7）。`transitionFinished` の代替として **finishedGen + lastFinishedViewId** プロパティを公開。受け手 (例: Main.qml) はローカル binding と `onFinishedGenChanged + ready` ガードで購読する。

#### 9-3-1. startTransition の write 順 (重要)

`startTransition` 内の property write 順序は **意図的に**:

1. 進行状態フラグ群 (`state`, `enterReported`, `leaveReported`, `pendingFinalId`, `isCrossScreen`, `hasLeavingView`) を立てる
2. cross-screen の場合は **entering Screen の source** をセット (Loader が即同期で screen QML をロード)
3. **Entering view の metadata** (viewSlotXViewId / NavDirection / PartnerId / ViewLifecycle) をセット
4. **Leaving view の metadata** (該当 view の binding 経由で leaveAnim を起動)
5. **Entering view の source を最後にセット** (Loader.source 変化で view QML がロードされる時点で metadata が揃っている → ロードされた view の `Component.onCompleted` が正しい myLifecycle/direction/partner を見られる)

この順序を逆にすると、ロード直後の `Component.onCompleted` で `myLifecycle=Idle` という stale 状態が一瞬見え、`reactToLifecycle` が空振りで先行発火する問題が起きる（実装初期に踏んだバグ）。

#### 9-3-2. ランダム duration と 0 ケースの取り扱い

§9-1 の通り「フェード時間」は view の In/Out 処理の placeholder。POC では各 view が独立に duration を抽選する。

**抽選ルール** (ViewBase の標準実装):
- 約 20% の確率で `0` を返す（「データ不要、即時表示できる」ケースの placeholder）
- それ以外は 200〜800 ms の一様乱数

`0` が出た場合は **アニメーションをスキップ + opacity を直接代入 + `Qt.callLater` で完了報告を遅延** する。

```qml
// ViewBase 内部 (抜粋)
function pickDuration() {
    if (Math.random() < 0.2) return 0
    return 200 + Math.floor(Math.random() * 600)
}

function performEnter() {
    var dur = pickDuration()
    if (dur === 0) {
        opacity = 1
        Qt.callLater(reportEnterCompleteDeferred)   // 同期報告だと race / binding loop
    } else {
        enterAnim.duration = dur
        enterAnim.start()                            // 完了は enterAnim.onStopped で報告
    }
}
function reportEnterCompleteDeferred() {
    TransitionManager.reportEnterComplete(thisViewId)
}
```

`Qt.callLater` で遅延する理由は **ClosingView の即完了 Enter と同じ** (§10-2-1 で詳述):

- `reportEnterComplete` を同期で呼ぶと、その内部の `finalizeTransition` が `viewSlotXLifecycle` を書き換える
- そのまま `myLifecycle` binding に逆流して "Binding loop detected" 警告
- さらに startTransition がまだ leaving 側 lifecycle を書く前に finalize が走ると、leaving view が leave アニメ無しで破棄される race
- → 1 イベントループ遅らせて binding 連鎖を切る


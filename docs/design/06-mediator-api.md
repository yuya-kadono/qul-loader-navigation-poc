## 6. Mediator API と履歴トラッキング

### 6-1. Mediator が公開するインターフェース

```qml
// Mediator/Mediator.qml (singleton)
pragma Singleton
import QtQuick
import Constants            // ViewId, NavDirection を使う

QtObject {
    // 現在のView ID (整数、ViewId enum)。遷移開始時点で targetId に更新される
    property int currentViewId:  0

    // 直前のView ID (戻り先のカーソル位置復元等に使う)
    property int previousViewId: 0

    // 履歴 (int 配列、古い順、末尾が previousViewId と一致)
    property var history: []

    // ★ 次にロードされる view の ID (§9-10: ViewBase が自己取得用に参照)
    // switchView の冒頭で **先行公開** する。同一 QML を複数 ID で再利用する
    // view (例: Sample2View が sample2a/sample2b 両対応) が自分の thisViewId を
    // 動的に決めるためのスナップショット元。
    property int pendingViewId: 0

    // ---- 遷移 API ----
    // ID (int) と direction を指定して遷移する (これが唯一の遷移 API)
    // direction は NavDirection.Next / Back (§9-3)
    function switchView(viewId, direction) {
        // direction 省略時のデフォルトは NavDirection.Next
        // 1. pendingViewId = viewId を先行公開 (ViewBase の自己取得用)
        // 2. 旧 currentViewId を history に push、previousViewId に保存
        // 3. currentViewId = viewId
        // 4. TransitionManager.startTransition(viewId, direction) を呼ぶ
        // 5. closing/closing への遷移なら history をクリア (中断時の戻り先は固定で home なので履歴不要)
    }
}
```

`goNext()` / `goBack()` は **提供しない**。戻り先・進み先の判断は各 view の責務（§5-3）。  
**方向（Next/Back）**も view が明示する。BACK キーで戻る経路なら view 自身が `NavDirection.Back` を指定して `switchView` を呼ぶ。これにより遷移先 view は `directionOf(thisViewId)` で「どちら向きで来たか」を知れる（§9-4）。

### 6-2. 履歴トラッキングの方針

- `switchView` 呼び出し時、旧 `currentViewId` を `history` の末尾に push
- 同時に `previousViewId` を旧 `currentViewId` に更新
- `history` は view から read-only に参照可能で、複数前まで遡って戻り先カーソル位置を判定する用途で使う
- `Closing/Closing` へ遷移するタイミングで `history` をクリア（中断時の戻り先は固定で `Normal/Home` なので履歴不要）
- 履歴はView ID の int 値のみ。Screen情報は `ViewId.screenOf(viewId)` で復元できる

**view 側の利用例**:

```qml
// MenuView.qml (一部、戻り時のカーソル位置復元)
// ※ viewId は整数 (ViewId enum)、ViewBase の onEntering フックで処理
function onEntering() {
    var prev = Mediator.previousViewId
    if (prev === ViewId.NormalSample2b) {
        cursorIndex = 2
    } else if (prev === ViewId.NormalSample2a) {
        cursorIndex = 1
    } else {
        cursorIndex = 0   // Sample 1 (デフォルト)
    }
}
```

```qml
// OkView.qml / NgView.qml (例: BACK で menu に戻る、direction = Back)
// ViewBase 派生 (§9-10) — onViewKey フックを override するだけ
ViewBase {
    thisViewId: ViewId.NormalOkView  // 仮の ID。ViewId enum に追加が前提
    displayName: "OK"
    function onViewKey(vk, ve) {
        if (vk === VirtualKey.Back && ve === VirtualEvent.Click) {
            Mediator.switchView(ViewId.NormalMenu,
                                     NavDirection.Back)
        }
    }
}
```

### 6-3. Screen切替とView解決

- 実際の Loader スロット切替・ライフサイクル通知は **TransitionManager**（§9）に委譲する
- Mediator は「どこへどの向きで遷移したいか」を判断し、`TransitionManager.startTransition(viewId, direction)` を呼ぶだけ
- `Mediator.currentViewId` は遷移開始時点で targetId に更新する（新コンテンツの初期 binding を解決するため）
- TransitionManager が旧スロット解放と新スロットロード、各 view への lifecycle 通知、両完了の待ち合わせを担い、完了 signal を Mediator に返す


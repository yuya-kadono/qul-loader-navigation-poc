### 9-10. 基底コンポーネント (ScreenBase / ViewBase / Logger)

§8-5 / §9-4 / §9-9 で示したパターンは全 Screen / View で共通になるため、基底コンポーネントに括り出してある。

#### ScreenBase.qml — Screen の共通骨格

派生 Screen は `thisScreenId` (`ScreenId.*` の整数値) と、必要なら `handleAbsorb(vk, ve)` を override するだけ。

```qml
// ScreenBase.qml (構造の要約)
Item {
    property int thisScreenId: 0
    function handleAbsorb(vk, ve) { return false }   // 派生で override

    // KeyDispatcher 監視 (Connections 不使用、§8-3 の property-token パターン)
    property int screenEventGen: KeyDispatcher.screenEventGen
    property bool ready: false
    Component.onCompleted: ready = true
    onScreenEventGenChanged: {
        if (!ready) return
        if (handleAbsorb(KeyDispatcher.screenEventVk, KeyDispatcher.screenEventVe)) return
        KeyDispatcher.dispatchToView(KeyDispatcher.screenEventVk,
                                     KeyDispatcher.screenEventVe)
    }

    // 派生で「views を配置する領域」を Item で指定できる。デフォルトは screen 全体。
    // 派生で `viewArea: contentArea` のように bind すると ViewSlot A/B が contentArea に
    // anchors.fill するので、Header/Footer/Aside など chrome を周囲に配置できる。
    // (NormalScreen はこれを使って 4:3 中央領域に view を閉じ込めている)
    property Item viewArea: screen

    // ViewSlot A/B — screen フィルタ binding (§9-9)、anchors.fill: screen.viewArea
    Loader { id: viewSlotA; anchors.fill: screen.viewArea; /* source = screen match check */ }
    Loader { id: viewSlotB; anchors.fill: screen.viewArea; /* same */ }
}
```

派生 screen で chrome を持ちたい場合の例 (NormalScreen):

```qml
ScreenBase {
    thisScreenId: ScreenId.Normal
    Rectangle { id: headerArea; anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; height: 60; color: "#141414" }
    Rectangle { id: footerArea; anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; height: 60; color: "#141414" }
    Rectangle { id: asideLArea; anchors.top: headerArea.bottom; anchors.bottom: footerArea.top; anchors.left: parent.left; width: 80; color: "#141414" }
    Rectangle { id: asideRArea; anchors.top: headerArea.bottom; anchors.bottom: footerArea.top; anchors.right: parent.right; width: 80; color: "#141414" }
    Item { id: contentArea; anchors.top: headerArea.bottom; anchors.bottom: footerArea.top; anchors.left: asideLArea.right; anchors.right: asideRArea.left }
    viewArea: contentArea   // ★ これで views は中央 640×480 に閉じ込められる
}
```

(Opening/Closing screen は viewArea を override しないので、views は画面全体に描画される。)

#### ViewBase.qml — 標準 View の共通骨格

派生 View は `thisViewId` / `displayName` / `backgroundColor` を指定し、必要なら以下のフックを override:

| フック | 用途 |
| --- | --- |
| `onEntering()` / `onLeaving()` | lifecycle 検知時の前処理（例: MenuView の cursor 初期化） |
| `performEnter()` / `performLeave()` | Enter / Leave アニメ起動を **完全置換** (例: Opening の 1.5s ParallelAnimation, Closing の即完了+内部別走) |
| `onViewKey(vk, ve)` | viewEventGen 経由で受け取った仮想キーへの反応 |

標準実装としては、以下を提供する:
- 上部に **情報 Column** (displayName / thisViewId / direction / from / prev / history.length) — `showInfo: false` で抑止可
- 背景 Rectangle
- 標準 `enterAnim` / `leaveAnim` (opacity 0↔1、duration は §9-3-2 のランダム抽選)
- KeyDispatcher.viewEventGen を `property + onViewEventGenChanged + ready` で購読し `onViewKey()` に分配
- lifecycle 変化を購読 (`onMyLifecycleChanged`) し `performEnter` / `performLeave` を起動
- **`thisViewId` の自己取得 (同一 QML 多重 ID 対応)** — 下記サブセクション参照

これにより派生 View はおおむね 20-40 行で書ける（HomeView / Sample1View / Sample2View が好例）。

##### thisViewId の決め方 (2 パターン)

| パターン | 派生 view の書き方 | 適用例 |
| --- | --- | --- |
| **明示指定** | `thisViewId: ViewId.NormalHome` | 単一 ID の view (Home / Menu / Sample1 / Opening / Closing) |
| **自己取得 (未指定)** | `thisViewId` を書かない (デフォルト 0 のまま) | **同一 QML を複数 ID で再利用** する view (Sample2View が sample2a / sample2b 両対応) |

自己取得の流れ:

1. 派生 view (例: `Sample2View.qml`) は `thisViewId` を明示しない → 初期値 0
2. `Mediator.switchView(viewId)` の冒頭で `Mediator.pendingViewId = viewId` が **先行公開** される (§6-1)
3. `TransitionManager.startTransition` → Loader.source 変更 → Sample2View 構築
4. ViewBase の `Component.onCompleted` で `thisViewId === 0` を検知 → `Mediator.pendingViewId` からスナップショット
5. 以降は自分の ID で lifecycle/direction/partner を解決し、内部変数 (`isVariantA`/`isVariantB` 等) で挙動分岐

```qml
// ViewBase.qml の onCompleted (要点)
Component.onCompleted: {
    if (root.thisViewId === 0) {
        root.thisViewId = Mediator.pendingViewId   // ★ 自己取得
    }
    if (!reactedInitial) reactToLifecycle()
    readyForKeys = true
}
```

```qml
// Sample2View.qml の派生 (thisViewId 明示しない)
ViewBase {
    // thisViewId は ViewBase が Mediator.pendingViewId から動的取得
    readonly property bool isVariantA: thisViewId === ViewId.NormalSample2a
    readonly property bool isVariantB: thisViewId === ViewId.NormalSample2b

    displayName: isVariantA ? "SAMPLE 2A" : "SAMPLE 2B"
    backgroundColor: isVariantA ? "#6a1b9a" : "#283593"
    // ...
}
```

これにより、見た目や挙動がほぼ同じだが履歴/カーソル復元の対象として別 ID にしたい複数 view を、**継承で派生クラスを増やすことなく 1 つの QML で表現** できる。

`Mediator.pendingViewId` の衝突可能性: 同時に複数 view がロード中になることはない（進行中 transition の entering view は常に 1 つ）ため、衝突は起きない。

#### Logger.qml — 統一ログ singleton

全 singleton / Screen / View / Main がフローを `console.log` するための共通フォーマット singleton。`[HH:MM:SS.mmm] Component.fn(args) | params` 形式。enum 値の人間可読化は各 enum singleton の nameOf に分離した (`VirtualKey.nameOf(vk)`, `VirtualEvent.nameOf(ev)`, `NavDirection.nameOf(d)`, `ViewLifecycle.nameOf(lc)`, `ScreenId.nameOf(sid)`, `ViewId.nameOf(vid)`)。Logger 本体は時刻付き整形と `console.log` のみを担う。

QUL 移植性メモ: `new Date()` を使う部分は **デスクトップ Qt 6 でのフロー検証用** 前提。本物の MCU 移植時は時計取得 API か、単純なフレームカウンタに置き換える。


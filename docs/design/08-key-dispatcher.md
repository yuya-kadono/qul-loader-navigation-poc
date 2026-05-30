## 8. 仮想キー入力層

実機 MCU の物理ボタンを模すため、PC キーボードの物理キーを「仮想キー」に変換してアプリ内に配送する層を設ける。アプリ側はどの物理キーが押されたかには依存せず、仮想キーだけを扱う。

### 8-1. 物理キー → 仮想キー対応

| 物理キー | 仮想キー | 想定用途 |
| ---     | ---      | --- |
| A       | `PREV`   | 前候補（リスト等のカーソル前移動） |
| S       | `ENTER`  | 決定 |
| D       | `NEXT`   | 次候補（リスト等のカーソル次移動） |
| Z       | `MENU`   | メニュー呼び出し |
| X       | `HOME`   | ホーム画面へ |
| C       | `BACK`   | 戻る |

### 8-2. 仮想イベント

仮想キー 1 つにつき、以下 3 種類の仮想イベントを発火する。

| 仮想イベント | 発火タイミング |
| ---         | --- |
| `PRESS`     | 物理キー押下時（`autoRepeat` は無視） |
| `RELEASE`   | 物理キー開放時 |
| `CLICK`     | 同じキーで PRESS→RELEASE の対が成立したら **RELEASE 直後に追加発火** |

長押し検出（`LONG_PRESS` 等）は POC スコープ外。必要なら後から拡張する。

### 8-3. KeyDispatcher singleton

仮想キー種別・仮想イベントは `int` 定数として singleton に保持する。
配送は **「世代カウンタ」property + 「最終値」property** の組み合わせで表現する（§2-3 の方針）。signal + `Connections{target: KeyDispatcher}` は QUL での使用を避けるため採用しない。

screen 用と view 用で別々の世代カウンタを持つ。「Screenが先に受け取り、必要に応じてViewへ転送する」という配送順序は、Screen 側ハンドラが終わってから Screen が `dispatchToView()` を呼ぶ、というフロー制御で保証する。

```qml
// Mediator/KeyDispatcher.qml (singleton)
pragma Singleton
import QtQuick
import Constants            // VirtualKey, VirtualEvent を使う

QtObject {
    // ---- 仮想キー種別 ----
    readonly property int keyPrev:  0
    readonly property int keyEnter: 1
    readonly property int keyNext:  2
    readonly property int keyMenu:  3
    readonly property int keyHome:  4
    readonly property int keyBack:  5

    // ---- 仮想イベント種別 ----
    readonly property int evPress:   0
    readonly property int evRelease: 1
    readonly property int evClick:   2

    // ---- 入力受付フラグ ----
    // false の間は dispatchToScreen / dispatchToView が no-op になる。
    // TransitionManager が遷移中に false にする (§9-7)。
    property bool enabled: true

    // ---- Screen 向け配送状態 (signal 代替) ----
    // screenEventGen を Screen 側がローカル binding 経由で監視する。
    // 値そのものに意味はなく、変化したら「新規イベントあり」のしるし。
    property int screenEventGen: 0
    property int screenEventVk:  0
    property int screenEventVe:  0

    // ---- View 向け配送状態 ----
    property int viewEventGen: 0
    property int viewEventVk:  0
    property int viewEventVe:  0

    // ---- 配送 API ----
    function dispatchToScreen(vk, ve) {
        if (!enabled) return
        screenEventVk = vk
        screenEventVe = ve
        screenEventGen = screenEventGen + 1   // 受け手の binding を駆動
    }
    function dispatchToView(vk, ve) {
        if (!enabled) return
        viewEventVk = vk
        viewEventVe = ve
        viewEventGen = viewEventGen + 1
    }
}
```

受け手側 (Screen / View) は次の **property-token + on*Changed + ready ガード** パターンで購読する:

```qml
Item {
    property int screenEventGen: KeyDispatcher.screenEventGen   // ローカルにミラー
    property bool ready: false
    Component.onCompleted: ready = true                       // 初期 binding 評価を skip するガード

    onScreenEventGenChanged: {
        if (!ready) return
        var vk = KeyDispatcher.screenEventVk
        var ve = KeyDispatcher.screenEventVe
        // ... 処理
    }
}
```

`ready` フラグは QML の binding 初回評価で `onXxxChanged` が発火するケースに対する保険。
これにより `Connections{target: KeyDispatcher}` を使わずに同等の通知を得られる。

### 8-4. Main.qml の変換層

物理キー → 仮想キーの変換は `Main.qml` の `Keys` ハンドラで行う。CLICK は RELEASE 時に合成する。

```qml
// Main.qml (抜粋)
Window {
    focus: true

    // PRESS 中のキーを記録して CLICK 判定に使う
    property int pressedPhysicalKey: -1

    Keys.onPressed: function(event) {
        if (event.isAutoRepeat) return
        var vk = physicalToVirtual(event.key)
        if (vk < 0) return
        pressedPhysicalKey = event.key
        KeyDispatcher.dispatchToScreen(vk, VirtualEvent.Press)
        event.accepted = true
    }

    Keys.onReleased: function(event) {
        if (event.isAutoRepeat) return
        var vk = physicalToVirtual(event.key)
        if (vk < 0) return
        KeyDispatcher.dispatchToScreen(vk, VirtualEvent.Release)
        // PRESS→RELEASE の対が成立していれば CLICK も発火
        if (pressedPhysicalKey === event.key) {
            KeyDispatcher.dispatchToScreen(vk, VirtualEvent.Click)
            pressedPhysicalKey = -1
        }
        event.accepted = true
    }

    function physicalToVirtual(key) {
        switch (key) {
            case Qt.Key_A: return VirtualKey.Prev
            case Qt.Key_S: return VirtualKey.Enter
            case Qt.Key_D: return VirtualKey.Next
            case Qt.Key_Z: return VirtualKey.Menu
            case Qt.Key_X: return VirtualKey.Home
            case Qt.Key_C: return VirtualKey.Back
        }
        return -1
    }
}
```

#### 8-4-1. POC 専用の Main.qml 拡張 (production 移植時に削除)

実際の POC 実装はこの最小例に加えて以下を持つ。すべて debug / 動作確認の補助で、実機 MCU 移植時には Main.qml ごと書き換える前提:

- **同時押し検出 (conflict mode)**: PC キーボードでテスト中の指の滑り (A 押下中に S を触ってしまう等) で View に不整合な Press/Release シーケンスが届くと不可解な挙動を招くため、本層で同時押しを検出して dispatch を抑制する。`property var pressedKeys: []` で物理押下中のキー集合を追跡し、2 つ目のキー押下で `conflictMode = true` 確定。この瞬間に先押しキーの Release を **pre-emptive dispatch** して View の押下色などの状態をクリーンに戻し、以後の Press/Release は一切 dispatch しない (Click も発火させない)。全キーが離れた時点で conflict 解除。
- **隠しジャンプキー (debug 用ショートカット)**: `Qt.Key_1`〜`Qt.Key_5` を押すと `Mediator.switchView(target, NavDirection.Next)` で対応 view へ直接遷移 (`1`→home、`2`→menu、`3`→sample1、`4`→sample2a、`5`→sample2b)。物理キー追跡 / conflict 検出を完全バイパス。通常の switchView 経由なので history も普通に更新される。
- **右上 debug overlay**: `currentViewId` / `previousViewId` / `pendingViewId` / `history.length` / TransitionManager の slot 状態 / 物理押下キー数と conflict 状態を半透明 Rectangle にライブ表示。
- **左下ミニキーボード overlay**: QWERTY 左下部 (Q/W/E/R + A/S/D/F + Z/X/C/V) を実物配置で再現。使用キーに仮想キー名併記、未使用キーはグレー。押下中は黄色枠 (正常 dispatch)、conflict 中は赤枠 (dispatch 抑制中の警告)。

### 8-5. 2 段配送（Dispatcher → Screen → View）

配送経路は次のとおり。Screen / View はそれぞれ KeyDispatcher の **世代カウンタプロパティを ローカルにバインド** して購読する（§8-3）。

```
Main.qml (物理キー)
   │ dispatchToScreen(vk, ev)
   │   → KeyDispatcher.screenEventGen を ++
   ▼
各 Screen の onScreenEventGenChanged が発火
   │
   │  (Screen の handleAbsorb() が判断)
   ├── 自分で処理 (吸収) →  そこで完結。Viewへは転送しない
   │
   └── Viewへ転送するキー →  KeyDispatcher.dispatchToView(vk, ev)
                                  │   → KeyDispatcher.viewEventGen を ++
                                  ▼
                              各 View の onViewEventGenChanged が発火 → View 側ハンドラ
```

実装の共通骨格は **ScreenBase / ViewBase** 基底コンポーネントに集約（§9-10）。派生 Screen / View はフックを override するだけでよい。

Screen 側の典型実装（NormalScreen の例）:

```qml
// NormalScreen.qml
ScreenBase {
    thisScreenId: ScreenId.Normal

    // 吸収判断のフックを override。true を返すと view に転送しない。
    function handleAbsorb(vk, ve) {
        if (ve === VirtualEvent.Click) {
            if (vk === VirtualKey.Menu) {
                Mediator.switchView(ViewId.NormalMenu,
                                         NavDirection.Next)
                return true
            }
            if (vk === VirtualKey.Home) {
                Mediator.switchView(ViewId.NormalHome,
                                         NavDirection.Next)
                return true
            }
        }
        return false
    }
}
```

ScreenBase 内部（参考）— KeyDispatcher 監視は `Connections` ではなく property binding + `on*Changed`:

```qml
// ScreenBase.qml (抜粋)
property int screenEventGen: KeyDispatcher.screenEventGen   // ローカル binding
property bool ready: false
Component.onCompleted: ready = true

onScreenEventGenChanged: {
    if (!ready) return
    var vk = KeyDispatcher.screenEventVk
    var ve = KeyDispatcher.screenEventVe
    if (handleAbsorb(vk, ve)) return         // 派生のフック
    KeyDispatcher.dispatchToView(vk, ve)     // 吸収されなければ view へ
}
```

View 側の典型実装:

```qml
// MenuView.qml (例)
ViewBase {
    thisViewId: ViewId.NormalMenu
    displayName: "MENU"

    function onViewKey(vk, ve) {              // ViewBase のフックを override
        if (ve !== VirtualEvent.Click) return
        switch (vk) {
            case VirtualKey.Prev:  /* カーソル前 */ break
            case VirtualKey.Next:  /* カーソル次 */ break
            case VirtualKey.Enter: /* 選択中項目で switchView */ break
            case VirtualKey.Back:
                Mediator.switchView(ViewId.NormalHome,
                                         NavDirection.Back)
                break
        }
    }
}
```

ViewBase 内部も同じ property-token + `on*Changed + ready` パターンで viewEventGen を購読し、`onViewKey(vk, ve)` フックに分配する（§9-10）。

### 8-6. Screen別の吸収ルール

| Screen   | 吸収するキー（イベント） | 吸収後の動作 |
| ---     | --- | --- |
| opening | なし（Enter 中は `KeyDispatcher.enabled=false` で入力到達しない） | — |
| normal  | `MENU` CLICK              | `Mediator.switchView(ViewId.NormalMenu, Next)` |
| normal  | `HOME` CLICK              | `Mediator.switchView(ViewId.NormalHome, Next)` |
| closing | なし（Screen は素通し、ClosingView 側で処理） | — |

吸収対象は CLICK のみ。`MENU` / `HOME` / `BACK` の PRESS / RELEASE は吸収せずViewに転送する（ホールド表現等の余地を残す）。

closing の `BACK` / `HOME` CLICK は **ClosingView の `onViewKey` 側で受信**して中断手順を実行する（§10-3）。ClosingView の Enter は即完了で `state=Idle` に戻るため `KeyDispatcher.enabled=true` に復帰しており、内部 Timer 進行中も Screen → View まで入力が流れる。


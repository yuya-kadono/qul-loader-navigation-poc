## 10. Opening / Closing: 統一ライフサイクル上での実装パターン

Opening と Closing も §9 の view 主導ライフサイクルに乗せる。「特殊な screen」ではなく、ライフサイクル契約の **2 つの実装パターン**として扱う。

| 観点                       | OpeningView                        | ClosingView                                |
| ---                        | ---                                | ---                                        |
| Enter 完了までの時間       | 長い (1800ms、演出アニメ完了まで) | 即時 (Qt.callLater で 1 tick 遅延報告)     |
| Enter 中の `KeyDispatcher` | `state=InProgress` で無効          | `state=Idle` ですぐ enable に戻る          |
| Enter 完了後の挙動         | 自分で `switchView(home)`     | 内部 Timer 起動 (3000ms 後 Qt.quit)        |
| 入力割り込み               | 不可（スキップ禁止、ユーザ要件）   | 可（Timer 中、BACK/HOME で abort）         |
| 終端動作                   | leave → 次 view (home) に交代      | 自然完了 → `Qt.quit()`、中断時は home へ |
| ビジュアル                 | 5 本の sine 波が **広がる**       | 5 本の sine 波が **収束する**             |
| 描画方式                   | `Shape` + `ShapePath` + `PathPolyline` で連続実線 (Qt6::QuickShapes 必要) | 同上 |
| 流れ方向                   | L→R                               | R→L                                       |

### 10-1. Opening: 「長い Enter」パターン

Enter 中に演出アニメを実行し、完了で `reportEnterComplete` する。完了と同時に `switchView("Normal/Home", Next)` を発火し、自分は leave される側に移る。`performEnter` を override してカスタムアニメを起動するだけ。`performLeave` は ViewBase の標準（ランダム fade-out）をそのまま使う。

```qml
// OpeningView.qml (ViewBase 派生、抜粋)
import QtQuick
import QtQuick.Shapes
import Constants
import Mediator

ViewBase {
    id: root
    thisViewId: ViewId.OpeningOpening
    // accentColor 未指定 (POC splash として上部 6px ラインは目立たせない方針)

    // 縦グラデ背景
    Rectangle { anchors.fill: parent; gradient: Gradient { /* 濃紺 → 紺 → 暗紺 */ } }

    // 5 本の sine 波実線 (画面全幅、左右隙間なし、L→R に流れる)
    // 各線が独立した乱数パラメータ (amplitude/frequency/phase/verticalOffset/duration/alpha/lineWidth)
    // 「広がる」: amplitude 0 → target、verticalOffset 0 → target を 1500ms OutCubic で
    Item {
        id: waveContainer
        anchors.left: parent.left; anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter; height: 260
        Repeater {
            model: 5
            delegate: Item {
                id: line
                readonly property real targetAmplitude: 15 + Math.random() * 45
                readonly property real targetVerticalOffset: (Math.random() - 0.5) * 80
                readonly property real frequency: 0.6 + Math.random() * 2.0
                readonly property real phaseOffset: Math.random() * 2 * Math.PI
                readonly property real lineAlpha: 0.35 + Math.random() * 0.4
                readonly property real lineWidth: 1.5 + Math.random() * 2.0
                readonly property int  dotCount: 60   // polyline segments

                property real amplitude: 0
                NumberAnimation on amplitude { from: 0; to: line.targetAmplitude; duration: 1500; easing.type: Easing.OutCubic }
                property real verticalOffset: 0
                NumberAnimation on verticalOffset { from: 0; to: line.targetVerticalOffset; duration: 1500; easing.type: Easing.OutCubic }

                property real wavePhase: 2 * Math.PI
                NumberAnimation on wavePhase { from: 2*Math.PI; to: 0; duration: 2500 + Math.random()*2500; loops: Animation.Infinite }

                Shape {
                    anchors.fill: parent; opacity: line.lineAlpha
                    ShapePath {
                        strokeWidth: line.lineWidth; strokeColor: "#bbdefb"
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
                        PathPolyline {
                            path: {
                                var pts = []
                                for (var i = 0; i <= line.dotCount; ++i) {
                                    pts.push(Qt.point(
                                        i * (waveContainer.width / line.dotCount),
                                        waveContainer.height/2 + line.verticalOffset
                                          + line.amplitude * Math.sin(line.wavePhase
                                              + line.frequency * 2 * Math.PI * i / line.dotCount
                                              + line.phaseOffset)
                                    ))
                                }
                                return pts
                            }
                        }
                    }
                }
            }
        }
    }

    // メインアニメ (opacity 0→1 を 1800ms かけて) 完了で switchView(NormalHome, Next)
    NumberAnimation {
        id: openingEnterAnim
        target: root; property: "opacity"; from: 0; to: 1; duration: 1800
        onStopped: {
            TransitionManager.reportEnterComplete(root.thisViewId)
            Mediator.switchView(ViewId.NormalHome, NavDirection.Next)
        }
    }
    function performEnter() { openingEnterAnim.start() }
}
```

- Enter 中は `state=InProgress` のため `KeyDispatcher.enabled=false`。**ユーザによるスキップは不可**（要件通り）
- Enter 完了で `switchView` 発火 → Mediator → TransitionManager が新 transition を開始 → OpeningView は leave、HomeView は enter

### 10-2. Closing: 「即完了 Enter + 内部アニメ別走」パターン

Closing は中断可能性のため、`KeyDispatcher.enabled` が **`true` のままアニメを再生**する必要がある。そこで、Enter は **即座に完了報告**してしまい、内部アニメは lifecycle と切り離して別途走らせる。

これにより:

- `state` が `Idle` に戻る → `KeyDispatcher.enabled = true`
- 内部アニメの間、ユーザは BACK/HOME を押せる
- 中断時は ClosingView 自身の `onViewKey` が BACK/HOME Click を受信し、内部 Timer を `stop()` してから通常の `switchView(ViewId.NormalHome, Back)` を呼ぶ（§10-3）。中断専用の API （フラグや force-unload）は持たない

```qml
// ClosingView.qml (ViewBase 派生、抜粋)
import QtQuick
import QtQuick.Shapes
import Constants
import Mediator

ViewBase {
    id: root
    thisViewId: ViewId.ClosingClosing

    // 縦グラデ背景 (暗いグレーブルー)
    Rectangle { anchors.fill: parent; gradient: Gradient { /* #263238 → #37474f → #1c272d */ } }

    // 5 本の sine 波実線 (R→L、「収束する」: amplitude initial → 0、verticalOffset initial → 0)
    // 構造は OpeningView と対称 (direction と amplitude アニメ方向だけ逆)
    Item {
        id: waveContainer
        anchors.left: parent.left; anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter; height: 260
        Repeater {
            model: 5
            delegate: Item {
                id: line
                readonly property real initialAmplitude: 15 + Math.random() * 45
                readonly property real initialVerticalOffset: (Math.random() - 0.5) * 80
                // ... 他のパラメータは Opening と同じ ...

                property real amplitude: line.initialAmplitude
                NumberAnimation on amplitude { from: line.initialAmplitude; to: 0; duration: 2500; easing.type: Easing.InCubic }
                property real verticalOffset: line.initialVerticalOffset
                NumberAnimation on verticalOffset { from: line.initialVerticalOffset; to: 0; duration: 2500; easing.type: Easing.InCubic }

                property real wavePhase: 0
                NumberAnimation on wavePhase { from: 0; to: 2*Math.PI; duration: 2500 + Math.random()*2500; loops: Animation.Infinite }

                Shape { /* PathPolyline 構造は OpeningView と同じ、strokeColor だけ "#cfd8dc" */ }
            }
        }
    }

    // 内部 Timer (lifecycle と独立。3000ms 後 Qt.quit、500ms の静止余韻あり)
    // 中断時は下の onViewKey / Component.onDestruction が stop() を呼ぶため、
    // ここに到達した時点で「中断されなかった」= 自然完了と確定する。
    Timer {
        id: closingTimer
        interval: 3000; repeat: false
        onTriggered: Qt.quit()
    }

    // 中断ハンドリング: BACK/HOME Click を ClosingView 自身で捕捉し、
    // 内部 Timer を止めてから通常の switchView で HomeView へ戻る。
    // → Mediator / TransitionManager 側に中断専用 API は一切不要
    function onViewKey(vk, ve) {
        if (ve !== VirtualEvent.Click) return
        if (vk !== VirtualKey.Back && vk !== VirtualKey.Home) return
        closingTimer.stop()                                       // Qt.quit を未然に防ぐ
        Mediator.switchView(ViewId.NormalHome, NavDirection.Back) // 通常の leave/enter サイクル
    }

    // 保険: View 破棄時にも Timer を確実に停止 (onViewKey 経由しない経路への防御)
    Component.onDestruction: {
        if (closingTimer.running) closingTimer.stop()
    }

    function performEnter() {
        opacity = 1                                       // 即時可視
        Qt.callLater(reportEnterCompleteDeferred)         // §10-2-1: 同期報告だと race + binding loop
        closingTimer.start()                              // lifecycle 外で独立動作
    }
    function reportEnterCompleteDeferred() {
        TransitionManager.reportEnterComplete(root.thisViewId)
    }
}
```

Easing は Opening / Closing で対称: Opening は `OutCubic` (素早く立ち上がる勢い)、Closing は `InCubic` (緩やかに死んでいく余韻)。波の流動 (`wavePhase` 無限ループ) と amplitude/verticalOffset の収束アニメは独立に走るので、収束中もずっと流れている。

#### 10-2-1. なぜ Qt.callLater で reportEnterComplete を遅延するか

`reportEnterComplete` を **同期で** 呼ぶと 2 つの問題が起きる:

1. **startTransition との race**: startTransition は (entering 設定 → leaving 設定 → entering source 設定) の順に走る (§9-3-1)。ClosingView の Enter は entering source 設定で即ロードされて synchronously `performEnter` が走る。その中で同期報告すると、まだ leaving 側 lifecycle が `Leaving` に書かれていない時点で `finalizeTransition` が走ってしまい、leaving view が leaveAnim 無しで破棄される
2. **myLifecycle binding loop**: 同期報告で `finalizeTransition` 内が `viewSlotXLifecycle` を書き換えると、binding 経由で `myLifecycle` が再評価される。Qt がそれを binding loop として検出して警告を出す

→ `Qt.callLater` で **1 イベントループ遅らせて** binding 連鎖を切り、startTransition が完了してから report する。

§9-3-2 のランダム 0 duration のケースも全く同じ理由で `Qt.callLater` を使う。

### 10-3. Closing 中断の手順

中断ロジックは **ClosingView の `onViewKey` に集約**する。ClosingScreen 側は素通し（ScreenBase default の `handleAbsorb` が `false` を返すため、CLICK は View まで届く）。

```qml
// ClosingScreen.qml (ScreenBase 派生) — 中断ロジックなし、素通し
ScreenBase {
    thisScreenId: ScreenId.Closing
    // handleAbsorb を override しない (default で false 返却 = 全て View に転送)
}
```

```qml
// ClosingView.qml の onViewKey (§10-2 コードの抜粋)
function onViewKey(vk, ve) {
    if (ve !== VirtualEvent.Click) return
    if (vk !== VirtualKey.Back && vk !== VirtualKey.Home) return
    closingTimer.stop()                                       // 1. 内部 Timer を殺して Qt.quit を防ぐ
    Mediator.switchView(ViewId.NormalHome, NavDirection.Back) // 2. 通常の switchView で HomeView へ
}
```

中断は **2 step** で完了する。Mediator / TransitionManager 側は何も変えていない（特別な「中断モード」を持たない）ことに注目。`switchView` 呼び出しは通常のナビと完全に同じ経路を辿るため、ClosingView は通常通り `performLeave` → `Component.onDestruction` で破棄され、HomeView が enter する。

### 10-4. キャンセル安全性の要件

- **Timer.stop() を switchView より前に**: `closingTimer.stop()` を必ず先に呼ぶ。`switchView()` 経由の通常 leave サイクルは数ミリ秒以上の幅があり、その間に Timer が fire しないことを保証する
- **保険: `Component.onDestruction` での Timer.stop()**: `onViewKey` を経由しない破棄経路 (将来の追加経路など) でも `Qt.quit` が漏れないようにする最後の砦。`if (closingTimer.running)` でガード
- **自然完了との同時発生**: ユーザ Click と Timer fire が同 frame で起こる極端な race は理論上残るが、QML のイベントループ上 onViewKey 内の同期 `stop()` がほぼ確実に先行する。仮に Timer 側が先に fire しても、それは「自然完了」として扱われる (= Qt.quit が呼ばれる) — これは中断 Click が間に合わなかったケースであり仕様通り
- 中断専用 API （`closingAborted` フラグ / `forceUnloadCurrentView`）は **持たない**。「Timer を止めれば Qt.quit() は呼ばれない」という直接的な実装で完結させ、状態フラグや force-unload による分岐を排除した

### 10-5. パターンの一般化

Opening / Closing 以外の view も、この 2 パターン（または併用）から選んで実装する:

- バックエンドリクエストが完了するまで Enter を待つ view = 「長い Enter」パターン
- 即時表示できる view = 「即完了 Enter」パターン
- 経路に応じて両方使い分ける view = `directionOf` / `partnerOf` を見て分岐

「フェードイン/フェードアウト」は POC でこれらを表現するための最も単純な手段に過ぎず、本物のアプリでは各 view が自身の事情で Enter / Leave 処理の中身と所要時間を決める。


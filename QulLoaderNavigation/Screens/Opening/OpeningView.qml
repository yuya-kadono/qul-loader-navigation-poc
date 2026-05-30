// OpeningView.qml
// Opening: 「長い Enter」パターン (§10-1)。
// ビジュアル: 縦グラデ背景 + 画面全幅に走る 5 本の sine 波 **実線** (L→R)。
// 「広がる」表現: 各線の振幅と縦オフセットを 0 から乱数最大値へアニメーション。
//   起動直後: 中央に重なった平らな 5 本 (見た目は実質 1 本の水平線)
//   1500ms 経過: 振幅を持ち、縦に散らばった 5 本の波が L→R に流れる
//
// 実装: Shape + ShapePath + PathPolyline で連続パス描画 (Qt 6 の QtQuick.Shapes)。
//   1 line あたり 60 セグメントの polyline で sine を近似 → アンチエイリアスされた滑らかな曲線。
//   path: は line.wavePhase/amplitude/verticalOffset を参照するので、それらの変化で
//   バインディング再評価 → 毎フレーム re-render される。
//
// メインアニメ: root.opacity を 0→1 にフェードイン (1800ms)、完了で Normal/Home へ遷移。

import QtQuick
import QtQuick.Shapes
import Constants
import Mediator

ViewBase {
    id: root

    thisViewId: ViewId.OpeningOpening

    // ---- 縦グラデーション背景 ----
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#1a237e" }
            GradientStop { position: 0.5; color: "#0d47a1" }
            GradientStop { position: 1.0; color: "#062366" }
        }
    }

    // ---- 複数本の sine 波実線 (画面全幅、左右隙間なし) ----
    Item {
        id: waveContainer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: 260

        Repeater {
            model: 5  // 5 本重ね
            delegate: Item {
                id: line
                anchors.fill: parent

                // ---- 乱数パラメータ (instantiation 時に 1 回だけ確定) ----
                readonly property real targetAmplitude: 15 + Math.random() * 45
                readonly property real targetVerticalOffset: (Math.random() - 0.5) * 80
                readonly property real frequency: 0.6 + Math.random() * 2.0
                readonly property real phaseOffset: Math.random() * 2 * Math.PI
                readonly property real lineAlpha: 0.35 + Math.random() * 0.4
                readonly property real lineWidth: 1.5 + Math.random() * 2.0
                readonly property int segmentCount: 60

                // ---- 広がりアニメーション: 0 → target ----
                property real amplitude: 0
                NumberAnimation on amplitude {
                    from: 0; to: line.targetAmplitude
                    duration: 1500
                    easing.type: Easing.OutCubic
                    running: true
                }
                property real verticalOffset: 0
                NumberAnimation on verticalOffset {
                    from: 0; to: line.targetVerticalOffset
                    duration: 1500
                    easing.type: Easing.OutCubic
                    running: true
                }

                // ---- wave 駆動位相 (2π → 0 で L→R に伝播、永続ループ) ----
                property real wavePhase: 2 * Math.PI
                NumberAnimation on wavePhase {
                    from: 2 * Math.PI; to: 0
                    duration: 2500 + Math.random() * 2500
                    loops: Animation.Infinite
                    running: true
                }

                // ---- 実線描画 ----
                Shape {
                    anchors.fill: parent
                    opacity: line.lineAlpha
                    ShapePath {
                        strokeWidth: line.lineWidth
                        strokeColor: "#bbdefb"
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        joinStyle: ShapePath.RoundJoin
                        PathPolyline {
                            path: {
                                var pts = []
                                var w = waveContainer.width
                                var h = waveContainer.height
                                var n = line.segmentCount
                                for (var i = 0; i <= n; ++i) {
                                    pts.push(Qt.point(
                                        i * (w / n),
                                        h / 2 + line.verticalOffset
                                        + line.amplitude * Math.sin(line.wavePhase
                                                                    + line.frequency * 2 * Math.PI
                                                                      * i / n
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

    // ---- メインアニメ (完了で次画面へ遷移) ----
    NumberAnimation {
        id: openingEnterAnim
        target: root; property: "opacity"
        from: 0; to: 1
        duration: 1800
        onStopped: {
            Logger.log(ViewId.nameOf(root.thisViewId), "openingEnterAnim.onStopped",
                       "", "duration=1800ms (long-enter pattern)")
            TransitionManager.reportEnterComplete(root.thisViewId)
            Logger.log(ViewId.nameOf(root.thisViewId), "self-trigger",
                       "after enter complete",
                       "switchView(Normal/Home, Next)")
            Mediator.switchView(ViewId.NormalHome, NavDirection.Next)
        }
    }

    function performEnter() {
        Logger.log(ViewId.nameOf(root.thisViewId), "performEnter (custom)", "",
                   "openingEnterAnim.start (1800ms)")
        openingEnterAnim.start()
    }
}

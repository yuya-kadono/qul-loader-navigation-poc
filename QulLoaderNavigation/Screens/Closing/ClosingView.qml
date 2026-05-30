// ClosingView.qml
// Closing: 「即完了 Enter + 内部別走アニメ」パターン (§10-2)。
// ビジュアル: 縦グラデ背景 + 画面全幅に走る 5 本の sine 波 **実線** (R→L、Opening と逆方向)。
// 「収束する」表現: 各線の振幅と縦オフセットを 初期最大値 から 0 へアニメーション。
//   起動直後: 縦に散らばった 5 本の波が R→L に流れる
//   2500ms 経過: 振幅 0、中央に重なった平らな 5 本 (実質 1 本の水平線)
// → 3000ms で Qt.quit (500ms の静止余韻)。
// Opening と対称構造: Shape + PathPolyline で連続パス、direction だけ逆。

import QtQuick
import QtQuick.Shapes
import Constants
import Mediator

ViewBase {
    id: root

    thisViewId: ViewId.ClosingClosing

    // ---- 縦グラデーション背景 ----
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#263238" }
            GradientStop { position: 0.5; color: "#37474f" }
            GradientStop { position: 1.0; color: "#1c272d" }
        }
    }

    // ---- 複数本の sine 波実線 (画面全幅、左右隙間なし、R→L、収束) ----
    Item {
        id: waveContainer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: 260

        Repeater {
            model: 5
            delegate: Item {
                id: line
                anchors.fill: parent

                // ---- 乱数パラメータ (Opening と同じレンジ) ----
                readonly property real initialAmplitude: 15 + Math.random() * 45
                readonly property real initialVerticalOffset: (Math.random() - 0.5) * 80
                readonly property real frequency: 0.6 + Math.random() * 2.0
                readonly property real phaseOffset: Math.random() * 2 * Math.PI
                readonly property real lineAlpha: 0.35 + Math.random() * 0.4
                readonly property real lineWidth: 1.5 + Math.random() * 2.0
                readonly property int segmentCount: 60

                // ---- 収束アニメーション: initial → 0 ----
                property real amplitude: line.initialAmplitude
                NumberAnimation on amplitude {
                    from: line.initialAmplitude; to: 0
                    duration: 2500
                    easing.type: Easing.InCubic
                    running: true
                }
                property real verticalOffset: line.initialVerticalOffset
                NumberAnimation on verticalOffset {
                    from: line.initialVerticalOffset; to: 0
                    duration: 2500
                    easing.type: Easing.InCubic
                    running: true
                }

                // ---- wave 駆動位相 (0 → 2π で R→L に伝播、永続ループ) ----
                property real wavePhase: 0
                NumberAnimation on wavePhase {
                    from: 0; to: 2 * Math.PI
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
                        strokeColor: "#cfd8dc"
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

    // ---- 内部 Timer (lifecycle と独立。3 秒後 Qt.quit) ----
    Timer {
        id: closingTimer
        interval: 3000
        running: false
        repeat: false
        onTriggered: {
            Logger.log(ViewId.nameOf(root.thisViewId), "closingTimer.onTriggered", "",
                       "closingAborted=" + Mediator.closingAborted)
            if (!Mediator.closingAborted) {
                Logger.log(ViewId.nameOf(root.thisViewId), "Qt.quit", "",
                           "natural completion")
                Qt.quit()
            } else {
                Logger.log(ViewId.nameOf(root.thisViewId), "Qt.quit SUPPRESSED",
                           "closingAborted=true", "")
            }
        }
    }

    function performEnter() {
        opacity = 1
        Logger.log(ViewId.nameOf(root.thisViewId), "performEnter (custom)",
                   "", "deferred reportEnterComplete via Qt.callLater")
        Qt.callLater(reportEnterCompleteDeferred)
        Logger.log(ViewId.nameOf(root.thisViewId), "closingTimer.start", "",
                   "interval=3000ms")
        closingTimer.start()
    }

    function reportEnterCompleteDeferred() {
        Logger.log(ViewId.nameOf(root.thisViewId), "deferred reportEnterComplete", "",
                   "called via Qt.callLater")
        TransitionManager.reportEnterComplete(root.thisViewId)
    }
}

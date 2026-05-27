// OpeningView.qml
// Opening: 「長い Enter」パターン (§10-1)。
// ViewBase の performEnter を override してカスタムアニメ (1.5s フェード+スケール)。
// アニメ完了で reportEnterComplete + 自分から requestNavigate(home, Next)。

import QtQuick
import QulLoaderNavigation

ViewBase {
    id: root
    thisViewId: NavigationTable.idOpeningOpening
    backgroundColor: "#0d47a1"   // dark blue
    showInfo: false

    Text {
        id: openingText
        anchors.centerIn: parent
        text: "OPENING"
        color: "white"
        font.pixelSize: 64
        font.bold: true
        scale: 0.5
    }
    Text {
        anchors.top: openingText.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 20
        text: "opening/opening — 長い Enter パターン"
        color: "#bbdefb"
        font.pixelSize: 14
    }

    ParallelAnimation {
        id: openingEnterAnim
        NumberAnimation { target: root;        property: "opacity"; from: 0;   to: 1; duration: 1500 }
        NumberAnimation { target: openingText; property: "scale";   from: 0.5; to: 1; duration: 1500; easing.type: Easing.OutBack }
        onStopped: {
            Logger.log(NavigationTable.nameOf(root.thisViewId), "openingEnterAnim.onStopped",
                       "", "duration=1500ms (long-enter pattern)")
            TransitionManager.reportEnterComplete(root.thisViewId)
            Logger.log(NavigationTable.nameOf(root.thisViewId), "self-trigger",
                       "after enter complete",
                       "requestNavigate(normal/home, Next)")
            Mediator.requestNavigate(NavigationTable.idNormalHome,
                                     TransitionManager.directionNext)
        }
    }

    function performEnter() {
        Logger.log(NavigationTable.nameOf(root.thisViewId), "performEnter (custom)", "",
                   "openingEnterAnim.start (1500ms)")
        openingEnterAnim.start()
    }
}

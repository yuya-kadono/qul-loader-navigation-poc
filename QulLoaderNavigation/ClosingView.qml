// ClosingView.qml
// Closing: 「即完了 Enter + 内部別走アニメ」パターン (§10-2)。

import QtQuick
import QulLoaderNavigation

ViewBase {
    id: root
    thisViewId: NavigationTable.idClosingClosing
    backgroundColor: "#37474f"
    showInfo: false

    Text {
        id: closingText
        anchors.centerIn: parent
        text: "CLOSING"
        color: "white"
        font.pixelSize: 64
        font.bold: true
    }
    Text {
        anchors.top: closingText.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 20
        text: "closing/closing — BACK(C) または HOME(X) で中断"
        color: "#cfd8dc"
        font.pixelSize: 14
    }

    NumberAnimation {
        id: internalAnim
        target: closingText; property: "opacity"; from: 1; to: 0
        duration: 3000
        onStopped: {
            Logger.log(NavigationTable.nameOf(root.thisViewId), "internalAnim.onStopped", "",
                       "closingAborted=" + Mediator.closingAborted)
            if (!Mediator.closingAborted) {
                Logger.log(NavigationTable.nameOf(root.thisViewId), "Qt.quit", "",
                           "natural completion")
                Qt.quit()
            } else {
                Logger.log(NavigationTable.nameOf(root.thisViewId), "Qt.quit SUPPRESSED",
                           "closingAborted=true", "")
            }
        }
    }

    function performEnter() {
        opacity = 1
        Logger.log(NavigationTable.nameOf(root.thisViewId), "performEnter (custom)",
                   "", "deferred reportEnterComplete via Qt.callLater")
        Qt.callLater(emitEnterComplete)
        Logger.log(NavigationTable.nameOf(root.thisViewId), "internalAnim.start", "",
                   "duration=3000ms")
        internalAnim.start()
    }

    function emitEnterComplete() {
        Logger.log(NavigationTable.nameOf(root.thisViewId), "deferred reportEnterComplete", "",
                   "called via Qt.callLater")
        TransitionManager.reportEnterComplete(root.thisViewId)
    }
}

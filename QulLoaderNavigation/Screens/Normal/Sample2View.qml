// Sample2View.qml
// サンプル②: **同一 QML で 2 つの viewId (sample2a / sample2b) を担当**する例。
//
// 操作 (Click のみ):
//   PREV(A) : 2a → (境界、no-op) | 2b → 2a (Back 方向)
//   NEXT(D) : 2a → 2b (Next 方向)    | 2b → (境界、no-op)
//   BACK(C) : 2a/2b → menu (Back)

import QtQuick
import Constants
import Mediator

ViewBase {
    id: root
    // thisViewId を明示しない (= 0) → ViewBase が Mediator.pendingViewId から取得

    readonly property bool isVariantA: thisViewId === ViewId.NormalSample2a
    readonly property bool isVariantB: thisViewId === ViewId.NormalSample2b

    displayName: isVariantA ? "SAMPLE 2A" : (isVariantB ? "SAMPLE 2B" : "SAMPLE 2?")
    accentColor: isVariantA ? "#ab47bc"   // soft purple (Material purple 400)
                            : "#5c6bc0"   // soft indigo (Material indigo 400)

    Item {
        anchors.fill: parent
        anchors.margins: 24

        Column {
            anchors.centerIn: parent
            spacing: 14
            width: parent.width

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: isVariantA ? "VARIANT  A" : "VARIANT  B"
                color: "#e0e0e0"
                font.pixelSize: 36
                font.bold: true
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Loaded from Sample2View.qml"
                color: "#9e9e9e"
                font.pixelSize: 13
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "(same QML file as variant " + (isVariantA ? "B" : "A") + ")"
                color: "#9e9e9e"
                font.pixelSize: 13
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 260; height: 1
                color: "#3a3a3a"
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "thisViewId = 0x" + thisViewId.toString(16).toUpperCase()
                color: root.accentColor
                font.pixelSize: 14
                font.bold: true
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "(auto-resolved from Mediator.pendingViewId)"
                color: "#9e9e9e"
                font.pixelSize: 11
            }
        }

        Text {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            text: isVariantA ? "PREV(A): boundary    NEXT(D) → 2B    BACK(C) → Menu"
                             : "PREV(A) → 2A    NEXT(D): boundary    BACK(C) → Menu"
            color: "#5a5a5a"
            font.pixelSize: 11
        }
    }

    function onViewKey(vk, ve) {
        if (ve !== VirtualEvent.Click) return

        if (vk === VirtualKey.Back) {
            Logger.log(ViewId.nameOf(thisViewId), "action", "BACK/CLICK",
                       "switchView(normal/menu, Back)")
            Mediator.switchView(ViewId.NormalMenu, NavDirection.Back)
            return
        }

        if (vk === VirtualKey.Next) {
            if (isVariantA) {
                Logger.log(ViewId.nameOf(thisViewId), "action", "NEXT/CLICK",
                           "switchView(normal/sample2b, Next)")
                Mediator.switchView(ViewId.NormalSample2b, NavDirection.Next)
            } else {
                Logger.log(ViewId.nameOf(thisViewId), "action ignored",
                           "NEXT/CLICK", "boundary: already at last variant (2b)")
            }
            return
        }

        if (vk === VirtualKey.Prev) {
            if (isVariantB) {
                Logger.log(ViewId.nameOf(thisViewId), "action", "PREV/CLICK",
                           "switchView(normal/sample2a, Back)")
                Mediator.switchView(ViewId.NormalSample2a, NavDirection.Back)
            } else {
                Logger.log(ViewId.nameOf(thisViewId), "action ignored",
                           "PREV/CLICK", "boundary: already at first variant (2a)")
            }
            return
        }
    }
}

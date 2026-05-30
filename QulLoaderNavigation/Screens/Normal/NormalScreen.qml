// NormalScreen.qml
// Normal シーン。MENU CLICK → normal/menu、HOME CLICK → normal/home を吸収 (§8-6)。
// chrome (Header/Footer/AsideL/AsideR) でダーク統一の枠を作り、中央 contentArea に
// view を配置する (4:3 = 640×480)。各 chrome の境界には 1px のハイラインを引いて
// エリア区切りを明示する。

import QtQuick
import Constants
import Mediator

ScreenBase {
    id: screen
    thisScreenId: ScreenId.Normal

    // ---- 境界線の色 (Header/Footer の下/上、Aside の view 側エッジ用) ----
    readonly property color dividerColor: "#333333"

    Rectangle {
        id: headerArea
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 60
        color: "#141414"
        Text {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: "NORMAL  ·  " + ViewId.nameOf(Mediator.currentViewId)
            color: "#e0e0e0"
            font.pixelSize: 14
            font.bold: true
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: "Header"
            color: "#5a5a5a"
            font.pixelSize: 10
        }
        // 下端 1px ハイライン (header と view 領域の境界)
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: screen.dividerColor
        }
    }

    Rectangle {
        id: footerArea
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 60
        color: "#141414"
        // 左下はミニキーボード overlay (Main.qml、z=9998) に隠れるのでテキストは置かない
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: "Footer    |    ← " + ViewId.nameOf(Mediator.previousViewId)
                  + "    |    history: " + Mediator.history.length
            color: "#9e9e9e"
            font.pixelSize: 11
        }
        // 上端 1px ハイライン (view 領域と footer の境界)
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: screen.dividerColor
        }
    }

    Rectangle {
        id: asideLArea
        anchors.top: headerArea.bottom
        anchors.bottom: footerArea.top
        anchors.left: parent.left
        width: 80
        color: "#141414"
        Text {
            anchors.centerIn: parent
            text: "L"
            color: "#5a5a5a"
            font.pixelSize: 32
            font.bold: true
        }
        Text {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 6
            anchors.horizontalCenter: parent.horizontalCenter
            text: "AsideL"
            color: "#5a5a5a"
            font.pixelSize: 10
        }
        // 右端 1px ハイライン (asideL と view 領域の境界)
        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 1
            color: screen.dividerColor
        }
    }

    Rectangle {
        id: asideRArea
        anchors.top: headerArea.bottom
        anchors.bottom: footerArea.top
        anchors.right: parent.right
        width: 80
        color: "#141414"
        Text {
            anchors.centerIn: parent
            text: "R"
            color: "#5a5a5a"
            font.pixelSize: 32
            font.bold: true
        }
        Text {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 6
            anchors.horizontalCenter: parent.horizontalCenter
            text: "AsideR"
            color: "#5a5a5a"
            font.pixelSize: 10
        }
        // 左端 1px ハイライン (view 領域と asideR の境界)
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 1
            color: screen.dividerColor
        }
    }

    // ---- contentArea: views を描画する中央領域 (4:3 = 640×480) ----
    Item {
        id: contentArea
        anchors.top: headerArea.bottom
        anchors.bottom: footerArea.top
        anchors.left: asideLArea.right
        anchors.right: asideRArea.left
    }

    viewArea: contentArea

    function handleAbsorb(vk, ve) {
        if (ve === VirtualEvent.Click) {
            if (vk === VirtualKey.Menu) {
                Logger.log("NormalScreen", "absorb", "vk=MENU/CLICK",
                           "action=switchView(normal/menu, Next)")
                Mediator.switchView(ViewId.NormalMenu, NavDirection.Next)
                return true
            }
            if (vk === VirtualKey.Home) {
                Logger.log("NormalScreen", "absorb", "vk=HOME/CLICK",
                           "action=switchView(normal/home, Next)")
                Mediator.switchView(ViewId.NormalHome, NavDirection.Next)
                return true
            }
        }
        return false
    }
}

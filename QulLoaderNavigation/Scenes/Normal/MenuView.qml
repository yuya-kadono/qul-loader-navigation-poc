// MenuView.qml
// メニュー画面: 3 つのボタン (Sample 1 / Sample 2A / Sample 2B) を選択カーソルで操作する。
// 操作:
//   PREV(A) click  → カーソル一つ左 (Sample 1)
//   NEXT(D) click  → カーソル一つ右 (Sample 2B)
//   ENTER(S) click → カーソル位置のサンプルへ遷移 (Next)
//   BACK(C) click  → home (Back)
//   ※ HOME(X) は NormalScene が吸収 → normal/home
//
// 戻ってきた時のカーソル初期位置:
//   previousViewId === ViewId.ViewId.NormalSample1   → Sample 1   (cursorIndex=0)
//   previousViewId === ViewId.ViewId.NormalSample2a  → Sample 2A  (cursorIndex=1)
//   previousViewId === ViewId.ViewId.NormalSample2b  → Sample 2B  (cursorIndex=2)
//   それ以外 (home から初めて来た等)                 → Sample 1   (cursorIndex=0, デフォルト)

import QtQuick
import Constants
import Mediator

ViewBase {
    id: menu
    thisViewId: ViewId.ViewId.NormalMenu
    displayName: "MENU"
    backgroundColor: "#ef6c00"  // orange

    // 0 = Sample 1, 1 = Sample 2A, 2 = Sample 2B
    property int cursorIndex: 0

    function onEntering() {
        var prev = Mediator.previousViewId
        var oldCursor = cursorIndex
        if (prev === ViewId.ViewId.NormalSample2a) {
            cursorIndex = 1
        } else if (prev === ViewId.ViewId.NormalSample2b) {
            cursorIndex = 2
        } else {
            cursorIndex = 0
        }
        Logger.log(ViewId.nameOf(thisViewId), "onEntering cursor init",
                   "previousViewId=" + ViewId.nameOf(prev),
                   "cursorIndex: " + oldCursor + " → " + cursorIndex)
    }

    // ---- ボタン UI (3 個) ----
    Row {
        anchors.centerIn: parent
        spacing: 24

        Rectangle {
            width: 180; height: 100
            radius: 8
            color: menu.cursorIndex === 0 ? "#fff176" : "#5d4037"
            border.color: menu.cursorIndex === 0 ? "white" : "#3e2723"
            border.width: menu.cursorIndex === 0 ? 4 : 1
            Text {
                anchors.centerIn: parent
                text: "Sample 1"
                font.pixelSize: 24
                font.bold: true
                color: menu.cursorIndex === 0 ? "#3e2723" : "white"
            }
        }
        Rectangle {
            width: 180; height: 100
            radius: 8
            color: menu.cursorIndex === 1 ? "#fff176" : "#5d4037"
            border.color: menu.cursorIndex === 1 ? "white" : "#3e2723"
            border.width: menu.cursorIndex === 1 ? 4 : 1
            Text {
                anchors.centerIn: parent
                text: "Sample 2A"
                font.pixelSize: 24
                font.bold: true
                color: menu.cursorIndex === 1 ? "#3e2723" : "white"
            }
        }
        Rectangle {
            width: 180; height: 100
            radius: 8
            color: menu.cursorIndex === 2 ? "#fff176" : "#5d4037"
            border.color: menu.cursorIndex === 2 ? "white" : "#3e2723"
            border.width: menu.cursorIndex === 2 ? 4 : 1
            Text {
                anchors.centerIn: parent
                text: "Sample 2B"
                font.pixelSize: 24
                font.bold: true
                color: menu.cursorIndex === 2 ? "#3e2723" : "white"
            }
        }
    }

    Text {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 24
        color: "white"
        font.pixelSize: 14
        text: "PREV(A)/NEXT(D): カーソル移動   |   ENTER(S): 決定   |   BACK(C): home"
    }

    function onViewKey(vk, ve) {
        if (ve !== Event.Event.Click) return
        switch (vk) {
            case Key.Key.Prev:
                if (menu.cursorIndex > 0) {
                    menu.cursorIndex = menu.cursorIndex - 1
                    Logger.log("normal/menu", "cursor moved", "PREV/CLICK",
                               "cursorIndex=" + menu.cursorIndex)
                } else {
                    Logger.log("normal/menu", "cursor unchanged", "PREV/CLICK",
                               "already 0")
                }
                break
            case Key.Key.Next:
                if (menu.cursorIndex < 2) {
                    menu.cursorIndex = menu.cursorIndex + 1
                    Logger.log("normal/menu", "cursor moved", "NEXT/CLICK",
                               "cursorIndex=" + menu.cursorIndex)
                } else {
                    Logger.log("normal/menu", "cursor unchanged", "NEXT/CLICK",
                               "already 2")
                }
                break
            case Key.Key.Enter:
                var targetId
                switch (menu.cursorIndex) {
                    case 0: targetId = ViewId.ViewId.NormalSample1;  break
                    case 1: targetId = ViewId.ViewId.NormalSample2a; break
                    case 2: targetId = ViewId.ViewId.NormalSample2b; break
                }
                Logger.log("normal/menu", "action", "ENTER/CLICK",
                           "cursorIndex=" + menu.cursorIndex
                           + " → requestNavigate(" + ViewId.nameOf(targetId) + ", Next)")
                Mediator.requestNavigate(targetId, Direction.Direction.Next)
                break
            case Key.Key.Back:
                Logger.log("normal/menu", "action", "BACK/CLICK",
                           "requestNavigate(normal/home, Back)")
                Mediator.requestNavigate(ViewId.ViewId.NormalHome,
                                         Direction.Direction.Back)
                break
        }
    }
}

// MenuView.qml
// メニュー画面 = タイル式アイコンランチャー (HomeView と同じ Grid 4 列の発想)。
//
// 操作:
//   PREV(A) click : カーソル一つ左 (index 0 で no-op)
//   NEXT(D) click : カーソル一つ右 (最右端で no-op)
//   ENTER(S)      : Press で枠が黄色 (押下フィードバック)、Click で起動
//   BACK(C) click : home (Back 方向)
//   ※ HOME(X) は NormalScreen が吸収 → normal/home
//
// タイル 3 状態は HomeView と統一 (中立色枠 + 押下時のみ黄色)。

import QtQuick
import Constants
import Mediator

ViewBase {
    id: menu
    thisViewId: ViewId.NormalMenu
    displayName: "MENU"
    accentColor: "#ffa726"  // soft orange (Material orange 400)

    readonly property var iconModel: [
        { symbol: "★", label: "Sample 1",  action: "sample1"  },
        { symbol: "◆", label: "Sample 2A", action: "sample2a" },
        { symbol: "◇", label: "Sample 2B", action: "sample2b" }
    ]

    property int cursorIndex: 0
    readonly property int iconCount: iconModel.length

    // ENTER 押下中フラグ
    property bool enterPressed: false

    function onEntering() {
        var prev = Mediator.previousViewId
        var oldCursor = cursorIndex
        if (prev === ViewId.NormalSample1) {
            cursorIndex = indexOfAction("sample1")
        } else if (prev === ViewId.NormalSample2a) {
            cursorIndex = indexOfAction("sample2a")
        } else if (prev === ViewId.NormalSample2b) {
            cursorIndex = indexOfAction("sample2b")
        } else {
            cursorIndex = 0
        }
        if (cursorIndex < 0) cursorIndex = 0
        enterPressed = false
        Logger.log("normal/menu", "onEntering cursor init",
                   "previousViewId=" + ViewId.nameOf(prev),
                   "cursorIndex: " + oldCursor + " → " + cursorIndex)
    }

    function indexOfAction(actionName) {
        for (var i = 0; i < iconModel.length; ++i) {
            if (iconModel[i].action === actionName) return i
        }
        return -1
    }

    Grid {
        anchors.centerIn: parent
        columns: 4
        rowSpacing: 28
        columnSpacing: 28

        Repeater {
            model: menu.iconModel
            delegate: Column {
                spacing: 6
                Rectangle {
                    id: tile
                    width: 90; height: 90; radius: 12
                    property bool selected: menu.cursorIndex === index
                    property bool pressed: selected && menu.enterPressed
                    color: "#2a2a2a"
                    border.color: pressed ? "#ffeb3b"
                                          : (selected ? "#e0e0e0" : "#3a3a3a")
                    border.width: pressed ? 3 : (selected ? 2 : 1)
                    Text {
                        anchors.centerIn: parent
                        text: modelData.symbol
                        color: tile.selected ? "#ffffff" : "#e0e0e0"
                        font.pixelSize: 44
                        font.bold: true
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: modelData.label
                    color: menu.cursorIndex === index ? "#e0e0e0" : "#9e9e9e"
                    font.pixelSize: 13
                    font.bold: menu.cursorIndex === index
                }
            }
        }
    }

    function onViewKey(vk, ve) {
        // ENTER は Press/Release/Click すべて処理
        if (vk === VirtualKey.Enter) {
            if (ve === VirtualEvent.Press) {
                menu.enterPressed = true
                return
            }
            if (ve === VirtualEvent.Release) {
                menu.enterPressed = false
                return
            }
            if (ve === VirtualEvent.Click) {
                menu.activateAt(menu.cursorIndex)
                return
            }
        }

        // それ以外は Click のみ
        if (ve !== VirtualEvent.Click) return
        switch (vk) {
            case VirtualKey.Prev:
                if (menu.cursorIndex > 0) {
                    menu.cursorIndex = menu.cursorIndex - 1
                    Logger.log("normal/menu", "cursor moved", "PREV/CLICK",
                               "cursorIndex=" + menu.cursorIndex)
                } else {
                    Logger.log("normal/menu", "cursor unchanged", "PREV/CLICK",
                               "already 0 (boundary)")
                }
                break
            case VirtualKey.Next:
                if (menu.cursorIndex < menu.iconCount - 1) {
                    menu.cursorIndex = menu.cursorIndex + 1
                    Logger.log("normal/menu", "cursor moved", "NEXT/CLICK",
                               "cursorIndex=" + menu.cursorIndex)
                } else {
                    Logger.log("normal/menu", "cursor unchanged", "NEXT/CLICK",
                               "already " + (menu.iconCount - 1) + " (boundary)")
                }
                break
            case VirtualKey.Back:
                Logger.log("normal/menu", "action", "BACK/CLICK",
                           "switchView(normal/home, Back)")
                Mediator.switchView(ViewId.NormalHome, NavDirection.Back)
                break
        }
    }

    function activateAt(idx) {
        var action = menu.iconModel[idx].action
        var targetId = 0
        switch (action) {
            case "sample1":  targetId = ViewId.NormalSample1;  break
            case "sample2a": targetId = ViewId.NormalSample2a; break
            case "sample2b": targetId = ViewId.NormalSample2b; break
            default:
                Logger.log("normal/menu", "action ignored",
                           "ENTER/CLICK on cursorIndex=" + idx,
                           "unknown action: " + action)
                return
        }
        Logger.log("normal/menu", "action", "ENTER/CLICK",
                   "switchView(" + ViewId.nameOf(targetId) + ", Next)")
        Mediator.switchView(targetId, NavDirection.Next)
    }
}

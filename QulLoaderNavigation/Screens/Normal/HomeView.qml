// HomeView.qml
// Home 画面 = Windows ライクなアイコンランチャー (4 列 Grid)。
// 実装のあるアイコンのみ並べる方針 (= 押せないボタンは置かない)。
//
// アイコン一覧 (現状 2 個):
//   0: ☰ Menu     → switchView(normal/menu, Next)
//   1: ⏻ Shutdown → switchView(closing/closing, Next)
//
// 操作:
//   PREV(A) click : カーソル一つ左 (index 0 で no-op)
//   NEXT(D) click : カーソル一つ右 (最右端で no-op)
//   ENTER(S)      : Press で枠が黄色 (押下フィードバック)、Click で起動
//   ※ MENU(Z) は NormalScreen が吸収 → normal/menu
//
// タイルの 3 状態:
//   非選択       : 枠 #3a3a3a 1px
//   選択 (cursor): 枠 #e0e0e0 2px (白、中立色で一律)
//   押下 (ENTER) : 枠 #ffeb3b 3px (黄、ミニキーボードと統一)
// タイル本体色は常に #2a2a2a 一律。identity は上部 6px ライン (accentColor) のみ。

import QtQuick
import Constants
import Mediator

ViewBase {
    id: home
    thisViewId: ViewId.NormalHome
    displayName: "HOME"
    accentColor: "#66bb6a"  // soft green (Material green 400)

    readonly property var iconModel: [
        { symbol: "☰", label: "Menu",     action: "menu" },
        { symbol: "⏻", label: "Shutdown", action: "shutdown" }
    ]

    property int cursorIndex: 0
    readonly property int iconCount: iconModel.length

    // ENTER 押下中フラグ (押下フィードバック用)
    property bool enterPressed: false

    function onEntering() {
        var prev = Mediator.previousViewId
        var oldCursor = cursorIndex
        if (prev === ViewId.ClosingClosing) {
            cursorIndex = indexOfAction("shutdown")
        } else {
            cursorIndex = indexOfAction("menu")
        }
        if (cursorIndex < 0) cursorIndex = 0
        enterPressed = false  // 念のため
        Logger.log("normal/home", "onEntering cursor init",
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
            model: home.iconModel
            delegate: Column {
                spacing: 6
                Rectangle {
                    id: tile
                    width: 90; height: 90; radius: 12
                    property bool selected: home.cursorIndex === index
                    property bool pressed: selected && home.enterPressed
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
                    color: home.cursorIndex === index ? "#e0e0e0" : "#9e9e9e"
                    font.pixelSize: 13
                    font.bold: home.cursorIndex === index
                }
            }
        }
    }

    function onViewKey(vk, ve) {
        // ENTER は Press/Release/Click すべて処理
        if (vk === VirtualKey.Enter) {
            if (ve === VirtualEvent.Press) {
                home.enterPressed = true
                return
            }
            if (ve === VirtualEvent.Release) {
                home.enterPressed = false
                return
            }
            if (ve === VirtualEvent.Click) {
                home.activateAt(home.cursorIndex)
                return
            }
        }

        // それ以外は Click のみ
        if (ve !== VirtualEvent.Click) return
        switch (vk) {
            case VirtualKey.Prev:
                if (home.cursorIndex > 0) {
                    home.cursorIndex = home.cursorIndex - 1
                    Logger.log("normal/home", "cursor moved", "PREV/CLICK",
                               "cursorIndex=" + home.cursorIndex)
                } else {
                    Logger.log("normal/home", "cursor unchanged", "PREV/CLICK",
                               "already 0 (boundary)")
                }
                break
            case VirtualKey.Next:
                if (home.cursorIndex < home.iconCount - 1) {
                    home.cursorIndex = home.cursorIndex + 1
                    Logger.log("normal/home", "cursor moved", "NEXT/CLICK",
                               "cursorIndex=" + home.cursorIndex)
                } else {
                    Logger.log("normal/home", "cursor unchanged", "NEXT/CLICK",
                               "already " + (home.iconCount - 1) + " (boundary)")
                }
                break
        }
    }

    function activateAt(idx) {
        var action = home.iconModel[idx].action
        switch (action) {
            case "menu":
                Logger.log("normal/home", "action", "ENTER/CLICK on Menu",
                           "switchView(normal/menu, Next)")
                Mediator.switchView(ViewId.NormalMenu, NavDirection.Next)
                break
            case "shutdown":
                Logger.log("normal/home", "action", "ENTER/CLICK on Shutdown",
                           "switchView(closing/closing, Next)")
                Mediator.switchView(ViewId.ClosingClosing, NavDirection.Next)
                break
            default:
                Logger.log("normal/home", "action ignored",
                           "ENTER/CLICK on cursorIndex=" + idx,
                           "unknown action: " + action)
                break
        }
    }
}

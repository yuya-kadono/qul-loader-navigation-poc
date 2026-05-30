// Sample1View.qml
// サンプル①: ナビゲーション履歴 (Mediator.history) を表示する画面。
// 履歴が長くなって画面に収まらなくなった時のために Flickable + 自前 scrollbar を用意。
//
// 操作:
//   PREV(A) click → 上にスクロール (60px)、上端で clamp
//   NEXT(D) click → 下にスクロール (60px)、下端で clamp
//   BACK(C) click → menu (Back)
//   ※ MENU(Z)/HOME(X) は NormalScreen が吸収
//
// レイアウト:
//   [accent line 6px]
//   [固定 header: タイトル + 件数]
//   [Flickable: 履歴リスト + 現在位置] [scroll track + thumb on right (overflow 時のみ)]
//   [固定 footer: 操作ヒント]

import QtQuick
import Constants
import Mediator

ViewBase {
    id: sample1
    thisViewId: ViewId.NormalSample1
    displayName: "SAMPLE 1"
    accentColor: "#ef5350"  // soft red (Material red 400)

    Item {
        anchors.fill: parent
        anchors.margins: 20
        anchors.topMargin: 18    // 6px accent line の下に余白

        // ---- 固定 header (上端) ----
        Column {
            id: headerCol
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 4

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Navigation Trail"
                color: "#e0e0e0"
                font.pixelSize: 22
                font.bold: true
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Mediator.history.length + " view(s) visited before this one"
                color: "#9e9e9e"
                font.pixelSize: 12
            }
        }

        // ---- 固定 footer (下端): 操作ヒント ----
        Text {
            id: hintText
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            text: "PREV(A) / NEXT(D) scroll    BACK(C) → Menu"
            color: "#5a5a5a"
            font.pixelSize: 11
        }

        // ---- スクロールエリア (中央) ----
        Flickable {
            id: scrollArea
            anchors.top: headerCol.bottom
            anchors.topMargin: 12
            anchors.bottom: hintText.top
            anchors.bottomMargin: 12
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.rightMargin: 14   // scroll track 用の余白

            clip: true
            contentWidth: width
            contentHeight: scrollContent.implicitHeight

            // 滑らかなスクロールアニメ
            Behavior on contentY {
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }

            Column {
                id: scrollContent
                width: scrollArea.width
                spacing: 8

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 280; height: 1
                    color: "#3a3a3a"
                }

                // 履歴リスト
                Repeater {
                    model: Mediator.history
                    delegate: Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: (index + 1) + ".  " + ViewId.nameOf(modelData)
                        color: "#e0e0e0"
                        font.pixelSize: 14
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "↳ now: " + ViewId.nameOf(Mediator.currentViewId)
                    color: sample1.accentColor
                    font.pixelSize: 14
                    font.bold: true
                }
            }
        }

        // ---- スクロールバー (右側、scrollArea の外、overflow 時のみ表示) ----
        Rectangle {
            id: scrollTrack
            anchors.top: scrollArea.top
            anchors.bottom: scrollArea.bottom
            anchors.right: parent.right
            width: 4
            color: "#2a2a2a"
            radius: 2
            visible: scrollArea.contentHeight > scrollArea.height

            Rectangle {
                id: scrollThumb
                anchors.left: parent.left
                anchors.right: parent.right
                radius: 2
                color: "#9e9e9e"
                // thumb 高: 表示比率
                height: Math.max(20,
                                 scrollTrack.height
                                 * scrollArea.height
                                 / Math.max(scrollArea.contentHeight, 1))
                // thumb y: スクロール比率
                y: scrollArea.contentY
                   * (scrollTrack.height - height)
                   / Math.max(scrollArea.contentHeight - scrollArea.height, 1)
            }
        }
    }

    function onViewKey(vk, ve) {
        if (ve !== VirtualEvent.Click) return
        var step = 60
        if (vk === VirtualKey.Prev) {
            var newY1 = Math.max(0, scrollArea.contentY - step)
            Logger.log(ViewId.nameOf(thisViewId), "scroll up", "PREV/CLICK",
                       "contentY: " + scrollArea.contentY + " → " + newY1)
            scrollArea.contentY = newY1
        } else if (vk === VirtualKey.Next) {
            var maxY = Math.max(0, scrollArea.contentHeight - scrollArea.height)
            var newY2 = Math.min(maxY, scrollArea.contentY + step)
            Logger.log(ViewId.nameOf(thisViewId), "scroll down", "NEXT/CLICK",
                       "contentY: " + scrollArea.contentY + " → " + newY2
                       + " (max=" + maxY + ")")
            scrollArea.contentY = newY2
        } else if (vk === VirtualKey.Back) {
            Logger.log(ViewId.nameOf(thisViewId), "action", "BACK/CLICK",
                       "switchView(normal/menu, Back)")
            Mediator.switchView(ViewId.NormalMenu, NavDirection.Back)
        }
    }
}

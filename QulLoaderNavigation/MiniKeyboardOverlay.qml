// MiniKeyboardOverlay.qml
// POC 専用: QWERTY 左下部 (Q/W/E/R + A/S/D/F + Z/X/C/V) を実物のキーボード配置で再現。
// 使用キー (A/S/D/Z/X/C) には仮想キー名 (PREV/ENTER/NEXT/MENU/HOME/BACK) を併記。
// production 移植時に Main.qml の参照ごと削除する想定。
//
// 物理押下中の表示:
//   - 黄色枠 → 単独押下 (正常 dispatch 中)
//   - 赤枠   → 同時押し検出中 (dispatch 抑制)
// 未使用キー (Q/W/E/R/F/V) は文字を中央にグレー表示。
//
// 外部から受け取るプロパティ (Main.qml の keyHandler から bind 経由):
//   - pressedKeys : 現在押下中の Qt.Key_* 配列
//   - conflictMode: 同時押し検出中フラグ (赤ハイライト切替)

import QtQuick
import Constants

Item {
    id: overlay

    property var pressedKeys: []
    property bool conflictMode: false

    z: 9998
    width: 240
    height: 140
    opacity: 0.85

    Column {
        spacing: 4

        // Q W E R 行 (Tab 行、全部未使用)
        Row {
            spacing: 4
            x: 0
            Repeater {
                model: [
                    { letter: "Q", virt: "", vk: -1, pk: -1 },
                    { letter: "W", virt: "", vk: -1, pk: -1 },
                    { letter: "E", virt: "", vk: -1, pk: -1 },
                    { letter: "R", virt: "", vk: -1, pk: -1 }
                ]
                delegate: Rectangle {
                    id: keyQR
                    width: 52; height: 44; radius: 4
                    property bool isUsed: modelData.vk >= 0
                    property bool isPressed: isUsed
                        && overlay.pressedKeys.indexOf(modelData.pk) >= 0
                    color: isPressed
                        ? (overlay.conflictMode ? "#f44336" : "#ffeb3b")
                        : (isUsed ? "#404040" : "#1a1a1a")
                    border.color: isUsed ? "#888888" : "#3a3a3a"
                    border.width: 1
                    Column {
                        anchors.centerIn: parent
                        spacing: 1
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.letter
                            color: keyQR.isPressed
                                ? (overlay.conflictMode ? "white" : "#212121")
                                : (keyQR.isUsed ? "#cccccc" : "#555555")
                            font.pixelSize: keyQR.isUsed ? 10 : 14
                            font.bold: !keyQR.isUsed
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: keyQR.isUsed
                            text: modelData.virt
                            color: (keyQR.isPressed && !overlay.conflictMode)
                                ? "#212121" : "white"
                            font.pixelSize: 11
                            font.bold: true
                        }
                    }
                }
            }
        }

        // A S D F 行 (ホーム行、A/S/D 使用、F 未使用)
        Row {
            spacing: 4
            x: 14
            Repeater {
                model: [
                    { letter: "A", virt: "PREV",  vk: VirtualKey.Prev,  pk: Qt.Key_A },
                    { letter: "S", virt: "ENTER", vk: VirtualKey.Enter, pk: Qt.Key_S },
                    { letter: "D", virt: "NEXT",  vk: VirtualKey.Next,  pk: Qt.Key_D },
                    { letter: "F", virt: "",      vk: -1,               pk: -1       }
                ]
                delegate: Rectangle {
                    id: keyAF
                    width: 52; height: 44; radius: 4
                    property bool isUsed: modelData.vk >= 0
                    property bool isPressed: isUsed
                        && overlay.pressedKeys.indexOf(modelData.pk) >= 0
                    color: isPressed
                        ? (overlay.conflictMode ? "#f44336" : "#ffeb3b")
                        : (isUsed ? "#404040" : "#1a1a1a")
                    border.color: isUsed ? "#888888" : "#3a3a3a"
                    border.width: 1
                    Column {
                        anchors.centerIn: parent
                        spacing: 1
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.letter
                            color: keyAF.isPressed
                                ? (overlay.conflictMode ? "white" : "#212121")
                                : (keyAF.isUsed ? "#cccccc" : "#555555")
                            font.pixelSize: keyAF.isUsed ? 10 : 14
                            font.bold: !keyAF.isUsed
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: keyAF.isUsed
                            text: modelData.virt
                            color: (keyAF.isPressed && !overlay.conflictMode)
                                ? "#212121" : "white"
                            font.pixelSize: 11
                            font.bold: true
                        }
                    }
                }
            }
        }

        // Z X C V 行 (Shift 行、Z/X/C 使用、V 未使用)
        Row {
            spacing: 4
            x: 42
            Repeater {
                model: [
                    { letter: "Z", virt: "MENU", vk: VirtualKey.Menu, pk: Qt.Key_Z },
                    { letter: "X", virt: "HOME", vk: VirtualKey.Home, pk: Qt.Key_X },
                    { letter: "C", virt: "BACK", vk: VirtualKey.Back, pk: Qt.Key_C },
                    { letter: "V", virt: "",     vk: -1,              pk: -1       }
                ]
                delegate: Rectangle {
                    id: keyZV
                    width: 52; height: 44; radius: 4
                    property bool isUsed: modelData.vk >= 0
                    property bool isPressed: isUsed
                        && overlay.pressedKeys.indexOf(modelData.pk) >= 0
                    color: isPressed
                        ? (overlay.conflictMode ? "#f44336" : "#ffeb3b")
                        : (isUsed ? "#404040" : "#1a1a1a")
                    border.color: isUsed ? "#888888" : "#3a3a3a"
                    border.width: 1
                    Column {
                        anchors.centerIn: parent
                        spacing: 1
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.letter
                            color: keyZV.isPressed
                                ? (overlay.conflictMode ? "white" : "#212121")
                                : (keyZV.isUsed ? "#cccccc" : "#555555")
                            font.pixelSize: keyZV.isUsed ? 10 : 14
                            font.bold: !keyZV.isUsed
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: keyZV.isUsed
                            text: modelData.virt
                            color: (keyZV.isPressed && !overlay.conflictMode)
                                ? "#212121" : "white"
                            font.pixelSize: 11
                            font.bold: true
                        }
                    }
                }
            }
        }
    }
}

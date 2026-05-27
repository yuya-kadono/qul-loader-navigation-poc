// Main.qml
// Window + 物理キー → 仮想キー変換層 (§8-4) + SceneSlot ペア (§3-2)。
//
// 移植性メモ:
//   - Keys.onPressed/onReleased は **POC 限定の物理キー受信** (デスクトップ Qt 6 で
//     キーボード入力をテストするため)。実機 MCU 移植時にはハードウェアボタンから
//     直接 KeyDispatcher.dispatchToScene() を呼ぶ形になるため、この層は丸ごと
//     置き換わる。よってここでは Qt 6 推奨の function(event) 形式を使い、Qt 6 の
//     deprecation 警告を抑止する (QUL 互換性は不要)。
//   - 一方、Connections{target: TransitionManager} は singleton 通知パターンの本質
//     なので不使用。代わりに finishedGen を local property にバインドして on*Changed
//     で検知する (QUL 互換)。

import QtQuick
import QulLoaderNavigation

Window {
    id: window
    width: 800
    height: 600
    visible: true
    title: "QUL Loader Navigation POC"
    color: "black"

    // ---- キー入力受け口 ----
    Item {
        id: keyHandler
        anchors.fill: parent
        focus: true

        property int pressedPhysicalKey: -1

        Keys.onPressed: function(event) {
            if (event.isAutoRepeat) return
            var vk = physicalToVirtual(event.key)
            if (vk < 0) return
            pressedPhysicalKey = event.key
            Logger.log("Main", "Keys.onPressed",
                       "physicalKey=" + event.key,
                       "vk=" + Logger.vkName(vk))
            KeyDispatcher.dispatchToScene(vk, KeyDispatcher.evPress)
            event.accepted = true
        }
        Keys.onReleased: function(event) {
            if (event.isAutoRepeat) return
            var vk = physicalToVirtual(event.key)
            if (vk < 0) return
            Logger.log("Main", "Keys.onReleased",
                       "physicalKey=" + event.key,
                       "vk=" + Logger.vkName(vk))
            KeyDispatcher.dispatchToScene(vk, KeyDispatcher.evRelease)
            // PRESS と対の RELEASE が成立 → CLICK を追加発火 (§8-2)
            if (pressedPhysicalKey === event.key) {
                Logger.log("Main", "CLICK synthesized",
                           "physicalKey=" + event.key,
                           "vk=" + Logger.vkName(vk))
                KeyDispatcher.dispatchToScene(vk, KeyDispatcher.evClick)
                pressedPhysicalKey = -1
            }
            event.accepted = true
        }

        function physicalToVirtual(key) {
            switch (key) {
                case Qt.Key_A: return KeyDispatcher.keyPrev
                case Qt.Key_S: return KeyDispatcher.keyEnter
                case Qt.Key_D: return KeyDispatcher.keyNext
                case Qt.Key_Z: return KeyDispatcher.keyMenu
                case Qt.Key_X: return KeyDispatcher.keyHome
                case Qt.Key_C: return KeyDispatcher.keyBack
            }
            return -1
        }

        // ---- SceneSlot ペア (§3-2) ----
        Loader {
            id: sceneSlotA
            anchors.fill: parent
            source: TransitionManager.sceneSourceA
            active: source !== ""
        }
        Loader {
            id: sceneSlotB
            anchors.fill: parent
            source: TransitionManager.sceneSourceB
            active: source !== ""
        }

        // ---- TransitionManager.finishedGen の監視 (Connections 不使用) ----
        // signal の代わりに世代カウンタをバインドして on*Changed で検知する。
        property int finishedGen: TransitionManager.finishedGen
        property bool ready: false
        onFinishedGenChanged: {
            if (!ready) return
            Logger.log("Main", "onTransitionFinished",
                       "finalViewId=" + NavigationTable.nameOf(TransitionManager.lastFinishedViewId),
                       "")
        }
        Component.onCompleted: {
            ready = true
            Logger.log("Main", "Component.onCompleted", "",
                       "kickoff: requestNavigate(opening/opening, Next)")
            Mediator.requestNavigate(NavigationTable.idOpeningOpening,
                                     TransitionManager.directionNext)
        }
    }
}

// SceneBase.qml
// Scene の共通骨格 (§3-2 / §8-6)。
//
// 派生 scene が指定するもの:
//   - thisSceneId : 自分の scene ID (NavigationTable.sceneOpening/sceneNormal/sceneClosing)
//
// 派生 scene が override できるもの:
//   - function handleAbsorb(vk, ve) : 吸収した場合 true を返す。
//                                     false なら自動で KeyDispatcher.dispatchToView() に転送。
//
// 共通機能:
//   - ViewSlot A/B Loader (scene フィルタ付き binding)
//     現在 view ID の所属 scene が thisSceneId と一致する場合のみロード (§9-9)。
//   - Component.onCompleted / onDestruction でロード/破棄をログ
//   - sceneEventGen 変化で handleAbsorb() を呼び、吸収されなければ view に転送

import QtQuick
import QulLoaderNavigation

Item {
    id: scene
    anchors.fill: parent

    // ---- 派生で指定するもの ----
    property int thisSceneId: 0

    // ---- 派生が override 可能なフック ----
    function handleAbsorb(vk, ve) { return false }

    // ---- KeyDispatcher 受信用バインディング ----
    property int sceneEventGen: KeyDispatcher.sceneEventGen
    property bool ready: false

    Component.onCompleted: {
        Logger.log(NavigationTable.sceneNameOf(scene.thisSceneId) + "Scene",
                   "loaded", "", "")
        scene.ready = true
    }
    Component.onDestruction: Logger.log(
        NavigationTable.sceneNameOf(scene.thisSceneId) + "Scene",
        "destroyed", "", "")

    onSceneEventGenChanged: {
        if (!scene.ready) return
        var vk = KeyDispatcher.sceneEventVk
        var ve = KeyDispatcher.sceneEventVe
        Logger.log(NavigationTable.sceneNameOf(scene.thisSceneId) + "Scene",
                   "onSceneKeyEvent",
                   "vk=" + Logger.vkName(vk) + ", ev=" + Logger.veName(ve), "")
        if (scene.handleAbsorb(vk, ve)) {
            return
        }
        Logger.log(NavigationTable.sceneNameOf(scene.thisSceneId) + "Scene",
                   "forward-to-view",
                   "vk=" + Logger.vkName(vk) + ", ev=" + Logger.veName(ve), "")
        KeyDispatcher.dispatchToView(vk, ve)
    }

    // ---- View スロット A: scene フィルタ付き binding ----
    Loader {
        id: viewSlotA
        anchors.fill: parent
        source: {
            var vid = TransitionManager.viewSlotAViewId
            if (vid === 0) return ""
            if (NavigationTable.sceneOf(vid) === scene.thisSceneId) {
                return TransitionManager.viewSlotASource
            }
            return ""
        }
        active: source !== ""
    }

    // ---- View スロット B ----
    Loader {
        id: viewSlotB
        anchors.fill: parent
        source: {
            var vid = TransitionManager.viewSlotBViewId
            if (vid === 0) return ""
            if (NavigationTable.sceneOf(vid) === scene.thisSceneId) {
                return TransitionManager.viewSlotBSource
            }
            return ""
        }
        active: source !== ""
    }
}

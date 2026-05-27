// NormalScene.qml
// Normal シーン。MENU CLICK → normal/menu、HOME CLICK → normal/home を吸収 (§8-6)。

import QtQuick
import QulLoaderNavigation

SceneBase {
    id: scene
    thisSceneId: NavigationTable.sceneNormal

    function handleAbsorb(vk, ve) {
        if (ve === KeyDispatcher.evClick) {
            if (vk === KeyDispatcher.keyMenu) {
                Logger.log("normalScene", "absorb", "vk=MENU/CLICK",
                           "action=requestNavigate(normal/menu, Next)")
                Mediator.requestNavigate(NavigationTable.idNormalMenu,
                                         TransitionManager.directionNext)
                return true
            }
            if (vk === KeyDispatcher.keyHome) {
                Logger.log("normalScene", "absorb", "vk=HOME/CLICK",
                           "action=requestNavigate(normal/home, Next)")
                Mediator.requestNavigate(NavigationTable.idNormalHome,
                                         TransitionManager.directionNext)
                return true
            }
        }
        return false
    }
}

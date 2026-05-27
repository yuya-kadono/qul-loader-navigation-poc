// ClosingScene.qml
// Closing シーン。BACK/HOME CLICK で中断 (§8-6 / §10-3)。

import QtQuick
import QulLoaderNavigation

SceneBase {
    id: scene
    thisSceneId: NavigationTable.sceneClosing

    function handleAbsorb(vk, ve) {
        if (ve === KeyDispatcher.evClick
            && (vk === KeyDispatcher.keyBack || vk === KeyDispatcher.keyHome)) {
            Logger.log("closingScene", "absorb (abort sequence start)",
                       "vk=" + Logger.vkName(vk) + "/CLICK",
                       "step1: closingAborted=true")
            Mediator.closingAborted = true
            Logger.log("closingScene", "abort sequence", "",
                       "step2: forceUnloadCurrentView")
            TransitionManager.forceUnloadCurrentView()
            Logger.log("closingScene", "abort sequence", "",
                       "step3: requestNavigate(normal/home, Back)")
            Mediator.requestNavigate(NavigationTable.idNormalHome,
                                     TransitionManager.directionBack)
            return true
        }
        return false
    }
}

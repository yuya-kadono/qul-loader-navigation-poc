// ClosingScene.qml
// Closing シーン。BACK/HOME CLICK で中断 (§8-6 / §10-3)。

import QtQuick
import Constants
import Mediator

SceneBase {
    id: scene
    thisSceneId: SceneId.SceneId.Closing

    function handleAbsorb(vk, ve) {
        if (ve === Event.Event.Click
            && (vk === Key.Key.Back || vk === Key.Key.Home)) {
            Logger.log("closingScene", "absorb (abort sequence start)",
                       "vk=" + Key.nameOf(vk) + "/CLICK",
                       "step1: closingAborted=true")
            Mediator.closingAborted = true
            Logger.log("closingScene", "abort sequence", "",
                       "step2: forceUnloadCurrentView")
            TransitionManager.forceUnloadCurrentView()
            Logger.log("closingScene", "abort sequence", "",
                       "step3: requestNavigate(normal/home, Back)")
            Mediator.requestNavigate(ViewId.ViewId.NormalHome,
                                     Direction.Direction.Back)
            return true
        }
        return false
    }
}

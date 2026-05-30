// ClosingScreen.qml
// Closing シーン。BACK/HOME CLICK で中断 (§8-6 / §10-3)。

import QtQuick
import Constants
import Mediator

ScreenBase {
    id: screen
    thisScreenId: ScreenId.Closing

    function handleAbsorb(vk, ve) {
        if (ve === VirtualEvent.Click
            && (vk === VirtualKey.Back || vk === VirtualKey.Home)) {
            Logger.log("closingScreen", "absorb (abort sequence start)",
                       "vk=" + VirtualKey.nameOf(vk) + "/CLICK",
                       "step1: closingAborted=true")
            Mediator.closingAborted = true
            Logger.log("closingScreen", "abort sequence", "",
                       "step2: forceUnloadCurrentView")
            TransitionManager.forceUnloadCurrentView()
            Logger.log("closingScreen", "abort sequence", "",
                       "step3: switchView(normal/home, Back)")
            Mediator.switchView(ViewId.NormalHome,
                                     NavDirection.Back)
            return true
        }
        return false
    }
}

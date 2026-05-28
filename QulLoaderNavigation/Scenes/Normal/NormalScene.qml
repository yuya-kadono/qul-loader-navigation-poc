// NormalScene.qml
// Normal シーン。MENU CLICK → normal/menu、HOME CLICK → normal/home を吸収 (§8-6)。

import QtQuick
import Constants
import Mediator

SceneBase {
    id: scene
    thisSceneId: SceneId.SceneId.Normal

    function handleAbsorb(vk, ve) {
        if (ve === Event.Event.Click) {
            if (vk === Key.Key.Menu) {
                Logger.log("normalScene", "absorb", "vk=MENU/CLICK",
                           "action=requestNavigate(normal/menu, Next)")
                Mediator.requestNavigate(ViewId.ViewId.NormalMenu,
                                         Direction.Direction.Next)
                return true
            }
            if (vk === Key.Key.Home) {
                Logger.log("normalScene", "absorb", "vk=HOME/CLICK",
                           "action=requestNavigate(normal/home, Next)")
                Mediator.requestNavigate(ViewId.ViewId.NormalHome,
                                         Direction.Direction.Next)
                return true
            }
        }
        return false
    }
}

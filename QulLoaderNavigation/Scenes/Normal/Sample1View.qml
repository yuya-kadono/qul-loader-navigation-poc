// Sample1View.qml
// サンプル①。標準ライフサイクル (ViewBase)。
// 操作:
//   BACK(C) click → menu (Back)

import QtQuick
import Constants
import Mediator

ViewBase {
    thisViewId: ViewId.ViewId.NormalSample1
    displayName: "SAMPLE 1"
    backgroundColor: "#c62828"  // red

    Text {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 24
        color: "white"
        font.pixelSize: 14
        text: "BACK(C): menu に戻る"
    }

    function onViewKey(vk, ve) {
        if (ve !== Event.Event.Click) return
        if (vk === Key.Key.Back) {
            Logger.log("normal/sample1", "action", "BACK/CLICK",
                       "requestNavigate(normal/menu, Back)")
            Mediator.requestNavigate(ViewId.ViewId.NormalMenu,
                                     Direction.Direction.Back)
        }
    }
}

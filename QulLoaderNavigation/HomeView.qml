// HomeView.qml
// Home 画面。標準ライフサイクル (ViewBase)。
// 操作:
//   ENTER click → closing/closing (Next) ※終了開始
//   ※ MENU(Z) は NormalScene が吸収 → normal/menu

import QtQuick
import QulLoaderNavigation

ViewBase {
    thisViewId: NavigationTable.idNormalHome
    displayName: "HOME"
    backgroundColor: "#2e7d32"  // green

    Text {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 24
        color: "white"
        font.pixelSize: 14
        text: "ENTER(S): closing へ   |   MENU(Z): menu へ"
    }

    function onViewKey(vk, ve) {
        if (ve !== KeyDispatcher.evClick) return
        if (vk === KeyDispatcher.keyEnter) {
            Logger.log("normal/home", "action", "ENTER/CLICK",
                       "requestNavigate(closing/closing, Next)")
            Mediator.requestNavigate(NavigationTable.idClosingClosing,
                                     TransitionManager.directionNext)
        }
    }
}

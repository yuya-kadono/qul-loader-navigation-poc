// Sample2View.qml
// サンプル②。**同一 QML で 2 つの viewId (sample2a / sample2b) を担当**する例。
//
// 自分の thisViewId は ViewBase の Component.onCompleted で Mediator.nextLoadingViewId
// から自動取得される (派生で明示指定しないことが key)。
// 取得した ID に応じて displayName / backgroundColor を変える内部分岐 isVariantA / isVariantB。
//
// 操作:
//   BACK(C) click → menu (Back)

import QtQuick
import QulLoaderNavigation

ViewBase {
    id: root
    // thisViewId を明示しない (= 0) → ViewBase が Mediator.nextLoadingViewId から取得

    readonly property bool isVariantA: thisViewId === NavigationTable.idNormalSample2a
    readonly property bool isVariantB: thisViewId === NavigationTable.idNormalSample2b

    displayName: isVariantA ? "SAMPLE 2A" : (isVariantB ? "SAMPLE 2B" : "SAMPLE 2?")
    backgroundColor: isVariantA ? "#6a1b9a" : "#283593"  // purple / indigo

    Text {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 24
        color: "white"
        font.pixelSize: 14
        text: "BACK(C): menu に戻る  (variant=" + (isVariantA ? "A" : "B") + ")"
    }

    function onViewKey(vk, ve) {
        if (ve !== KeyDispatcher.evClick) return
        if (vk === KeyDispatcher.keyBack) {
            Logger.log(NavigationTable.nameOf(thisViewId), "action", "BACK/CLICK",
                       "requestNavigate(normal/menu, Back)")
            Mediator.requestNavigate(NavigationTable.idNormalMenu,
                                     TransitionManager.directionBack)
        }
    }
}

// KeyDispatcher.qml
// 仮想キー (§8-1) / 仮想イベント (§8-2) の enum、配送、enabled フラグ。
//
// QUL 移植性: signal + Connections{target: ...} は使わない。
// 代わりに「世代カウンタ + 最終値プロパティ」で push する:
//   - sceneEventGen / sceneEventVk / sceneEventVe
//   - viewEventGen  / viewEventVk  / viewEventVe
// 受け手 (Scene / View) は自分のローカルプロパティを singleton の世代カウンタに
// バインドし、on<Property>Changed ハンドラで反応する (Connections 不要)。

pragma Singleton
import QtQuick
import QulLoaderNavigation

QtObject {
    // ---- 仮想キー種別 ----
    readonly property int keyPrev:  0
    readonly property int keyEnter: 1
    readonly property int keyNext:  2
    readonly property int keyMenu:  3
    readonly property int keyHome:  4
    readonly property int keyBack:  5

    // ---- 仮想イベント種別 ----
    readonly property int evPress:   0
    readonly property int evRelease: 1
    readonly property int evClick:   2

    // ---- 入力受付フラグ ----
    // false の間は dispatchToScene / dispatchToView が no-op。
    // TransitionManager が transition 中に false にする (§9-7)。
    property bool enabled: true
    onEnabledChanged: Logger.log("KeyDispatcher", "enabled changed",
                                 "value=" + enabled, "")

    // ---- Scene 向け配送状態 (signal 代替) ----
    // sceneEventGen を Scene 側がバインド + on*Changed で監視する。
    // 値そのものに意味はなく、変化したら「新規イベントあり」のしるし。
    property int sceneEventGen: 0
    property int sceneEventVk:  0
    property int sceneEventVe:  0

    // ---- View 向け配送状態 (signal 代替) ----
    property int viewEventGen: 0
    property int viewEventVk:  0
    property int viewEventVe:  0

    // ---- 配送 API ----
    function dispatchToScene(vk, ve) {
        Logger.log("KeyDispatcher", "dispatchToScene",
                   "vk=" + Logger.vkName(vk) + ", ev=" + Logger.veName(ve),
                   "enabled=" + enabled)
        if (!enabled) return
        sceneEventVk = vk
        sceneEventVe = ve
        sceneEventGen = sceneEventGen + 1  // 受け手の binding を更新
        Logger.log("KeyDispatcher", "sceneEvent posted",
                   "vk=" + Logger.vkName(vk) + ", ev=" + Logger.veName(ve),
                   "gen=" + sceneEventGen)
    }
    function dispatchToView(vk, ve) {
        Logger.log("KeyDispatcher", "dispatchToView",
                   "vk=" + Logger.vkName(vk) + ", ev=" + Logger.veName(ve),
                   "enabled=" + enabled)
        if (!enabled) return
        viewEventVk = vk
        viewEventVe = ve
        viewEventGen = viewEventGen + 1
        Logger.log("KeyDispatcher", "viewEvent posted",
                   "vk=" + Logger.vkName(vk) + ", ev=" + Logger.veName(ve),
                   "gen=" + viewEventGen)
    }
}

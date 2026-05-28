// KeyDispatcher.qml
// 仮想キー / 仮想イベントの配送、enabled フラグ (§8)。
//
// 仮想キー種別と仮想イベント種別はそれぞれ Key.qml / Event.qml の enum singleton
// に分離した (例: Key.Key.Enter, Event.Event.Click)。
//
// QUL 移植性: signal + Connections{target: ...} は使わない。
// 代わりに「世代カウンタ + 最終値プロパティ」で push する:
//   - sceneEventGen / sceneEventVk / sceneEventVe
//   - viewEventGen  / viewEventVk  / viewEventVe
// 受け手 (Scene / View) は自分のローカルプロパティを singleton の世代カウンタに
// バインドし、on<Property>Changed ハンドラで反応する (Connections 不要)。

pragma Singleton
import QtQuick
import Constants

QtObject {
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
                   "vk=" + Key.nameOf(vk) + ", ev=" + Event.nameOf(ve),
                   "enabled=" + enabled)
        if (!enabled) return
        sceneEventVk = vk
        sceneEventVe = ve
        sceneEventGen = sceneEventGen + 1  // 受け手の binding を更新
        Logger.log("KeyDispatcher", "sceneEvent posted",
                   "vk=" + Key.nameOf(vk) + ", ev=" + Event.nameOf(ve),
                   "gen=" + sceneEventGen)
    }
    function dispatchToView(vk, ve) {
        Logger.log("KeyDispatcher", "dispatchToView",
                   "vk=" + Key.nameOf(vk) + ", ev=" + Event.nameOf(ve),
                   "enabled=" + enabled)
        if (!enabled) return
        viewEventVk = vk
        viewEventVe = ve
        viewEventGen = viewEventGen + 1
        Logger.log("KeyDispatcher", "viewEvent posted",
                   "vk=" + Key.nameOf(vk) + ", ev=" + Event.nameOf(ve),
                   "gen=" + viewEventGen)
    }
}

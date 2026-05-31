// KeyDispatcher.qml
// 仮想キー / 仮想イベントの配送、enabled フラグ (§8)。
//
// 仮想キー種別と仮想イベント種別はそれぞれ VirtualKey.qml / VirtualEvent.qml の enum singleton
// に分離した (例: VirtualKey.Enter, VirtualEvent.Click)。
//
// QUL 移植性: signal + Connections{target: ...} は使わない。
// 代わりに「世代カウンタ + 最終値プロパティ」で push する:
//   - screenEventGen / screenEventVk / screenEventVe
//   - viewEventGen  / viewEventVk  / viewEventVe
// 受け手 (Screen / View) は自分のローカルプロパティを singleton の世代カウンタに
// バインドし、on<Property>Changed ハンドラで反応する (Connections 不要)。

pragma Singleton
import QtQuick
import Constants

QtObject {
    // ---- 入力受付フラグ ----
    // false の間は dispatchToScreen / dispatchToView が no-op。
    // TransitionManager が transition 中に false にする (§9-7)。
    property bool enabled: true
    onEnabledChanged: Logger.log("KeyDispatcher", "enabled changed",
                                 "value=" + enabled, "")

    // ---- Screen 向け配送状態 (signal 代替) ----
    // screenEventGen を Screen 側がバインド + on*Changed で監視する。
    // 値そのものに意味はなく、変化したら「新規イベントあり」のしるし。
    property int screenEventGen: 0
    property int screenEventVk:  0
    property int screenEventVe:  0

    // ---- View 向け配送状態 (signal 代替) ----
    property int viewEventGen: 0
    property int viewEventVk:  0
    property int viewEventVe:  0

    // ---- 配送 API ----
    function dispatchToScreen(vk, ve) {
        // enabled ガードを先頭へ: 抑制中 (遷移アニメ中) は nameOf 2 回 + 文字列連結を
        // 走らせず固定文字列ログだけで即 return する (デバッグ追跡性は維持)。
        if (!enabled) {
            Logger.log("KeyDispatcher", "dispatchToScreen suppressed (disabled)", "", "")
            return
        }
        Logger.log("KeyDispatcher", "dispatchToScreen",
                   "vk=" + VirtualKey.nameOf(vk) + ", ev=" + VirtualEvent.nameOf(ve),
                   "enabled=" + enabled)
        screenEventVk = vk
        screenEventVe = ve
        screenEventGen = screenEventGen + 1  // 受け手の binding を更新
        Logger.log("KeyDispatcher", "screenEvent posted",
                   "vk=" + VirtualKey.nameOf(vk) + ", ev=" + VirtualEvent.nameOf(ve),
                   "gen=" + screenEventGen)
    }
    function dispatchToView(vk, ve) {
        // enabled ガードを先頭へ (dispatchToScreen と同方針)。
        if (!enabled) {
            Logger.log("KeyDispatcher", "dispatchToView suppressed (disabled)", "", "")
            return
        }
        Logger.log("KeyDispatcher", "dispatchToView",
                   "vk=" + VirtualKey.nameOf(vk) + ", ev=" + VirtualEvent.nameOf(ve),
                   "enabled=" + enabled)
        viewEventVk = vk
        viewEventVe = ve
        viewEventGen = viewEventGen + 1
        Logger.log("KeyDispatcher", "viewEvent posted",
                   "vk=" + VirtualKey.nameOf(vk) + ", ev=" + VirtualEvent.nameOf(ve),
                   "gen=" + viewEventGen)
    }
}

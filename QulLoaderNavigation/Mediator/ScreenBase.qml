// ScreenBase.qml
// Screen の共通骨格 (§3-2 / §8-6)。
//
// 派生 screen が指定するもの:
//   - thisScreenId : 自分の screen ID (ScreenId.Opening/Normal/Closing)
//
// 派生 screen が override できるもの:
//   - function handleAbsorb(vk, ve) : 吸収した場合 true を返す。
//                                     false なら自動で KeyDispatcher.dispatchToView() に転送。
//   - property Item viewArea         : view を描画する領域。デフォルトは screen 全体 (全画面)。
//                                     派生で「中央の小さい Item」を bind すると view はそこに閉じ込められる
//                                     → Header/Footer/Aside など chrome を周囲に配置できる。
//
// 共通機能:
//   - ViewSlot A/B Loader (screen フィルタ付き binding) を viewArea に anchors.fill する。
//     現在 view ID の所属 screen が thisScreenId と一致する場合のみロード (§9-9)。
//   - Component.onCompleted / onDestruction でロード/破棄をログ
//   - screenEventGen 変化で handleAbsorb() を呼び、吸収されなければ view に転送

import QtQuick
import Constants

Item {
    id: screen
    anchors.fill: parent

    // ---- 派生で指定するもの ----
    property int thisScreenId: 0

    // ---- 派生が override 可能なフック ----
    function handleAbsorb(vk, ve) { return false }

    // ---- view 配置領域 (派生で chrome 付き layout に変更可) ----
    // デフォルト: screen 全体 → views は全画面に描画される (Opening/Closing screen 用)。
    // 派生で `viewArea: contentArea` のように bind すると、views はその Item の anchors.fill で
    // 配置される (chrome 付き screen 用)。binding なので viewArea が後から変わっても追従。
    property Item viewArea: screen

    // ---- KeyDispatcher 受信用バインディング ----
    property int screenEventGen: KeyDispatcher.screenEventGen
    property bool ready: false

    Component.onCompleted: {
        Logger.log(ScreenId.nameOf(screen.thisScreenId) + "Screen",
                   "loaded", "", "")
        screen.ready = true
    }
    Component.onDestruction: Logger.log(
        ScreenId.nameOf(screen.thisScreenId) + "Screen",
        "destroyed", "", "")

    onScreenEventGenChanged: {
        if (!screen.ready) return
        var vk = KeyDispatcher.screenEventVk
        var ve = KeyDispatcher.screenEventVe
        Logger.log(ScreenId.nameOf(screen.thisScreenId) + "Screen",
                   "onScreenKeyEvent",
                   "vk=" + VirtualKey.nameOf(vk) + ", ev=" + VirtualEvent.nameOf(ve), "")
        if (screen.handleAbsorb(vk, ve)) {
            return
        }
        Logger.log(ScreenId.nameOf(screen.thisScreenId) + "Screen",
                   "forward-to-view",
                   "vk=" + VirtualKey.nameOf(vk) + ", ev=" + VirtualEvent.nameOf(ve), "")
        KeyDispatcher.dispatchToView(vk, ve)
    }

    // ---- View スロット A: screen フィルタ付き binding ----
    // anchors.fill が screen.viewArea にバインドされるので、派生が viewArea を上書き
    // した瞬間に view 配置領域も追従する。
    Loader {
        id: viewSlotA
        anchors.fill: screen.viewArea
        source: {
            var vid = TransitionManager.viewSlotAViewId
            if (vid === 0) return ""
            if (ViewId.screenOf(vid) === screen.thisScreenId) {
                return TransitionManager.viewSlotASource
            }
            return ""
        }
        active: source !== ""
    }

    // ---- View スロット B ----
    Loader {
        id: viewSlotB
        anchors.fill: screen.viewArea
        source: {
            var vid = TransitionManager.viewSlotBViewId
            if (vid === 0) return ""
            if (ViewId.screenOf(vid) === screen.thisScreenId) {
                return TransitionManager.viewSlotBSource
            }
            return ""
        }
        active: source !== ""
    }
}

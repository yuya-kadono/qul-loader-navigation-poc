// Logger.qml
// フロー可視化用のログ singleton。
// 統一フォーマット: [HH:MM:SS.mmm] Component.fn(args)  | params
//
// QUL 移植性メモ:
//   - var / function 宣言のみ使用 (let/const, arrow function 不使用)
//   - new Date() を使用しているのは「デスクトップ Qt 6 でのフロー検証用」前提。
//     QUL の Date サポートは限定的なので、本物の MCU 移植時は Date を外して
//     単純なカウンタ等に置き換えること。
//   - console.log は QUL でもサポートあり (ただしホスト出力には限定)。
//
// 呼び出し例:
//   Logger.log("KeyDispatcher", "dispatchToScene",
//              "vk=" + Logger.vkName(vk) + ", ev=" + Logger.veName(ve),
//              "enabled=" + enabled)

pragma Singleton
import QtQuick

QtObject {
    // ---- タイムスタンプ (Date は debug-only) ----
    function currentTimestamp() {
        var d = new Date()
        var hh = d.getHours()
        var mm = d.getMinutes()
        var ss = d.getSeconds()
        var ms = d.getMilliseconds()
        var sHh = (hh < 10 ? "0" + hh : "" + hh)
        var sMm = (mm < 10 ? "0" + mm : "" + mm)
        var sSs = (ss < 10 ? "0" + ss : "" + ss)
        var sMs = (ms < 10 ? "00" + ms : (ms < 100 ? "0" + ms : "" + ms))
        return sHh + ":" + sMm + ":" + sSs + "." + sMs
    }

    // ---- ログ出力本体 ----
    function log(component, fn, args, params) {
        var msg = "[" + currentTimestamp() + "] " + component + "." + fn + "(" + (args || "") + ")"
        if (params !== undefined && params !== "" && params !== null) {
            msg += "  | " + params
        }
        console.log(msg)
    }

    // ---- enum 名変換ヘルパ ----
    function vkName(vk) {
        switch (vk) {
            case 0: return "PREV"
            case 1: return "ENTER"
            case 2: return "NEXT"
            case 3: return "MENU"
            case 4: return "HOME"
            case 5: return "BACK"
        }
        return "?(" + vk + ")"
    }
    function veName(ve) {
        switch (ve) {
            case 0: return "PRESS"
            case 1: return "RELEASE"
            case 2: return "CLICK"
        }
        return "?(" + ve + ")"
    }
    function dirName(d) {
        switch (d) {
            case 0: return "Next"
            case 1: return "Back"
        }
        return "?(" + d + ")"
    }
    function lcName(lc) {
        switch (lc) {
            case 0: return "Idle"
            case 1: return "Entering"
            case 2: return "Leaving"
        }
        return "?(" + lc + ")"
    }
}

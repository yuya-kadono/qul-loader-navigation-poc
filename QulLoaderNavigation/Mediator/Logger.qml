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
//              "vk=" + Key.nameOf(vk) + ", ev=" + Event.nameOf(ve),
//              "enabled=" + enabled)
//
// enum 名変換 (vkName/veName/dirName/lcName) は各 enum singleton (Key/Event/Direction/
// Lifecycle) の nameOf に移管した。

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
}

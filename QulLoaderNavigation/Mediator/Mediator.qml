// Mediator.qml
// ナビゲーション意図と履歴トラッキング (§6)。
// 唯一の遷移 API: switchView(viewId, direction)。
// goNext / goBack は持たない — 戻り先・進み先は各 view が判断する (§5-3)。
//
// viewId は ViewId enum (例: ViewId.NormalHome)。0 は「未指定」sentinel。
// direction は NavDirection enum (NavDirection.Next / Back)。

pragma Singleton
import QtQuick
import Constants

QtObject {
    // ---- 状態 ----
    property int currentViewId:  0
    property int previousViewId: 0
    // ★ デバッグ/デモ表示専用。正式なナビゲーション処理では使わない。
    //   戻り先・進み先は各 view が switchView で明示指定する設計 (§2 / §6) なので、
    //   この履歴配列を読んで遷移を決めるコードは存在しない。表示するのは Sample1View
    //   と NormalScreen フッターのみ。本番移植時は削除可。
    //   (1 個前の view だけで足りるカーソル復元は previousViewId を使う — そちらは本番でも必要)
    property var debugHistory: []     // int の配列、末尾が最新 (デバッグ表示専用)

    // ---- 次にロードされる view の ID (§9-10: ViewBase が自己取得用に参照) ----
    // switchView の冒頭で立てる。同一 QML を別 ID で再利用する view
    // (例: Sample2View が sample2a / sample2b 両対応) が自分の thisViewId を
    // 動的に決めるためのスナップショット元。
    property int pendingViewId: 0

    // ---- 唯一の遷移 API ----
    // direction は NavDirection.Next / Back
    // 省略時は NavDirection.Next として扱う。
    function switchView(viewId, direction) {
        if (direction === undefined) direction = NavDirection.Next

        Logger.log("Mediator", "switchView",
                   "viewId=" + ViewId.nameOf(viewId)
                   + ", direction=" + NavDirection.nameOf(direction),
                   "currentViewId=" + ViewId.nameOf(currentViewId)
                   + ", previousViewId=" + ViewId.nameOf(previousViewId)
                   + ", debugHistory.length=" + debugHistory.length)

        // ViewBase が次にロードされる view の ID をスナップショットするための先行公開
        pendingViewId = viewId

        if (viewId === ViewId.ClosingClosing) {
            // closing に入る時点で履歴クリア (もう戻り先はない)
            debugHistory = []
            Logger.log("Mediator", "closing entry reset",
                       "", "debugHistory cleared")
        } else {
            // 通常: 旧 currentViewId を debugHistory に push
            if (currentViewId !== 0) {
                var newHistory = debugHistory.slice()
                newHistory.push(currentViewId)
                debugHistory = newHistory
            }
        }
        previousViewId = currentViewId
        currentViewId  = viewId
        Logger.log("Mediator", "state updated", "",
                   "currentViewId=" + ViewId.nameOf(currentViewId)
                   + ", previousViewId=" + ViewId.nameOf(previousViewId)
                   + ", debugHistory.length=" + debugHistory.length)
        TransitionManager.startTransition(viewId, direction)
    }
}

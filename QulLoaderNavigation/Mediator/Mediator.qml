// Mediator.qml
// ナビゲーション意図と履歴トラッキング (§6)。
// 唯一の遷移 API: requestNavigate(viewId, direction)。
// goNext / goBack は持たない — 戻り先・進み先は各 view が判断する (§5-3)。
//
// viewId は ViewId enum (例: ViewId.ViewId.NormalHome)。0 は「未指定」sentinel。
// direction は Direction enum (Direction.Direction.Next / Back)。

pragma Singleton
import QtQuick
import Constants

QtObject {
    // ---- 状態 ----
    property int currentViewId:  0
    property int previousViewId: 0
    property var history: []          // int の配列、末尾が最新

    // ---- Closing アニメ中断中フラグ (§10-2 / §10-3) ----
    property bool closingAborted: false

    // ---- 次にロードされる view の ID (§9-10: ViewBase が自己取得用に参照) ----
    // requestNavigate の冒頭で立てる。同一 QML を別 ID で再利用する view
    // (例: Sample2View が sample2a / sample2b 両対応) が自分の thisViewId を
    // 動的に決めるためのスナップショット元。
    property int nextLoadingViewId: 0

    // ---- 唯一の遷移 API ----
    // direction は Direction.Direction.Next / Back
    // 省略時は Direction.Direction.Next として扱う。
    function requestNavigate(viewId, direction) {
        if (direction === undefined) direction = Direction.Direction.Next

        Logger.log("Mediator", "requestNavigate",
                   "viewId=" + ViewId.nameOf(viewId)
                   + ", direction=" + Direction.nameOf(direction),
                   "currentViewId=" + ViewId.nameOf(currentViewId)
                   + ", previousViewId=" + ViewId.nameOf(previousViewId)
                   + ", history.length=" + history.length)

        // ViewBase が次にロードされる view の ID をスナップショットするための先行公開
        nextLoadingViewId = viewId

        if (viewId === ViewId.ViewId.ClosingClosing) {
            // closing に入る時点で履歴クリア・中断フラグリセット
            history = []
            closingAborted = false
            Logger.log("Mediator", "closing entry reset",
                       "", "history cleared, closingAborted=false")
        } else {
            // 通常: 旧 currentViewId を history に push
            if (currentViewId !== 0) {
                var newHistory = history.slice()
                newHistory.push(currentViewId)
                history = newHistory
            }
        }
        previousViewId = currentViewId
        currentViewId  = viewId
        Logger.log("Mediator", "state updated", "",
                   "currentViewId=" + ViewId.nameOf(currentViewId)
                   + ", previousViewId=" + ViewId.nameOf(previousViewId)
                   + ", history.length=" + history.length)
        TransitionManager.startTransition(viewId, direction)
    }
}

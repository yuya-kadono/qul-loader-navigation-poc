// TransitionManager.qml
// View 主導ライフサイクルのオーケストレータ (§9)。
//
// viewId は ViewId enum (§5-2)。0 = 未指定。
// direction は NavDirection.Next/Back。
// lifecycle は ViewLifecycle.Idle/Entering/Leaving。
//
// QUL 移植性: signal + Connections は使わない。
//   - transitionFinished signal の代替: finishedGen / lastFinishedViewId プロパティ
//   - screenSourceA/B 変化のログは自オブジェクト内の on<Property>Changed で完結
//
// ★ ID → qrc URL の解決は DI (§3-3)。
//   Mediator モジュールはメインモジュールの qrc 配置を知らない方針なので、URL マップ
//   (ScreenRegistry singleton、メインモジュール所属) を起動時に外部から
//   `TransitionManager.screenRegistry = ScreenRegistry` と注入してもらう。
//   startTransition は screenRegistry.screenUrlOf / viewUrlOf 経由で URL を取得する。
//   未注入のまま startTransition が呼ばれた場合はログだけ吐いて no-op。
//
// 外部 API:
//   startTransition(toViewId, direction)  - 遷移を開始
//   reportEnterComplete(viewId)           - view から enter 完了通知
//   reportLeaveComplete(viewId)           - view から leave 完了通知
//   forceUnloadCurrentView()              - closing 中断専用 (§10-2)
//   abortCurrentTransition()              - 進行中遷移の即終了
//
// View 用 ID キー lookup (§9-3):
//   lifecycleOf(viewId)                   - 現在の lifecycle 値
//   directionOf(viewId)                   - 方向 (next/back)
//   partnerOf(viewId)                     - enter 側 = fromId, leave 側 = toId

pragma Singleton
import QtQuick
import Constants

QtObject {
    id: tm

    // ---- DI: ID → qrc URL のリゾルバ (Main.qml で注入) ----
    // ScreenRegistry singleton (メインモジュール所属) を期待。期待インターフェース:
    //   function screenUrlOf(screenId: int) -> string
    //   function viewUrlOf(viewId: int)   -> string
    property var screenRegistry: null

    // ---- 進行状態 (Idle / InProgress) ----
    property int state: ViewLifecycle.Idle

    // ---- Screen スロット (Main.qml がバインド) ----
    property string screenSourceA: ""
    property string screenSourceB: ""
    property bool   screenAIsCurrent: true

    onScreenSourceAChanged: Logger.log("TransitionManager", "screenSourceA changed",
                                      "", "value=" + screenSourceA)
    onScreenSourceBChanged: Logger.log("TransitionManager", "screenSourceB changed",
                                      "", "value=" + screenSourceB)

    // ---- View スロット (各 Screen 内 ViewLoader が screen フィルタ付きでバインド) ----
    property string viewSlotASource: ""
    property string viewSlotBSource: ""
    property int    viewSlotAViewId: 0      // 0 = unset
    property int    viewSlotBViewId: 0
    property int    viewSlotALifecycle: ViewLifecycle.Idle
    property int    viewSlotBLifecycle: ViewLifecycle.Idle
    property int    viewSlotADirection:  NavDirection.Next
    property int    viewSlotBDirection:  NavDirection.Next
    property int    viewSlotAPartnerId:  0  // 0 = unset
    property int    viewSlotBPartnerId:  0
    property bool   viewAIsCurrent: true

    // ---- 遷移完了通知 (signal の代替: 世代カウンタ + 最終 view ID) ----
    property int    finishedGen: 0
    property int    lastFinishedViewId: 0

    // ---- 内部追跡 ----
    property bool   enterReported: false
    property bool   leaveReported: false
    property int    pendingFinalId: 0
    property bool   isCrossScreen:   false
    property bool   hasLeavingView: false

    // ============================================================
    // View 用 ID キー lookup
    // ============================================================
    function lifecycleOf(viewId) {
        if (viewSlotAViewId === viewId) return viewSlotALifecycle
        if (viewSlotBViewId === viewId) return viewSlotBLifecycle
        return ViewLifecycle.Idle
    }
    function directionOf(viewId) {
        if (viewSlotAViewId === viewId) return viewSlotADirection
        if (viewSlotBViewId === viewId) return viewSlotBDirection
        return NavDirection.Next
    }
    function partnerOf(viewId) {
        if (viewSlotAViewId === viewId) return viewSlotAPartnerId
        if (viewSlotBViewId === viewId) return viewSlotBPartnerId
        return 0
    }

    // ============================================================
    // 完了報告 (view 側から呼ぶ)
    // ============================================================
    function reportEnterComplete(viewId) {
        Logger.log("TransitionManager", "reportEnterComplete",
                   "viewId=" + ViewId.nameOf(viewId),
                   "slotA(" + ViewId.nameOf(viewSlotAViewId) + ")=" + ViewLifecycle.nameOf(viewSlotALifecycle)
                   + ", slotB(" + ViewId.nameOf(viewSlotBViewId) + ")=" + ViewLifecycle.nameOf(viewSlotBLifecycle))
        if (viewSlotAViewId === viewId && viewSlotALifecycle === ViewLifecycle.Entering) {
            enterReported = true
        } else if (viewSlotBViewId === viewId && viewSlotBLifecycle === ViewLifecycle.Entering) {
            enterReported = true
        }
        checkAndFinish()
    }
    function reportLeaveComplete(viewId) {
        Logger.log("TransitionManager", "reportLeaveComplete",
                   "viewId=" + ViewId.nameOf(viewId),
                   "slotA(" + ViewId.nameOf(viewSlotAViewId) + ")=" + ViewLifecycle.nameOf(viewSlotALifecycle)
                   + ", slotB(" + ViewId.nameOf(viewSlotBViewId) + ")=" + ViewLifecycle.nameOf(viewSlotBLifecycle))
        if (viewSlotAViewId === viewId && viewSlotALifecycle === ViewLifecycle.Leaving) {
            leaveReported = true
        } else if (viewSlotBViewId === viewId && viewSlotBLifecycle === ViewLifecycle.Leaving) {
            leaveReported = true
        }
        checkAndFinish()
    }

    function checkAndFinish() {
        var enterNeeded = (viewSlotALifecycle === ViewLifecycle.Entering
                        || viewSlotBLifecycle === ViewLifecycle.Entering)
        var leaveNeeded = (viewSlotALifecycle === ViewLifecycle.Leaving
                        || viewSlotBLifecycle === ViewLifecycle.Leaving)
        Logger.log("TransitionManager", "checkAndFinish", "",
                   "enterNeeded=" + enterNeeded + "/reported=" + enterReported
                   + ", leaveNeeded=" + leaveNeeded + "/reported=" + leaveReported)
        if (enterNeeded && !enterReported) return
        if (leaveNeeded && !leaveReported) return
        finalizeTransition()
    }

    function finalizeTransition() {
        Logger.log("TransitionManager", "finalizeTransition", "",
                   "isCrossScreen=" + isCrossScreen
                   + ", screenAIsCurrent=" + screenAIsCurrent
                   + ", viewAIsCurrent=" + viewAIsCurrent
                   + ", pendingFinalId=" + ViewId.nameOf(pendingFinalId))
        // Leaving 側のスロットを解放
        if (viewSlotALifecycle === ViewLifecycle.Leaving) {
            viewSlotASource = ""
            viewSlotAViewId = 0
            viewSlotAPartnerId = 0
            viewSlotALifecycle = ViewLifecycle.Idle
        }
        if (viewSlotBLifecycle === ViewLifecycle.Leaving) {
            viewSlotBSource = ""
            viewSlotBViewId = 0
            viewSlotBPartnerId = 0
            viewSlotBLifecycle = ViewLifecycle.Idle
        }
        // Entering 側のスロットを current に昇格
        if (viewSlotALifecycle === ViewLifecycle.Entering) {
            viewSlotALifecycle = ViewLifecycle.Idle
            viewSlotAPartnerId = 0
            viewAIsCurrent = true
        }
        if (viewSlotBLifecycle === ViewLifecycle.Entering) {
            viewSlotBLifecycle = ViewLifecycle.Idle
            viewSlotBPartnerId = 0
            viewAIsCurrent = false
        }

        // Cross-screen の場合は旧 screen スロットを解放
        if (isCrossScreen) {
            if (screenAIsCurrent) {
                screenSourceA = ""
                screenAIsCurrent = false
            } else {
                screenSourceB = ""
                screenAIsCurrent = true
            }
        }

        state = ViewLifecycle.Idle
        KeyDispatcher.enabled = true
        enterReported = false
        leaveReported = false
        isCrossScreen = false
        hasLeavingView = false

        var finalId = pendingFinalId
        pendingFinalId = 0
        // transitionFinished signal の代わりに finishedGen を進める
        lastFinishedViewId = finalId
        finishedGen = finishedGen + 1
        Logger.log("TransitionManager", "transition finished",
                   "finalViewId=" + ViewId.nameOf(finalId) + ", gen=" + finishedGen,
                   "screenSourceA=" + screenSourceA + ", screenSourceB=" + screenSourceB
                   + ", screenAIsCurrent=" + screenAIsCurrent
                   + ", viewSlotA(" + ViewId.nameOf(viewSlotAViewId) + ")"
                   + ", viewSlotB(" + ViewId.nameOf(viewSlotBViewId) + ")"
                   + ", viewAIsCurrent=" + viewAIsCurrent)
    }

    // ============================================================
    // 遷移開始
    // ============================================================
    function startTransition(toViewId, direction) {
        if (direction === undefined) direction = NavDirection.Next

        if (!screenRegistry) {
            Logger.log("TransitionManager", "startTransition ABORT",
                       "toViewId=" + ViewId.nameOf(toViewId),
                       "screenRegistry not injected (Main.qml の Component.onCompleted で代入忘れ?)")
            return
        }

        var fromViewId = (viewAIsCurrent ? viewSlotAViewId : viewSlotBViewId)
        var targetScreenId = ViewId.screenOf(toViewId)
        var targetScreen = screenRegistry.screenUrlOf(targetScreenId)
        var targetView  = screenRegistry.viewUrlOf(toViewId)
        if (targetScreen === "" || targetView === "") {
            Logger.log("TransitionManager", "startTransition ABORT",
                       "toViewId=" + ViewId.nameOf(toViewId),
                       "screenRegistry returned empty URL (未登録の ID か qrc パスのずれ)")
            return
        }
        var fromScreenId = (fromViewId !== 0) ? ViewId.screenOf(fromViewId) : 0
        var screenChanged = (fromScreenId !== targetScreenId)
        Logger.log("TransitionManager", "startTransition",
                   "toViewId=" + ViewId.nameOf(toViewId)
                   + ", direction=" + NavDirection.nameOf(direction),
                   "fromViewId=" + ViewId.nameOf(fromViewId)
                   + ", screenChanged=" + screenChanged
                   + ", hasLeavingView=" + (fromViewId !== 0)
                   + ", targetScreen=" + targetScreen
                   + ", targetView=" + targetView)

        KeyDispatcher.enabled = false
        state = ViewLifecycle.Entering
        enterReported = false
        leaveReported = false
        pendingFinalId = toViewId
        isCrossScreen = screenChanged
        hasLeavingView = (fromViewId !== 0)

        // 新 screen をロード
        if (screenChanged) {
            if (screenAIsCurrent) {
                screenSourceB = targetScreen
            } else {
                screenSourceA = targetScreen
            }
        }

        // ★ write 順が重要 ★ (§9-3-1)
        // 1. Entering の metadata (ID/direction/partner/lifecycle) を先に
        // 2. Leaving の metadata (= 既存 view の leaveAnim を起動)
        // 3. Entering の source を最後 (Loader.source 変化で新 view ロード時に
        //    metadata が揃っている → onCompleted が正しい state を見られる)
        var enteringIsA = !viewAIsCurrent

        if (enteringIsA) {
            // (1) Entering = A の metadata
            viewSlotAViewId     = toViewId
            viewSlotADirection  = direction
            viewSlotAPartnerId  = fromViewId
            viewSlotALifecycle  = ViewLifecycle.Entering

            // (2) Leaving = B の metadata
            if (hasLeavingView) {
                viewSlotBDirection  = direction
                viewSlotBPartnerId  = toViewId
                viewSlotBLifecycle  = ViewLifecycle.Leaving
            }

            // (3) Entering = A の source は最後
            viewSlotASource     = targetView
        } else {
            // (1) Entering = B の metadata
            viewSlotBViewId     = toViewId
            viewSlotBDirection  = direction
            viewSlotBPartnerId  = fromViewId
            viewSlotBLifecycle  = ViewLifecycle.Entering

            // (2) Leaving = A の metadata
            if (hasLeavingView) {
                viewSlotADirection  = direction
                viewSlotAPartnerId  = toViewId
                viewSlotALifecycle  = ViewLifecycle.Leaving
            }

            // (3) Entering = B の source は最後
            viewSlotBSource     = targetView
        }
        Logger.log("TransitionManager", "startTransition done", "",
                   "enteringIsA=" + enteringIsA
                   + ", slotA(" + ViewId.nameOf(viewSlotAViewId) + ")=" + ViewLifecycle.nameOf(viewSlotALifecycle)
                   + ", slotB(" + ViewId.nameOf(viewSlotBViewId) + ")=" + ViewLifecycle.nameOf(viewSlotBLifecycle))
    }

    // ============================================================
    // Closing 中断専用: current の View スロットを強制アンロード (§10-2)
    // ============================================================
    function forceUnloadCurrentView() {
        Logger.log("TransitionManager", "forceUnloadCurrentView", "",
                   "viewAIsCurrent=" + viewAIsCurrent
                   + ", slotA=" + ViewId.nameOf(viewSlotAViewId)
                   + ", slotB=" + ViewId.nameOf(viewSlotBViewId))
        if (viewAIsCurrent) {
            viewSlotASource = ""
            viewSlotAViewId = 0
            viewSlotAPartnerId = 0
            viewSlotALifecycle = ViewLifecycle.Idle
        } else {
            viewSlotBSource = ""
            viewSlotBViewId = 0
            viewSlotBPartnerId = 0
            viewSlotBLifecycle = ViewLifecycle.Idle
        }
        state = ViewLifecycle.Idle
        enterReported = false
        leaveReported = false
        pendingFinalId = 0
        isCrossScreen = false
        hasLeavingView = false
        KeyDispatcher.enabled = true
    }

    // ============================================================
    // 連続遷移用: 進行中遷移を即終了 (§9-8)
    // ============================================================
    function abortCurrentTransition() {
        Logger.log("TransitionManager", "abortCurrentTransition", "",
                   "state=" + state)
        if (state === ViewLifecycle.Idle) return
        enterReported = true
        leaveReported = true
        finalizeTransition()
    }
}

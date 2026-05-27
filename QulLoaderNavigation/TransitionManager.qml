// TransitionManager.qml
// View 主導ライフサイクルのオーケストレータ (§9)。
//
// viewId は NavigationTable の整数 enum (§5-2)。0 = 未指定。
//
// QUL 移植性: signal + Connections は使わない。
//   - transitionFinished signal の代替: finishedGen / lastFinishedViewId プロパティ
//   - sceneSourceA/B 変化のログは自オブジェクト内の on<Property>Changed で完結
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
import QulLoaderNavigation

QtObject {
    id: tm

    // ---- Direction enum ----
    readonly property int directionNext: 0
    readonly property int directionBack: 1

    // ---- Lifecycle enum ----
    readonly property int lifecycleIdle:     0
    readonly property int lifecycleEntering: 1
    readonly property int lifecycleLeaving:  2

    // ---- 進行状態 (Idle / InProgress) ----
    property int state: lifecycleIdle

    // ---- Scene スロット (Main.qml がバインド) ----
    property string sceneSourceA: ""
    property string sceneSourceB: ""
    property bool   sceneAIsCurrent: true

    onSceneSourceAChanged: Logger.log("TransitionManager", "sceneSourceA changed",
                                      "", "value=" + sceneSourceA)
    onSceneSourceBChanged: Logger.log("TransitionManager", "sceneSourceB changed",
                                      "", "value=" + sceneSourceB)

    // ---- View スロット (各 Scene 内 ViewLoader が scene フィルタ付きでバインド) ----
    property string viewSlotASource: ""
    property string viewSlotBSource: ""
    property int    viewSlotAViewId: 0      // 0 = unset
    property int    viewSlotBViewId: 0
    property int    viewSlotALifecycle: lifecycleIdle
    property int    viewSlotBLifecycle: lifecycleIdle
    property int    viewSlotADirection:  directionNext
    property int    viewSlotBDirection:  directionNext
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
    property bool   isCrossScene:   false
    property bool   hasLeavingView: false

    // ============================================================
    // View 用 ID キー lookup
    // ============================================================
    function lifecycleOf(viewId) {
        if (viewSlotAViewId === viewId) return viewSlotALifecycle
        if (viewSlotBViewId === viewId) return viewSlotBLifecycle
        return lifecycleIdle
    }
    function directionOf(viewId) {
        if (viewSlotAViewId === viewId) return viewSlotADirection
        if (viewSlotBViewId === viewId) return viewSlotBDirection
        return directionNext
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
                   "viewId=" + NavigationTable.nameOf(viewId),
                   "slotA(" + NavigationTable.nameOf(viewSlotAViewId) + ")=" + Logger.lcName(viewSlotALifecycle)
                   + ", slotB(" + NavigationTable.nameOf(viewSlotBViewId) + ")=" + Logger.lcName(viewSlotBLifecycle))
        if (viewSlotAViewId === viewId && viewSlotALifecycle === lifecycleEntering) {
            enterReported = true
        } else if (viewSlotBViewId === viewId && viewSlotBLifecycle === lifecycleEntering) {
            enterReported = true
        }
        checkAndFinish()
    }
    function reportLeaveComplete(viewId) {
        Logger.log("TransitionManager", "reportLeaveComplete",
                   "viewId=" + NavigationTable.nameOf(viewId),
                   "slotA(" + NavigationTable.nameOf(viewSlotAViewId) + ")=" + Logger.lcName(viewSlotALifecycle)
                   + ", slotB(" + NavigationTable.nameOf(viewSlotBViewId) + ")=" + Logger.lcName(viewSlotBLifecycle))
        if (viewSlotAViewId === viewId && viewSlotALifecycle === lifecycleLeaving) {
            leaveReported = true
        } else if (viewSlotBViewId === viewId && viewSlotBLifecycle === lifecycleLeaving) {
            leaveReported = true
        }
        checkAndFinish()
    }

    function checkAndFinish() {
        var enterNeeded = (viewSlotALifecycle === lifecycleEntering
                        || viewSlotBLifecycle === lifecycleEntering)
        var leaveNeeded = (viewSlotALifecycle === lifecycleLeaving
                        || viewSlotBLifecycle === lifecycleLeaving)
        Logger.log("TransitionManager", "checkAndFinish", "",
                   "enterNeeded=" + enterNeeded + "/reported=" + enterReported
                   + ", leaveNeeded=" + leaveNeeded + "/reported=" + leaveReported)
        if (enterNeeded && !enterReported) return
        if (leaveNeeded && !leaveReported) return
        finalizeTransition()
    }

    function finalizeTransition() {
        Logger.log("TransitionManager", "finalizeTransition", "",
                   "isCrossScene=" + isCrossScene
                   + ", sceneAIsCurrent=" + sceneAIsCurrent
                   + ", viewAIsCurrent=" + viewAIsCurrent
                   + ", pendingFinalId=" + NavigationTable.nameOf(pendingFinalId))
        // Leaving 側のスロットを解放
        if (viewSlotALifecycle === lifecycleLeaving) {
            viewSlotASource = ""
            viewSlotAViewId = 0
            viewSlotAPartnerId = 0
            viewSlotALifecycle = lifecycleIdle
        }
        if (viewSlotBLifecycle === lifecycleLeaving) {
            viewSlotBSource = ""
            viewSlotBViewId = 0
            viewSlotBPartnerId = 0
            viewSlotBLifecycle = lifecycleIdle
        }
        // Entering 側のスロットを current に昇格
        if (viewSlotALifecycle === lifecycleEntering) {
            viewSlotALifecycle = lifecycleIdle
            viewSlotAPartnerId = 0
            viewAIsCurrent = true
        }
        if (viewSlotBLifecycle === lifecycleEntering) {
            viewSlotBLifecycle = lifecycleIdle
            viewSlotBPartnerId = 0
            viewAIsCurrent = false
        }

        // Cross-scene の場合は旧 scene スロットを解放
        if (isCrossScene) {
            if (sceneAIsCurrent) {
                sceneSourceA = ""
                sceneAIsCurrent = false
            } else {
                sceneSourceB = ""
                sceneAIsCurrent = true
            }
        }

        state = lifecycleIdle
        KeyDispatcher.enabled = true
        enterReported = false
        leaveReported = false
        isCrossScene = false
        hasLeavingView = false

        var finalId = pendingFinalId
        pendingFinalId = 0
        // transitionFinished signal の代わりに finishedGen を進める
        lastFinishedViewId = finalId
        finishedGen = finishedGen + 1
        Logger.log("TransitionManager", "transition finished",
                   "finalViewId=" + NavigationTable.nameOf(finalId) + ", gen=" + finishedGen,
                   "sceneSourceA=" + sceneSourceA + ", sceneSourceB=" + sceneSourceB
                   + ", sceneAIsCurrent=" + sceneAIsCurrent
                   + ", viewSlotA(" + NavigationTable.nameOf(viewSlotAViewId) + ")"
                   + ", viewSlotB(" + NavigationTable.nameOf(viewSlotBViewId) + ")"
                   + ", viewAIsCurrent=" + viewAIsCurrent)
    }

    // ============================================================
    // 遷移開始
    // ============================================================
    function startTransition(toViewId, direction) {
        if (direction === undefined) direction = directionNext

        var fromViewId = (viewAIsCurrent ? viewSlotAViewId : viewSlotBViewId)
        var targetScene = NavigationTable.sceneFileOf(toViewId)
        var targetView  = NavigationTable.viewFileOf(toViewId)
        if (targetScene === "" || targetView === "") {
            Logger.log("TransitionManager", "startTransition ABORT",
                       "toViewId=" + NavigationTable.nameOf(toViewId),
                       "unknown view ID")
            return
        }
        var fromSceneId = (fromViewId !== 0) ? NavigationTable.sceneOf(fromViewId) : 0
        var sceneChanged = (fromSceneId !== NavigationTable.sceneOf(toViewId))
        Logger.log("TransitionManager", "startTransition",
                   "toViewId=" + NavigationTable.nameOf(toViewId)
                   + ", direction=" + Logger.dirName(direction),
                   "fromViewId=" + NavigationTable.nameOf(fromViewId)
                   + ", sceneChanged=" + sceneChanged
                   + ", hasLeavingView=" + (fromViewId !== 0)
                   + ", targetScene=" + targetScene
                   + ", targetView=" + targetView)

        KeyDispatcher.enabled = false
        state = lifecycleEntering
        enterReported = false
        leaveReported = false
        pendingFinalId = toViewId
        isCrossScene = sceneChanged
        hasLeavingView = (fromViewId !== 0)

        // 新 scene をロード
        if (sceneChanged) {
            if (sceneAIsCurrent) {
                sceneSourceB = targetScene
            } else {
                sceneSourceA = targetScene
            }
        }

        // ★ write 順が重要 ★ (§9-3-1)
        // 1. Incoming の metadata (ID/direction/partner/lifecycle) を先に
        // 2. Leaving の metadata (= 既存 view の leaveAnim を起動)
        // 3. Incoming の source を最後 (Loader.source 変化で新 view ロード時に
        //    metadata が揃っている → onCompleted が正しい state を見られる)
        var incomingIsA = !viewAIsCurrent

        if (incomingIsA) {
            // (1) Incoming = A の metadata
            viewSlotAViewId     = toViewId
            viewSlotADirection  = direction
            viewSlotAPartnerId  = fromViewId
            viewSlotALifecycle  = lifecycleEntering

            // (2) Leaving = B の metadata
            if (hasLeavingView) {
                viewSlotBDirection  = direction
                viewSlotBPartnerId  = toViewId
                viewSlotBLifecycle  = lifecycleLeaving
            }

            // (3) Incoming = A の source は最後
            viewSlotASource     = targetView
        } else {
            // (1) Incoming = B の metadata
            viewSlotBViewId     = toViewId
            viewSlotBDirection  = direction
            viewSlotBPartnerId  = fromViewId
            viewSlotBLifecycle  = lifecycleEntering

            // (2) Leaving = A の metadata
            if (hasLeavingView) {
                viewSlotADirection  = direction
                viewSlotAPartnerId  = toViewId
                viewSlotALifecycle  = lifecycleLeaving
            }

            // (3) Incoming = B の source は最後
            viewSlotBSource     = targetView
        }
        Logger.log("TransitionManager", "startTransition done", "",
                   "incomingIsA=" + incomingIsA
                   + ", slotA(" + NavigationTable.nameOf(viewSlotAViewId) + ")=" + Logger.lcName(viewSlotALifecycle)
                   + ", slotB(" + NavigationTable.nameOf(viewSlotBViewId) + ")=" + Logger.lcName(viewSlotBLifecycle))
    }

    // ============================================================
    // Closing 中断専用: current の View スロットを強制アンロード (§10-2)
    // ============================================================
    function forceUnloadCurrentView() {
        Logger.log("TransitionManager", "forceUnloadCurrentView", "",
                   "viewAIsCurrent=" + viewAIsCurrent
                   + ", slotA=" + NavigationTable.nameOf(viewSlotAViewId)
                   + ", slotB=" + NavigationTable.nameOf(viewSlotBViewId))
        if (viewAIsCurrent) {
            viewSlotASource = ""
            viewSlotAViewId = 0
            viewSlotAPartnerId = 0
            viewSlotALifecycle = lifecycleIdle
        } else {
            viewSlotBSource = ""
            viewSlotBViewId = 0
            viewSlotBPartnerId = 0
            viewSlotBLifecycle = lifecycleIdle
        }
        state = lifecycleIdle
        enterReported = false
        leaveReported = false
        pendingFinalId = 0
        isCrossScene = false
        hasLeavingView = false
        KeyDispatcher.enabled = true
    }

    // ============================================================
    // 連続遷移用: 進行中遷移を即終了 (§9-8)
    // ============================================================
    function abortCurrentTransition() {
        Logger.log("TransitionManager", "abortCurrentTransition", "",
                   "state=" + state)
        if (state === lifecycleIdle) return
        enterReported = true
        leaveReported = true
        finalizeTransition()
    }
}

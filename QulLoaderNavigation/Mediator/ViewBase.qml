// ViewBase.qml
// View の共通骨格 (§9-4 View ライフサイクル契約)。
//
// viewId は ViewId enum (§5-2)。0 = 未指定。
//
// thisViewId の決め方:
//   - 派生 view が明示的に `thisViewId: ViewId.NormalHome` のように
//     指定すればそれを使う (単一 ID の view: Home/Menu/Sample1 等)
//   - 派生 view が指定しなければ (0 のまま)、Component.onCompleted で
//     Mediator.pendingViewId から自動取得 (同一 QML 多重 ID の view: Sample2View 等)
//
// 派生 view が override 可能なフック:
//   - function onEntering()     : lifecycle Entering 検知時 (performEnter の直前)
//   - function onLeaving()      : lifecycle Leaving  検知時 (performLeave の直前)
//   - function performEnter()   : enter アニメ起動。default は標準ランダム fade-in。
//   - function performLeave()   : leave アニメ起動。default は標準ランダム fade-out。
//   - function onViewKey(vk, ve): KeyDispatcher の viewEvent を受信したときの処理。
//
// ---- 配色方針 (ダーク統一) ----
//   ViewBase はダーク背景 (#1c1c1c) + 上部 6px の **アクセントライン** を提供する。
//   派生 view は accentColor だけ指定すれば identity が伝わる (Material 300 level の柔色推奨)。
//   過去にあった原色背景 (緑/オレンジ/赤/紫等) は廃止 → 「フラットダーク + 細い色帯」で識別。

import QtQuick
import Constants

Item {
    id: root
    anchors.fill: parent

    // ---- 派生プロパティ ----
    // thisViewId は派生が直接指定 or 未指定 (0) なら Mediator から取得
    property int    thisViewId: 0
    property string displayName: ""        // 論理名 (現在は UI として描画しない、メタデータのみ)
    property color  backgroundColor: "#1e1e1e"  // 統一ダーク (Material dark surface 系)
    property color  accentColor: "#404040"      // 派生で identity 色を指定 (= 上部 6px ライン色)

    // ---- TransitionManager から view 状態を取得 ----
    // 機能で使うのは myLifecycle だけ (reactToLifecycle を駆動)。
    // direction / partner はログ表示専用なので live binding を持たず、
    // ログ出力時に TransitionManager.directionOf / partnerOf を都度呼ぶ。
    // → 各 view が TransitionManager に持つ reactive 結合を 3 本から 1 本に削減し、
    //   遷移中の slot メタデータ書き換えによる再評価 fan-out を抑える。
    readonly property int    myLifecycle: TransitionManager.lifecycleOf(thisViewId)

    opacity: 0  // 初期は不可視

    // ---- 背景 ----
    Rectangle {
        anchors.fill: parent
        color: root.backgroundColor
    }

    // ---- 上部アクセントライン (派生 view ごとの identity を伝える 6px の細帯) ----
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 6
        color: root.accentColor
        z: 1  // 背景の上、コンテンツの下
    }

    NumberAnimation {
        id: enterAnim
        target: root; property: "opacity"
        from: 0; to: 1
        onStopped: {
            Logger.log(ViewId.nameOf(root.thisViewId), "enterAnim.onStopped", "",
                       "duration=" + enterAnim.duration + "ms")
            TransitionManager.reportEnterComplete(root.thisViewId)
        }
    }
    NumberAnimation {
        id: leaveAnim
        target: root; property: "opacity"
        from: 1; to: 0
        onStopped: {
            Logger.log(ViewId.nameOf(root.thisViewId), "leaveAnim.onStopped", "",
                       "duration=" + leaveAnim.duration + "ms")
            TransitionManager.reportLeaveComplete(root.thisViewId)
        }
    }

    // ---- 派生フック ----
    function onEntering() {}
    function onLeaving() {}

    function pickDuration() {
        if (Math.random() < 0.2) return 0
        return 200 + Math.floor(Math.random() * 600)
    }

    function performEnter() {
        var dur = pickDuration()
        if (dur === 0) {
            opacity = 1
            Logger.log(ViewId.nameOf(root.thisViewId), "performEnter (instant)", "",
                       "duration=0, deferred report via Qt.callLater")
            Qt.callLater(reportEnterCompleteDeferred)
        } else {
            enterAnim.duration = dur
            Logger.log(ViewId.nameOf(root.thisViewId), "enterAnim.start", "",
                       "duration=" + dur + "ms")
            enterAnim.start()
        }
    }
    function performLeave() {
        var dur = pickDuration()
        if (dur === 0) {
            opacity = 0
            Logger.log(ViewId.nameOf(root.thisViewId), "performLeave (instant)", "",
                       "duration=0, deferred report via Qt.callLater")
            Qt.callLater(reportLeaveCompleteDeferred)
        } else {
            leaveAnim.duration = dur
            Logger.log(ViewId.nameOf(root.thisViewId), "leaveAnim.start", "",
                       "duration=" + dur + "ms")
            leaveAnim.start()
        }
    }

    function reportEnterCompleteDeferred() {
        Logger.log(ViewId.nameOf(root.thisViewId), "deferred reportEnterComplete",
                   "", "(instant enter)")
        TransitionManager.reportEnterComplete(root.thisViewId)
    }
    function reportLeaveCompleteDeferred() {
        Logger.log(ViewId.nameOf(root.thisViewId), "deferred reportLeaveComplete",
                   "", "(instant leave)")
        TransitionManager.reportLeaveComplete(root.thisViewId)
    }

    // ---- lifecycle 反応 ----
    property bool reactedInitial: false

    function reactToLifecycle() {
        // 昇格/解放で lifecycle が Idle に戻ったときの空振り発火を無視する。
        // (finalizeTransition が Entering/Leaving → Idle に書き戻す瞬間に
        //  onMyLifecycleChanged が 1 回鳴るが、ここでは何もすることがない)
        if (myLifecycle === ViewLifecycle.Idle) return
        reactedInitial = true
        var lcDir = TransitionManager.directionOf(thisViewId)
        var lcPartner = TransitionManager.partnerOf(thisViewId)
        Logger.log(ViewId.nameOf(root.thisViewId), "reactToLifecycle", "",
                   "myLifecycle=" + ViewLifecycle.nameOf(myLifecycle)
                   + ", direction=" + NavDirection.nameOf(lcDir)
                   + ", partner=" + (lcPartner !== 0 ? ViewId.nameOf(lcPartner) : "(none)"))
        if (myLifecycle === ViewLifecycle.Entering) {
            onEntering()
            performEnter()
        } else if (myLifecycle === ViewLifecycle.Leaving) {
            onLeaving()
            performLeave()
        }
    }

    onMyLifecycleChanged: reactToLifecycle()

    // ---- KeyDispatcher viewEvent 受信用バインディング ----
    property int viewEventGen: KeyDispatcher.viewEventGen
    property bool readyForKeys: false

    function onViewKey(vk, ve) {}

    onViewEventGenChanged: {
        if (!readyForKeys) return
        var vk = KeyDispatcher.viewEventVk
        var ve = KeyDispatcher.viewEventVe
        Logger.log(ViewId.nameOf(root.thisViewId), "onViewKey",
                   "vk=" + VirtualKey.nameOf(vk) + ", ev=" + VirtualEvent.nameOf(ve), "")
        onViewKey(vk, ve)
    }

    Component.onCompleted: {
        // 派生が thisViewId を指定していなければ、Mediator から取得
        // (同一 QML 多重 ID 用、例: Sample2View が sample2a/sample2b 両対応)
        if (root.thisViewId === 0) {
            root.thisViewId = Mediator.pendingViewId
            Logger.log(ViewId.nameOf(root.thisViewId),
                       "thisViewId auto-resolved", "",
                       "from Mediator.pendingViewId=" + ViewId.nameOf(Mediator.pendingViewId))
        }
        Logger.log(ViewId.nameOf(root.thisViewId), "Component.onCompleted", "",
                   "myLifecycle=" + ViewLifecycle.nameOf(myLifecycle))
        if (!reactedInitial) reactToLifecycle()
        readyForKeys = true
    }
    Component.onDestruction: Logger.log(
        ViewId.nameOf(root.thisViewId), "Component.onDestruction", "", "")
}

// ViewBase.qml
// View の共通骨格 (§9-4 View ライフサイクル契約)。
//
// viewId は ViewId enum (§5-2)。0 = 未指定。
//
// thisViewId の決め方:
//   - 派生 view が明示的に `thisViewId: ViewId.ViewId.NormalHome` のように
//     指定すればそれを使う (単一 ID の view: Home/Menu/Sample1 等)
//   - 派生 view が指定しなければ (0 のまま)、Component.onCompleted で
//     Mediator.nextLoadingViewId から自動取得 (同一 QML 多重 ID の view: Sample2View 等)
//
// 派生 view が override 可能なフック:
//   - function onEntering()     : lifecycle Entering 検知時 (performEnter の直前)
//   - function onLeaving()      : lifecycle Leaving  検知時 (performLeave の直前)
//   - function performEnter()   : enter アニメ起動。default は標準ランダム fade-in。
//   - function performLeave()   : leave アニメ起動。default は標準ランダム fade-out。
//   - function onViewKey(vk, ve): KeyDispatcher の viewEvent を受信したときの処理。

import QtQuick
import Constants
import Mediator

Item {
    id: root
    anchors.fill: parent

    // ---- 派生プロパティ ----
    // thisViewId は派生が直接指定 or 未指定 (0) なら Mediator から取得
    property int    thisViewId: 0
    property string displayName: ""
    property color  backgroundColor: "#444444"
    property bool   showInfo: true

    // ---- TransitionManager から view 状態を取得 ----
    readonly property int    myLifecycle: TransitionManager.lifecycleOf(thisViewId)
    readonly property int    myDirection: TransitionManager.directionOf(thisViewId)
    readonly property int    myPartnerId: TransitionManager.partnerOf(thisViewId)

    opacity: 0  // 初期は不可視

    Rectangle {
        anchors.fill: parent
        color: root.backgroundColor
    }

    Column {
        visible: root.showInfo
        anchors.top: parent.top
        anchors.topMargin: 24
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 6

        Text {
            text: root.displayName
            color: "white"
            font.pixelSize: 40
            font.bold: true
            anchors.horizontalCenter: parent.horizontalCenter
        }
        Text {
            text: ViewId.nameOf(root.thisViewId)
            color: "#dddddd"
            font.pixelSize: 16
            anchors.horizontalCenter: parent.horizontalCenter
        }
        Text {
            text: "direction: "
                  + (root.myDirection === Direction.Direction.Next ? "Next" : "Back")
                  + "    from: "
                  + (root.myPartnerId !== 0 ? ViewId.nameOf(root.myPartnerId) : "(none)")
            color: "#dddddd"
            font.pixelSize: 13
            anchors.horizontalCenter: parent.horizontalCenter
        }
        Text {
            text: "prev: "
                  + (Mediator.previousViewId !== 0 ? ViewId.nameOf(Mediator.previousViewId) : "(none)")
                  + "    history.length: " + Mediator.history.length
            color: "#aaaaaa"
            font.pixelSize: 12
            anchors.horizontalCenter: parent.horizontalCenter
        }
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
        reactedInitial = true
        Logger.log(ViewId.nameOf(root.thisViewId), "reactToLifecycle", "",
                   "myLifecycle=" + Lifecycle.nameOf(myLifecycle)
                   + ", direction=" + Direction.nameOf(myDirection)
                   + ", partner=" + (myPartnerId !== 0 ? ViewId.nameOf(myPartnerId) : "(none)"))
        if (myLifecycle === Lifecycle.Lifecycle.Entering) {
            onEntering()
            performEnter()
        } else if (myLifecycle === Lifecycle.Lifecycle.Leaving) {
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
                   "vk=" + Key.nameOf(vk) + ", ev=" + Event.nameOf(ve), "")
        onViewKey(vk, ve)
    }

    Component.onCompleted: {
        // 派生が thisViewId を指定していなければ、Mediator から取得
        // (同一 QML 多重 ID 用、例: Sample2View が sample2a/sample2b 両対応)
        if (root.thisViewId === 0) {
            root.thisViewId = Mediator.nextLoadingViewId
            Logger.log(ViewId.nameOf(root.thisViewId),
                       "thisViewId auto-resolved", "",
                       "from Mediator.nextLoadingViewId=" + ViewId.nameOf(Mediator.nextLoadingViewId))
        }
        Logger.log(ViewId.nameOf(root.thisViewId), "Component.onCompleted", "",
                   "myLifecycle=" + Lifecycle.nameOf(myLifecycle))
        if (!reactedInitial) reactToLifecycle()
        readyForKeys = true
    }
    Component.onDestruction: Logger.log(
        ViewId.nameOf(root.thisViewId), "Component.onDestruction", "", "")
}

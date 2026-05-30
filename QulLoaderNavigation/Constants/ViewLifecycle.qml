// ViewLifecycle.qml
// View ライフサイクル状態の enum (§9-3 TransitionManager lifecycle)。
//
// QUL の QML enum 構文 (cf. https://doc.qt.io/QtForMCUs/qml-enumeration.html)。アクセスは `ViewLifecycle.Entering` の 2 段形式 (`<Type>.<value>`)。
// helper は `ViewLifecycle.nameOf(lc)`。

pragma Singleton
import QtQml

QtObject {
    enum ViewLifecycle {
        Idle = 0,
        Entering = 1,
        Leaving = 2
    }

    function nameOf(lc) {
        switch (lc) {
            case ViewLifecycle.Idle:     return "Idle"
            case ViewLifecycle.Entering: return "Entering"
            case ViewLifecycle.Leaving:  return "Leaving"
        }
        return "?(" + lc + ")"
    }
}

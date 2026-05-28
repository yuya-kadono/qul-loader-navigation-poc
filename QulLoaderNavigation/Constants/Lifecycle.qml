// Lifecycle.qml
// View ライフサイクル状態の enum (§9-3 TransitionManager lifecycle)。
//
// QUL 2.9 の QML enum 構文。アクセスは `Lifecycle.Lifecycle.Entering` の 3 段形式。
// helper は `Lifecycle.nameOf(lc)`。

pragma Singleton
import QtQml

QtObject {
    enum Lifecycle {
        Idle = 0,
        Entering = 1,
        Leaving = 2
    }

    function nameOf(lc) {
        switch (lc) {
            case Lifecycle.Lifecycle.Idle:     return "Idle"
            case Lifecycle.Lifecycle.Entering: return "Entering"
            case Lifecycle.Lifecycle.Leaving:  return "Leaving"
        }
        return "?(" + lc + ")"
    }
}

// Event.qml
// 仮想イベント種別の enum (§8-2)。
//
// QUL 2.9 の QML enum 構文。アクセスは `Event.Event.Click` の 3 段形式。
// helper は `Event.nameOf(ev)`。

pragma Singleton
import QtQml

QtObject {
    enum Event {
        Press   = 0,
        Release = 1,
        Click   = 2
    }

    function nameOf(ev) {
        switch (ev) {
            case Event.Event.Press:   return "PRESS"
            case Event.Event.Release: return "RELEASE"
            case Event.Event.Click:   return "CLICK"
        }
        return "?(" + ev + ")"
    }
}

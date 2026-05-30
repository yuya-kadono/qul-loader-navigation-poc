// VirtualEvent.qml
// 仮想イベント種別の enum (§8-2)。
//
// QUL の QML enum 構文 (cf. https://doc.qt.io/QtForMCUs/qml-enumeration.html)。アクセスは `VirtualEvent.Click` の 2 段形式 (`<Type>.<value>`)。
// helper は `VirtualEvent.nameOf(ev)`。

pragma Singleton
import QtQml

QtObject {
    enum VirtualEvent {
        Press   = 0,
        Release = 1,
        Click   = 2
    }

    function nameOf(ev) {
        switch (ev) {
            case VirtualEvent.Press:   return "Press"
            case VirtualEvent.Release: return "Release"
            case VirtualEvent.Click:   return "Click"
        }
        return "?(" + ev + ")"
    }
}

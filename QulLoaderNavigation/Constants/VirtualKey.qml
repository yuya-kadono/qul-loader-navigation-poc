// VirtualKey.qml
// 仮想キー種別の enum (§8-1)。
//
// QUL の QML enum 構文 (cf. https://doc.qt.io/QtForMCUs/qml-enumeration.html)。アクセスは `VirtualKey.Enter` の 2 段形式 (`<Type>.<value>`)。
// helper は `VirtualKey.nameOf(vk)`。

pragma Singleton
import QtQml

QtObject {
    enum VirtualKey {
        Prev  = 0,
        Enter = 1,
        Next  = 2,
        Menu  = 3,
        Home  = 4,
        Back  = 5
    }

    function nameOf(vk) {
        switch (vk) {
            case VirtualKey.Prev:  return "Prev"
            case VirtualKey.Enter: return "Enter"
            case VirtualKey.Next:  return "Next"
            case VirtualKey.Menu:  return "Menu"
            case VirtualKey.Home:  return "Home"
            case VirtualKey.Back:  return "Back"
        }
        return "?(" + vk + ")"
    }
}

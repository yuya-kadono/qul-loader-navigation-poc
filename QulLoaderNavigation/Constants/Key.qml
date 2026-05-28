// Key.qml
// 仮想キー種別の enum (§8-1)。
//
// QUL 2.9 の QML enum 構文。アクセスは `Key.Key.Enter` の 3 段形式。
// helper は `Key.nameOf(vk)`。

pragma Singleton
import QtQml

QtObject {
    enum Key {
        Prev  = 0,
        Enter = 1,
        Next  = 2,
        Menu  = 3,
        Home  = 4,
        Back  = 5
    }

    function nameOf(vk) {
        switch (vk) {
            case Key.Key.Prev:  return "PREV"
            case Key.Key.Enter: return "ENTER"
            case Key.Key.Next:  return "NEXT"
            case Key.Key.Menu:  return "MENU"
            case Key.Key.Home:  return "HOME"
            case Key.Key.Back:  return "BACK"
        }
        return "?(" + vk + ")"
    }
}

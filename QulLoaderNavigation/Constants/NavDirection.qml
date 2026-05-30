// NavDirection.qml
// 遷移方向の enum (§9-3 TransitionManager direction)。
//
// QUL の QML enum 構文に従い、QtObject 内に enum 宣言を持つ singleton として
// 定義する。アクセスは `NavDirection.Next` の 2 段形式 (`<Type>.<value>`、QUL 標準
// cf. `Loader.Ready`)。helper 関数は `NavDirection.nameOf(d)`。
//
// 参考: https://doc.qt.io/QtForMCUs/qml-enumeration.html

pragma Singleton
import QtQml

QtObject {
    enum NavDirection {
        Next = 0,
        Back = 1
    }

    function nameOf(d) {
        switch (d) {
            case NavDirection.Next: return "Next"
            case NavDirection.Back: return "Back"
        }
        return "?(" + d + ")"
    }
}

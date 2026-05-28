// Direction.qml
// 遷移方向の enum (§9-3 TransitionManager direction)。
//
// QUL 2.9 の QML enum 構文に従い、QtObject 内に enum 宣言を持つ singleton として
// 定義する。アクセスは `Direction.Direction.Next` のように `<TypeName>.<EnumName>.<Value>` の
// 3 段。helper 関数は `Direction.nameOf(d)`。

pragma Singleton
import QtQml

QtObject {
    enum Direction {
        Next = 0,
        Back = 1
    }

    function nameOf(d) {
        switch (d) {
            case Direction.Direction.Next: return "Next"
            case Direction.Direction.Back: return "Back"
        }
        return "?(" + d + ")"
    }
}

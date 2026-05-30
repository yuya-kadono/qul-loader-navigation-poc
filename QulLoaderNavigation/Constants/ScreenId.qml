// ScreenId.qml — Constants モジュール
// シーン ID の enum + デバッグ用名前 helper のみ (§5-2)。
//
// QUL の QML enum 構文 (cf. https://doc.qt.io/QtForMCUs/qml-enumeration.html)。アクセスは `ScreenId.Normal` の 2 段形式 (`<Type>.<value>`)。
// 0 は「未指定」sentinel として予約。
//
// helper:
//   ScreenId.nameOf(screenId)  - "Normal" などログ可読化用
//
// 設計メモ: ID → qrc URL のマップは ScreenRegistry (メインモジュール所属) に持たせる。
// Constants は値とその名前だけ管理し、メインモジュールの qrc 配置を一切知らない。
// これにより依存方向 Constants ← Mediator ← Main が一方向に保たれる (Constants が
// メインモジュールの URL 構造を知ると逆向きの参照になってしまう)。

pragma Singleton
import QtQml

QtObject {
    enum ScreenId {
        Opening = 1,
        Normal  = 2,
        Closing = 3
    }

    function nameOf(screenId) {
        switch (screenId) {
            case ScreenId.Opening: return "Opening"
            case ScreenId.Normal:  return "Normal"
            case ScreenId.Closing: return "Closing"
        }
        return "?(" + screenId + ")"
    }
}

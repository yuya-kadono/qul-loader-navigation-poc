// ViewId.qml — Constants モジュール
// View ID の enum + デバッグ用名前 helper + screen 抽出 helper のみ (§5-2)。
//
// ID は bit-packed 整数: ((screenId << 8) | localId)
//   - 上位 8bit: screenId (ScreenId.Opening=1, Normal=2, Closing=3)
//   - 下位 8bit: screen 内 view 番号
//   - 0 は「未指定」sentinel
//
// QUL の QML enum 構文 (cf. https://doc.qt.io/QtForMCUs/qml-enumeration.html)。アクセスは `ViewId.NormalHome` の 2 段形式 (`<Type>.<value>`)。
// enum 値は QUL 仕様で「正の数値リテラル」が要求されるため、ビットシフト式ではなく
// 直接 hex リテラルで書く (コメントに分解形を併記)。
//
// helper:
//   ViewId.nameOf(viewId)   - "Normal/Home" などログ可読化用
//   ViewId.screenOf(viewId) - 上位 8bit を抽出 (= ScreenId.* と同じ値)
//
// 設計メモ: ID → qrc URL のマップは ScreenRegistry (メインモジュール所属) に持たせる。
// ScreenId.qml と同じ理由で Constants 側は URL を知らない (依存方向の一方向性維持)。

pragma Singleton
import QtQml

QtObject {
    enum ViewId {
        None           = 0x0000,
        OpeningOpening = 0x0100,  // (Opening << 8) | 0
        NormalHome     = 0x0200,  // (Normal  << 8) | 0
        NormalMenu     = 0x0201,  // (Normal  << 8) | 1
        NormalSample1  = 0x0202,  // (Normal  << 8) | 2
        NormalSample2a = 0x0203,  // (Normal  << 8) | 3
        NormalSample2b = 0x0204,  // (Normal  << 8) | 4
        ClosingClosing = 0x0300   // (Closing << 8) | 0
    }

    function screenOf(viewId) {
        return (viewId >> 8) & 0xFF
    }

    function nameOf(viewId) {
        switch (viewId) {
            case ViewId.None:           return "None"
            case ViewId.OpeningOpening: return "Opening/Opening"
            case ViewId.NormalHome:     return "Normal/Home"
            case ViewId.NormalMenu:     return "Normal/Menu"
            case ViewId.NormalSample1:  return "Normal/Sample1"
            case ViewId.NormalSample2a: return "Normal/Sample2a"
            case ViewId.NormalSample2b: return "Normal/Sample2b"
            case ViewId.ClosingClosing: return "Closing/Closing"
        }
        return "?(0x" + viewId.toString(16) + ")"
    }
}

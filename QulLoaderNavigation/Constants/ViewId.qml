// ViewId.qml — Constants モジュール
// View ID の enum + view QML ファイル URL/表示名/scene 抽出 helper (§5-2)。
//
// ID は bit-packed 整数: ((sceneId << 8) | localId)
//   - 上位 8bit: sceneId (SceneId.SceneId.Opening=1, Normal=2, Closing=3)
//   - 下位 8bit: scene 内 view 番号
//   - 0 は「未指定」sentinel
//
// QUL 2.9 の QML enum 構文。アクセスは `ViewId.ViewId.NormalHome` の 3 段形式。
// enum 値は QUL 仕様で「正の数値リテラル」が要求されるため、ビットシフト式ではなく
// 直接 hex リテラルで書く (コメントに分解形を併記)。
//
// helper:
//   ViewId.fileOf(viewId)   - "qrc:/qt/qml/Scenes/HomeView.qml" など絶対 URL
//                             (同一 QML 多重 ID 対応)
//   ViewId.nameOf(viewId)   - "normal/home" などログ可読化用
//   ViewId.sceneOf(viewId)  - 上位 8bit を抽出 (= SceneId.SceneId.* の値)
//
// fileOf が絶対 qrc URL を返す理由は SceneId.qml と同じ (Loader.source の解決基点問題)。

pragma Singleton
import QtQml

QtObject {
    enum ViewId {
        OpeningOpening = 0x0100,  // (Opening << 8) | 0
        NormalHome     = 0x0200,  // (Normal  << 8) | 0
        NormalMenu     = 0x0201,  // (Normal  << 8) | 1
        NormalSample1  = 0x0202,  // (Normal  << 8) | 2
        NormalSample2a = 0x0203,  // (Normal  << 8) | 3
        NormalSample2b = 0x0204,  // (Normal  << 8) | 4
        ClosingClosing = 0x0300   // (Closing << 8) | 0
    }

    function sceneOf(viewId) {
        return (viewId >> 8) & 0xFF
    }

    function fileOf(viewId) {
        // Scenes モジュール内のサブフォルダ込みパス。各 view はその view が属する
        // scene と同じフォルダに置く (Opening/, Normal/, Closing/)。
        switch (viewId) {
            case ViewId.ViewId.OpeningOpening: return "qrc:/qt/qml/Scenes/Opening/OpeningView.qml"
            case ViewId.ViewId.NormalHome:     return "qrc:/qt/qml/Scenes/Normal/HomeView.qml"
            case ViewId.ViewId.NormalMenu:     return "qrc:/qt/qml/Scenes/Normal/MenuView.qml"
            case ViewId.ViewId.NormalSample1:  return "qrc:/qt/qml/Scenes/Normal/Sample1View.qml"
            case ViewId.ViewId.NormalSample2a: return "qrc:/qt/qml/Scenes/Normal/Sample2View.qml"  // a/b 同一 QML
            case ViewId.ViewId.NormalSample2b: return "qrc:/qt/qml/Scenes/Normal/Sample2View.qml"  // a/b 同一 QML
            case ViewId.ViewId.ClosingClosing: return "qrc:/qt/qml/Scenes/Closing/ClosingView.qml"
        }
        return ""
    }

    function nameOf(viewId) {
        switch (viewId) {
            case 0:                            return "(unset)"
            case ViewId.ViewId.OpeningOpening: return "opening/opening"
            case ViewId.ViewId.NormalHome:     return "normal/home"
            case ViewId.ViewId.NormalMenu:     return "normal/menu"
            case ViewId.ViewId.NormalSample1:  return "normal/sample1"
            case ViewId.ViewId.NormalSample2a: return "normal/sample2a"
            case ViewId.ViewId.NormalSample2b: return "normal/sample2b"
            case ViewId.ViewId.ClosingClosing: return "closing/closing"
        }
        return "?(0x" + viewId.toString(16) + ")"
    }
}

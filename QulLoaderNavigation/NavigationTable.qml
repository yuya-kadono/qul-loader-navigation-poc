// NavigationTable.qml
// ID から {scene QML, view QML} を解決する singleton (§5-2)。
// next / back は持たない (各 view が遷移先を判断する: §5-3)。
//
// ID は bit-packed 整数: ((sceneId << 8) | localId)
//   - 上位 8bit: sceneId (sceneOpening=1, sceneNormal=2, sceneClosing=3)
//   - 下位 8bit: scene 内 view 番号
//   - 0 は「未指定」sentinel として予約
//
// 整数化のメリット: 比較高速、メモリ効率、QUL の文字列処理コスト回避。
// ログ可読化は nameOf(viewId) ヘルパで対応。

pragma Singleton
import QtQuick

QtObject {
    // ---- Scene ID (1 から開始、0 は未指定 sentinel) ----
    readonly property int sceneOpening: 1
    readonly property int sceneNormal:  2
    readonly property int sceneClosing: 3

    // ---- View ID (sceneId << 8 | localId) ----
    readonly property int idOpeningOpening:  (sceneOpening << 8) | 0   // 0x0100
    readonly property int idNormalHome:      (sceneNormal  << 8) | 0   // 0x0200
    readonly property int idNormalMenu:      (sceneNormal  << 8) | 1   // 0x0201
    readonly property int idNormalSample1:   (sceneNormal  << 8) | 2   // 0x0202
    readonly property int idNormalSample2a:  (sceneNormal  << 8) | 3   // 0x0203
    readonly property int idNormalSample2b:  (sceneNormal  << 8) | 4   // 0x0204
    readonly property int idClosingClosing:  (sceneClosing << 8) | 0   // 0x0300

    // ---- ID から scene を抜き出す ----
    function sceneOf(viewId) {
        return (viewId >> 8) & 0xFF
    }

    // ---- ID から scene QML ファイル名を解決 ----
    function sceneFileOf(viewId) {
        switch (sceneOf(viewId)) {
            case sceneOpening: return "OpeningScene.qml"
            case sceneNormal:  return "NormalScene.qml"
            case sceneClosing: return "ClosingScene.qml"
        }
        return ""
    }

    // ---- ID から view QML ファイル名を解決 ----
    // 注意: 同一 QML を複数 ID から参照することがある (sample2a / sample2b 等)
    function viewFileOf(viewId) {
        switch (viewId) {
            case idOpeningOpening:  return "OpeningView.qml"
            case idNormalHome:      return "HomeView.qml"
            case idNormalMenu:      return "MenuView.qml"
            case idNormalSample1:   return "Sample1View.qml"
            case idNormalSample2a:  return "Sample2View.qml"   // a/b 同一 QML
            case idNormalSample2b:  return "Sample2View.qml"   // a/b 同一 QML
            case idClosingClosing:  return "ClosingView.qml"
        }
        return ""
    }

    // ---- ログ可読化用: ID → 文字列名 ----
    function nameOf(viewId) {
        switch (viewId) {
            case 0:                 return "(unset)"
            case idOpeningOpening:  return "opening/opening"
            case idNormalHome:      return "normal/home"
            case idNormalMenu:      return "normal/menu"
            case idNormalSample1:   return "normal/sample1"
            case idNormalSample2a:  return "normal/sample2a"
            case idNormalSample2b:  return "normal/sample2b"
            case idClosingClosing:  return "closing/closing"
        }
        return "?(0x" + viewId.toString(16) + ")"
    }

    // ---- scene 名 (ログ用) ----
    function sceneNameOf(sceneId) {
        switch (sceneId) {
            case sceneOpening: return "opening"
            case sceneNormal:  return "normal"
            case sceneClosing: return "closing"
        }
        return "?(" + sceneId + ")"
    }
}

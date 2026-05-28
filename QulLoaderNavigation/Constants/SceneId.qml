// SceneId.qml — Constants モジュール
// シーン ID の enum + シーン QML ファイル URL/表示名解決 helper (§5-2)。
//
// QUL 2.9 の QML enum 構文。アクセスは `SceneId.SceneId.Normal` の 3 段形式。
// 0 は「未指定」sentinel として予約。
//
// helper:
//   SceneId.fileOf(sceneId)  - "qrc:/qt/qml/Scenes/NormalScene.qml" など絶対 URL
//   SceneId.nameOf(sceneId)  - "normal" などログ可読化用
//
// fileOf が絶対 qrc URL を返す理由:
//   Loader.source は相対パス文字列を「呼び元 QML ファイルの URL」に対して解決する。
//   呼び元が Main.qml (ルート) のときと SceneBase.qml (Scenes/ 配下) のときで
//   解決基点が違うため、相対パスだと一方で必ず壊れる。Scenes モジュールの
//   qrc 配置位置に基づく絶対 URL を返すことで、呼び元の位置に依存しない。

pragma Singleton
import QtQml

QtObject {
    enum SceneId {
        Opening = 1,
        Normal  = 2,
        Closing = 3
    }

    function fileOf(sceneId) {
        // Scenes モジュール内のサブフォルダ込みパス。Scenes/<SceneName>/<SceneName>Scene.qml に
        // 整理されている (Base/Opening/Normal/Closing)。
        switch (sceneId) {
            case SceneId.SceneId.Opening: return "qrc:/qt/qml/Scenes/Opening/OpeningScene.qml"
            case SceneId.SceneId.Normal:  return "qrc:/qt/qml/Scenes/Normal/NormalScene.qml"
            case SceneId.SceneId.Closing: return "qrc:/qt/qml/Scenes/Closing/ClosingScene.qml"
        }
        return ""
    }

    function nameOf(sceneId) {
        switch (sceneId) {
            case SceneId.SceneId.Opening: return "opening"
            case SceneId.SceneId.Normal:  return "normal"
            case SceneId.SceneId.Closing: return "closing"
        }
        return "?(" + sceneId + ")"
    }
}

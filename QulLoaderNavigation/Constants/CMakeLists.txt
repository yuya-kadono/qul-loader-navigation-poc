# Constants/CMakeLists.txt
# Enum + helper の純粋データモジュール (依存なし)。
# 全ファイル singleton。

set_source_files_properties(SceneId.qml   PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(ViewId.qml    PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(Direction.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(Lifecycle.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(Key.qml       PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(Event.qml     PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_qml_module(Constants
    URI Constants
    VERSION 1.0
    STATIC
    QML_FILES
        SceneId.qml
        ViewId.qml
        Direction.qml
        Lifecycle.qml
        Key.qml
        Event.qml
)

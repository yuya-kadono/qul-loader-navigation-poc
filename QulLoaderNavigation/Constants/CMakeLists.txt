# Constants/CMakeLists.txt
# Enum + helper の純粋データモジュール (依存なし)。
# 全ファイル singleton。

set_source_files_properties(ScreenId.qml   PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(ViewId.qml    PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(NavDirection.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(ViewLifecycle.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(VirtualKey.qml       PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(VirtualEvent.qml     PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_qml_module(Constants
    URI Constants
    VERSION 1.0
    STATIC
    QML_FILES
        ScreenId.qml
        ViewId.qml
        NavDirection.qml
        ViewLifecycle.qml
        VirtualKey.qml
        VirtualEvent.qml
)

# Mediator/CMakeLists.txt
# Orchestration singleton 群 (Mediator + TransitionManager + KeyDispatcher + Logger)。
# Constants モジュールに依存する。

set_source_files_properties(Mediator.qml          PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(TransitionManager.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(KeyDispatcher.qml     PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(Logger.qml            PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_qml_module(Mediator
    URI Mediator
    VERSION 1.0
    STATIC
    QML_FILES
        Mediator.qml
        TransitionManager.qml
        KeyDispatcher.qml
        Logger.qml
    IMPORTS
        Constants
)

target_link_libraries(Mediator PRIVATE Constantsplugin)

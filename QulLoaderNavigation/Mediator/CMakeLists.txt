# Mediator/CMakeLists.txt
# Orchestration singleton 群 + 基底コンポーネント (ScreenBase / ViewBase)。
# Constants モジュールに依存する。
#
# 構成方針:
#   - 振る舞いを持つ singleton (Mediator / TransitionManager / KeyDispatcher / Logger)
#     は「ナビゲーション制御 = アプリ全体で 1 つ」のインスタンス。
#   - ScreenBase / ViewBase は派生される基底コンポーネント。
#     具体シーン/ビュー (= 画面そのもの) はメインモジュール側に置き、
#     ここは「画面ではない、ナビゲーションの制御層」だけに留める。

set_source_files_properties(Mediator.qml          PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(TransitionManager.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(KeyDispatcher.qml     PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(Logger.qml            PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
# ScreenBase / ViewBase は singleton ではない (派生用基底)

qt_add_qml_module(Mediator
    URI Mediator
    VERSION 1.0
    STATIC
    QML_FILES
        # Singletons
        Mediator.qml
        TransitionManager.qml
        KeyDispatcher.qml
        Logger.qml
        # 派生用 base components
        ScreenBase.qml
        ViewBase.qml
    IMPORTS
        Constants
)

target_link_libraries(Mediator PRIVATE Constantsplugin)

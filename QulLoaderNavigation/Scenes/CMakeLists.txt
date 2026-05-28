# Scenes/CMakeLists.txt
# Base コンポーネント (SceneBase/ViewBase) + 具体 Scene 3 種 + 具体 View 6 種。
# Constants + Mediator モジュールに依存する。
# singleton は無い (全部インスタンス化される QML 型)。
#
# ファイルは Scene 単位のサブフォルダで整理 (Base / Opening / Normal / Closing)。
# URI は "Scenes" 単一 — サブフォルダはあくまでソース整理の都合で、QML 型名は
# サブ URI を持たず `import Scenes` だけで型が見える。
# qrc 配置はサブフォルダ込み (例: qrc:/qt/qml/Scenes/Normal/HomeView.qml) なので
# fileOf() helper (Constants/SceneId.qml, ViewId.qml) もこれに合わせて URL を返す。

qt_add_qml_module(Scenes
    URI Scenes
    VERSION 1.0
    STATIC
    QML_FILES
        # Base components (派生用)
        Base/SceneBase.qml
        Base/ViewBase.qml
        # Opening scene + views
        Opening/OpeningScene.qml
        Opening/OpeningView.qml
        # Normal scene + views (Sample2View は同一 QML 多重 ID)
        Normal/NormalScene.qml
        Normal/HomeView.qml
        Normal/MenuView.qml
        Normal/Sample1View.qml
        Normal/Sample2View.qml
        # Closing scene + view
        Closing/ClosingScene.qml
        Closing/ClosingView.qml
    IMPORTS
        Constants
        Mediator
)

target_link_libraries(Scenes PRIVATE Constantsplugin Mediatorplugin)

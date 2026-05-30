cmake_minimum_required(VERSION 3.16)

project(QulLoaderNavigation VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Quick QuickShapes)

qt_standard_project_setup(REQUIRES 6.10)

# ============================================================
# サブモジュール
#   Constants  - enum + helper (依存なし)
#   Mediator   - orchestration singleton 群 + ScreenBase/ViewBase
#                (Constants 依存)
#
# 具体シーン/ビュー (= 画面そのもの) はメインモジュール (appQulLoaderNavigation)
# 側の Screens/ 配下に置く。サブモジュール化しないのは、画面は本アプリ固有
# (= 再利用性が低い) ためライブラリとして切り出す動機が薄いから。
# ============================================================
add_subdirectory(Constants)
add_subdirectory(Mediator)

# ============================================================
# アプリ本体: Main.qml + ScreenRegistry + 具体 Screen/View (Screens/ 配下)
#   2 サブモジュール (Constants / Mediator) に依存
# ============================================================
qt_add_executable(appQulLoaderNavigation
    main.cpp
)

# メインモジュール所属 singleton 群
#   ScreenRegistry  - ID → qrc URL マップ (TransitionManager に DI)
#   HelpRegistry    - viewId → 操作ヘルプ文字列マップ (Main.qml の左上 overlay が表示)
set_source_files_properties(Screens/ScreenRegistry.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(Screens/HelpRegistry.qml   PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_qml_module(appQulLoaderNavigation
    URI QulLoaderNavigation
    VERSION 1.0
    QML_FILES
        Main.qml
        # POC 専用 overlay (production 移植時は削除)
        DebugOverlay.qml
        MiniKeyboardOverlay.qml
        # メインモジュール所属 singleton
        Screens/ScreenRegistry.qml
        Screens/HelpRegistry.qml
        # Opening screen + view
        Screens/Opening/OpeningScreen.qml
        Screens/Opening/OpeningView.qml
        # Normal screen + views (Sample2View は同一 QML 多重 ID)
        Screens/Normal/NormalScreen.qml
        Screens/Normal/HomeView.qml
        Screens/Normal/MenuView.qml
        Screens/Normal/Sample1View.qml
        Screens/Normal/Sample2View.qml
        # Closing screen + view
        Screens/Closing/ClosingScreen.qml
        Screens/Closing/ClosingView.qml
    IMPORTS
        Constants
        Mediator
)

target_link_libraries(appQulLoaderNavigation
    PRIVATE
        Qt6::Quick
        Qt6::QuickShapes
        Constantsplugin
        Mediatorplugin
)

# Qt for iOS sets MACOSX_BUNDLE_GUI_IDENTIFIER automatically since Qt 6.1.
# If you are developing for iOS or macOS you should consider setting an
# explicit, fixed bundle identifier manually though.
set_target_properties(appQulLoaderNavigation PROPERTIES
#    MACOSX_BUNDLE_GUI_IDENTIFIER com.example.appQulLoaderNavigation
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)


install(TARGETS appQulLoaderNavigation
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

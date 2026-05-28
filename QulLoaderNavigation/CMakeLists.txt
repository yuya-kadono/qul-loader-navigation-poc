cmake_minimum_required(VERSION 3.16)

project(QulLoaderNavigation VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Quick)

qt_standard_project_setup(REQUIRES 6.10)

# ============================================================
# サブモジュール (各 qt_add_qml_module で URI 登録)
#   Constants  - enum + helper (依存なし)
#   Mediator   - orchestration singleton 群 (Constants 依存)
#   Scenes     - base + concrete Scene/View (Constants + Mediator 依存)
# ============================================================
add_subdirectory(Constants)
add_subdirectory(Mediator)
add_subdirectory(Scenes)

# ============================================================
# アプリ本体: Main.qml のみを QML_FILES に持つ
#   3 サブモジュールに依存 (link するとプラグインが自動 register される)
# ============================================================
qt_add_executable(appQulLoaderNavigation
    main.cpp
)

qt_add_qml_module(appQulLoaderNavigation
    URI QulLoaderNavigation
    VERSION 1.0
    QML_FILES
        Main.qml
    IMPORTS
        Constants
        Mediator
        Scenes
)

target_link_libraries(appQulLoaderNavigation
    PRIVATE
        Qt6::Quick
        Constantsplugin
        Mediatorplugin
        Scenesplugin
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

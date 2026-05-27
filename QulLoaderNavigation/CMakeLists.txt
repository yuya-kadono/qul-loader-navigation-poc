cmake_minimum_required(VERSION 3.16)

project(QulLoaderNavigation VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Quick)

qt_standard_project_setup(REQUIRES 6.10)

qt_add_executable(appQulLoaderNavigation
    main.cpp
)

# Mark singleton QML files BEFORE qt_add_qml_module
set_source_files_properties(NavigationTable.qml  PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(KeyDispatcher.qml    PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(TransitionManager.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(Mediator.qml         PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(Logger.qml           PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_qml_module(appQulLoaderNavigation
    URI QulLoaderNavigation
    QML_FILES
        Main.qml
        # Singletons
        NavigationTable.qml
        KeyDispatcher.qml
        TransitionManager.qml
        Mediator.qml
        Logger.qml
        # Scenes
        SceneBase.qml
        OpeningScene.qml
        NormalScene.qml
        ClosingScene.qml
        # Views
        ViewBase.qml
        OpeningView.qml
        HomeView.qml
        MenuView.qml
        Sample1View.qml
        Sample2View.qml
        ClosingView.qml
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

target_link_libraries(appQulLoaderNavigation
    PRIVATE Qt6::Quick
)

install(TARGETS appQulLoaderNavigation
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

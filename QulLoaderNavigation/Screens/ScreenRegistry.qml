// ScreenRegistry.qml — メインモジュール所属 singleton
// Screen/View の qrc URL マップ。
//
// 設計上の役割:
//   Constants の ScreenId / ViewId enum は ID 値 (整数) と nameOf (デバッグ用文字列) だけを
//   持ち、qrc URL は知らない。URL 解決はメインモジュール (= 自分が画面ファイルを抱えている
//   モジュール) の責務という分け方をしている。これによって Constants → メインモジュール
//   の参照が発生せず、依存方向が一方向 (Constants ← Mediator ← Main) に保たれる。
//
//   Mediator/TransitionManager は ID しか知らない。Main.qml が起動時に
//   `TransitionManager.screenRegistry = ScreenRegistry` と注入することで、
//   TransitionManager.startTransition() が ID から URL を引けるようになる (DI)。
//
// 画面ファイルを追加/移動するとき更新が必要なのはこのファイルと CMakeLists.txt の
// QML_FILES (および Constants/ScreenId.qml / ViewId.qml の enum) だけ。Mediator 側は
// ノータッチで済む。

pragma Singleton
import QtQml
import Constants

QtObject {
    function screenUrlOf(screenId) {
        switch (screenId) {
            case ScreenId.Opening: return "qrc:/qt/qml/QulLoaderNavigation/Screens/Opening/OpeningScreen.qml"
            case ScreenId.Normal:  return "qrc:/qt/qml/QulLoaderNavigation/Screens/Normal/NormalScreen.qml"
            case ScreenId.Closing: return "qrc:/qt/qml/QulLoaderNavigation/Screens/Closing/ClosingScreen.qml"
        }
        return ""
    }

    function viewUrlOf(viewId) {
        switch (viewId) {
            case ViewId.OpeningOpening: return "qrc:/qt/qml/QulLoaderNavigation/Screens/Opening/OpeningView.qml"
            case ViewId.NormalHome:     return "qrc:/qt/qml/QulLoaderNavigation/Screens/Normal/HomeView.qml"
            case ViewId.NormalMenu:     return "qrc:/qt/qml/QulLoaderNavigation/Screens/Normal/MenuView.qml"
            case ViewId.NormalSample1:  return "qrc:/qt/qml/QulLoaderNavigation/Screens/Normal/Sample1View.qml"
            case ViewId.NormalSample2a: return "qrc:/qt/qml/QulLoaderNavigation/Screens/Normal/Sample2View.qml"  // a/b 同一 QML
            case ViewId.NormalSample2b: return "qrc:/qt/qml/QulLoaderNavigation/Screens/Normal/Sample2View.qml"  // a/b 同一 QML
            case ViewId.ClosingClosing: return "qrc:/qt/qml/QulLoaderNavigation/Screens/Closing/ClosingView.qml"
        }
        return ""
    }
}

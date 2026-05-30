// OpeningScreen.qml
// Opening シーン。吸収ルールなし (§8-6)。

import QtQuick
import Constants
import Mediator

ScreenBase {
    thisScreenId: ScreenId.Opening
    // handleAbsorb は base のデフォルト (常に false) を使う
}

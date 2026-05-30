// Main.qml
// Window + 物理キー → 仮想キー変換層 (§8-4) + 同時押し検出 + 隠しジャンプキー
//        + ScreenSlot ペア (§3-2)。
// 視覚的な POC overlay は別ファイルに分離 (DebugOverlay.qml / MiniKeyboardOverlay.qml)。
//
// 移植性メモ:
//   - Keys.onPressed/onReleased は **POC 限定の物理キー受信** (デスクトップ Qt 6 で
//     キーボード入力をテストするため)。実機 MCU 移植時にはハードウェアボタンから
//     直接 KeyDispatcher.dispatchToScreen() を呼ぶ形になるため、この層は丸ごと
//     置き換わる。よってここでは Qt 6 推奨の function(event) 形式を使い、Qt 6 の
//     deprecation 警告を抑止する (QUL 互換性は不要)。
//   - Connections{target: TransitionManager} は singleton 通知パターンの本質なので不使用。
//     代わりに finishedGen を local property にバインドして on*Changed で検知する (QUL 互換)。
//   - DebugOverlay / MiniKeyboardOverlay / 隠しジャンプキー (1-5) は production 移植時に
//     削除する想定 (POC 動作確認用)。
//
// 同時押し検出ポリシー (キー dispatch の信頼性確保):
//   View 側は「物理ハードウェアボタン = 排他押下」を前提に設計されている。
//   PC キーボードでテストする時の指の滑り (A 押下中に S を触ってしまう等) で
//   View に不整合な Press/Release シーケンスが届くと不可解な挙動を招くため、
//   本層で同時押しを検出して dispatch を抑制する:
//     1. マップ済みキー (A/S/D/Z/X/C) を 1 個押す → 通常通り Press dispatch
//     2. その状態で 2 個目を押す = **conflict 確定**。この瞬間に:
//        - 先押し (= Press 通知済み) のキーの Release を **即 dispatch**
//          → View の押下色などの状態をすぐクリーンに戻す。
//        - 2 個目の Press: 通知しない (View はその存在を知らない)
//        - その後 conflict 中に増える Press も全部抑制
//        - 物理的に Release されたタイミングの Release 通知: すべて抑制
//        - Click: 通知しない
//     3. すべて物理 release された時点で conflict 解除、次の単独押下から正常 dispatch
//
// 隠しジャンプキー (POC debug 用、1/2/3/4/5):
//   1 → normal/home、2 → normal/menu、3 → normal/sample1、4 → normal/sample2a、5 → normal/sample2b
//   物理キー追跡や conflict 検出を完全バイパスして直接 Mediator.switchView を呼ぶ。
//   通常の遷移と同じ扱い (history も普通に更新される)。

import QtQuick
import Constants
import Mediator
// 具体 Screen/View は Loader.source 経由 (qrc URL 文字列) でロードされるだけで、
// QML 型としての参照は無いため import 不要。
// DebugOverlay / MiniKeyboardOverlay は同じメインモジュール (URI QulLoaderNavigation) 所属
// なので import なしで型参照できる。

Window {
    id: window
    width: 800
    height: 600
    visible: true
    title: "QUL Loader Navigation POC"
    color: "black"

    // ---- キー入力受け口 + dispatch ロジック ----
    Item {
        id: keyHandler
        anchors.fill: parent
        focus: true

        // ---- 物理押下状態 (マップ済みキーのみ追跡) ----
        property var pressedKeys: []
        property bool conflictMode: false
        property int dispatchedPressKey: -1

        Keys.onPressed: function(event) {
            if (event.isAutoRepeat) return

            // ---- 隠しジャンプキー (POC debug 用、最優先) ----
            var jumpTarget = jumpKeyToViewId(event.key)
            if (jumpTarget !== 0) {
                Logger.log("Main", "HIDDEN JUMP",
                           "physicalKey=" + event.key,
                           "switchView(" + ViewId.nameOf(jumpTarget) + ", Next)")
                Mediator.switchView(jumpTarget, NavDirection.Next)
                event.accepted = true
                return
            }

            var pk = event.key
            var vk = physicalToVirtual(pk)
            if (vk < 0) return

            if (pressedKeys.indexOf(pk) >= 0) {
                event.accepted = true
                return
            }

            var np = pressedKeys.slice()
            np.push(pk)
            pressedKeys = np

            if (pressedKeys.length >= 2) {
                if (!conflictMode) {
                    conflictMode = true
                    if (dispatchedPressKey >= 0) {
                        var prevVk = physicalToVirtual(dispatchedPressKey)
                        Logger.log("Main", "MULTI-KEY conflict ENTERED",
                                   "newKey=" + VirtualKey.nameOf(vk),
                                   "pre-emptive Release dispatched for first-pressed vk="
                                   + VirtualKey.nameOf(prevVk)
                                   + " (Click suppressed); further dispatch suppressed")
                        KeyDispatcher.dispatchToScreen(prevVk, VirtualEvent.Release)
                        dispatchedPressKey = -1
                    } else {
                        Logger.log("Main", "MULTI-KEY conflict ENTERED",
                                   "newKey=" + VirtualKey.nameOf(vk),
                                   "no dispatched press to release pre-emptively")
                    }
                } else {
                    Logger.log("Main", "Press SUPPRESSED (conflict)",
                               "vk=" + VirtualKey.nameOf(vk),
                               "pressedCount=" + pressedKeys.length)
                }
                event.accepted = true
                return
            }

            Logger.log("Main", "Keys.onPressed",
                       "physicalKey=" + pk,
                       "vk=" + VirtualKey.nameOf(vk))
            KeyDispatcher.dispatchToScreen(vk, VirtualEvent.Press)
            dispatchedPressKey = pk
            event.accepted = true
        }

        Keys.onReleased: function(event) {
            if (event.isAutoRepeat) return
            var pk = event.key
            var vk = physicalToVirtual(pk)
            if (vk < 0) return

            var np = pressedKeys.slice()
            var idx = np.indexOf(pk)
            if (idx >= 0) np.splice(idx, 1)
            pressedKeys = np

            if (conflictMode) {
                Logger.log("Main", "Release SUPPRESSED (conflict, already handled)",
                           "vk=" + VirtualKey.nameOf(vk),
                           "remainingPressed=" + pressedKeys.length)
                if (pressedKeys.length === 0) {
                    conflictMode = false
                    Logger.log("Main", "MULTI-KEY conflict CLEARED",
                               "all keys released",
                               "next single press will dispatch normally")
                }
                event.accepted = true
                return
            }

            Logger.log("Main", "Keys.onReleased",
                       "physicalKey=" + pk,
                       "vk=" + VirtualKey.nameOf(vk))
            KeyDispatcher.dispatchToScreen(vk, VirtualEvent.Release)
            Logger.log("Main", "CLICK synthesized",
                       "physicalKey=" + pk,
                       "vk=" + VirtualKey.nameOf(vk))
            KeyDispatcher.dispatchToScreen(vk, VirtualEvent.Click)
            dispatchedPressKey = -1
            event.accepted = true
        }

        function physicalToVirtual(key) {
            switch (key) {
                case Qt.Key_A: return VirtualKey.Prev
                case Qt.Key_S: return VirtualKey.Enter
                case Qt.Key_D: return VirtualKey.Next
                case Qt.Key_Z: return VirtualKey.Menu
                case Qt.Key_X: return VirtualKey.Home
                case Qt.Key_C: return VirtualKey.Back
            }
            return -1
        }

        // ---- 隠しジャンプキー: 1/2/3/4/5 → 直接 view ジャンプ (POC debug 用) ----
        // 戻り値: 対象 viewId (0 ならジャンプ対象外で通常処理へ)
        function jumpKeyToViewId(key) {
            switch (key) {
                case Qt.Key_1: return ViewId.NormalHome
                case Qt.Key_2: return ViewId.NormalMenu
                case Qt.Key_3: return ViewId.NormalSample1
                case Qt.Key_4: return ViewId.NormalSample2a
                case Qt.Key_5: return ViewId.NormalSample2b
            }
            return 0
        }

        // ---- ScreenSlot ペア (§3-2) ----
        Loader {
            id: screenSlotA
            anchors.fill: parent
            source: TransitionManager.screenSourceA
            active: source !== ""
        }
        Loader {
            id: screenSlotB
            anchors.fill: parent
            source: TransitionManager.screenSourceB
            active: source !== ""
        }

        // ---- 左下ミニキーボード overlay (POC debug 用) ----
        MiniKeyboardOverlay {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.bottomMargin: 16
            anchors.leftMargin: 16
            pressedKeys: keyHandler.pressedKeys
            conflictMode: keyHandler.conflictMode
        }

        // ---- 右上 debug overlay (POC debug 用) ----
        DebugOverlay {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 8
            pressedKeysCount: keyHandler.pressedKeys.length
            conflictMode: keyHandler.conflictMode
        }

        // ---- TransitionManager.finishedGen の監視 (Connections 不使用) ----
        property int finishedGen: TransitionManager.finishedGen
        property bool ready: false
        onFinishedGenChanged: {
            if (!ready) return
            Logger.log("Main", "onTransitionFinished",
                       "finalViewId=" + ViewId.nameOf(TransitionManager.lastFinishedViewId),
                       "")
        }
        Component.onCompleted: {
            // ★ DI: TransitionManager に ScreenRegistry を注入 (§3-3)
            //   Mediator モジュールはメインモジュールの qrc 配置を知らない構造なので、
            //   ここで URL マップを注入してから navigate を呼ぶ必要がある。
            TransitionManager.screenRegistry = ScreenRegistry
            Logger.log("Main", "DI", "ScreenRegistry",
                       "TransitionManager.screenRegistry = ScreenRegistry")

            ready = true
            Logger.log("Main", "Component.onCompleted", "",
                       "kickoff: switchView(Opening/Opening, Next)")
            Mediator.switchView(ViewId.OpeningOpening, NavDirection.Next)
        }
    }
}

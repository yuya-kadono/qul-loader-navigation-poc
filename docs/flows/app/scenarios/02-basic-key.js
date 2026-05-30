/* flows/app/scenarios/02-basic-key.js
   シナリオ basicKey の定義。scenarios.js (空 SCENARIOS の宣言) より後に読み込まれる。
*/
'use strict';

SCENARIOS.basicKey = {
    title: '② 基本キーフロー',
    precondition: {
        mediator: { current: 'NormalHome', pending: 'NormalHome', history: '[]' },
        screenSlotB: { source: 'NormalScreen.qml', active: 'true' },
        transMgr: { phase: 'Idle', screenSrcB: 'NormalScreen.qml' },
    },
    preSpawned: ['screen', 'loaderA', 'view'],
    desc: 'PC キーボード <strong>A</strong> を 1 回タップした時の信号の流れ。Press → Release → Click の 3 段に分解され、Main → KeyDispatcher → Screen → View と伝播する。Screen の <strong>handleAbsorb</strong> が false を返すので View まで届く。',
    steps: [
        { from: 'user',    to: 'main',    label: 'Qt.Key_A press',                    kind: 'key' },
        { from: 'main',    to: 'main',    label: 'physicalToVirtual → PREV',          kind: 'self' },
        { from: 'main',    to: 'keyDisp', label: 'dispatchToScreen(PREV, Press)',     kind: 'msg' },
        { from: 'keyDisp', to: 'screen',  label: 'screenEventGen++ (binding 発火)',   kind: 'msg' },
        { from: 'screen',  to: 'screen',  label: 'handleAbsorb(PREV,Press) → false',  kind: 'self' },
        { from: 'screen',  to: 'keyDisp', label: 'dispatchToView(PREV, Press)',       kind: 'msg' },
        { from: 'keyDisp', to: 'view',    label: 'viewEventGen++ (binding 発火)',     kind: 'msg' },
        { from: 'view',    to: 'view',    label: 'onViewKey(PREV, Press)\n→ enterPressed=true', kind: 'self' },

        { from: 'user',    to: 'main',    label: 'Qt.Key_A release',                  kind: 'key' },
        { from: 'main',    to: 'keyDisp', label: 'dispatchToScreen(PREV, Release)',   kind: 'msg' },
        { from: 'keyDisp', to: 'screen',  label: 'screenEventGen++',                  kind: 'msg' },
        { from: 'screen',  to: 'keyDisp', label: 'dispatchToView(PREV, Release)',     kind: 'msg' },
        { from: 'keyDisp', to: 'view',    label: 'viewEventGen++',                    kind: 'msg' },
        { from: 'view',    to: 'view',    label: 'enterPressed=false',                kind: 'self' },

        { from: 'main',    to: 'keyDisp', label: 'dispatchToScreen(PREV, Click) ★合成', kind: 'action' },
        { from: 'keyDisp', to: 'screen',  label: 'screenEventGen++',                  kind: 'msg' },
        { from: 'screen',  to: 'keyDisp', label: 'dispatchToView(PREV, Click)',       kind: 'msg' },
        { from: 'keyDisp', to: 'view',    label: 'viewEventGen++',                    kind: 'msg' },
        { from: 'view',    to: 'view',    label: 'onViewKey(PREV, Click)\n→ cursorIndex--', kind: 'action' },
    ],
};

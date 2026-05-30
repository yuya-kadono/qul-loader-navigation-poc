/* flows/app/scenarios/03-nav.js
   シナリオ nav の定義。scenarios.js (空 SCENARIOS の宣言) より後に読み込まれる。
*/
'use strict';

SCENARIOS.nav = {
    title: '③ 画面遷移 (Home → Menu)',
    precondition: {
        mediator: { current: 'NormalHome', pending: 'NormalHome', history: '[]' },
        screenSlotB: { source: 'NormalScreen.qml', active: 'true' },
        transMgr: { phase: 'Idle', screenSrcB: 'NormalScreen.qml' },
    },
    preSpawned: ['screen', 'view', 'loaderA'],
    desc: 'Home でカーソルが Menu タイルの上にある状態で <strong>S (ENTER)</strong> Click → <strong>switchView(NormalMenu, Next)</strong>。Mediator が history を更新し TransitionManager が ViewSlot ペアでクロスフェード遷移を行う。Loader B と新 view (MenuView) は遷移開始時に新規ロードされて登場する。',
    steps: [
        { from: 'user',    to: 'main',    label: 'Qt.Key_S click',                    kind: 'key' },
        { from: 'main',    to: 'keyDisp', label: 'dispatchToScreen(ENTER, Click)',    kind: 'msg' },
        { from: 'keyDisp', to: 'screen',  label: 'screenEventGen++',                  kind: 'msg' },
        { from: 'screen',  to: 'keyDisp', label: 'dispatchToView(ENTER, Click)',      kind: 'msg' },
        { from: 'keyDisp', to: 'view',    label: 'viewEventGen++',                    kind: 'msg' },
        { from: 'view',    to: 'view',    label: 'activateAt(cursorIndex=0)\n= Menu', kind: 'self' },
        { from: 'view',    to: 'mediator', label: 'switchView(NormalMenu, Next)',     kind: 'action' },
        { from: 'mediator', to: 'mediator', label: 'history.push(NormalHome)\npreviousViewId = NormalHome\ncurrentViewId = NormalMenu', kind: 'self',
          setState: { mediator: { current: 'NormalMenu', prev: 'NormalHome', history: '[…, NormalHome]' } } },
        { from: 'mediator', to: 'transMgr', label: 'startTransition(NormalMenu, Next)', kind: 'action' },
        { from: 'transMgr', to: 'loaderA',  label: '現在 view を保持 (current 側)',  kind: 'msg' },
        { from: 'transMgr', to: 'loaderB',  label: 'source = MenuView.qml\n(entering 側に新規ロード)', kind: 'action' },
        { from: 'loaderB',  to: 'newView',  label: 'Component.onCompleted\nViewBase.lifecycle = Entering', kind: 'msg' },
        { from: 'transMgr', to: 'loaderA',  label: 'lifecycle = Leaving',             kind: 'msg' },
        { from: 'view',     to: 'view',     label: 'performLeave\nfade out 800ms', kind: 'self' },
        { from: 'newView',  to: 'newView',  label: 'enterAnim (fade in)',             kind: 'self' },
        { from: 'view',     to: 'transMgr', label: 'reportLeaveComplete',             kind: 'msg' },
        { from: 'newView',  to: 'transMgr', label: 'reportEnterComplete',             kind: 'msg' },
        { from: 'transMgr', to: 'transMgr', label: 'finalizeTransition\n旧 Loader を active=false で解放\n→ HomeView を破棄', kind: 'self', destroy: ['view'] },
    ],
};

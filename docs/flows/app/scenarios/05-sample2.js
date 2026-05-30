/* flows/app/scenarios/05-sample2.js
   シナリオ sample2 の定義。scenarios.js (空 SCENARIOS の宣言) より後に読み込まれる。
*/
'use strict';

SCENARIOS.sample2 = {
    title: '⑤ Sample 2A → Sample 2B (同 QML、別 ViewId)',
    precondition: {
        mediator: { current: 'NormalSample2a', prev: 'NormalMenu', pending: 'NormalSample2a', history: '[…, NormalMenu]' },
        screenSlotB: { source: 'NormalScreen.qml', active: 'true' },
        transMgr: { phase: 'Idle', screenSrcB: 'NormalScreen.qml' },
    },
    preSpawned: ['screen', 'sample2aView', 'loaderA'],
    desc: 'Sample 2A 表示中に <strong>D (NEXT)</strong> Click。Sample2View 自身が <strong>switchView(NormalSample2b)</strong> を発火 → TransitionManager は **同じ Sample2View.qml** を **別の ViewSlot Loader** に新規ロードする。両 Loader に **同じ QML の別インスタンス** が存在し、それぞれ <strong>thisViewId</strong> 経由で a/b を判別する。「QML 1 ファイルを複数の View ID で使い回す」設計の実例。',
    steps: [
        { from: 'user',    to: 'main',    label: 'Qt.Key_D click',                    kind: 'key' },
        { from: 'main',    to: 'keyDisp', label: 'dispatchToScreen(NEXT, Click)',     kind: 'msg' },
        { from: 'keyDisp', to: 'screen',  label: 'screenEventGen++',                  kind: 'msg' },
        { from: 'screen',  to: 'keyDisp', label: 'dispatchToView(NEXT, Click)',       kind: 'msg' },
        { from: 'keyDisp', to: 'sample2aView', label: 'viewEventGen++',               kind: 'msg' },
        { from: 'sample2aView', to: 'sample2aView', label: 'onViewKey(NEXT, Click)\n→ Sample2A は次は 2B', kind: 'self' },
        { from: 'sample2aView', to: 'mediator', label: 'switchView(NormalSample2b, Next)', kind: 'action' },
        { from: 'mediator', to: 'mediator', label: 'history.push(NormalSample2a)\npending = NormalSample2b', kind: 'self',
          setState: { mediator: { current: 'NormalSample2b', prev: 'NormalSample2a', history: '[…, NormalSample2a]' } } },
        { from: 'mediator', to: 'transMgr', label: 'startTransition(NormalSample2b, Next)', kind: 'action' },
        { from: 'transMgr', to: 'loaderA',  label: '現 view を保持 (current 側 = Sample2A)', kind: 'msg' },
        { from: 'transMgr', to: 'loaderB',  label: 'source = Sample2View.qml\n(★ 同 QML を entering 側にも load)', kind: 'action' },
        { from: 'loaderB',  to: 'sample2bView', label: 'Component.onCompleted\nthisViewId を Mediator.pendingViewId から取得\n→ NormalSample2b', kind: 'msg' },
        { from: 'transMgr', to: 'loaderA',  label: 'lifecycle = Leaving',             kind: 'msg' },
        { from: 'sample2aView', to: 'sample2aView', label: 'performLeave\nfade out 800ms', kind: 'self' },
        { from: 'sample2bView', to: 'sample2bView', label: 'enterAnim (fade in)',     kind: 'self' },
        { from: 'sample2aView', to: 'transMgr', label: 'reportLeaveComplete',         kind: 'msg' },
        { from: 'sample2bView', to: 'transMgr', label: 'reportEnterComplete',         kind: 'msg' },
        { from: 'transMgr', to: 'transMgr', label: 'finalizeTransition\n旧 Loader を active=false で解放\n→ Sample2A インスタンス破棄', kind: 'self', destroy: ['sample2aView'] },
    ],
};

/* flows/app/scenarios/04-closing.js
   シナリオ closing の定義。scenarios.js (空 SCENARIOS の宣言) より後に読み込まれる。
*/
'use strict';

SCENARIOS.closing = {
    title: '④ Closing 中断 (BACK で home へ)',
    precondition: {
        mediator: { current: 'ClosingClosing', prev: 'NormalHome', pending: 'ClosingClosing', debugHistory: '[]' },
        screenSlotB: { source: 'ClosingScreen.qml', active: 'true' },
        transMgr: { phase: 'Idle', screenSrcB: 'ClosingScreen.qml' },
    },
    preSpawned: ['closingScreen', 'closingLoaderA', 'closingView'],
    desc: 'ClosingView 表示中 (内部 Timer が <strong>Qt.quit()</strong> を呼ぼうとしている最中) に <strong>C (BACK)</strong> Click。中断ロジックは <strong>ClosingView 自身の onViewKey</strong> に集約されている。本質: <strong>Timer を殺せば Qt.quit() は呼ばれない</strong>。① <strong>closingTimer.stop()</strong> で Qt.quit を未然に防ぐ / ② 通常の <strong>switchView(NormalHome, Back)</strong> を発火 → あとは普通の leave/enter サイクルで HomeView へ戻る。Mediator / TransitionManager / ClosingScreen 側に <em>中断専用 API は一切なし</em> (フラグや force-unload も持たない)。',
    steps: [
        // BACK key 入力チェイン (Screen は素通し → View まで届く)
        { from: 'user',    to: 'main',     label: 'Qt.Key_C click',                   kind: 'key' },
        { from: 'main',    to: 'keyDisp',  label: 'dispatchToScreen(BACK, Click)',    kind: 'msg' },
        { from: 'keyDisp', to: 'closingScreen', label: 'screenEventGen++',            kind: 'msg' },
        { from: 'closingScreen', to: 'closingScreen', label: 'handleAbsorb(BACK,Click)\n→ false (default、素通し)', kind: 'self' },
        { from: 'closingScreen', to: 'keyDisp', label: 'dispatchToView(BACK, Click)', kind: 'msg' },
        { from: 'keyDisp', to: 'closingView', label: 'viewEventGen++',                kind: 'msg' },
        // ClosingView.onViewKey で中断処理
        { from: 'closingView', to: 'closingView', label: 'onViewKey(BACK, Click)\n→ abort 判定 (BACK or HOME)', kind: 'self' },
        { from: 'closingView', to: 'closingView', label: 'closingTimer.stop()\n① Qt.quit を未然に防ぐ', kind: 'self' },
        // ② 通常の switchView で HomeView へ
        { from: 'closingView', to: 'mediator', label: 'switchView(NormalHome, Back)\n② 通常のナビ (中断専用 API なし)', kind: 'action',
          setState: { mediator: { current: 'NormalHome', prev: 'ClosingClosing', debugHistory: '[ClosingClosing]' } } },
        { from: 'mediator', to: 'transMgr', label: 'startTransition(NormalHome, Back)\nscreenChanged=true', kind: 'msg',
          setState: { transMgr: { phase: 'Loading', screenSrcA: 'NormalScreen.qml' } } },
        // NormalScreen を ★空いている ScreenSlot A 側★ に新規 load
        { from: 'transMgr', to: 'screenSlotA', label: 'source = NormalScreen.qml\n(空いている A 側に新 Screen を load)', kind: 'action',
          setState: { screenSlotA: { source: 'NormalScreen.qml', active: 'true' } } },
        { from: 'screenSlotA', to: 'normalScreenA', label: 'NormalScreen を構築',           kind: 'msg' },
        { from: 'normalScreenA', to: 'loaderA_inNormalScreenA', label: '内部 ViewSlot Loader を構築',         kind: 'msg' },
        { from: 'loaderA_inNormalScreenA', to: 'homeView_inNormalScreenA', label: 'source = HomeView.qml\nLoader.onLoaded → 構築', kind: 'msg' },
        // ClosingView (B 側) は普通の leave サイクルで退場
        { from: 'transMgr', to: 'closingView', label: 'lifecycle = Leaving',         kind: 'msg' },
        { from: 'closingView', to: 'closingView', label: 'performLeave\n(instant: opacity=0, Qt.callLater で報告)', kind: 'self',
          setState: { transMgr: { phase: 'Crossfading' } } },
        { from: 'homeView_inNormalScreenA', to: 'homeView_inNormalScreenA', label: 'performEnter\n(fade in)', kind: 'self' },
        { from: 'closingView', to: 'transMgr', label: 'reportLeaveComplete',         kind: 'msg' },
        { from: 'homeView_inNormalScreenA', to: 'transMgr', label: 'reportEnterComplete',                kind: 'msg' },
        // finalize: ScreenSlot B 側 (Closing 一式) を全部破棄
        { from: 'transMgr', to: 'transMgr', label: 'finalizeTransition\nClosingView.Component.onDestruction\n→ ScreenSlot B を active=false で解放', kind: 'self',
          destroy: ['closingView', 'closingScreen', 'closingLoaderA'],
          setState: { screenSlotB: { source: '(empty)', active: 'false' }, transMgr: { phase: 'Idle', screenSrcA: 'NormalScreen.qml', screenSrcB: '(empty)' } } },
    ],
};

/* flows/app/scenarios/01-startup.js
   シナリオ startup の定義。scenarios.js (空 SCENARIOS の宣言) より後に読み込まれる。
*/
'use strict';

SCENARIOS.startup = {
    title: '① 起動 → Opening → Home (cross-screen 遷移)',
    desc: 'アプリ起動から Home が表示されるまで。Main.qml の <strong>Component.onCompleted</strong> で DI 注入 → kickoff <strong>switchView(OpeningOpening, Next)</strong> → ScreenSlot A に OpeningScreen ロード → 中の ViewSlot で OpeningView ロード → 1800ms 演出 → 完了で **自分自身で** <strong>switchView(NormalHome, Next)</strong> 発火 → ScreenSlot B に NormalScreen ロード → クロスフェード。**View が自分の離脱を自分でトリガーする**「self-triggered transition」パターンの実例。',
    steps: [
        { from: 'main',           to: 'main',           label: 'Component.onCompleted', kind: 'self' },
        { from: 'main',           to: 'transMgr',       label: 'screenRegistry = ScreenRegistry\n(DI 注入: URL マップを渡す)', kind: 'action' },
        { from: 'main',           to: 'mediator',       label: 'switchView(OpeningOpening, Next)\n(初期キックオフ)', kind: 'action' },
        { from: 'mediator',       to: 'mediator',       label: 'debugHistory = []\ncurrentViewId = OpeningOpening\npendingViewId = OpeningOpening', kind: 'self',
          setState: { mediator: { current: 'OpeningOpening', pending: 'OpeningOpening', debugHistory: '[]' } } },
        { from: 'mediator',       to: 'transMgr',       label: 'startTransition(Opening, Next)', kind: 'msg',
          setState: { transMgr: { phase: 'Loading', screenSrcA: 'OpeningScreen.qml' } } },
        { from: 'transMgr',       to: 'screenRegistry', label: 'screenUrlOf(Opening)\nviewUrlOf(OpeningOpening)\n→ qrc URL を取得', kind: 'msg' },
        { from: 'transMgr',       to: 'screenSlotA',    label: 'source = OpeningScreen.qml', kind: 'action',
          setState: { screenSlotA: { source: 'OpeningScreen.qml', active: 'true' } } },
        { from: 'screenSlotA',    to: 'openingScreen',  label: 'Loader.onLoaded\nOpeningScreen を構築', kind: 'msg' },
        { from: 'openingScreen',  to: 'openingLoaderA', label: '内部 ViewSlot Loader を構築', kind: 'msg' },
        { from: 'openingLoaderA', to: 'openingView',    label: 'source = OpeningView.qml\nLoader.onLoaded → 構築', kind: 'msg' },
        { from: 'openingView',    to: 'openingView',    label: 'performEnter (custom)\n1800ms fade-in + 5 本 sine 波', kind: 'self' },
        { from: 'openingView',    to: 'transMgr',       label: 'reportEnterComplete', kind: 'msg',
          setState: { transMgr: { phase: 'Idle' } } },
        { from: 'openingView',    to: 'mediator',       label: '★ self-trigger\nswitchView(NormalHome, Next)', kind: 'action' },
        { from: 'mediator',       to: 'mediator',       label: 'debugHistory.push(OpeningOpening)\npreviousViewId = OpeningOpening\ncurrentViewId = NormalHome', kind: 'self',
          setState: { mediator: { current: 'NormalHome', prev: 'OpeningOpening', debugHistory: '[OpeningOpening]' } } },
        { from: 'mediator',       to: 'transMgr',       label: 'startTransition(NormalHome, Next)', kind: 'msg',
          setState: { transMgr: { phase: 'Loading', screenSrcB: 'NormalScreen.qml' } } },
        { from: 'transMgr',       to: 'screenSlotB',    label: 'source = NormalScreen.qml\n(別 Screen → 別 ScreenSlot に load)', kind: 'action',
          setState: { screenSlotB: { source: 'NormalScreen.qml', active: 'true' } } },
        { from: 'screenSlotB',    to: 'screen',         label: 'NormalScreen を構築\n(中の chrome + viewArea を組み立て)', kind: 'msg' },
        { from: 'screen',         to: 'loaderA',        label: '内部 ViewSlot Loader を構築', kind: 'msg' },
        { from: 'loaderA',        to: 'view',           label: 'source = HomeView.qml\nLoader.onLoaded → 構築', kind: 'msg' },
        { from: 'openingScreen',  to: 'openingScreen',  label: 'fade out (ScreenSlot A 側)', kind: 'self',
          setState: { transMgr: { phase: 'Crossfading' } } },
        { from: 'view',           to: 'view',           label: 'fade in (ScreenSlot B 側)', kind: 'self' },
        { from: 'transMgr',       to: 'transMgr',       label: 'finalizeTransition\nScreenSlot A を active=false で解放\n→ OpeningScreen / OpeningView を破棄', kind: 'self', destroy: ['openingScreen', 'openingLoaderA', 'openingView'],
          setState: { screenSlotA: { source: '(empty)', active: 'false' }, transMgr: { phase: 'Idle', screenSrcA: '(empty)' } } },
    ],
};

/* flows/app/actors.js
   アクター定義 (位置・ラベル・色クラス)。
   配置はアーキテクチャ俯瞰風 (input 上、control 左、routing 中央、UI 右、loaders 下)。
   グローバル ACTORS を export (<script> タグ読み込み想定)。
*/
'use strict';

const ACTORS = {
    // ---- Input layer (画面外、Application 外) ----
    user:       { x:  40, y:  60, w: 140, h: 50, label: 'Physical Keyboard',  sub: '物理キー入力',     cls: 'user' },

    // ---- Mediator module 内 ----
    mediator:   { x:  50, y: 240, w: 140, h: 50, label: 'Mediator',           sub: 'singleton',        cls: 'singleton',
                preInstantiated: true, initialState: { current: '(none)', prev: '(none)', pending: '(none)', debugHistory: '[]' } },
    transMgr:   { x:  40, y: 360, w: 160, h: 50, label: 'TransitionManager',  sub: 'singleton',        cls: 'singleton',
                preInstantiated: true, initialState: { phase: 'Idle', screenSrcA: '(empty)', screenSrcB: '(empty)' } },

    // ---- Application 内: 上段 (singleton + Main.qml) ----
    main:       { x: 290, y:  60, w: 140, h: 50, label: 'Main.qml',           sub: 'Window + DI',     cls: '',
                preInstantiated: true, initialState: { state: 'Window active' } },
    screenRegistry: { x: 450, y:  60, w: 140, h: 50, label: 'ScreenRegistry', sub: 'qrc URL マップ',   cls: 'singleton',
                preInstantiated: true, initialState: { entries: '8 view + 3 screen URL' } },
    keyDisp:    { x: 610, y:  60, w: 140, h: 50, label: 'KeyDispatcher',      sub: 'singleton',        cls: 'singleton',
                preInstantiated: true, initialState: { enabled: 'true' } },

    // ---- screenSlot A/B = ScreenSlot group の左上に重ねる Loader actor ----
    screenSlotA: { x: 270, y: 200, w: 140, h: 35, label: 'screenSlotA',         sub: 'Loader',    cls: 'loader',
                preInstantiated: true, initialState: { source: '(empty)', active: 'false' } },
    screenSlotB: { x: 970, y: 200, w: 140, h: 35, label: 'screenSlotB',         sub: 'Loader',    cls: 'loader',
                preInstantiated: true, initialState: { source: '(empty)', active: 'false' } },

    // ---- OpeningScreen = openingScreen_contents group の左上に重ねる Screen actor ----
    openingScreen: { x: 290, y: 250, w: 140, h: 40, label: 'OpeningScreen',   sub: 'ScreenBase 派生', cls: '' },
    // openingLoaderA = viewSlotA_inOpeningScreen group の左上に重ねる Loader actor
    openingLoaderA: { x: 310, y: 305, w: 140, h: 30, label: 'viewSlotA',         sub: 'Loader', cls: 'loader' },
    openingView:   { x: 470, y: 365, w: 280, h: 60, label: 'OpeningView',     sub: 'ViewBase 派生', cls: 'view' },

    // ---- NormalScreen を ScreenSlot A 側にロードするシナリオ専用 (④ closing 中断後) ----
    //      Opening と同位置 (A 側) の NormalScreen + その内側 viewSlotA + HomeView。
    //      通常の NormalScreen (screen, x=990) は B 側固定なので、A 側にロードする
    //      ケース専用に別 actor を用意 (同じ「NormalScreen」表記)。
    normalScreenA:           { x: 290, y: 250, w: 140, h: 40, label: 'NormalScreen', sub: 'ScreenBase 派生', cls: '' },
    loaderA_inNormalScreenA: { x: 310, y: 305, w: 140, h: 30, label: 'viewSlotA',    sub: 'Loader',          cls: 'loader' },
    homeView_inNormalScreenA: { x: 470, y: 365, w: 280, h: 60, label: 'HomeView',    sub: 'ViewBase 派生',   cls: 'view' },

    // ---- NormalScreen = normalScreen_contents group の左上に重ねる Screen actor ----
    screen:     { x: 990, y: 250, w: 140, h: 40, label: 'NormalScreen',       sub: 'ScreenBase 派生', cls: '' },
    // ClosingScreen = closingScreen_contents group の左上 (Normal と同位置、scenario 切替で alt) ----
    closingScreen: { x: 990, y: 250, w: 140, h: 40, label: 'ClosingScreen',   sub: 'ScreenBase 派生', cls: '' },
    // NormalScreen の viewSlotA/B Loader actors
    loaderA:    { x: 1010, y: 305, w: 140, h: 30, label: 'viewSlotA',          sub: 'Loader', cls: 'loader' },
    loaderB:    { x: 1010, y: 485, w: 140, h: 30, label: 'viewSlotB',          sub: 'Loader', cls: 'loader' },
    // ClosingScreen の viewSlotA Loader (Normal の loaderA と同位置)
    closingLoaderA: { x: 1010, y: 305, w: 140, h: 30, label: 'viewSlotA',         sub: 'Loader', cls: 'loader' },
    // Views
    view:       { x: 1180, y: 365, w: 280, h: 60, label: 'HomeView',           sub: 'ViewBase 派生', cls: 'view' },
    newView:    { x: 1180, y: 545, w: 280, h: 60, label: 'MenuView',           sub: 'ViewBase 派生', cls: 'view' },
    closingView:   { x: 1180, y: 365, w: 280, h: 60, label: 'ClosingView',     sub: 'ViewBase 派生', cls: 'view' },
    sample2aView:  { x: 1180, y: 365, w: 280, h: 60, label: 'Sample2View',     sub: 'thisViewId=2a', cls: 'view' },
    sample2bView:  { x: 1180, y: 545, w: 280, h: 60, label: 'Sample2View',     sub: 'thisViewId=2b', cls: 'view' },
};

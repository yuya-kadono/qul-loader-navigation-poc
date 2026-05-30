/* flows/app/groups.js
   内包関係を可視化する group box (背景に薄い破線矩形 + ラベルを描画) の定義。
     contains: そのグループ内に居る (べき) アクター ID のリスト。
               シナリオの steps に「contains の中の誰か」が出てくる group だけ描画する。
     描画は z-order 最奥 (アクターより後ろ、バブルより遥か後ろ)。
   グローバル GROUPS を export (<script> タグ読み込み想定、actors.js の後に読む)。
*/
'use strict';

const GROUPS = {
    mediatorModule: {
        x:  20, y: 210, w: 200, h: 230,
        label: 'Mediator module',
        sub: 'orchestration singletons',
        contains: ['mediator', 'transMgr'],
    },

    application: {
        x: 250, y:  30, w: 1430, h: 740,
        label: 'Application',
        sub: 'Window と中で動くもの一式',
        contains: ['main', 'screenRegistry', 'keyDisp', 'screenSlotA', 'screenSlotB'],
    },

    // ========== ScreenSlot A 階層 ==========
    // Level 1: screenSlotA Loader (左上の actor が group を代表)
    //          OpeningScreen と (④ 中断後の) NormalScreen が同位置で alt 配置
    screenSlotA_contents: {
        x: 270, y: 200, w: 690, h: 550,
        label: 'screenSlotA の中身', sub: '',
        contains: ['screenSlotA', 'openingScreen', 'normalScreenA'],
        representedByActor: 'screenSlotA',
        parentGroup: 'application',
    },
    // Level 2 (Opening): OpeningScreen (= screenSlotA が抱える Screen、起動時)
    openingScreen_contents: {
        x: 290, y: 250, w: 650, h: 485,
        label: 'OpeningScreen の中身', sub: '',
        contains: ['openingScreen', 'openingLoaderA', 'openingView'],
        representedByActor: 'openingScreen',
        parentGroup: 'screenSlotA_contents',
    },
    // Level 3: viewSlotA (= OpeningScreen の ViewSlot A)
    viewSlotA_inOpeningScreen: {
        x: 310, y: 305, w: 620, h: 160,
        label: 'viewSlotA の中身', sub: '',
        contains: ['openingLoaderA', 'openingView'],
        representedByActor: 'openingLoaderA',
        parentGroup: 'openingScreen_contents',
    },
    // Level 3: viewSlotB (空、命名統一のため明示)
    viewSlotB_inOpeningScreen: {
        x: 310, y: 485, w: 620, h: 240,
        label: 'viewSlotB の中身',
        sub: '(OpeningScreen 単一 Loader、未使用)',
        contains: [],
        parentGroup: 'openingScreen_contents',
    },

    // Level 2 (NormalA): NormalScreen が ScreenSlot A 側にロードされるケース (④ 中断後)
    //                    Opening と同位置に overlap (scenario 切替で alt)
    normalScreenA_contents: {
        x: 290, y: 250, w: 650, h: 485,
        label: 'NormalScreen の中身', sub: '',
        contains: ['normalScreenA', 'loaderA_inNormalScreenA', 'homeView_inNormalScreenA'],
        representedByActor: 'normalScreenA',
        parentGroup: 'screenSlotA_contents',
    },
    // Level 3: viewSlotA of NormalScreenA
    viewSlotA_inNormalScreenA: {
        x: 310, y: 305, w: 620, h: 160,
        label: 'viewSlotA の中身', sub: '',
        contains: ['loaderA_inNormalScreenA', 'homeView_inNormalScreenA'],
        representedByActor: 'loaderA_inNormalScreenA',
        parentGroup: 'normalScreenA_contents',
    },

    // ========== ScreenSlot B 階層 (NormalScreen / ClosingScreen が同位置で alt) ==========
    // Level 1: screenSlotB Loader
    screenSlotB_contents: {
        x: 970, y: 200, w: 710, h: 550,
        label: 'screenSlotB の中身', sub: '',
        contains: ['screenSlotB', 'screen', 'closingScreen'],
        representedByActor: 'screenSlotB',
        parentGroup: 'application',
    },
    // Level 2 (Normal): NormalScreen
    normalScreen_contents: {
        x: 990, y: 250, w: 670, h: 485,
        label: 'NormalScreen の中身', sub: '',
        contains: ['screen', 'loaderA', 'loaderB', 'view', 'newView', 'sample2aView', 'sample2bView'],
        representedByActor: 'screen',
        parentGroup: 'screenSlotB_contents',
    },
    // Level 3: viewSlotA of NormalScreen
    viewSlotA_inNormalScreen: {
        x: 1010, y: 305, w: 640, h: 160,
        label: 'viewSlotA の中身', sub: '',
        contains: ['loaderA', 'view', 'sample2aView'],
        representedByActor: 'loaderA',
        parentGroup: 'normalScreen_contents',
    },
    // Level 3: viewSlotB of NormalScreen
    viewSlotB_inNormalScreen: {
        x: 1010, y: 485, w: 640, h: 240,
        label: 'viewSlotB の中身', sub: '',
        contains: ['loaderB', 'newView', 'sample2bView'],
        representedByActor: 'loaderB',
        parentGroup: 'normalScreen_contents',
    },

    // Level 2 (Closing): ClosingScreen — Normal と同位置に overlap (scenario 切替)
    closingScreen_contents: {
        x: 990, y: 250, w: 670, h: 485,
        label: 'ClosingScreen の中身', sub: '',
        contains: ['closingScreen', 'closingLoaderA', 'closingView'],
        representedByActor: 'closingScreen',
        parentGroup: 'screenSlotB_contents',
    },
    // Level 3: viewSlotA of ClosingScreen
    viewSlotA_inClosingScreen: {
        x: 1010, y: 305, w: 640, h: 160,
        label: 'viewSlotA の中身', sub: '',
        contains: ['closingLoaderA', 'closingView'],
        representedByActor: 'closingLoaderA',
        parentGroup: 'closingScreen_contents',
    },
};

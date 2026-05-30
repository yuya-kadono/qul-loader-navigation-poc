# qul-loader-navigation-poc

Qt for MCUs (Qt Quick Ultralite、以下 QUL) の `Loader` の制約下で、Screen 切り替え + Screen 内の View 切り替えを成立させるためのナビゲーションパターンを検証する POC。

## 目的

QUL の Loader は通常の Qt Quick の Loader と比べて以下の制限があり、これらを満たすナビゲーション設計を事前に検証することが目的。

- `Loader.item` 経由でのプロパティ参照・関数呼び出しが不可（オブジェクトイントロスペクション非対応）
- ロード済みアイテムとの通信は **Mediator singleton** または **`sourceComponent` + 外側スコープのバインディング** で行う必要がある
- Loader は View Delegate 内では使用不可

詳細は [Qt 公式ドキュメント](https://doc.qt.io/QtForMCUs/qml-qtquick-loader.html#limitations) を参照。

## 実装方針

- **実機 (MCU) へのデプロイは行わず、通常の Qt (Qt 6 系) で実装して理論検証**を行う
- ただし QUL の制約はそのまま守ることで、後から QUL へ移植可能な設計とする
- 画面遷移は **View ID ベース** で記述する
  - 各 View に一意の ID を割り当て、「進む先」「戻る先」を ID で指定
  - 遷移ロジックは Mediator singleton に集約

設計詳細は [`docs/design.md`](docs/design.md) を参照。フロー図のまとめは [`docs/flows.md`](docs/flows.md) (mermaid 静的版) と [`docs/flows/`](docs/flows/はじめに.txt) (**SVG/JS アニメ版**: アクター間のシグナル動きをブラウザで再生・一時停止・速度調整可、5 シナリオ選択付き。`file://` 直開きが上手くいかない場合は同フォルダの `start_app.bat` (Windows) または `scripts/start_app.sh` (Mac/Linux) でローカル HTTP 経由起動) を参照。

## プロジェクト構成

| 項目 | 値 |
| --- | --- |
| Git リポジトリ名 | `qul-loader-navigation-poc` |
| Qt Creator プロジェクト名 | `QulLoaderNavigation` |
| ビルド対象 | 通常の Qt 6 (デスクトップ) |
| 想定移植先 | Qt for MCUs (Qt Quick Ultralite 2.x) |
| Qt の最低バージョン | 6.10 (`qt_standard_project_setup(REQUIRES 6.10)`) |
| 必要な Qt6 コンポーネント | `Qt6::Quick`、`Qt6::QuickShapes` (Opening/Closing の sine 波実線描画用) |

## 本 POC で扱う Screen / View

| Screen   | View   | 表示 ID           | 整数 ID  | 担当 QML            | 内容 |
| ---     | ---      | ---               | ---     | ---                 | --- |
| opening | opening  | `Opening/Opening` | `0x0100`| OpeningView.qml     | 起動スプラッシュ。5 本の sine 波が広がる |
| normal  | home     | `Normal/Home`     | `0x0200`| HomeView.qml        | アイコンランチャー (Menu / Shutdown タイル) |
| normal  | menu     | `Normal/Menu`     | `0x0201`| MenuView.qml        | サンプル選択ランチャー (Sample 1/2A/2B タイル) |
| normal  | sample1  | `Normal/Sample1`  | `0x0202`| Sample1View.qml     | ナビゲーション履歴表示 + Flickable スクロール |
| normal  | sample2a | `Normal/Sample2a` | `0x0203`| **Sample2View.qml** | バリアント A (紫アクセント) |
| normal  | sample2b | `Normal/Sample2b` | `0x0204`| **Sample2View.qml** | バリアント B (藍アクセント)、A と同一 QML |
| closing | closing  | `Closing/Closing` | `0x0300`| ClosingView.qml     | 終了スプラッシュ。5 本の sine 波が中央へ収束 → `Qt.quit()` |

View ID は **bit-packed 整数** `((screenId << 8) | localId)`。QUL 2.x の QML enum 構文に従い、`ScreenId.qml` / `ViewId.qml` の singleton 内に enum を持つ。アクセスは `ViewId.NormalSample2a` の 2 段形式 (`<Type>.<value>`、QUL 標準 cf. `Loader.Ready`)。文字列名 `"Normal/Sample2a"` 等はログ可読化用 (`ViewId.nameOf(id)`)。

`sample2a` と `sample2b` は **同一 Sample2View.qml** をロードする。ViewBase が `Mediator.pendingViewId` から `thisViewId` を動的に取得し、内部変数 `isVariantA` / `isVariantB` で挙動を分岐する（継承で派生クラスを増やさない設計）。

遷移グラフ・ナビゲーションテーブル・Mediator API の詳細は [`docs/design.md`](docs/design.md) を参照。

## 仮想キー（PC キーボード割り当て）

実機 MCU のボタンを模す仮想キー入力層を持つ。PC キーボードの物理キーは下表の仮想キーにマップされ、以降アプリ内では仮想キーだけが配送される（PRESS / RELEASE / CLICK の 3 イベント）。

| 物理キー | 仮想キー | 想定用途 |
| --- | --- | --- |
| A | `PREV`  | 前候補 / カーソル左 / スクロール上 |
| S | `ENTER` | 決定 / アクション発火 |
| D | `NEXT`  | 次候補 / カーソル右 / スクロール下 |
| Z | `MENU`  | メニュー呼び出し |
| X | `HOME`  | ホーム画面へ |
| C | `BACK`  | 戻る |

詳細は [`docs/design.md` §8](docs/design.md) を参照。

### POC 専用デバッグ機能 (production 移植時に削除)

`Main.qml` に以下のデバッグ機能を持たせている (実機 MCU 移植時にはすべて剥がす想定):

- **右上 debug overlay**: `currentViewId`、`previousViewId`、`pendingViewId`、`history.length`、TransitionManager の各 slot 状態、現在押されているキー数と conflict 状態をライブ表示
- **左下ミニキーボード overlay**: QWERTY 左下 (Q/W/E/R + A/S/D/F + Z/X/C/V) を物理レイアウト通り再現。使用キーには仮想キー名 (PREV/ENTER/NEXT/MENU/HOME/BACK) を併記、未使用キーはグレー。押下中は黄色枠 (正常 dispatch)、conflict 中は赤枠 (dispatch 抑制中)
- **同時押し検出 (conflict mode)**: 2 つ目のキーが押された瞬間に conflict 確定 → 先押しキーの Release を即発行して View の押下色を解放、以後の Press / 物理 Release は一切 dispatch しない。全キーが離れたら conflict 解除
- **隠しジャンプキー**: `1`/`2`/`3`/`4`/`5` で `Normal/Home`/`Normal/Menu`/`Normal/Sample1`/`Normal/Sample2a`/`Normal/Sample2b` へ直接ジャンプ。通常の `switchView` 経由なので history も普通に更新される

## ビルド

通常の Qt 6 + Qt Creator でそのまま開いてビルド可能。

CMake は `qt_standard_project_setup(REQUIRES 6.10)` を指定しているため **Qt 6.10 以上** を想定。古い Qt 6 でビルドする場合は `QulLoaderNavigation/CMakeLists.txt` のこの行を環境に合わせて緩めること。

`Qt6::QuickShapes` モジュールが必要 (Opening/Closing の sine 波を Shape + PathPolyline で連続実線描画するため)。標準的な Qt 6 インストールには含まれているはず。

コマンドラインからビルドする場合の例:

```sh
cd QulLoaderNavigation
cmake -B build -S .
cmake --build build
./build/appQulLoaderNavigation
```

## 動作確認の流れ

起動するとまず OPENING が約 1.8 秒で表示され、自動的に HOME に遷移する。以降は仮想キーで操作する。

OPENING / CLOSING は全画面の splash visual (5 本の sine 波線が広がる / 収束する)、normal Screen は chrome (Header/Footer/AsideL/AsideR) で囲まれた中央 4:3 領域 (640×480) に各 view が描画される。

### 主な操作

| 状況 | キー | 結果 |
| --- | --- | --- |
| HOME 表示中 | `A` (PREV) / `D` (NEXT) | カーソルを Menu ↔ Shutdown 間で移動 |
| HOME 表示中 | `S` (ENTER) | 選択中タイルを起動 (Menu → menu、Shutdown → closing) |
| HOME 表示中 | `Z` (MENU)  | MENU へ直接遷移 (NormalScreen が吸収、Menu タイル + ENTER と同等) |
| MENU 表示中 | `A` (PREV) / `D` (NEXT) | カーソルを Sample 1 / 2A / 2B 間で移動 |
| MENU 表示中 | `S` (ENTER) | カーソル位置のサンプルへ遷移 |
| MENU 表示中 | `C` (BACK)  | HOME へ戻る |
| SAMPLE 1 表示中 | `A` (PREV) / `D` (NEXT) | 履歴リストを上 / 下にスクロール (60px、両端 clamp) |
| SAMPLE 1 表示中 | `C` (BACK)  | MENU へ戻る |
| SAMPLE 2A 表示中 | `D` (NEXT) | Sample 2B へ (Next 方向) |
| SAMPLE 2B 表示中 | `A` (PREV) | Sample 2A へ (Back 方向) |
| SAMPLE 2A/2B 表示中 | `C` (BACK)  | MENU へ戻る |
| いずれの normal 画面 | `X` (HOME) | HOME へ戻る (NormalScreen が吸収) |
| CLOSING 表示中 (アニメ中) | `C` (BACK) or `X` (HOME) | アニメ中断して HOME へ戻る |
| CLOSING 表示中 (アニメ完了) | — | `Qt.quit()` でアプリ終了 |

### タイルの 3 状態ビジュアル (HomeView / MenuView)

| 状態 | タイル背景 | 枠線 | シンボル / ラベル |
| --- | --- | --- | --- |
| 非選択 | `#2a2a2a` | `#3a3a3a` 1px | `#e0e0e0` / `#9e9e9e` |
| 選択中 (カーソル) | `#2a2a2a` (同じ) | `#e0e0e0` 2px (白) | `#ffffff` / `#e0e0e0` 太字 |
| 押下中 (ENTER 押下) | `#2a2a2a` (同じ) | `#ffeb3b` 3px (黄) | `#ffffff` / `#e0e0e0` 太字 |

タイル本体色は常に `#2a2a2a` で一律。view identity は **上部 6px のアクセントライン** (`accentColor`) のみで表現する設計。

### 戻り時のカーソル復元

各 view は `Mediator.previousViewId` を見て初期カーソル位置を決める:

**HomeView**:

| 直前の view | 初期カーソル |
| --- | --- |
| `Closing/Closing` (中断で戻った) | Shutdown |
| それ以外 (起動直後・menu から) | Menu |

**MenuView**:

| 直前の view | 初期カーソル |
| --- | --- |
| `Normal/Sample1` | Sample 1 |
| `Normal/Sample2a` | Sample 2A |
| `Normal/Sample2b` | Sample 2B |
| それ以外 (home から初めて来た等) | Sample 1 |

## 配色

ダーク統一 + 上部アクセントライン方式。エリアの境界は 1px ハイラインで明示する。

| 階層 | 色 | 用途 |
| --- | --- | --- |
| Window | `#000000` | 最外フレーム |
| Chrome (Header/Footer/AsideL/R) | `#141414` | 最も暗い「フレーム」 |
| View 背景 (`ViewBase.backgroundColor` デフォルト) | `#1e1e1e` | 一段明るい「画面の中身」 |
| Tile (`#2a2a2a`) | `#2a2a2a` | さらに上の「カード」 |
| Divider line (chrome 境界 1px) | `#333333` | クリスプな区切り |

View 別の **accentColor** (上部 6px ライン + 押下中ではない選択タイルの hint 等):

| View | accentColor |
| --- | --- |
| HomeView | `#66bb6a` (soft green) |
| MenuView | `#ffa726` (soft orange) |
| Sample1View | `#ef5350` (soft red) |
| Sample2View (A) | `#ab47bc` (soft purple) |
| Sample2View (B) | `#5c6bc0` (soft indigo) |

Opening/Closing は POC の splash として既存のグラデーション背景 (`#1a237e` 系 / `#263238` 系) を維持。

## ログ出力でフローを追う

全 singleton / Screen / View / Main は `Logger` singleton 経由で標準出力に呼び出しタイムスタンプ・コンポーネント名・関数名・引数・関連 state を出す。フォーマット:

```
[HH:MM:SS.mmm] Component.fn(args)  | params
```

例 (MENU で D→D→S を押して `sample2b` へ遷移するときの抜粋):

```
[12:34:56.700] Main.Keys.onPressed(physicalKey=68)  | vk=NEXT
[12:34:56.700] KeyDispatcher.dispatchToScreen(vk=NEXT, ev=PRESS)  | enabled=true
[12:34:56.700] normalScreen.onScreenKeyEvent(vk=NEXT, ev=PRESS)
[12:34:56.700] normalScreen.forward-to-view(vk=NEXT, ev=PRESS)
[12:34:56.700] normal/menu.onViewKey(vk=NEXT, ev=PRESS)
...
[12:34:56.850] normal/menu.cursor moved(NEXT/CLICK)  | cursorIndex=2
[12:34:57.200] Main.Keys.onPressed(physicalKey=83)  | vk=ENTER
...
[12:34:57.350] normal/menu.action(ENTER/CLICK)  | switchView(normal/sample2b, Next)
[12:34:57.350] Mediator.switchView(viewId=normal/sample2b, direction=Next)  | currentViewId=normal/menu, previousViewId=normal/home, history.length=2
[12:34:57.351] TransitionManager.startTransition(toViewId=normal/sample2b, ...)  | fromViewId=normal/menu, screenChanged=false, ...
[12:34:57.351] normal/sample2b.thisViewId auto-resolved()  | from Mediator.pendingViewId=normal/sample2b   ★同一QML多重ID
[12:34:57.351] normal/sample2b.Component.onCompleted()  | myLifecycle=Entering
...
```

`normal/sample2b.thisViewId auto-resolved` のログが、同一 QML (`Sample2View.qml`) が `sample2b` として動的にロードされていることを示す。Sample 2A を選んだ場合は同じファイルが `Normal/Sample2a` として auto-resolve される。

同時押しを発生させると以下のような警告ログが出る:

```
[12:35:01.100] Main.MULTI-KEY conflict ENTERED(newKey=ENTER)  | pre-emptive Release dispatched for first-pressed vk=PREV (Click suppressed); further dispatch suppressed
[12:35:01.250] Main.Release SUPPRESSED (conflict, already handled)(vk=PREV)  | remainingPressed=1
[12:35:01.300] Main.Release SUPPRESSED (conflict, already handled)(vk=ENTER)  | remainingPressed=0
[12:35:01.300] Main.MULTI-KEY conflict CLEARED(all keys released)  | next single press will dispatch normally
```

ログは QML の `console.log` 経由なので、Qt Creator では「アプリケーション出力」、コマンドラインでは標準出力で見える。フィルタしたいときは grep:

```sh
./build/appQulLoaderNavigation 2>&1 | grep -E 'Mediator|TransitionManager|conflict'
```

## ディレクトリ構成

実装の構成は [`docs/design.md`](docs/design.md) §3-3 と一致している。`QulLoaderNavigation/` 配下は **2 つの QML サブモジュール** (Constants / Mediator) + **メインモジュール** (appQulLoaderNavigation の Screens/) から成る。再利用しうる「制御」「定数」「派生用 base」だけサブモジュール化し、本アプリ固有の「画面そのもの」(具体 Screen/View) はメインモジュール側のフォルダツリーに置く方針。

```
QulLoaderNavigation/
├── CMakeLists.txt        # ルート: 2 サブモジュール add_subdirectory + appQulLoaderNavigation
├── main.cpp
├── Screens/              # ★ メインモジュール (URI QulLoaderNavigation) の画面一式
│   ├── ScreenRegistry.qml  # ID→qrc URL マップ singleton (Main.qml から TransitionManager に DI)
│   ├── HelpRegistry.qml    # viewId → 操作ヘルプ文字列マップ singleton (未使用、将来用)
│   ├── Opening/          #   opening screen 一式
│   │   ├── OpeningScreen.qml
│   │   └── OpeningView.qml  # Shape + PathPolyline で 5 本の sine 波実線
│   ├── Normal/           #   normal screen 一式
│   │   ├── NormalScreen.qml  # Header/Footer/AsideL/AsideR + 中央 contentArea (4:3)
│   │   ├── HomeView.qml     # アイコンランチャー (Menu / Shutdown)
│   │   ├── MenuView.qml     # アイコンランチャー (Sample 1 / 2A / 2B)
│   │   ├── Sample1View.qml  # 履歴表示 + Flickable scroll
│   │   └── Sample2View.qml  # ※ 同一 QML 多重 ID (a/b variant)
│   └── Closing/          #   closing screen 一式
│       ├── ClosingScreen.qml
│       └── ClosingView.qml  # Shape + PathPolyline で 5 本の sine 波 (収束)
├── Constants/            # サブモジュール: enum + helper (依存なし)
│   ├── CMakeLists.txt
│   ├── ScreenId.qml        #   §5-2: enum ScreenId + nameOf
│   ├── ViewId.qml          #   §5-2: enum ViewId + nameOf + screenOf
│   ├── NavDirection.qml    #   §9-3: enum NavDirection (Next/Back) + nameOf
│   ├── ViewLifecycle.qml   #   §9-3: enum ViewLifecycle (Idle/Entering/Leaving) + nameOf
│   ├── VirtualKey.qml      #   §8-1: enum VirtualKey (Prev/Enter/Next/Menu/Home/Back) + nameOf
│   └── VirtualEvent.qml    #   §8-2: enum VirtualEvent (Press/Release/Click) + nameOf
└── Mediator/             # サブモジュール: ナビゲーション制御 + base (Constants 依存)
    ├── CMakeLists.txt
    ├── Mediator.qml          #   §6: ナビゲーション意図と履歴 (singleton)
    ├── TransitionManager.qml #   §9: スロット管理と view ライフサイクル通知 (singleton)
    ├── KeyDispatcher.qml     #   §8-3: 仮想キー/イベント配送 + enabled フラグ (singleton)
    ├── Logger.qml            #   タイムスタンプ付き console.log フォーマッタ (singleton)
    ├── ScreenBase.qml        #   §9-10: 派生元 (viewArea property、ViewSlot ペア、入力吸収転送)
    └── ViewBase.qml          #   §9-10/§9-11: 派生元 (accentColor + 上部 6px ライン、lifecycle 契約)
```

**サブモジュールに含めるかどうかの基準**:

「ナビゲーション制御として、別のアプリでも再利用しうるか」を判断基準にしている。Constants の enum も Mediator の singleton も ScreenBase/ViewBase も「制御」側で、別のアプリに移植する余地がある。一方、具体 Screen/View (= 画面そのもの) と `ScreenRegistry` (ID→qrc URL マップ、本アプリの画面配置に固有) は本 POC 固有なのでサブモジュール化せずメインモジュール内の Screens/ 配下に置く。

**ID → qrc URL の解決方法 (DI)**:

Constants の ScreenId/ViewId enum は「値」と「デバッグ用文字列名」だけを持ち、qrc URL の知識は持たない。URL 知識を Constants に置くと「Constants → メインモジュール qrc 構造」の参照が発生して依存方向が崩れるため、URL マップは `Screens/ScreenRegistry.qml` (メインモジュール所属の singleton) に分離した。

Mediator/TransitionManager は `property var screenRegistry: null` を持ち、Main.qml の `Component.onCompleted` で `TransitionManager.screenRegistry = ScreenRegistry` と注入される。`startTransition` は `screenRegistry.viewUrlOf(viewId)` / `screenUrlOf(screenId)` 経由で URL を取得する。これで Mediator はメインモジュールの qrc 配置を知らずに済む。

各モジュールの使い方:

```qml
// 例: Mediator/Mediator.qml
import QtQuick
import Constants            // ViewId, NavDirection を使うため

QtObject {
    function switchView(viewId, direction) {
        if (viewId === ViewId.ClosingClosing) { ... }
    }
}
```

```qml
// 例: Screens/Normal/HomeView.qml
import QtQuick
import Constants            // ViewId, VirtualEvent, VirtualKey, NavDirection
import Mediator             // Mediator, KeyDispatcher, Logger, ViewBase (派生元)

ViewBase {
    thisViewId: ViewId.NormalHome
    accentColor: "#66bb6a"
    function onViewKey(vk, ve) {
        if (ve !== VirtualEvent.Click) return
        if (vk === VirtualKey.Enter) {
            Mediator.switchView(ViewId.ClosingClosing,
                                     NavDirection.Next)
        }
    }
}
```

依存方向は **Constants ← Mediator ← appQulLoaderNavigation(Screens/)** の一方向で、循環なし。ScreenBase / ViewBase は Mediator モジュール内なので、派生する具体 Screen/View は `import Mediator` だけで base を取れる。
                             
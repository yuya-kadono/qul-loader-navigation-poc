# qul-loader-navigation-poc

Qt for MCUs (Qt Quick Ultralite, 以下 QUL) の `Loader` の制約下で、Screen切り替え + Screen内のView切り替えを成立させるためのナビゲーションパターンを検証する POC。

## 目的

QUL の Loader は通常の Qt Quick の Loader と比べて以下の制限があり、これらを満たすナビゲーション設計を事前に検証することが目的。

- `Loader.item` 経由でのプロパティ参照・関数呼び出しが不可（オブジェクトイントロスペクション非対応のため）
- ロード済みアイテムとの通信は **Mediator singleton** または **`sourceComponent` + 外側スコープのバインディング** で行う必要がある
- Loader は View Delegate 内では使用不可

詳細は [Qt 公式ドキュメント](https://doc.qt.io/QtForMCUs/qml-qtquick-loader.html#limitations) を参照。

## 実装方針

- **実機 (MCU) へのデプロイは行わず、通常の Qt (Qt 6 系) で実装して理論検証**を行う
- ただし QUL の制約はそのまま守ることで、後から QUL へ移植可能な設計とする
- 画面遷移は **View ID ベース** で記述する
  - 各Viewに一意の ID を割り当て、「進む先」「戻る先」を ID で指定
  - 遷移ロジックは Mediator singleton に集約

設計詳細は [`docs/design.md`](docs/design.md) を参照。フロー図のまとめは [`docs/flows.md`](docs/flows.md) (mermaid 版) と [`docs/flows.pptx`](docs/flows.pptx) (PowerPoint 版) を参照。

## プロジェクト構成

| 項目 | 値 |
| --- | --- |
| Git リポジトリ名 | `qul-loader-navigation-poc` |
| Qt Creator プロジェクト名 | `QulLoaderNavigation` |
| ビルド対象 | 通常の Qt 6 (デスクトップ) |
| 想定移植先 | Qt for MCUs (Qt Quick Ultralite 2.x) |

## 本 POC で扱うScreen / View

| Screen   | View   | 表示 ID           | 整数 ID  | 担当 QML            |
| ---     | ---      | ---               | ---     | ---                 |
| opening | opening  | `opening/opening` | `0x0100`| OpeningView.qml     |
| normal  | home     | `normal/home`     | `0x0200`| HomeView.qml        |
| normal  | menu     | `normal/menu`     | `0x0201`| MenuView.qml (3 ボタン) |
| normal  | sample1  | `normal/sample1`  | `0x0202`| Sample1View.qml     |
| normal  | sample2a | `normal/sample2a` | `0x0203`| **Sample2View.qml** |
| normal  | sample2b | `normal/sample2b` | `0x0204`| **Sample2View.qml** (同一 QML 多重 ID) |
| closing | closing  | `closing/closing` | `0x0300`| ClosingView.qml     |

View ID は **bit-packed 整数** `((screenId << 8) | localId)`。QUL 2.9 の QML enum 構文に従い、`ScreenId.qml` / `ViewId.qml` の singleton 内に `enum ScreenId { ... }` / `enum ViewId { ... }` を持つ。アクセスは `ViewId.NormalSample2a` の 2 段形式 (`<Type>.<value>`、QUL 標準 cf. `Loader.Ready`)。文字列名 `"normal/sample2a"` 等はログ可読化用 (`ViewId.nameOf(id)`)。

`sample2a` と `sample2b` は **同一 Sample2View.qml** をロードする。ViewBase が `Mediator.pendingViewId` から `thisViewId` を動的に取得し、内部変数 `isVariantA` / `isVariantB` で挙動を分岐する（継承で派生クラスを増やさない設計）。

遷移グラフ・ナビゲーションテーブル・Mediator API の詳細は [`docs/design.md`](docs/design.md) を参照。

## 仮想キー（PC キーボード割り当て）

実機 MCU のボタンを模す仮想キー入力層を持つ。PC キーボードの物理キーは下表の仮想キーにマップされ、以降アプリ内では仮想キーだけが配送される（PRESS / RELEASE / CLICK の 3 イベント）。

| 物理キー | 仮想キー | 想定用途 |
| --- | --- | --- |
| A | `PREV`  | 前候補 |
| S | `ENTER` | 決定 |
| D | `NEXT`  | 次候補 |
| Z | `MENU`  | メニュー呼び出し |
| X | `HOME`  | ホーム画面へ |
| C | `BACK`  | 戻る |

詳細は [`docs/design.md` §8](docs/design.md) を参照。

## ビルド

通常の Qt 6 + Qt Creator でそのまま開いてビルド可能。

CMake は `qt_standard_project_setup(REQUIRES 6.10)` を指定しているため **Qt 6.10 以上** を想定。古い Qt 6 でビルドする場合は `QulLoaderNavigation/CMakeLists.txt` のこの行を環境に合わせて緩めること。

コマンドラインからビルドする場合の例:

```sh
cd QulLoaderNavigation
cmake -B build -S .
cmake --build build
./build/appQulLoaderNavigation
```

## 動作確認の流れ

起動するとまず OPENING が約 1.5 秒で表示され、自動的に HOME に遷移する。以降は仮想キーで操作する。

主な動線:

| 状況 | キー | 結果 |
| --- | --- | --- |
| HOME 表示中 | `S` (ENTER) | CLOSING へ遷移 (Next) |
| HOME 表示中 | `Z` (MENU)  | MENU へ遷移 (NormalScreen が吸収) |
| MENU 表示中 | `A` (PREV)  | 選択カーソルを 1 つ左へ (Sample 1 ← Sample 2A ← Sample 2B) |
| MENU 表示中 | `D` (NEXT)  | 選択カーソルを 1 つ右へ (Sample 1 → Sample 2A → Sample 2B) |
| MENU 表示中 | `S` (ENTER) | カーソル位置のサンプルへ遷移 (Next) |
| MENU 表示中 | `C` (BACK)  | HOME へ戻る (Back) |
| SAMPLE 1/2A/2B 表示中 | `C` (BACK) | MENU へ戻る (Back) |
| いずれの normal 画面 | `X` (HOME) | HOME へ戻る (NormalScreen が吸収) |
| CLOSING 表示中 (アニメ中) | `C` (BACK) or `X` (HOME) | アニメ中断して HOME へ戻る |
| CLOSING 表示中 (アニメ完了) | — | `Qt.quit()` でアプリ終了 |

MENU 画面に戻ったときの**初期カーソル位置**は `Mediator.previousViewId` を見て決まる:

| 直前の view | 初期 cursorIndex | カーソル位置 |
| --- | --- | --- |
| `normal/sample1`   | 0 | Sample 1 |
| `normal/sample2a`  | 1 | Sample 2A |
| `normal/sample2b`  | 2 | Sample 2B |
| `normal/home` から初めて来た 等 | 0 | Sample 1 (デフォルト) |

各画面には `direction`、`from` (遷移元 view ID)、`prev` (Mediator.previousViewId)、`history.length` を表示するので、設計通り情報が伝達できているか目視確認できる。Sample 2A は紫背景、Sample 2B は藍背景で見分けられる (同じ Sample2View.qml だが内部分岐で見た目を変えている)。

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
[12:34:57.350] normal/menu.action(ENTER/CLICK)  | cursorIndex=2 → switchView(normal/sample2b, Next)
[12:34:57.350] Mediator.switchView(viewId=normal/sample2b, direction=Next)  | currentViewId=normal/menu, previousViewId=normal/home, history.length=2
[12:34:57.351] TransitionManager.startTransition(toViewId=normal/sample2b, ...)  | fromViewId=normal/menu, screenChanged=false, ...
[12:34:57.351] normal/sample2b.thisViewId auto-resolved()  | from Mediator.pendingViewId=normal/sample2b   ★同一QML多重ID
[12:34:57.351] normal/sample2b.Component.onCompleted()  | myLifecycle=Entering
...
```

`normal/sample2b.thisViewId auto-resolved` のログが、同一 QML (`Sample2View.qml`) が `sample2b` として動的にロードされていることを示す。Sample 2A を選んだ場合は同じファイルが `normal/sample2a` として auto-resolve される。

ログは QML の `console.log` 経由なので、Qt Creator では「アプリケーション出力」、コマンドラインでは標準出力で見える。フィルタしたいときは grep:

```sh
./build/appQulLoaderNavigation 2>&1 | grep -E 'Mediator|TransitionManager'
```

実装の構成は [`docs/design.md`](docs/design.md) と一致している。`QulLoaderNavigation/` 配下は **2 つの QML サブモジュール** (Constants / Mediator) + **メインモジュール** (appQulLoaderNavigation の Screens/) から成る。再利用しうる「制御」「定数」「派生用 base」だけサブモジュール化し、本アプリ固有の「画面そのもの」(具体 Screen/View) はメインモジュール側のフォルダツリーに置く方針。

```
QulLoaderNavigation/
├── CMakeLists.txt        # ルート: 2 サブモジュール add_subdirectory + appQulLoaderNavigation
├── main.cpp
├── Main.qml              # Window、物理→仮想キー変換、ScreenSlot ペア (§3-2, §8-4)
├── Screens/              # ★ メインモジュール (URI QulLoaderNavigation) の画面一式
│   ├── ScreenRegistry.qml  # ID→qrc URL マップ singleton (Main.qml から TransitionManager に DI)
│   ├── Opening/          #   opening screen 一式
│   │   ├── OpeningScreen.qml
│   │   └── OpeningView.qml
│   ├── Normal/           #   normal screen 一式 (home + menu + 3 sample)
│   │   ├── NormalScreen.qml
│   │   ├── HomeView.qml MenuView.qml
│   │   ├── Sample1View.qml
│   │   └── Sample2View.qml  # ※ 同一 QML 多重 ID
│   └── Closing/          #   closing screen 一式
│       ├── ClosingScreen.qml
│       └── ClosingView.qml
├── Constants/            # サブモジュール: enum + helper (依存なし)
│   ├── CMakeLists.txt    #   URI: Constants
│   ├── ScreenId.qml       #   §5-2: enum ScreenId + fileOf/nameOf
│   ├── ViewId.qml        #   §5-2: enum ViewId + fileOf/nameOf/screenOf
│   ├── NavDirection.qml     #   §9-3: enum NavDirection (Next/Back) + nameOf
│   ├── ViewLifecycle.qml     #   §9-3: enum ViewLifecycle (Idle/Entering/Leaving) + nameOf
│   ├── VirtualKey.qml           #   §8-1: enum VirtualKey (PREV/ENTER/NEXT/MENU/HOME/BACK) + nameOf
│   └── VirtualEvent.qml         #   §8-2: enum VirtualEvent (PRESS/RELEASE/CLICK) + nameOf
└── Mediator/             # サブモジュール: ナビゲーション制御 + base (Constants 依存)
    ├── CMakeLists.txt    #   URI: Mediator
    ├── Mediator.qml      #   §6: ナビゲーション意図と履歴 (singleton)
    ├── TransitionManager.qml  # §9: スロット管理と view ライフサイクル通知 (singleton)
    ├── KeyDispatcher.qml #   §8-3: 仮想キー/イベント配送 + enabled フラグ (singleton)
    ├── Logger.qml        #   §9-10: タイムスタンプ付き console.log フォーマッタ (singleton)
    ├── ScreenBase.qml     #   §9-10: 派生元 (screen-filtered binding、ViewSlot ペア、入力吸収転送)
    └── ViewBase.qml      #   §9-10/§9-11: 派生元 (lifecycle 契約、ランダム duration、onViewKey フック)
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

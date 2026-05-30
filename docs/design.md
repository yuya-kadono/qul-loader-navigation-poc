# 設計メモ

このドキュメントは、QUL Loader の制約下で実現するScreen/View切り替えナビゲーションの設計方針をまとめたもの。

## 1. QUL Loader の制約まとめ

検証対象は [Qt for MCUs Loader Limitations](https://doc.qt.io/QtForMCUs/qml-qtquick-loader.html#limitations)。

### 1-1. ロード済みアイテムへの直接アクセス不可

通常の Qt Quick とは異なり、QUL Loader は `Loader.item` を介してロード済みアイテムにアクセスすることが**できない**。

- プロパティの読み書き不可
- 関数呼び出し不可
- 原因: オブジェクトイントロスペクションシステム非対応

### 1-2. View Delegate 内での使用不可

ListView などの delegate 内に Loader を置くことはできない。

### 1-3. アロケーション特性（実装時の注意）

- ロード対象は `QmlDynamicObjects` メモリアロケータから確保される
- `source` / `sourceComponent` 変更時、または `active = false` 時に解放
- すべてのアロケーションはシングルスレッドで実行されるため、ロード時のコンストラクタが重いと UI フリーズの可能性あり

## 2. 制約を回避する 2 つのパターン

### パターン A: Mediator singleton

`pragma singleton` を付けた QtObject に状態と信号を集約し、ロード元・ロード先の両方が同じ singleton を import して通信する。

```qml
// Mediator.qml
import QtQuick
pragma singleton

QtObject {
    property string currentViewId: ""
    signal navigateTo(string viewId)
}
```

**利点**
- ロード先が任意のモジュールでも疎結合に通信可能
- 状態の所在が一箇所に集約され、テストしやすい

**欠点**
- グローバル状態が増える
- 命名衝突に注意

### パターン B: `sourceComponent` + 外側スコープ

`source` ではなく `sourceComponent` を使うと、Component 内から外側のオブジェクトに直接バインドできる。

```qml
Component {
    id: pageComp
    Rectangle {
        color: globalSettings.pageColor  // 外側にバインド可
    }
}
Loader { sourceComponent: pageComp }
```

**利点**
- singleton 不要、ローカルにスコープが閉じる
- 軽量

**欠点**
- すべての Component を同じ QML ファイル内に書く必要がある
- ファイル分割でのスケーラビリティが低い

### 本 POC の方針

**パターン A (Mediator singleton) を主軸として採用**する。

理由:
- Screen/Viewの数が増えてもファイル分割でスケールする
- ナビゲーション状態を一箇所で管理できる
- View ID ベースの宣言的な遷移定義と相性が良い

ただしScreen内の小さな部品で `sourceComponent` パターンが有効な箇所があれば併用も検討する。

### 2-3. QUL 移植性のためのコーディング方針

実機 (Qt for MCUs) への移植を想定するため、QML / JS の使用範囲を以下に制限する。
これにより古い QUL バージョン (2.7〜2.9 等) でもビルド・動作する想定にする。

| 種別 | 採用 | 不採用 | 理由 |
| --- | --- | --- | --- |
| 変数宣言 | `var` | `let` / `const` | QUL の JS subset では未保証 |
| 関数表現 | `function name() {}` / `function() {}` | arrow function `() => {}` | 同上 |
| シグナルハンドラ | `on<Signal>: { ... }` (古典スタイル) | `function on<Signal>(args) { ... }` | QUL は **Connections の中で** function 構文を silent fail にする |
| Singleton への変化通知 | property + ローカルバインディング + `on<Property>Changed` | `Connections { target: singleton }` | singleton ターゲットの Connections は不安定。**property-token + binding パターン** に統一 (§8-3, §9-3) |
| 命名規則 | lowerCamelCase | `_` プレフィックス | [Qt QML Coding Conventions](https://doc.qt.io/qt-6/qml-codingconventions.html) に従う |
| ファイル配置 | QML module 内 (`pragma Singleton` 可) | 相対 import | QUL は singleton をモジュールに置く必要あり |

**例外**: 本 POC をデスクトップ Qt 6 で検証するための **物理キー受信層 (`Main.qml` の `Keys.onPressed` / `onReleased`)** のみ、Qt 6 推奨の `function(event) { ... }` 形式を使う。実機 MCU 移植時には物理ボタンから直接 `KeyDispatcher.dispatchToScreen()` を呼ぶため、この層は丸ごと置き換わる。

## 3. ナビゲーション構造

### 3-1. 2 階層構造

```
Application
├── Screen A
│   ├── View A-1
│   ├── View A-2
│   └── View A-3
├── Screen B
│   ├── View B-1
│   └── View B-2
└── Screen C
    └── View C-1
```

- **Screen**: アプリの大枠の状態（例: ホーム画面、設定画面、再生画面）
- **View**: Screen内の個別画面（例: 設定画面のサブページ）

### 3-2. Loader 階層（ペア構成）

クロスフェード遷移を成立させるため、各層に **2 つの Loader をペア**で持ち、片方を current、もう片方を entering として使う。

```
Window
├── ScreenSlotA (Loader)  ─┐
└── ScreenSlotB (Loader)  ─┘  Screen跨ぎ時はこのペアでクロスフェード
        └── (各 Screen QML 内)
                ├── ViewSlotA (Loader)  ─┐
                └── ViewSlotB (Loader)  ─┘  同Screen内 view 切替時のクロスフェード
```

- **Screen跨ぎ遷移**: ScreenSlotA/B でクロスフェード。新Screenの中では ViewSlotA 単独で初期 view を表示（view 層のフェードは行わない）
- **同Screen内 view 切替**: ScreenSlot 不変、active screen の ViewSlotA/B でクロスフェード
- 全スロットの「どちらが current か」「source」「opacity」は §9 の **TransitionManager singleton** が集中管理する
- メモリ瞬間ピーク: Screen跨ぎ中の 2 Screen × 各 1 view = 計 6 Loader アクティブ。フェード完了後は旧スロットを `active = false` で解放する

### 3-3. QML モジュール構成 (サブモジュール分割)

ソースは **2 つのサブモジュール** (Constants / Mediator) と **メインモジュール内の Screens/** から成る。依存方向は **一方向** (`Constants ← Mediator ← appQulLoaderNavigation(Screens/)`)、循環なし。

```
QulLoaderNavigation/
├── CMakeLists.txt        # ルート: add_subdirectory(2 個) + appQulLoaderNavigation
├── main.cpp
├── Main.qml              # アプリ entry。Constants + Mediator を import
│
├── Screens/              # ★ メインモジュール (URI QulLoaderNavigation) 配下の画面一式
│   ├── ScreenRegistry.qml    ID→qrc URL マップ singleton (DI 用、§後述)
│   ├── Opening/              OpeningScreen + OpeningView
│   ├── Normal/               NormalScreen + HomeView + MenuView + Sample1View + Sample2View
│   └── Closing/              ClosingScreen + ClosingView
│
├── Constants/   URI: Constants  (依存なし)
│   ├── ScreenId.qml ViewId.qml NavDirection.qml ViewLifecycle.qml VirtualKey.qml VirtualEvent.qml
│   └── CMakeLists.txt
│
└── Mediator/    URI: Mediator   (import Constants)
    ├── Mediator.qml TransitionManager.qml KeyDispatcher.qml Logger.qml  ← 制御 singleton
    ├── ScreenBase.qml ViewBase.qml                                       ← 派生元 base
    └── CMakeLists.txt
```

**サブモジュール分割の判断軸**:

「ナビゲーション制御として、別のアプリでも再利用しうるか」を基準にしている。Constants の enum、Mediator の orchestration singleton、ScreenBase / ViewBase はすべて制御側で、別 POC や別アプリへの移植性がある。一方、具体 Screen/View (= 画面そのもの) は本 POC 固有なのでサブモジュール化せず、メインモジュール (URI `QulLoaderNavigation`) の Screens/ 配下のフォルダツリーに置く。

| グループ | 配置 | URI | 理由 |
| --- | --- | --- | --- |
| 定数 + 解決 helper | `Constants/` (submodule) | `Constants` | 値とその nameOf/fileOf 変換だけ。完全に再利用可 |
| 制御 singleton + base | `Mediator/` (submodule) | `Mediator` | ナビゲーション制御本体 + 派生用骨格。アプリ固有部分を含まない |
| 具体Screen/View | `Screens/<Screen>/` (main module 配下) | `QulLoaderNavigation` | 本 POC 固有の画面。サブモジュール化する動機が薄い |

**Screens/ 配下のサブフォルダ命名** は screen 単位 (Opening / Normal / Closing)。1 つの screen に属する screen QML と view QML を 1 フォルダにまとめる。これで新 sample 追加時の編集範囲が 1 フォルダ + Constants/ の enum 追加 + ルート CMake の QML_FILES 1 行追加に局所化される。

**メインモジュール内のサブフォルダと QML 型登録**: `qt_add_qml_module(URI QulLoaderNavigation)` で `Screens/Opening/OpeningScreen.qml` のように subpath 付きで `QML_FILES` に列挙すると、QML 型名は `OpeningScreen` のままモジュール `QulLoaderNavigation` に登録される (サブ URI は作られない)。qrc 配置にはサブフォルダパスが現れる (例: `qrc:/qt/qml/QulLoaderNavigation/Screens/Opening/OpeningScreen.qml`)。

**ID → qrc URL の解決は DI** で行う (重要):

Constants の `ScreenId` / `ViewId` enum は「値」と「デバッグ用名前」だけを持ち、qrc URL は知らない。URL 知識を Constants に置くと「Constants → メインモジュール qrc 構造」という参照になり、宣言した一方向依存 (`Constants ← Mediator ← Main`) と矛盾するため。

URL マップ singleton `ScreenRegistry` (メインモジュール所属) を分離し、`Main.qml` の `Component.onCompleted` で kickoff `switchView` より前に `TransitionManager.screenRegistry = ScreenRegistry` と注入する。`TransitionManager.startTransition` は `screenRegistry.viewUrlOf(viewId)` / `screenUrlOf(screenId)` を経由して URL を取得する。

```qml
// Screens/ScreenRegistry.qml (メインモジュール singleton)
pragma Singleton
import QtQml
import Constants

QtObject {
    function screenUrlOf(screenId) {
        switch (screenId) {
            case ScreenId.Opening: return "qrc:/qt/qml/QulLoaderNavigation/Screens/Opening/OpeningScreen.qml"
            // ...
        }
    }
    function viewUrlOf(viewId) { /* 同様 */ }
}

// Main.qml 抜粋
Component.onCompleted: {
    TransitionManager.screenRegistry = ScreenRegistry   // 注入。順序: 注入 → navigate
    Mediator.switchView(ViewId.OpeningOpening, NavDirection.Next)
}

// Mediator/TransitionManager.qml 抜粋
property var screenRegistry: null
function startTransition(toViewId, direction) {
    if (!screenRegistry) { /* warn + return */ }
    var targetScreen = screenRegistry.screenUrlOf(ViewId.screenOf(toViewId))
    var targetView  = screenRegistry.viewUrlOf(toViewId)
    // ...
}
```

これにより、画面ファイルの配置を変えたとき更新が必要なのは `ScreenRegistry.qml` (URL マップ) と `Constants/ScreenId.qml` / `ViewId.qml` の enum 追加だけ。Mediator 側は無変更。

**3 つに分けた基準**:

| モジュール | 中身 | 役割 |
| --- | --- | --- |
| **Constants** | enum singleton 6 個 (ScreenId / ViewId / NavDirection / ViewLifecycle / VirtualKey / VirtualEvent) + ファイル名/表示名 helper | データ層。純粋に値とその変換だけ。他に依存しない |
| **Mediator** | 振る舞いを持つ singleton 4 個 (Mediator / TransitionManager / KeyDispatcher / Logger) | アプリ全体の状態とオーケストレーション。Constants の enum を使う |
| **Screens** | ScreenBase / ViewBase + 3 Screen + 6 View | 画面要素。Constants と Mediator の両方を使う |

**フラット URI を採用** (`import Constants` で参照可) する。`QulLoaderNavigation.Constants` のような名前空間付きにすると Qt 公式モジュールに倣った形になるが、POC としては冗長。再利用可能なライブラリ化を目指す段階で `<vendor>.<module>` への rename を検討する。

**Loader.source に絶対 qrc URL を返す約束**:

`ScreenRegistry.screenUrlOf()` / `viewUrlOf()` は `"qrc:/qt/qml/QulLoaderNavigation/Screens/Normal/HomeView.qml"` のような絶対 URL を返す。これは Loader.source の URL 解決が「呼び元 QML ファイルの URL に対して相対」のため、呼び元が `Main.qml` (ルート) のときと `ScreenBase.qml` (Mediator/ 配下) のときで解決基点が違うから。Screens/ の qrc パスを直接書く絶対 URL なら呼び元の位置に依存しない。デフォルト `RESOURCE_PREFIX="/qt/qml"` 前提なので、変更する場合は `ScreenRegistry` だけ追従させればよい。

**CMake 上のリンク順** (循環なし):

```cmake
# ルート CMakeLists.txt 抜粋
add_subdirectory(Constants)   # 依存なし、最初
add_subdirectory(Mediator)    # Constants に依存 (ScreenBase/ViewBase もここ)

qt_add_qml_module(appQulLoaderNavigation
    URI QulLoaderNavigation
    QML_FILES
        Main.qml
        Screens/Opening/OpeningScreen.qml  Screens/Opening/OpeningView.qml
        Screens/Normal/NormalScreen.qml    Screens/Normal/HomeView.qml
        Screens/Normal/MenuView.qml       Screens/Normal/Sample1View.qml
        Screens/Normal/Sample2View.qml
        Screens/Closing/ClosingScreen.qml  Screens/Closing/ClosingView.qml
    IMPORTS Constants Mediator
)
target_link_libraries(appQulLoaderNavigation PRIVATE
    Qt6::Quick
    Constantsplugin Mediatorplugin   # static plugin を link
)
```

`qt_add_qml_module(... STATIC)` で作られる static plugin (`<URI>plugin`) を実行ファイルにリンクすると、Qt 側が起動時に各モジュールを QML エンジンへ自動登録する。

## 4. 本 POC のScreen/View一覧

本 POC で扱うScreen/Viewは下表のとおり。View ID は表示名の他に **bit-packed 整数** (§5-2) を割り当てる。

| Screen   | View   | 表示 ID           | 整数 ID (`(screenId<<8)\|local`) | 担当 QML | 役割 |
| ---     | ---      | ---               | ---                          | ---            | --- |
| opening | opening  | `opening/opening` | `0x0100`                     | OpeningView.qml | 起動時のスプラッシュ。アニメ完了で自動 `normal/home` へ |
| normal  | home     | `normal/home`     | `0x0200`                     | HomeView.qml    | アプリのホーム。`normal/menu` 起動と `closing/closing` への終了遷移 |
| normal  | menu     | `normal/menu`     | `0x0201`                     | MenuView.qml    | 3 ボタンメニュー (Sample 1 / Sample 2A / Sample 2B)、カーソル選択 |
| normal  | sample1  | `normal/sample1`  | `0x0202`                     | Sample1View.qml | サンプルメニュー①。BACK で `normal/menu` |
| normal  | sample2a | `normal/sample2a` | `0x0203`                     | **Sample2View.qml** | サンプルメニュー②-A。**同一 QML 多重 ID** の例 |
| normal  | sample2b | `normal/sample2b` | `0x0204`                     | **Sample2View.qml** | サンプルメニュー②-B。Sample2View が a/b 両対応 (§9-10 参照) |
| closing | closing  | `closing/closing` | `0x0300`                     | ClosingView.qml | クロージング。自然完了で `Qt.quit()`、BACK/HOME で中断 |

**注 1**: 整数 ID は `((screenId << 8) | localId)`。screen ID は `ScreenId.Opening=1`, `ScreenId.Normal=2`, `ScreenId.Closing=3` (0 は未指定 sentinel)。

**注 2**: `normal/sample2a` と `normal/sample2b` は **同じ Sample2View.qml ファイル** をロードし、`Mediator.pendingViewId` から自分の `thisViewId` を動的に取得して動作を分岐する (§9-10 ViewBase の `thisViewId` 自己取得機構)。継承で派生 view を増やすのではなく内部変数 (`isVariantA` / `isVariantB`) で振る舞いを変える方針。

**Screen共通 UI は持たない方針**とする。各Screen QML は内部に固定背景・ヘッダ等の共通要素を持たず、Screen内 view 切替時にScreen側状態を保持する必要はない。Screenという階層は「入力吸収（§8-6）と Loader 切替の境界」としてのみ機能する。

### 4-1. 遷移グラフ

遷移先の決定は **各 view の責務**（§5-3）。`ScreenId` / `ViewId` enum singleton は「ID → ファイル」マップに徹し、view 自身が `Mediator.switchView(targetId, direction)` を呼ぶ。下図は想定される遷移可能性の概念図（具体的なトリガーキーは実装段階で決定）。

```
opening/opening  ──アニメ完了──▶  normal/home
normal/home      ──ENTER─────▶  closing/closing       // 終了操作
normal/home      ──MENU──────▶  normal/menu           // NormalScreen 吸収
normal/menu      ──ENTER(cur=0)▶ normal/sample1
normal/menu      ──ENTER(cur=1)▶ normal/sample2a       ┐
normal/menu      ──ENTER(cur=2)▶ normal/sample2b       ┘ (同じ Sample2View.qml)
normal/sample1   ──BACK──────▶  normal/menu
normal/sample2a  ──BACK──────▶  normal/menu (cursor=1 復元)
normal/sample2b  ──BACK──────▶  normal/menu (cursor=2 復元)
normal/menu      ──BACK──────▶  normal/home
normal/*         ──HOME──────▶  normal/home           // NormalScreen 吸収
closing/closing  ──アニメ完了──▶  Qt.quit()
closing/closing  ──BACK/HOME─▶  normal/home          // 中断 (§10-2)
```

各 view は必要に応じて `Mediator.previousViewId` / `Mediator.history` を参照し、戻り先のカーソル位置等を決定する（§6-2）。MenuView の cursor 復元 (sample2a/sample2b それぞれに対応) はこの仕組みの実例。

## 5. View ID とナビゲーションテーブル

### 5-1. ID 命名規則と表現形式

View ID は **bit-packed 整数**で表現する。`((screenId << 8) | localId)` の 16bit 値。

- 上位 8bit: **screenId** — `ScreenId.Opening=1`, `ScreenId.Normal=2`, `ScreenId.Closing=3` (0 は未指定 sentinel)
- 下位 8bit: screen 内 view 番号 (0 から連番)
- 全体として 1 Screenあたり 256 view まで、合計 65536 view ID 表現可能

整数化のメリット:
- `===` 比較が 1 命令で済む (文字列ハッシュ・比較不要)
- メモリ効率良い (string は heap 確保される可能性)
- QUL の JS subset でも安定動作
- screen 抽出は `viewId >> 8` で 1 命令

定数定義は QUL 2.9 の QML enum 構文を使い、`ScreenId.qml` / `ViewId.qml` という enum 専用の singleton ファイルに置く。アクセスは `<Type>.<value>` の 2 段:

```qml
property int t: ViewId.NormalSample2a  // 0x0203
property int s: ScreenId.Normal        // 2
```

ログや表示用の文字列名 (`"normal/sample2a"` 等) は `ViewId.nameOf(viewId)` ヘルパで取得。表示は `screen/view` 形式に揃え、単一Viewしか持たないScreen（`opening` / `closing`）も冗長を許容して同形式に統一する（可読性優先）。

### 5-2. ScreenId / ViewId enum singleton と ScreenRegistry

整数 ID の **定数定義** は、Constants サブモジュールの `ScreenId.qml` / `ViewId.qml` に **enum 専用 singleton** として置く。`<Type>.<value>` の 2 段アクセス (QUL 2.9 QML enum 構文)。

`<TypeName>` と `<EnumName>` を同じ名前にした理由は QUL ドキュメントの例 (`DeviceUnits` 等) に倣ったから。`Loader.Ready` のような Qt 公式の慣習と一貫した書き味になる。`readonly property int` の constants 並べと比べて、QUL の標準的な enum 構文に準拠する利点が大きい。

**`Constants/ScreenId.qml`**:

```qml
pragma Singleton
import QtQml

QtObject {
    enum ScreenId {
        Opening = 1,
        Normal  = 2,
        Closing = 3
    }

    function nameOf(screenId) { /* "opening" / "normal" / "closing" を返す */ }
}
```

**`Constants/ViewId.qml`**:

```qml
pragma Singleton
import QtQml

QtObject {
    // QUL の enum 値は正の数値リテラルが要求されるため hex リテラル直書き
    // (コメントで分解形 ((screenId<<8)|local) を併記)
    enum ViewId {
        OpeningOpening = 0x0100,  // (Opening << 8) | 0
        NormalHome     = 0x0200,  // (Normal  << 8) | 0
        NormalMenu     = 0x0201,
        NormalSample1  = 0x0202,
        NormalSample2a = 0x0203,
        NormalSample2b = 0x0204,  // ★ 同一 QML 多重 ID
        ClosingClosing = 0x0300
    }

    // ---- ID から screen 抽出 (= ScreenId.* と同じ値が返る) ----
    function screenOf(viewId) {
        return (viewId >> 8) & 0xFF
    }

    function nameOf(viewId) { /* "screen/view" 形式の文字列を返す */ }
}
```

Constants は **qrc URL を一切持たない**。値とそのデバッグ用文字列名だけを管理する。URL マップを Constants に置くと「Constants → メインモジュールの qrc 構造」という参照が発生して、宣言した依存方向 (`Constants ← Mediator ← Main`) と矛盾するため。

#### 5-2-1. ID → qrc URL マップ: `ScreenRegistry` (メインモジュール所属)

URL 解決は **メインモジュール側** の `Screens/ScreenRegistry.qml` (singleton) に集約する。これにより Constants/Mediator は qrc 配置を知らずに済む。

```qml
// Screens/ScreenRegistry.qml (URI QulLoaderNavigation)
pragma Singleton
import QtQml
import Constants

QtObject {
    function screenUrlOf(screenId) {
        switch (screenId) {
            case ScreenId.Opening: return "qrc:/qt/qml/QulLoaderNavigation/Screens/Opening/OpeningScreen.qml"
            case ScreenId.Normal:  return "qrc:/qt/qml/QulLoaderNavigation/Screens/Normal/NormalScreen.qml"
            case ScreenId.Closing: return "qrc:/qt/qml/QulLoaderNavigation/Screens/Closing/ClosingScreen.qml"
        }
        return ""
    }
    function viewUrlOf(viewId) {
        switch (viewId) {
            case ViewId.OpeningOpening: return "qrc:/qt/qml/QulLoaderNavigation/Screens/Opening/OpeningView.qml"
            case ViewId.NormalHome:     return "qrc:/qt/qml/QulLoaderNavigation/Screens/Normal/HomeView.qml"
            // ... 残りも同様
            case ViewId.NormalSample2a: return "qrc:/qt/qml/QulLoaderNavigation/Screens/Normal/Sample2View.qml"  // 同一 QML
            case ViewId.NormalSample2b: return "qrc:/qt/qml/QulLoaderNavigation/Screens/Normal/Sample2View.qml"  // 同一 QML
            case ViewId.ClosingClosing: return "qrc:/qt/qml/QulLoaderNavigation/Screens/Closing/ClosingView.qml"
        }
        return ""
    }
}
```

呼び出し側 (`Mediator/TransitionManager` の中):

```qml
property var screenRegistry: null   // Main.qml が起動時に注入

function startTransition(toViewId, direction) {
    if (!screenRegistry) { /* warn + return */ }
    var screenId   = ViewId.screenOf(toViewId)
    var screenFile = screenRegistry.screenUrlOf(screenId)
    var viewFile  = screenRegistry.viewUrlOf(toViewId)
    var logName   = ViewId.nameOf(toViewId)
    // ...
}
```

`Main.qml` 側で起動時に注入:

```qml
// Main.qml の Component.onCompleted
TransitionManager.screenRegistry = ScreenRegistry   // 注入を先に
Mediator.switchView(ViewId.OpeningOpening, NavDirection.Next)
```

順序依存に注意: 注入 → navigate。逆だと `screenRegistry === null` で startTransition が no-op になる (ガード済み、Logger 警告)。

#### 5-2-2. 同一 QML を複数 ID で再利用するパターン

`ScreenRegistry.viewUrlOf()` が同じファイル URL を複数 ID で返すケース（例: `ViewId.NormalSample2a` と `ViewId.NormalSample2b` が両方とも `Sample2View.qml` を指す）を許容する。この場合、Sample2View 自身は **自分がどちらの ID として呼ばれたかを動的に取得** する必要がある。仕組みは §6-1 の `Mediator.pendingViewId` と §9-10 の `ViewBase.thisViewId` 自己取得を参照。

これにより、見た目はほぼ同じだが ID 分けて履歴/cursor 復元の対象としたい複数の view を、**継承で派生クラスを増やすことなく 1 つの QML で表現** できる。

### 5-3. 遷移先の決定は各 view の責務

`ViewId` / `ScreenId` enum に `next` / `back` を持たせる設計は採用しない。理由:

- 「次にどこへ行くか」は **そのView自身が文脈に応じて決める**もので、テーブルで静的に表現できないケースが多い（例: sample2 の操作結果が成功か失敗かで遷移先が `okView` / `ngView` に分岐する）
- 戻り先も「BACK で必ず直前に戻る」とは限らない（例: okView / ngView から BACK で戻るのは menu であり、直前の sample2 ではない）
- 自由ジャンプ（任意Viewからの直接遷移）も全て同じ仕組みで扱える

このため:

- 遷移 API は `Mediator.switchView(targetId, direction)` のみ（§6-1。`goNext` / `goBack` は提供しない）
- 各 view 自身が「自分はどこへ進めるか／戻れるか」を知っており、対応する仮想キーで `switchView` を直接呼ぶ
- **方向（Next/Back）も view が明示**する。BACK キーで戻る経路の view は `NavDirection.Back` を指定して呼び出す
- 「どこから来たか」を知る必要がある view（例: menu に戻った際にカーソルを sample2 ボタンに戻したい）は `Mediator.previousViewId` / `Mediator.history` を参照する（§6-2）
- 「どちら向きで来たか」を知る必要がある view（例: 初回 Next 入場時のみデータ fetch、Back 入場時は復元）は `TransitionManager.directionOf(thisViewId)` を参照する（§9-4）

**設計上のトレードオフ**: ナビゲーショングラフを一覧する手段は失われるが、view 単位の柔軟性が高まる。POC ではグラフ可視化はこのドキュメントの §4-1 で代替する。

## 6. Mediator API と履歴トラッキング

### 6-1. Mediator が公開するインターフェース

```qml
// Mediator/Mediator.qml (singleton)
pragma Singleton
import QtQuick
import Constants            // ViewId, NavDirection を使う

QtObject {
    // 現在のView ID (整数、ViewId enum)。遷移開始時点で targetId に更新される
    property int currentViewId:  0

    // 直前のView ID (戻り先のカーソル位置復元等に使う)
    property int previousViewId: 0

    // 履歴 (int 配列、古い順、末尾が previousViewId と一致)
    property var history: []

    // Closing アニメ中断中フラグ (§10-2 で使用)
    property bool closingAborted: false

    // ★ 次にロードされる view の ID (§9-10: ViewBase が自己取得用に参照)
    // switchView の冒頭で **先行公開** する。同一 QML を複数 ID で再利用する
    // view (例: Sample2View が sample2a/sample2b 両対応) が自分の thisViewId を
    // 動的に決めるためのスナップショット元。
    property int pendingViewId: 0

    // ---- 遷移 API ----
    // ID (int) と direction を指定して遷移する (これが唯一の遷移 API)
    // direction は NavDirection.Next / Back (§9-3)
    function switchView(viewId, direction) {
        // direction 省略時のデフォルトは NavDirection.Next
        // 1. pendingViewId = viewId を先行公開 (ViewBase の自己取得用)
        // 2. 旧 currentViewId を history に push、previousViewId に保存
        // 3. currentViewId = viewId
        // 4. TransitionManager.startTransition(viewId, direction) を呼ぶ
        // 5. closing/closing への遷移なら history をクリア、closingAborted = false
    }
}
```

`goNext()` / `goBack()` は **提供しない**。戻り先・進み先の判断は各 view の責務（§5-3）。  
**方向（Next/Back）**も view が明示する。BACK キーで戻る経路なら view 自身が `NavDirection.Back` を指定して `switchView` を呼ぶ。これにより遷移先 view は `directionOf(thisViewId)` で「どちら向きで来たか」を知れる（§9-4）。

### 6-2. 履歴トラッキングの方針

- `switchView` 呼び出し時、旧 `currentViewId` を `history` の末尾に push
- 同時に `previousViewId` を旧 `currentViewId` に更新
- `history` は view から read-only に参照可能で、複数前まで遡って戻り先カーソル位置を判定する用途で使う
- `closing/closing` へ遷移するタイミングで `history` をクリア（中断時の戻り先は固定で `normal/home` なので履歴不要）
- 履歴はView ID の int 値のみ。Screen情報は `ViewId.screenOf(viewId)` で復元できる

**view 側の利用例**:

```qml
// MenuView.qml (一部、戻り時のカーソル位置復元)
// ※ viewId は整数 (ViewId enum)、ViewBase の onEntering フックで処理
function onEntering() {
    var prev = Mediator.previousViewId
    if (prev === ViewId.NormalSample2b) {
        cursorIndex = 2
    } else if (prev === ViewId.NormalSample2a) {
        cursorIndex = 1
    } else {
        cursorIndex = 0   // Sample 1 (デフォルト)
    }
}
```

```qml
// OkView.qml / NgView.qml (例: BACK で menu に戻る、direction = Back)
// ViewBase 派生 (§9-10) — onViewKey フックを override するだけ
ViewBase {
    thisViewId: ViewId.NormalOkView  // 仮の ID。ViewId enum に追加が前提
    displayName: "OK"
    function onViewKey(vk, ve) {
        if (vk === VirtualKey.Back && ve === VirtualEvent.Click) {
            Mediator.switchView(ViewId.NormalMenu,
                                     NavDirection.Back)
        }
    }
}
```

### 6-3. Screen切替とView解決

- 実際の Loader スロット切替・ライフサイクル通知は **TransitionManager**（§9）に委譲する
- Mediator は「どこへどの向きで遷移したいか」を判断し、`TransitionManager.startTransition(viewId, direction)` を呼ぶだけ
- `Mediator.currentViewId` は遷移開始時点で targetId に更新する（新コンテンツの初期 binding を解決するため）
- TransitionManager が旧スロット解放と新スロットロード、各 view への lifecycle 通知、両完了の待ち合わせを担い、完了 signal を Mediator に返す

## 7. 遷移フロー

### 7-1. 通常の遷移 (View 主導ライフサイクル)

遷移 API は `Mediator.switchView(targetId, direction)` のみ。実際の Enter / Leave 処理は各 view が担当する（詳細は §9）。

1. 操作（仮想キーまたは view 内部の自己発火）→ `Mediator.switchView(targetId, direction)`
2. Mediator は `history` に旧 `currentViewId` を push、`previousViewId` を更新
3. Mediator は `currentViewId` を **遷移開始時点で targetId に更新**する（新コンテンツの初期 binding を解決するため）
4. Mediator → `TransitionManager.startTransition(targetId, direction)`
5. TransitionManager は `ViewId.screenOf` で screen ID を抽出し、注入済みの `screenRegistry.screenUrlOf()` で URL を解決。必要なら新 screen QML を Screen スロット entering にロード
6. TransitionManager は対応する View スロット (`viewSlotA/B`) の lifecycle / direction / partner を設定 → `KeyDispatcher.enabled = false`、`state = InProgress`
7. 新旧 view が自身の `myLifecycle` 変化を検知して **Enter / Leave 処理を開始**
8. 両 view が `reportEnterComplete` / `reportLeaveComplete` を呼ぶ
9. TransitionManager がスロット swap、旧スロットを `active = false` で解放
10. `state = Idle`、`KeyDispatcher.enabled = true`、`transitionFinished(finalViewId)` 発火

opening / closing も同じフローに乗る。違いは「Enter / Leave 処理の中身」だけで、特殊扱いは存在しない。詳細パターンは §10 を参照。

### 7-2. 起動と終了の流れ

- **起動**: アプリ初期化で `Mediator.currentViewId = "opening/opening"` をセットし、初回 transition を起動する。Leave 対象 view が存在しないため、TransitionManager は Enter 単独モードで動作（detail: §9-3）
- **opening の自己発火**: OpeningView は Enter 完了（演出アニメ完了）と同時に `Mediator.switchView("normal/home", Next)` を呼ぶ → 次の transition が起こり、opening は leave される
- **closing の終端**: ClosingView は Enter は即完了し、内部アニメが別途走る。自然完了で `Qt.quit()`
- **closing の中断**: 内部アニメ中（`state = Idle` で `KeyDispatcher.enabled = true`）にユーザ BACK/HOME CLICK が入ると、ClosingScreen が `forceUnloadCurrentView` + `switchView("normal/home", Back)` を呼ぶ。詳細は §10-2 / §10-3

## 8. 仮想キー入力層

実機 MCU の物理ボタンを模すため、PC キーボードの物理キーを「仮想キー」に変換してアプリ内に配送する層を設ける。アプリ側はどの物理キーが押されたかには依存せず、仮想キーだけを扱う。

### 8-1. 物理キー → 仮想キー対応

| 物理キー | 仮想キー | 想定用途 |
| ---     | ---      | --- |
| A       | `PREV`   | 前候補（リスト等のカーソル前移動） |
| S       | `ENTER`  | 決定 |
| D       | `NEXT`   | 次候補（リスト等のカーソル次移動） |
| Z       | `MENU`   | メニュー呼び出し |
| X       | `HOME`   | ホーム画面へ |
| C       | `BACK`   | 戻る |

### 8-2. 仮想イベント

仮想キー 1 つにつき、以下 3 種類の仮想イベントを発火する。

| 仮想イベント | 発火タイミング |
| ---         | --- |
| `PRESS`     | 物理キー押下時（`autoRepeat` は無視） |
| `RELEASE`   | 物理キー開放時 |
| `CLICK`     | 同じキーで PRESS→RELEASE の対が成立したら **RELEASE 直後に追加発火** |

長押し検出（`LONG_PRESS` 等）は POC スコープ外。必要なら後から拡張する。

### 8-3. KeyDispatcher singleton

仮想キー種別・仮想イベントは `int` 定数として singleton に保持する。
配送は **「世代カウンタ」property + 「最終値」property** の組み合わせで表現する（§2-3 の方針）。signal + `Connections{target: KeyDispatcher}` は QUL での使用を避けるため採用しない。

screen 用と view 用で別々の世代カウンタを持つ。「Screenが先に受け取り、必要に応じてViewへ転送する」という配送順序は、Screen 側ハンドラが終わってから Screen が `dispatchToView()` を呼ぶ、というフロー制御で保証する。

```qml
// Mediator/KeyDispatcher.qml (singleton)
pragma Singleton
import QtQuick
import Constants            // VirtualKey, VirtualEvent を使う

QtObject {
    // ---- 仮想キー種別 ----
    readonly property int keyPrev:  0
    readonly property int keyEnter: 1
    readonly property int keyNext:  2
    readonly property int keyMenu:  3
    readonly property int keyHome:  4
    readonly property int keyBack:  5

    // ---- 仮想イベント種別 ----
    readonly property int evPress:   0
    readonly property int evRelease: 1
    readonly property int evClick:   2

    // ---- 入力受付フラグ ----
    // false の間は dispatchToScreen / dispatchToView が no-op になる。
    // TransitionManager が遷移中に false にする (§9-7)。
    property bool enabled: true

    // ---- Screen 向け配送状態 (signal 代替) ----
    // screenEventGen を Screen 側がローカル binding 経由で監視する。
    // 値そのものに意味はなく、変化したら「新規イベントあり」のしるし。
    property int screenEventGen: 0
    property int screenEventVk:  0
    property int screenEventVe:  0

    // ---- View 向け配送状態 ----
    property int viewEventGen: 0
    property int viewEventVk:  0
    property int viewEventVe:  0

    // ---- 配送 API ----
    function dispatchToScreen(vk, ve) {
        if (!enabled) return
        screenEventVk = vk
        screenEventVe = ve
        screenEventGen = screenEventGen + 1   // 受け手の binding を駆動
    }
    function dispatchToView(vk, ve) {
        if (!enabled) return
        viewEventVk = vk
        viewEventVe = ve
        viewEventGen = viewEventGen + 1
    }
}
```

受け手側 (Screen / View) は次の **property-token + on*Changed + ready ガード** パターンで購読する:

```qml
Item {
    property int screenEventGen: KeyDispatcher.screenEventGen   // ローカルにミラー
    property bool ready: false
    Component.onCompleted: ready = true                       // 初期 binding 評価を skip するガード

    onScreenEventGenChanged: {
        if (!ready) return
        var vk = KeyDispatcher.screenEventVk
        var ve = KeyDispatcher.screenEventVe
        // ... 処理
    }
}
```

`ready` フラグは QML の binding 初回評価で `onXxxChanged` が発火するケースに対する保険。
これにより `Connections{target: KeyDispatcher}` を使わずに同等の通知を得られる。

### 8-4. Main.qml の変換層

物理キー → 仮想キーの変換は `Main.qml` の `Keys` ハンドラで行う。CLICK は RELEASE 時に合成する。

```qml
// Main.qml (抜粋)
Window {
    focus: true

    // PRESS 中のキーを記録して CLICK 判定に使う
    property int pressedPhysicalKey: -1

    Keys.onPressed: function(event) {
        if (event.isAutoRepeat) return
        var vk = physicalToVirtual(event.key)
        if (vk < 0) return
        pressedPhysicalKey = event.key
        KeyDispatcher.dispatchToScreen(vk, VirtualEvent.Press)
        event.accepted = true
    }

    Keys.onReleased: function(event) {
        if (event.isAutoRepeat) return
        var vk = physicalToVirtual(event.key)
        if (vk < 0) return
        KeyDispatcher.dispatchToScreen(vk, VirtualEvent.Release)
        // PRESS→RELEASE の対が成立していれば CLICK も発火
        if (pressedPhysicalKey === event.key) {
            KeyDispatcher.dispatchToScreen(vk, VirtualEvent.Click)
            pressedPhysicalKey = -1
        }
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
}
```

### 8-5. 2 段配送（Dispatcher → Screen → View）

配送経路は次のとおり。Screen / View はそれぞれ KeyDispatcher の **世代カウンタプロパティを ローカルにバインド** して購読する（§8-3）。

```
Main.qml (物理キー)
   │ dispatchToScreen(vk, ev)
   │   → KeyDispatcher.screenEventGen を ++
   ▼
各 Screen の onScreenEventGenChanged が発火
   │
   │  (Screen の handleAbsorb() が判断)
   ├── 自分で処理 (吸収) →  そこで完結。Viewへは転送しない
   │
   └── Viewへ転送するキー →  KeyDispatcher.dispatchToView(vk, ev)
                                  │   → KeyDispatcher.viewEventGen を ++
                                  ▼
                              各 View の onViewEventGenChanged が発火 → View 側ハンドラ
```

実装の共通骨格は **ScreenBase / ViewBase** 基底コンポーネントに集約（§9-10）。派生 Screen / View はフックを override するだけでよい。

Screen 側の典型実装（NormalScreen の例）:

```qml
// NormalScreen.qml
ScreenBase {
    thisScreenId: ScreenId.Normal

    // 吸収判断のフックを override。true を返すと view に転送しない。
    function handleAbsorb(vk, ve) {
        if (ve === VirtualEvent.Click) {
            if (vk === VirtualKey.Menu) {
                Mediator.switchView(ViewId.NormalMenu,
                                         NavDirection.Next)
                return true
            }
            if (vk === VirtualKey.Home) {
                Mediator.switchView(ViewId.NormalHome,
                                         NavDirection.Next)
                return true
            }
        }
        return false
    }
}
```

ScreenBase 内部（参考）— KeyDispatcher 監視は `Connections` ではなく property binding + `on*Changed`:

```qml
// ScreenBase.qml (抜粋)
property int screenEventGen: KeyDispatcher.screenEventGen   // ローカル binding
property bool ready: false
Component.onCompleted: ready = true

onScreenEventGenChanged: {
    if (!ready) return
    var vk = KeyDispatcher.screenEventVk
    var ve = KeyDispatcher.screenEventVe
    if (handleAbsorb(vk, ve)) return         // 派生のフック
    KeyDispatcher.dispatchToView(vk, ve)     // 吸収されなければ view へ
}
```

View 側の典型実装:

```qml
// MenuView.qml (例)
ViewBase {
    thisViewId: ViewId.NormalMenu
    displayName: "MENU"

    function onViewKey(vk, ve) {              // ViewBase のフックを override
        if (ve !== VirtualEvent.Click) return
        switch (vk) {
            case VirtualKey.Prev:  /* カーソル前 */ break
            case VirtualKey.Next:  /* カーソル次 */ break
            case VirtualKey.Enter: /* 選択中項目で switchView */ break
            case VirtualKey.Back:
                Mediator.switchView(ViewId.NormalHome,
                                         NavDirection.Back)
                break
        }
    }
}
```

ViewBase 内部も同じ property-token + `on*Changed + ready` パターンで viewEventGen を購読し、`onViewKey(vk, ve)` フックに分配する（§9-10）。

### 8-6. Screen別の吸収ルール

| Screen   | 吸収するキー（イベント） | 吸収後の動作 |
| ---     | --- | --- |
| opening | なし（Enter 中は `KeyDispatcher.enabled=false` で入力到達しない） | — |
| normal  | `MENU` CLICK              | `Mediator.switchView(ViewId.NormalMenu, Next)` |
| normal  | `HOME` CLICK              | `Mediator.switchView(ViewId.NormalHome, Next)` |
| closing | `BACK` CLICK              | §10-3 の中断手順（`closingAborted` → `forceUnloadCurrentView` → `switchView(ViewId.NormalHome, Back)`） |
| closing | `HOME` CLICK              | 同上 |

吸収対象は CLICK のみ。`MENU` / `HOME` / `BACK` の PRESS / RELEASE は吸収せずViewに転送する（ホールド表現等の余地を残す）。

closing 中断が **CLICK で発動できる**のは、ClosingView の Enter が即完了で `state=Idle` に戻るため `KeyDispatcher.enabled=true` に復帰しているから（§10-2）。

## 9. View 主導ライフサイクルと TransitionManager

### 9-1. 設計の根幹: 「フェード」は view の In/Out 処理の placeholder

クロスフェードを「TransitionManager がアニメーションを駆動する」と捉えると、本質を見誤る。実際は:

- view が表示準備に要する時間は、**view にしかわからない**（バックエンドリクエストの応答待ち、入ってきた経路に応じて要否が変わる、即時表示できるケースもある）
- view が退出処理に要する時間も同様（状態保存、リソース解放、即終了など）

POC で行う「ランダム時間のフェード」は、この **不定時間の In/Out 処理を opacity アニメーションに置き換えた placeholder** に過ぎない。本物のアプリでは fade duration は「データが揃うまでの時間」だったり 0 だったりする。

したがって TransitionManager は**アニメを動かさない**。やるのは:

1. view に「Enter / Leave を始めて」と通知する
2. view から「完了した」報告を受ける
3. 両方が完了したらスロット swap して終了

これが view 主導ライフサイクルの本質。

### 9-2. 責務分担

| Singleton | 責務 |
| --- | --- |
| ScreenId / ViewId | 整数 ID の enum 定義 + ファイル名/表示名解決 helper (§5-2)。不変 |
| NavDirection / ViewLifecycle / VirtualKey / VirtualEvent | 列挙値とその nameOf helper のみを持つ enum singleton |
| Mediator         | ナビゲーション意図と履歴。`currentViewId` 更新、direction 判断 |
| TransitionManager| スロット (Screen/View) 管理。view へのライフサイクル通知と完了待ち合わせ。`KeyDispatcher.enabled` 制御 |
| KeyDispatcher    | 仮想キー/イベント配送、`enabled` フラグ |
| View (各 QML)    | **自分の Enter / Leave 処理本体**（POC ではランダム時間 opacity アニメ）。完了報告 |

### 9-3. TransitionManager の公開状態と API

```qml
// Mediator/TransitionManager.qml (singleton)
pragma Singleton
import QtQuick
import Constants            // ScreenId, ViewId, NavDirection, ViewLifecycle を使う

QtObject {
    // direction / lifecycle 列挙値は NavDirection / ViewLifecycle 専用 singleton に分離している (§5-2 と同じ
    // 「QUL enum 構文で QtObject 内に enum 宣言」のパターン)。TransitionManager は import して
    // NavDirection.Next / ViewLifecycle.Idle のように参照する。

    // ---- 進行状態 ----
    property int state: ViewLifecycle.Idle   // Idle / InProgress (= entering or leaving 中)

    // ---- Screen スロット (Main.qml がバインドする) ----
    property string screenSourceA: ""
    property string screenSourceB: ""
    property bool   screenAIsCurrent: true

    // ---- View スロット (各 Screen 内 ViewLoader がバインド) ----
    // スロット別に状態を持つが、view からは ID キー lookup で参照する (9-4)
    property string viewSlotASource: ""
    property string viewSlotBSource: ""
    property int    viewSlotAViewId: 0    // 現在 slot A にロードされる view の ID (0 = unset)
    property int    viewSlotBViewId: 0
    property int    viewSlotALifecycle: ViewLifecycle.Idle
    property int    viewSlotBLifecycle: ViewLifecycle.Idle
    property int    viewSlotADirection:  NavDirection.Next
    property int    viewSlotBDirection:  NavDirection.Next
    property int    viewSlotAPartnerId:  0  // Enter 中なら fromId、Leave 中なら toId
    property int    viewSlotBPartnerId:  0
    property bool   viewAIsCurrent: true

    // ---- View 用 ID キー lookup (view が自身の状態を取得する) ----
    function lifecycleOf(viewId) {
        if (viewSlotAViewId === viewId) return viewSlotALifecycle
        if (viewSlotBViewId === viewId) return viewSlotBLifecycle
        return ViewLifecycle.Idle
    }
    function directionOf(viewId) {
        if (viewSlotAViewId === viewId) return viewSlotADirection
        if (viewSlotBViewId === viewId) return viewSlotBDirection
        return NavDirection.Next
    }
    function partnerOf(viewId) {
        if (viewSlotAViewId === viewId) return viewSlotAPartnerId
        if (viewSlotBViewId === viewId) return viewSlotBPartnerId
        return 0
    }

    // ---- View からの完了報告 ----
    function reportEnterComplete(viewId) { /* manager が待ち合わせを進める */ }
    function reportLeaveComplete(viewId) { /* 同上 */ }

    // ---- Orchestration API (Mediator から呼ぶ) ----
    function startTransition(toViewId, direction) { /* §9-3-1 参照 */ }
    function abortCurrentTransition() { /* 進行中をキャンセル、entering 即確定 */ }

    // Closing 中断専用 API (§10-2)。
    // current の View スロットを active = false で強制アンロード、lifecycle state も Idle にリセット。
    function forceUnloadCurrentView() { /* ... */ }

    // ---- 完了通知 (signal の代わりに property-token 方式 §8-3) ----
    property int    finishedGen: 0        // 1 ずつ増える「世代カウンタ」
    property int    lastFinishedViewId: 0 // 直近完了した遷移先 (ViewId enum 値)
}
```

`KeyDispatcher.enabled` の制御は `state` に連動して TransitionManager 側で行う（§8-3 / §9-7）。`transitionFinished` の代替として **finishedGen + lastFinishedViewId** プロパティを公開。受け手 (例: Main.qml) はローカル binding と `onFinishedGenChanged + ready` ガードで購読する。

#### 9-3-1. startTransition の write 順 (重要)

`startTransition` 内の property write 順序は **意図的に**:

1. 進行状態フラグ群 (`state`, `enterReported`, `leaveReported`, `pendingFinalId`, `isCrossScreen`, `hasLeavingView`) を立てる
2. cross-screen の場合は **entering Screen の source** をセット (Loader が即同期で screen QML をロード)
3. **Entering view の metadata** (viewSlotXViewId / NavDirection / PartnerId / ViewLifecycle) をセット
4. **Leaving view の metadata** (該当 view の binding 経由で leaveAnim を起動)
5. **Entering view の source を最後にセット** (Loader.source 変化で view QML がロードされる時点で metadata が揃っている → ロードされた view の `Component.onCompleted` が正しい myLifecycle/direction/partner を見られる)

この順序を逆にすると、ロード直後の `Component.onCompleted` で `myLifecycle=Idle` という stale 状態が一瞬見え、`reactToLifecycle` が空振りで先行発火する問題が起きる（実装初期に踏んだバグ）。

#### 9-3-2. ランダム duration と 0 ケースの取り扱い

§9-1 の通り「フェード時間」は view の In/Out 処理の placeholder。POC では各 view が独立に duration を抽選する。

**抽選ルール** (ViewBase の標準実装):
- 約 20% の確率で `0` を返す（「データ不要、即時表示できる」ケースの placeholder）
- それ以外は 200〜800 ms の一様乱数

`0` が出た場合は **アニメーションをスキップ + opacity を直接代入 + `Qt.callLater` で完了報告を遅延** する。

```qml
// ViewBase 内部 (抜粋)
function pickDuration() {
    if (Math.random() < 0.2) return 0
    return 200 + Math.floor(Math.random() * 600)
}

function performEnter() {
    var dur = pickDuration()
    if (dur === 0) {
        opacity = 1
        Qt.callLater(reportEnterCompleteDeferred)   // 同期報告だと race / binding loop
    } else {
        enterAnim.duration = dur
        enterAnim.start()                            // 完了は enterAnim.onStopped で報告
    }
}
function reportEnterCompleteDeferred() {
    TransitionManager.reportEnterComplete(thisViewId)
}
```

`Qt.callLater` で遅延する理由は **ClosingView の即完了 Enter と同じ** (§10-2-1 で詳述):

- `reportEnterComplete` を同期で呼ぶと、その内部の `finalizeTransition` が `viewSlotXLifecycle` を書き換える
- そのまま `myLifecycle` binding に逆流して "Binding loop detected" 警告
- さらに startTransition がまだ leaving 側 lifecycle を書く前に finalize が走ると、leaving view が leave アニメ無しで破棄される race
- → 1 イベントループ遅らせて binding 連鎖を切る

### 9-4. View ライフサイクル契約

各 view は以下のプロトコルに従う:

1. 自身のView ID (`thisViewId`) を保持
2. `TransitionManager.lifecycleOf(thisViewId)` をバインドして購読
3. `ViewLifecycle.Entering` への変化を検知したら **Enter 処理開始**（データ取得、アニメ、即完了など何でもよい）
4. Enter 処理完了で `TransitionManager.reportEnterComplete(thisViewId)` を呼ぶ
5. `ViewLifecycle.Leaving` への変化を検知したら **Leave 処理開始**
6. Leave 処理完了で `TransitionManager.reportLeaveComplete(thisViewId)` を呼ぶ
7. 必要なら `directionOf(thisViewId)` と `partnerOf(thisViewId)` を読んで挙動を分岐する

```qml
// View ライフサイクル契約の最小形 (素朴な実装、参考用)
Item {
    id: root
    readonly property int thisViewId: ViewId.NormalMenu
    readonly property int myLifecycle: TransitionManager.lifecycleOf(thisViewId)
    readonly property int myDirection: TransitionManager.directionOf(thisViewId)
    readonly property int myPartnerId: TransitionManager.partnerOf(thisViewId)

    opacity: 0   // 初期は不可視

    NumberAnimation {
        id: enterAnim
        target: root; property: "opacity"
        from: 0; to: 1
        onStopped: TransitionManager.reportEnterComplete(root.thisViewId)
    }
    NumberAnimation {
        id: leaveAnim
        target: root; property: "opacity"
        from: 1; to: 0
        onStopped: TransitionManager.reportLeaveComplete(root.thisViewId)
    }

    onMyLifecycleChanged: {
        switch (myLifecycle) {
            case ViewLifecycle.Entering:
                // 本物アプリならここでバックエンドリクエスト等。
                // POC: ランダム duration の fade-in に置き換え
                enterAnim.duration = 200 + Math.floor(Math.random() * 600)
                enterAnim.start()
                break
            case ViewLifecycle.Leaving:
                leaveAnim.duration = 200 + Math.floor(Math.random() * 600)
                leaveAnim.start()
                break
        }
    }
}
```

実装では上記の骨格を **ViewBase.qml** (§9-10) に括り出してあり、派生 View は `thisViewId`/`displayName`/`backgroundColor` を指定し、必要に応じて `onEntering` / `performEnter` / `onViewKey` 等のフックを override するだけでよい。ViewBase は加えて以下も担う:
- `_reactedInitial` ガード ＋ `Component.onCompleted` 保険で初期 binding 評価を確実に検知
- KeyDispatcher 監視 (§8-3 の property-token + binding パターン)
- 上部の情報 Column 表示（`showInfo: false` で抑制可）
- 20% 0 確率 duration ＋ `Qt.callLater` 遅延 (§9-3-2)

§9-4 のサンプルはあくまで「契約の最小形を示すための説明用」。実コードでは ViewBase 派生型を使う。

### 9-5. シナリオ: 同Screen内 view 遷移 (例: home → menu)

1. ユーザ操作 → `Mediator.switchView(ViewId.NormalMenu, NavDirection.Next)`
2. Mediator: history push、`currentViewId = ViewId.NormalMenu`、`TransitionManager.startTransition(ViewId.NormalMenu, Next)`
3. TransitionManager:
   - Screen同じ (`NormalScreen`) と判断、Screen スロットは触らない
   - View 側で entering スロット（B）を選び、`viewSlotBSource = "MenuView.qml"`, `viewSlotBViewId = ViewId.NormalMenu`, `viewSlotBDirection = Next`, `viewSlotBPartnerId = ViewId.NormalHome`, `viewSlotBLifecycle = ViewLifecycle.Entering`
   - current スロット（A）について `viewSlotALifecycle = ViewLifecycle.Leaving`, `viewSlotADirection = Next`, `viewSlotAPartnerId = ViewId.NormalMenu`
   - `state = InProgress`、`KeyDispatcher.enabled = false`
4. ViewLoader B が `MenuView.qml` をロード → MenuView の `myLifecycle` が `ViewLifecycle.Entering` になる → enter 処理開始
5. ViewLoader A 内の HomeView の `myLifecycle` が `ViewLifecycle.Leaving` になる → leave 処理開始
6. 両者が完了報告 → TransitionManager が swap (`viewAIsCurrent = false`)、旧スロット A を `active = false` でアンロード
7. `state = Idle`、`KeyDispatcher.enabled = true`、`transitionFinished(ViewId.NormalMenu)`

### 9-6. シナリオ: Screen跨ぎ遷移 (例: opening/opening → normal/home)

1. ユーザ操作 or opening 自己発火 → `Mediator.switchView(ViewId.NormalHome, NavDirection.Next)`
2. Mediator: 同上の前処理 → `TransitionManager.startTransition`
3. TransitionManager:
   - Screen異なる (`OpeningScreen` → `NormalScreen`) → 新Screen QML を Screen スロット entering にロード
   - 新Screen QML がロードされたら（Loader.onLoaded）、その内部の ViewLoaderA に `viewSlotASource = "HomeView.qml"` 等を反映（**新Screenの View スロットは A から開始**）
   - 旧Screenの ViewLoader（旧 opening view）には `viewSlotXLifecycle = ViewLifecycle.Leaving` 相当を通知
4. HomeView が enter、OpeningView が leave
5. 両完了 → Screen スロット swap、旧Screen unload
6. 同上

**重要**: cross-screen 時は「新Screenの slot A」と「旧Screenの (元) slot A」が物理的に別の ViewLoader だが、ID キー lookup で view は自身の状態を取得するので、view 側のコードはシナリオの違いを意識しなくてよい。

### 9-7. KeyDispatcher.enabled の制御

- `state` が `InProgress` の間、TransitionManager は `KeyDispatcher.enabled = false` に保つ
- `transitionFinished` 発火直前に `KeyDispatcher.enabled = true` に戻す
- これにより transition 中（view が enter/leave 処理中）の仮想キー入力は dispatcher 段階で破棄される
- **例外**: `forceUnloadCurrentView()` 経由の中断時も `enabled = true` に戻す。Closing 中断後の入力受付に必要

### 9-8. 連続遷移と abort

遷移実行中に内部から次の遷移要求が来た場合（例: opening の onStopped → `switchView(home)` が manager の前回 transition 完了前に呼ばれる）:

- 通常はあり得ない（`KeyDispatcher.enabled = false` で外部入力は遮断、内部呼び出しは setState 順序で制御）
- 万一発生したら `abortCurrentTransition()` を内部で呼び、進行中の状態を強制完了させてから新規 transition を開始
- 「ボタン連打」「タイマー過剰発火」等に対する保険

### 9-9. View スロットと「active screen」の関係 (screen-filtered binding 必須)

View スロット (`viewSlotA/B`) の物理 Loader は **各 Screen QML 内部に存在する**（§3-2、screen-local）。TransitionManager 上の `viewSlot*` プロパティはグローバル singleton だが、それを参照する Loader は screen 内にいる。

cross-screen 遷移中は **旧 Screen と新 Screen が同時に alive** になる。両者の ViewLoader が同じ singleton プロパティ (`viewSlotASource`, `viewSlotAViewId` 等) を見て同じ view を load しようとすると衝突する。

→ 各 Screen の ViewLoader は **「current view の所属 screen が自分かどうか」を `ViewId.screenOf` 経由で確認するフィルタを binding に組み込む** 必要がある (ScreenBase で実装、§9-10):

```qml
// ScreenBase.qml の ViewLoader (抜粋)
Loader {
    id: viewSlotA
    anchors.fill: parent
    source: {
        var vid = TransitionManager.viewSlotAViewId
        if (vid === 0) return ""
        if (ViewId.screenOf(vid) === screen.thisScreenId) {
            return TransitionManager.viewSlotASource
        }
        return ""
    }
    active: source !== ""
}
```

このフィルタにより:
- 同Screen内遷移: 両 ViewLoader が同 Screen 内で動く（screen 一致なのでフィルタ通過、両方 active）
- cross-screen 遷移: 旧 Screen の Loader は **screen 不一致でフィルタ NG → source=""** になり、自分の view (旧 view) を保持し続ける（source 不変だから unload しない）。新 Screen の Loader だけが新 view を load する

これにより 1 つの singleton プロパティに 2 つの Loader がぶら下がっていても衝突せず、各 screen が自分の責任範囲だけ反映する。

### 9-10. 基底コンポーネント (ScreenBase / ViewBase / Logger)

§8-5 / §9-4 / §9-9 で示したパターンは全 Screen / View で共通になるため、基底コンポーネントに括り出してある。

#### ScreenBase.qml — Screen の共通骨格

派生 Screen は `thisScreenId` (`ScreenId.*` の整数値) と、必要なら `handleAbsorb(vk, ve)` を override するだけ。

```qml
// ScreenBase.qml (構造の要約)
Item {
    property int thisScreenId: 0
    function handleAbsorb(vk, ve) { return false }   // 派生で override

    // KeyDispatcher 監視 (Connections 不使用、§8-3 の property-token パターン)
    property int screenEventGen: KeyDispatcher.screenEventGen
    property bool ready: false
    Component.onCompleted: ready = true
    onScreenEventGenChanged: {
        if (!ready) return
        if (handleAbsorb(KeyDispatcher.screenEventVk, KeyDispatcher.screenEventVe)) return
        KeyDispatcher.dispatchToView(KeyDispatcher.screenEventVk,
                                     KeyDispatcher.screenEventVe)
    }

    // ViewSlot A/B — screen フィルタ binding (§9-9)
    Loader { id: viewSlotA; /* source = screen match check */ }
    Loader { id: viewSlotB; /* same */ }
}
```

#### ViewBase.qml — 標準 View の共通骨格

派生 View は `thisViewId` / `displayName` / `backgroundColor` を指定し、必要なら以下のフックを override:

| フック | 用途 |
| --- | --- |
| `onEntering()` / `onLeaving()` | lifecycle 検知時の前処理（例: MenuView の cursor 初期化） |
| `performEnter()` / `performLeave()` | Enter / Leave アニメ起動を **完全置換** (例: Opening の 1.5s ParallelAnimation, Closing の即完了+内部別走) |
| `onViewKey(vk, ve)` | viewEventGen 経由で受け取った仮想キーへの反応 |

標準実装としては、以下を提供する:
- 上部に **情報 Column** (displayName / thisViewId / direction / from / prev / history.length) — `showInfo: false` で抑止可
- 背景 Rectangle
- 標準 `enterAnim` / `leaveAnim` (opacity 0↔1、duration は §9-3-2 のランダム抽選)
- KeyDispatcher.viewEventGen を `property + onViewEventGenChanged + ready` で購読し `onViewKey()` に分配
- lifecycle 変化を購読 (`onMyLifecycleChanged`) し `performEnter` / `performLeave` を起動
- **`thisViewId` の自己取得 (同一 QML 多重 ID 対応)** — 下記サブセクション参照

これにより派生 View はおおむね 20-40 行で書ける（HomeView / Sample1View / Sample2View が好例）。

##### thisViewId の決め方 (2 パターン)

| パターン | 派生 view の書き方 | 適用例 |
| --- | --- | --- |
| **明示指定** | `thisViewId: ViewId.NormalHome` | 単一 ID の view (Home / Menu / Sample1 / Opening / Closing) |
| **自己取得 (未指定)** | `thisViewId` を書かない (デフォルト 0 のまま) | **同一 QML を複数 ID で再利用** する view (Sample2View が sample2a / sample2b 両対応) |

自己取得の流れ:

1. 派生 view (例: `Sample2View.qml`) は `thisViewId` を明示しない → 初期値 0
2. `Mediator.switchView(viewId)` の冒頭で `Mediator.pendingViewId = viewId` が **先行公開** される (§6-1)
3. `TransitionManager.startTransition` → Loader.source 変更 → Sample2View 構築
4. ViewBase の `Component.onCompleted` で `thisViewId === 0` を検知 → `Mediator.pendingViewId` からスナップショット
5. 以降は自分の ID で lifecycle/direction/partner を解決し、内部変数 (`isVariantA`/`isVariantB` 等) で挙動分岐

```qml
// ViewBase.qml の onCompleted (要点)
Component.onCompleted: {
    if (root.thisViewId === 0) {
        root.thisViewId = Mediator.pendingViewId   // ★ 自己取得
    }
    if (!reactedInitial) reactToLifecycle()
    readyForKeys = true
}
```

```qml
// Sample2View.qml の派生 (thisViewId 明示しない)
ViewBase {
    // thisViewId は ViewBase が Mediator.pendingViewId から動的取得
    readonly property bool isVariantA: thisViewId === ViewId.NormalSample2a
    readonly property bool isVariantB: thisViewId === ViewId.NormalSample2b

    displayName: isVariantA ? "SAMPLE 2A" : "SAMPLE 2B"
    backgroundColor: isVariantA ? "#6a1b9a" : "#283593"
    // ...
}
```

これにより、見た目や挙動がほぼ同じだが履歴/カーソル復元の対象として別 ID にしたい複数 view を、**継承で派生クラスを増やすことなく 1 つの QML で表現** できる。

`Mediator.pendingViewId` の衝突可能性: 同時に複数 view がロード中になることはない（進行中 transition の entering view は常に 1 つ）ため、衝突は起きない。

#### Logger.qml — 統一ログ singleton

全 singleton / Screen / View / Main がフローを `console.log` するための共通フォーマット singleton。`[HH:MM:SS.mmm] Component.fn(args) | params` 形式。enum 値の人間可読化は各 enum singleton の nameOf に分離した (`VirtualKey.nameOf(vk)`, `VirtualEvent.nameOf(ev)`, `NavDirection.nameOf(d)`, `ViewLifecycle.nameOf(lc)`, `ScreenId.nameOf(sid)`, `ViewId.nameOf(vid)`)。Logger 本体は時刻付き整形と `console.log` のみを担う。

QUL 移植性メモ: `new Date()` を使う部分は **デスクトップ Qt 6 でのフロー検証用** 前提。本物の MCU 移植時は時計取得 API か、単純なフレームカウンタに置き換える。

### 9-11. `Component.onCompleted` と `Loader.status` の使い分け

view ロード完了の検知手段として QML には 2 つあるが、**全く別の概念**として整理する:

| 観点 | `Component.onCompleted` | `Loader.status` |
| --- | --- | --- |
| 視点 | ロード**される**側 (View 自身) | ロード**する**側 (Loader = screen) |
| 値 | signal handler (1 回発火) | enum property (`Null`/`Loading`/`Ready`/`Error`) |
| 発火順 | View 自身の binding 評価直後（先） | その後で `Loader.status = Ready` (後) |
| 用途 | View が**自分で**初期化処理を行う | Screen が**外から**子のロード進捗を知る |

#### QUL 上の挙動

QUL の Loader は同期ロード（async 非サポート）。流れは以下:

```
Loader.source = "Foo.qml" を代入
  ↓ (同期)
Loader.status = Loading
  ↓ Foo インスタンス生成 + binding 評価
  ↓ Foo の Component.onCompleted 発火    ★ ここで自分自身を初期化 ★
  ↓
Loader.status = Ready (onStatusChanged 発火)
  ↓ 制御が呼び出し元に戻る
```

#### 本 POC が `Component.onCompleted` を採用する理由

ViewBase で行うこと:
- `thisViewId` を `Mediator.pendingViewId` から自己取得 (同一 QML 多重 ID 対応)
- `reactToLifecycle()` 保険呼び出し (初期 binding 評価で onMyLifecycleChanged が発火しなかった場合)
- `readyForKeys = true` 設定 (viewEventGen 受信ガード解除)

これらは全て **view 自身の自己初期化処理**なので、当事者視点の `Component.onCompleted` が自然。

`Loader.status` で同じことをやろうとすると screen 側 (`Loader.onStatusChanged`) から子の view を初期化する必要があるが、**QUL では `Loader.item` 経由のアクセス不可** (§1-1) のため screen → view への直接介入はできない。したがって `Loader.status` は QUL では「子のロード進捗のログを取る」「ロード失敗を catch する」程度の用途に限られる。

#### 使い分け早見表

| やりたいこと | 採用すべき仕組み |
| --- | --- |
| view が自分の初期化を完了させる | `Component.onCompleted` (本 POC で採用) |
| view が singleton から自分の状態を取り込む | `Component.onCompleted` |
| screen が「子 view のロードが終わったか」を観測する | `Loader.onStatusChanged` (status === Ready) |
| screen が「ロード失敗」を catch する | `Loader.onStatusChanged` (status === Error) |
| screen から子 view の関数を呼ぶ | QUL では不可 (§1-1) |
| screen から子 view に初期 property を渡す | `Loader.setSource(url, properties)` (本 POC では不採用) |

#### 補足: 発火順序

同一 Loader の中の Component.onCompleted は **インナー優先**:

```
View の Component.onCompleted
  ↓ (同期)
(view の親に Item があればその Component.onCompleted)
  ↓
Loader.status = Ready → Loader.onStatusChanged 発火
```

つまり ViewBase の `Component.onCompleted` で `readyForKeys = true` した時点では Loader.status はまだ Ready になっていないことがある。ただし「同じ event loop tick 内」なので外部から見れば一瞬の差で、本 POC の挙動には影響しない。

## 10. Opening / Closing: 統一ライフサイクル上での実装パターン

Opening と Closing も §9 の view 主導ライフサイクルに乗せる。「特殊な screen」ではなく、ライフサイクル契約の **2 つの実装パターン**として扱う。

| 観点                       | OpeningView                        | ClosingView                                |
| ---                        | ---                                | ---                                        |
| Enter 完了までの時間       | 長い（演出アニメ完了まで）        | 即時                                       |
| Enter 中の `KeyDispatcher` | `state=InProgress` で無効          | `state=Idle` ですぐ enable に戻る          |
| Enter 完了後の挙動         | 自分で `switchView(home)`     | 内部アニメ起動（lifecycle と無関係）       |
| 入力割り込み               | 不可（スキップ禁止、ユーザ要件）   | 可（内部アニメ中、BACK/HOME で abort）    |
| 終端動作                   | leave → 次 view (home) に交代      | 自然完了 → `Qt.quit()`、中断時は home へ |

### 10-1. Opening: 「長い Enter」パターン

Enter 中に演出アニメを実行し、完了で `reportEnterComplete` する。完了と同時に `switchView("normal/home", Next)` を発火し、自分は leave される側に移る。`performEnter` を override してカスタムアニメを起動するだけ。`performLeave` は ViewBase の標準（ランダム fade-out）をそのまま使う。

```qml
// OpeningView.qml (ViewBase 派生)
ViewBase {
    id: root
    thisViewId: "opening/opening"
    backgroundColor: "#0d47a1"
    showInfo: false                          // 上部の情報 Column は隠して独自演出

    Text { id: openingText; /* 演出 UI */ }

    // ---- カスタム Enter アニメ (1.5s フェード + スケールアップ) ----
    ParallelAnimation {
        id: openingEnterAnim
        NumberAnimation { target: root;        property: "opacity"; from: 0;   to: 1; duration: 1500 }
        NumberAnimation { target: openingText; property: "scale";   from: 0.5; to: 1; duration: 1500; easing.type: Easing.OutBack }
        onStopped: {
            TransitionManager.reportEnterComplete(root.thisViewId)
            // Enter 完了と同時に次へ。新 transition が起きて OpeningView は leave 側に
            Mediator.switchView(ViewId.NormalHome, NavDirection.Next)
        }
    }

    // ViewBase の performEnter を override してカスタムアニメで起動
    function performEnter() {
        openingEnterAnim.start()
    }
    // performLeave は ViewBase default (ランダム fade-out + 自動 reportLeaveComplete) を使う
}
```

- Enter 中は `state=InProgress` のため `KeyDispatcher.enabled=false`。**ユーザによるスキップは不可**（要件通り）
- Enter 完了で `switchView` 発火 → Mediator → TransitionManager が新 transition を開始 → OpeningView は leave、HomeView は enter

### 10-2. Closing: 「即完了 Enter + 内部アニメ別走」パターン

Closing は中断可能性のため、`KeyDispatcher.enabled` が **`true` のままアニメを再生**する必要がある。そこで、Enter は **即座に完了報告**してしまい、内部アニメは lifecycle と切り離して別途走らせる。

これにより:

- `state` が `Idle` に戻る → `KeyDispatcher.enabled = true`
- 内部アニメの間、ユーザは BACK/HOME を押せる
- 中断時は §8-6 / §10-3 の手順で `forceUnloadCurrentView` + `switchView(ViewId.NormalHome, Back)`

```qml
// ClosingView.qml (ViewBase 派生)
ViewBase {
    id: root
    thisViewId: ViewId.ClosingClosing
    backgroundColor: "#37474f"
    showInfo: false

    Text { id: closingText; /* 演出 UI */ }

    // 内部アニメ。lifecycle と独立。3 秒で fade out → Qt.quit
    NumberAnimation {
        id: internalAnim
        target: closingText; property: "opacity"; from: 1; to: 0; duration: 3000
        onStopped: {
            if (!Mediator.closingAborted) {
                Qt.quit()                    // 自然完了
            }
            // 中断時 (closingAborted=true) は Qt.quit を抑止
        }
    }

    // ViewBase の performEnter を override (Closing 専用パターン)
    function performEnter() {
        opacity = 1                              // 即時可視 (ViewBase の opacity:0 を上書き)
        Qt.callLater(reportEnterCompleteDeferred)          // §10-2-1: 同期報告だと race + binding loop
        internalAnim.start()                     // lifecycle 外で独立動作
    }
    function reportEnterCompleteDeferred() {
        TransitionManager.reportEnterComplete(root.thisViewId)
    }
    // performLeave は呼ばれない (Qt.quit で終わる or forceUnload で破棄される)
}
```

#### 10-2-1. なぜ Qt.callLater で reportEnterComplete を遅延するか

`reportEnterComplete` を **同期で** 呼ぶと 2 つの問題が起きる:

1. **startTransition との race**: startTransition は (entering 設定 → leaving 設定 → entering source 設定) の順に走る (§9-3-1)。ClosingView の Enter は entering source 設定で即ロードされて synchronously `performEnter` が走る。その中で同期報告すると、まだ leaving 側 lifecycle が `Leaving` に書かれていない時点で `finalizeTransition` が走ってしまい、leaving view が leaveAnim 無しで破棄される
2. **myLifecycle binding loop**: 同期報告で `finalizeTransition` 内が `viewSlotXLifecycle` を書き換えると、binding 経由で `myLifecycle` が再評価される。Qt がそれを binding loop として検出して警告を出す

→ `Qt.callLater` で **1 イベントループ遅らせて** binding 連鎖を切り、startTransition が完了してから report する。

§9-3-2 のランダム 0 duration のケースも全く同じ理由で `Qt.callLater` を使う。

### 10-3. Closing 中断の手順

ClosingScreen が BACK/HOME CLICK を吸収する側で実行する（§8-6）。**順序が重要**。

```qml
// ClosingScreen.qml (ScreenBase 派生)
ScreenBase {
    thisScreenId: ScreenId.Closing

    function handleAbsorb(vk, ve) {
        if (ve === VirtualEvent.Click
            && (vk === VirtualKey.Back || vk === VirtualKey.Home)) {
            // 順序: フラグ → アンロード → switchView
            Mediator.closingAborted = true                            // 1. 自然完了側を抑止
            TransitionManager.forceUnloadCurrentView()                // 2. ClosingView 破棄
            Mediator.switchView(ViewId.NormalHome,
                                     NavDirection.Back)        // 3. home へ Back 方向
            return true                                               // view に転送しない
        }
        return false
    }
}
```

`Mediator.closingAborted` は `switchView(ViewId.ClosingClosing)` の入口で `false` にリセットされる（§6-1）。

### 10-4. キャンセル安全性の要件

- **書き込み順序**: `closingAborted = true` → `forceUnloadCurrentView()` の順を厳守。逆順だと「アンロードで onStopped 発火 → フラグまだ false → Qt.quit 誤発」の競合
- 自然完了と中断要求の同時発生: フラグを先に立てる規約により CLICK 起点なら必ず抑止される
- `active = false` 時の `onStopped` 発火有無は Qt 6 / Qt for MCUs で差がある可能性 → §11 で実機確認
- `forceUnloadCurrentView()` の責務: current View スロットを `active = false`、対応する `viewSlot*ViewLifecycle = Idle` リセット、`state = Idle`、`KeyDispatcher.enabled = true`
- `forceUnloadCurrentView()` は **Closing 中断専用**の API として位置付け、通常の view 遷移には使わない

### 10-5. パターンの一般化

Opening / Closing 以外の view も、この 2 パターン（または併用）から選んで実装する:

- バックエンドリクエストが完了するまで Enter を待つ view = 「長い Enter」パターン
- 即時表示できる view = 「即完了 Enter」パターン
- 経路に応じて両方使い分ける view = `directionOf` / `partnerOf` を見て分岐

「フェードイン/フェードアウト」は POC でこれらを表現するための最も単純な手段に過ぎず、本物のアプリでは各 view が自身の事情で Enter / Leave 処理の中身と所要時間を決める。

## 11. 検証したいポイント

凡例: `[x]` = POC のデスクトップ Qt 6 ログで確認済 / `[ ]` = 未検証 (実機 QUL 移植時 or 後続課題)

### 11-1. ナビゲーション基盤
- [x] `Loader.item` を一切使わずに opening → home → menu → sample1/2 → closing の全経路が成立するか
- [x] Mediator singleton 経由で「現在View ID」をView側が取得できるか
- [x] `switchView(targetId, direction)` 一本で線形遷移・分岐遷移・自由ジャンプ全てが扱えるか
- [x] `previousViewId` / `history` を参照したカーソル位置復元が成立するか（sample2 → menu 戻りで cursorIndex が 1 に復元、ログ確認済）
- [x] `currentViewId` の即時更新を前提とした binding が transition 中も正しく動くか
- [x] `closing/closing` 遷移時の `history` クリアと `closingAborted = false` リセットが効くか

### 11-2. View 主導ライフサイクル
- [x] 各 view が `lifecycleOf(thisViewId)` の変化を購読でき、Enter / Leave 処理が起動するか
- [x] view からの `reportEnterComplete` / `reportLeaveComplete` で TransitionManager が正しく待ち合わせるか
- [x] 両 view の完了が揃った時点で `transitionFinished`（実装は `finishedGen` 増分）が 1 回だけ発火するか
- [x] direction (`Next` / `Back`) が view 側で `directionOf(thisViewId)` 経由で正しく取得できるか
- [x] `partnerOf(thisViewId)` が Enter なら from、Leave なら to を正しく返すか
- [x] Enter / Leave 処理の duration が大きく非対称でも（例: in 50ms, out 800ms）破綻しないか
- [x] Enter / Leave 処理がランダム duration の opacity アニメであっても、実アプリで「バックエンド待ち」に置き換えられる構造か
- [x] duration=0 ケースで `Qt.callLater` 遅延報告が startTransition との race / binding loop を回避できているか

### 11-3. Loader ペアとスロット管理
- [x] Screen跨ぎで ScreenSlot ペアと screen-local View スロットの両方が適切に管理されるか
- [x] Screen切替時に旧Screenの ViewSlot 状態がリセットされるか（再入時に初期Viewから始まるか）
- [x] 遷移完了後の旧スロット解放（`active = false`）がメモリリーク無く動くか (ログ上は destroyed まで確認、長時間負荷下のリークは未検証)
- [x] cross-screen 遷移時、旧Screen側と新Screen側の ViewLoader が **screen-filtered binding** で衝突なく動くか（§9-9 のフィルタ条件）
- [ ] アニメ進行中に次の遷移要求が来た場合（`abortCurrentTransition` 経由）の挙動が予測どおりか — POC 通常操作では transition 中に次遷移が来ない設計のため未検証

### 11-4. 仮想キー入力層
- [x] 仮想キーの 2 段配送（Dispatcher → Screen → View）が動くか
- [x] CLICK 合成（PRESS→RELEASE 対の成立判定）が autoRepeat やフォーカス遷移と競合しないか
- [ ] Screen切替の途中で物理キーが押されたまま開放されたときの挙動（PRESS と RELEASE の対が壊れないか）— 未検証
- [x] `normal` Screenの MENU/HOME 吸収が、別Screen (`opening` / `closing`) 在席時には作用しないこと
- [x] `state = InProgress` 中の `KeyDispatcher.enabled = false` で実際に入力が破棄され、完了後に復活するか
- [x] `state = Idle` 中の closing 内部アニメ進行中に BACK/HOME が確実に受信できるか
- [x] **Connections{target: singleton, function on...} を使わない property-token + binding パターン** が機能するか (§8-3)

### 11-5. Opening / Closing
- [x] opening の長い Enter 中に入力が無効化され、Enter 完了で次 transition が自然に起動するか
- [x] 初回 transition（Leave 対象なし）で TransitionManager が Enter 単独モードで動作するか
- [x] closing の即完了 Enter で `state` が短時間で Idle に戻り、内部アニメが lifecycle 外で走るか
- [x] closing 内部アニメ中の BACK/HOME 中断で `Qt.quit` がキャンセルされ、`normal/home` に確実に戻れるか
- [x] Closing 中断時の順序（`closingAborted = true` → `forceUnloadCurrentView` → `switchView`）が守られるか
- [ ] **`active = false` で ClosingView 内 NumberAnimation の `onStopped` が発火するかしないか**（実機 QUL での挙動確認が本命）
- [ ] 自然完了と中断要求が同時刻に起きた場合に `Qt.quit` 抑止が確実に動くか — race 再現環境がないため未検証
- [x] `forceUnloadCurrentView()` が Closing 以外で誤用されない設計運用ができるか（API コメントで Closing 専用と明示）

### 11-6. QML / JS 制約と移植性
- [x] `function on<Signal>()` 構文を一切使わず、すべて `on<Signal>:` 古典スタイル or property binding で記述している
- [x] `const` / `let` / arrow function を使わず、`var` と `function` 宣言のみで記述している
- [x] `Connections { target: singleton }` を一切使わず、property-token + binding パターンに統一している
- [x] 命名規則 lowerCamelCase（`_` プレフィックス無し）に統一している
- [ ] 実機 QUL 2.9 / 2.10 等でビルド・動作することの確認 — 未検証 (POC はデスクトップ Qt 6 のみ)

### 11-7. その他
- [ ] `sourceComponent` パターンを部分的に併用した場合の取り回し
- [ ] 長時間稼働でメモリリーク無く動作するか

## 12. 参考

- [Loader QML Type | Qt for MCUs](https://doc.qt.io/QtForMCUs/qml-qtquick-loader.html)
- [Limitations セクション](https://doc.qt.io/QtForMCUs/qml-qtquick-loader.html#limitations)
- [Defining singletons in QML | Qt for MCUs](https://doc.qt.io/QtForMCUs/qtul-qml-singleton.html)

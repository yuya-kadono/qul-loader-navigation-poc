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
| 定数 + 解決 helper | `Constants/` (submodule) | `Constants` | 値とその nameOf/screenUrlOf/viewUrlOf (ScreenRegistry) 変換だけ。完全に再利用可 |
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

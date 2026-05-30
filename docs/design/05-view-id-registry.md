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

ログや表示用の文字列名 (`"Normal/Sample2a"` 等) は `ViewId.nameOf(viewId)` ヘルパで取得。表示は `screen/view` 形式に揃え、単一Viewしか持たないScreen（`opening` / `closing`）も冗長を許容して同形式に統一する（可読性優先）。

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


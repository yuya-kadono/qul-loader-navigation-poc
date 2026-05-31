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

### 2-4. ログ専用の値は live binding にしない

property-token パターン (§2-3) で singleton 状態を購読するとき、その値を
**「機能」で使うのか「ログ表示」でしか読まないのか** を区別する。ログ専用の値に
`readonly property` の live binding を張ると、singleton が関連プロパティを書き換える
たびにマウント中の全インスタンスでバインディング再評価が走る (無駄な fan-out)。
ログのためだけにこの再評価コストを払うのは割に合わず、MCU 移植先では純粋な浪費になる。

方針:

- **機能で参照する値だけ** を live binding (`readonly property` + `on<Property>Changed`)
  で購読する。
- **ログでしか使わない付随値** は binding を持たず、ログ出力の直前に getter 関数
  (`directionOf` / `partnerOf` 等) をその場で呼んでローカル `var` に取る。

実例 (`ViewBase.qml`): 遷移状態の購読を 3 本 → 1 本に削減した。`myLifecycle` は
enter/leave を駆動する「機能」なので live binding のまま残し、`myDirection` /
`myPartnerId` は `reactToLifecycle` のログ生成時にしか読まれないため live binding を
撤去し、ログ時に `TransitionManager.directionOf/partnerOf(thisViewId)` を都度呼ぶ形に
した。これで `startTransition` が slot メタデータ (ID/direction/partner) を書き換える
たびに全 view で起きていた再評価 fan-out が、機能に必要な 1 本分だけになる。

関連する小技 (ログ自体を減らす):

- `enabled` 等のガードは `Logger.log` より **前** に置き、抑制パスでは `nameOf` +
  文字列連結を走らせない (`KeyDispatcher.dispatchToScreen/View`)。
- lifecycle が Idle に戻るときの空振り `on<Property>Changed` は早期 return で握りつぶす
  (`ViewBase.reactToLifecycle` 冒頭の `if (myLifecycle === ViewLifecycle.Idle) return`)。


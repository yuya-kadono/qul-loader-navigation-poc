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


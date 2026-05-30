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


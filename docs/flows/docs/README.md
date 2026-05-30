# flows/ — Signal Flow Animation (技術ドキュメント)

QUL Loader Navigation POC の内部信号フローを可視化する SVG/JS アニメーション。

**使い方を見るには** リポジトリの `flows/はじめに.txt` を開いてください。ここは技術詳細のページです。

## フォルダ構成

```
flows/
├── はじめに.txt        ← 非エンジニアでも分かる使い方説明
├── start_app.bat      ← Windows: これダブルクリックで起動
│
├── app/               ← Web アプリ本体 (普段は触らない)
│   ├── index.html         エントリーポイント (HTML マークアップのみ)
│   ├── style.css          スタイル (ダークテーマ + ステージ + バブル)
│   ├── scenarios.js       データ (ACTORS / SCENARIOS 定義)
│   └── app.js             ロジック (SVG 描画 / アニメエンジン / UI 配線 / heartbeat)
│
├── scripts/           ← 起動・サーバー類
│   ├── start_app.sh       Mac/Linux 用 launcher
│   └── server.py          ローカル HTTP サーバー (../app を配信、heartbeat 受信、自動終了)
│
└── docs/              ← 開発者向け技術ドキュメント
    └── README.md          (このファイル)
```

設計意図: **root には実行物 1 個 (`start_app.bat`) と読むもの 1 個 (`はじめに.txt`) しか置かない**。
非エンジニアが flows フォルダを開いた時に迷わない構造。

## 起動の仕組み

`start_app.bat` (Windows) または `scripts/start_app.sh` (Mac/Linux) は次の処理を行う:

1. `scripts/server.py` を Python で起動
2. `server.py` は自身の親フォルダの `app/` を `os.chdir()` で配信 root に設定 → port 8765 で listen
3. 既定ブラウザを `http://localhost:8765/` で開く
4. ブラウザのタブが閉じると、サーバーの watchdog が heartbeat 切れを検知して自動終了

タブが閉じられても Python プロセスが残らない設計。

## サーバーの heartbeat メカニズム (技術詳細)

`scripts/server.py` は標準の `http.server` を拡張して以下を実装:

1. **`/__ping__`**: ブラウザ (`app/app.js`) が `setInterval(fetch, 3000)` で 3 秒毎に叩く → サーバー側で `last_ping_time` を更新
2. **`/__shutdown__`**: `window.beforeunload` で `navigator.sendBeacon('/__shutdown__', '')` を送信 → サーバーが即時 `os._exit(0)`
3. **watchdog thread**: 2 秒毎に `time.time() - last_ping_time` をチェック、`10` 秒を超えたら自動終了

二段構えなので:
- 正常なタブ閉じ → sendBeacon で即時終了
- ブラウザクラッシュ / 手動ウィンドウ閉じ等 → 10 秒後に watchdog で自動終了

ゾンビ Python プロセスが残らない。

## シナリオ追加の手順

1. `app/scenarios.js` の `ACTORS` に必要なら新アクター追加
2. `SCENARIOS` に新シナリオ entry (`title` / `desc` / `steps`) 追加
3. `app/index.html` の `<select id="scenarioSel">` に `<option>` 1 行追加

→ `app.js` には手を入れずデータ追加だけでシナリオが増やせる構造。

## アニメ画面の操作

- **▶ 再生** / **⏸**: 連続再生・一時停止
- **◀** / **▶|**: 1 step 戻る・進む
- **⟲ リセット**: 最初に戻す
- **速度スライダー** (0.5×〜2.0×): デフォルト 1.0× が読める速度
- **シークバー**: 任意 step へジャンプ (ドラッグで silent jump、ダブルクリックでその step を再生)
- **ログ entry クリック**: その step へジャンプして再生

## 代替起動方法

ローカルサーバーが立てられない環境では `app/index.html` を直接ブラウザで開く方法もある。ただしブラウザのセキュリティ制限で JS/CSS が読み込めない場合がある (Chrome なら警告だけで動くことが多い、Firefox は厳しい)。基本は `start_app.bat` / `scripts/start_app.sh` 推奨。

VSCode の Live Server 拡張等を `app/` で起動するのも可。

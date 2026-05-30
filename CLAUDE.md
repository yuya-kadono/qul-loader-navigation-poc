# Claude エージェント向けメモ

このプロジェクトで作業する Claude エージェントが過去に何度も踏んでいる地雷をまとめておく。
ファイルを編集する前に必ず一読すること。

## ⚠ Edit ツールは日本語が多いファイルを高確率で末尾切断する

このプロジェクトでは Edit ツールが日本語コメント/ラベルを含む箇所を編集した際に、
`old_string` 直後だけでなく **ファイル末尾を巻き込んで数十〜数百行を破壊** する事故を
繰り返し起こしている (確認できているだけで通算 10 回以上)。

典型例:

- `QulLoaderNavigation/Screens/Closing/ClosingView.qml` — 末尾が `"View 破棄時に�"` で
  UTF-8 マルチバイト境界で切断
- `docs/flows/app/scenarios.js` — sample2 シナリオ末尾 + ファイル全体の閉じ `];};`
  が消失 (同一セッション内で 2 回連続発生)
- `QulLoaderNavigation/Main.qml` — 過去に同種の切断 (task #181 参照)
- `QulLoaderNavigation/Mediator/TransitionManager.qml` — 関数末尾の `}` が消えた事例 (task #159)

### 対処方針

1. **日本語コメント・ラベル・desc 文字列を多く含むファイルを編集する時は、最初から
   `mcp__workspace__bash` の Python ヒアドキュメントを使う**こと。Edit ツールは使わない。

   対象ファイルの目安:
   - `docs/flows/app/scenarios.js` (シナリオ説明文が全部日本語)
   - `docs/design.md` / `docs/flows.md` / `README.md`
   - `QulLoaderNavigation/**/*.qml` の日本語コメントブロック付近

2. **ASCII のみの編集なら Edit ツールでも可**。ただし編集後は必ず以下のいずれかで検証:
   - `node --check <file>` (`.js`)
   - Python による UTF-8 デコード + カッコ数チェック
   - `wc -l` で行数が想定通りか
   - 末尾を `tail -c 40 <file> | xxd` で hex 確認

3. **編集後の検証は省略しない**。Edit ツールが成功メッセージを返しても、ファイル末尾が
   消えていることがある。`"file state is current in your context"` と言われても信用せず、
   上記の検証を実施する。

### Python ヒアドキュメントの安全な書き方

bash ヒアドキュメントの中で Python の `'''` (triple quote) を使うとパースエラーになることが
あるので、Python 文字列内では `"""` (double-triple) を使うか、別ファイルに書いて `python3 foo.py`
で実行する。

最も安全なのは「ファイル全体を再生成する」パターン:

```bash
python3 <<'PYEOF'
path = 'docs/foo.js'
text = open(path, 'rb').read().decode('utf-8')
lines = text.split('\n')
# ... 該当行だけ差し替え or 末尾追加 ...
new_text = '\n'.join(lines)
with open(path, 'wb') as f:
    f.write(new_text.encode('utf-8'))

# 検証
import subprocess
r = subprocess.run(['node', '--check', path], capture_output=True, text=True)
print('exit', r.returncode, r.stderr or 'OK')
PYEOF
```

ヒアドキュメント終端は `PYEOF` のように **クォート付き** で。クォート無しの `EOF` だと
`$variable` がシェル展開されて事故る。

新規ファイル作成なら **Write ツールでも可** (差分編集ではなく全体上書きなので Edit よりは安全)。
ただし Write も使った後は必ず行数と UTF-8 整合を検証する。

### ファイル分割という予防策 (もう一つの方針)

切断事故が起きる確率は **ファイルサイズに比例** する傾向がある。そこで実装ファイルは
**早めに分割して 1 ファイルあたりの行数を抑える** ことも対策として進めてきた:

- `docs/flows/app/app.js` (722 行) → `engine.js` (描画) + `playback.js` (制御) + `app.js` (UI 配線) に 3 分割
- `docs/flows/` も monolithic な `flows.html` から `index.html` + `style.css` + `scenarios.js` + `app/` 構造に分割
- `Main.qml` から `DebugOverlay.qml` / `MiniKeyboardOverlay.qml` を独立コンポーネントに切り出し

#### まだ大きいまま残っているもの (将来分割候補)

- `docs/design.md` (~95KB) — §単位で `design/01-architecture.md` `design/09-transition-manager.md`
  `design/10-opening-closing.md` 等に分割すれば、各ファイル数 KB に収まり Edit リスクが大幅減
- `docs/flows/app/scenarios.js` (~27KB) — シナリオごとに `scenarios/startup.js` `scenarios/basic-key.js`
  ... に分割し、`scenarios.js` は集約だけ、という構成にできる

新しいセクションや章をどんどん足す前に、まず分割を検討すること。

## その他のプロジェクト固有メモ

- **Qt for MCUs 互換コード**を書く。`Connections { target: singleton }` は使えない。
  代わりに **property-token パターン** (`property X token: Singleton.x` + `onTokenChanged`) を使う。
- arrow function、`const` / `let`、`function on<Signal>()` 構文も避ける。
  `var` と `on<Signal>:` 古典スタイルで書く。
- enum は **2 段アクセス** (`Type.value`)。3 段 (`Module.Type.value`) は使わない。
- 詳細は `docs/design.md` §2 末尾「コーディング方針: QUL 互換 + Coding Conventions」を参照。
- `tmp/console.log` に実機実行ログが保存されている (デバッグ時に参照可)。

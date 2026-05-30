## 11. 検証したいポイント

凡例: `[x]` = POC のデスクトップ Qt 6 ログで確認済 / `[ ]` = 未検証 (実機 QUL 移植時 or 後続課題)

### 11-1. ナビゲーション基盤
- [x] `Loader.item` を一切使わずに opening → home → menu → sample1/2 → closing の全経路が成立するか
- [x] Mediator singleton 経由で「現在View ID」をView側が取得できるか
- [x] `switchView(targetId, direction)` 一本で線形遷移・分岐遷移・自由ジャンプ全てが扱えるか
- [x] `previousViewId` / `history` を参照したカーソル位置復元が成立するか（sample2 → menu 戻りで cursorIndex が 1 に復元、ログ確認済）
- [x] `currentViewId` の即時更新を前提とした binding が transition 中も正しく動くか
- [x] `Closing/Closing` 遷移時の `history` クリアが効くか（中断時の戻り先は固定で home なので履歴不要）

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
- [x] closing 内部アニメ中の BACK/HOME 中断で `Qt.quit` がキャンセルされ、`Normal/Home` に確実に戻れるか
- [x] Closing 中断時の順序（`closingTimer.stop()` → `Mediator.switchView(NormalHome, Back)`）が守られるか
- [x] 中断ロジックが ClosingView 自身に集約され、Mediator / TransitionManager / ClosingScreen 側に中断専用 API が存在しないか（self-contained 検証）
- [x] 中断時も通常の leave/enter サイクルで HomeView へ遷移し、`Component.onDestruction` まで正しく呼ばれるか（ログ確認済）
- [ ] 自然完了と中断要求が同時刻に起きた場合の挙動 — race 再現環境がないため未検証 (`onViewKey` の同期 stop が先行する設計)

### 11-6. QML / JS 制約と移植性
- [x] `function on<Signal>()` 構文を一切使わず、すべて `on<Signal>:` 古典スタイル or property binding で記述している
- [x] `const` / `let` / arrow function を使わず、`var` と `function` 宣言のみで記述している
- [x] `Connections { target: singleton }` を一切使わず、property-token + binding パターンに統一している
- [x] 命名規則 lowerCamelCase（`_` プレフィックス無し）に統一している
- [ ] 実機 QUL 2.9 / 2.10 等でビルド・動作することの確認 — 未検証 (POC はデスクトップ Qt 6 のみ)

### 11-7. その他
- [ ] `sourceComponent` パターンを部分的に併用した場合の取り回し
- [ ] 長時間稼働でメモリリーク無く動作するか

### 11-8. Chrome レイアウトと配色
- [x] ScreenBase の `viewArea` property を override することで NormalScreen に Header/Footer/AsideL/AsideR + 中央 contentArea (4:3 = 640×480) のレイアウトが組める
- [x] Opening/Closing screen は `viewArea` を override せず default (画面全体) を使う → splash として全画面演出が成立
- [x] 配色階層: Window `#000` > Chrome `#141414` > View `#1e1e1e` > Tile `#2a2a2a` の 3 段 + 各 view の上部 6px accentColor ライン + chrome 境界 1px divider (`#333333`) で「面の分離が一目でわかるダーク UI」が組める
- [x] View identity を背景色ではなく **accentColor の細帯** だけで表現することで、原色のうるさい配色を回避しつつ識別性も維持

### 11-9. View UI パターン
- [x] **タイル式ランチャー** (HomeView / MenuView): `Grid columns:4` + `Repeater { model: iconModel }` で動的にタイル数を増減可能。`iconModel` に entry を 1 行追加して `activateAt()` の switch に case を足すだけで拡張 (`indexOfAction(name)` helper でカーソル復元も action 名ベース)
- [x] **タイル 3 状態**: 非選択 (枠 `#3a3a3a` 1px) / 選択中 (枠 `#e0e0e0` 2px) / 押下中 (枠 `#ffeb3b` 3px)。タイル本体色は全状態で `#2a2a2a` 一律、押下フィードバックは ENTER の Press/Release を `onViewKey` で購読
- [x] **Flickable + 自前 scrollbar** (Sample1View の履歴表示): `contentHeight > height` のときだけ scrollbar 可視、`Behavior on contentY` で 180ms OutCubic な滑らかスクロール、PREV/NEXT click で ±60px scroll、両端 clamp
- [x] **同一 QML 多重 ID + identity 表示** (Sample2View): `thisViewId` が `Mediator.pendingViewId` から auto-resolve され、その値 (`0x203` / `0x204`) を hex で UI 表示することで「同じ QML でも別 identity」を視覚的に確認できる
- [x] **線形ナビゲーション** (Sample2 a↔b): NEXT で右隣、PREV で左隣、境界は no-op (ignored ログのみ)。Mediator.switchView の direction (Next/Back) を渡し方で進行/後退の遷移アニメ方向を制御

### 11-10. POC 専用 Main.qml 拡張機能
- [x] **同時押し検出 (conflict mode)**: 2 つ目のキー押下で conflict 確定 → 先押しキーの Release を pre-emptive dispatch して View の押下色を解放、以後の Press/Release/Click は一切 dispatch しない。全キー release で自動解除
- [x] ミニキーボード overlay で押下キーをライブ表示 (黄=正常 dispatch、赤=conflict 中)、視覚で同時押しが起きたことが確認できる
- [x] **隠しジャンプキー** (1/2/3/4/5): 物理キーを物理→仮想変換層の前で intercept、対応 view へ `Mediator.switchView(target, NavDirection.Next)` で直接遷移。auto-repeat / conflict 完全バイパス、debug overlay 上にヒント表示はしない (隠しの本旨を守る)
- [x] 右上 **debug overlay** (`currentViewId`, `previousViewId`, `pendingViewId`, `history.length`, TM の各 slot 状態, 物理押下キー数 + conflict 状態) のライブ表示で内部状態を逐次目視確認

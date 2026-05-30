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

- **起動**: アプリ初期化で `Mediator.currentViewId = "Opening/Opening"` をセットし、初回 transition を起動する。Leave 対象 view が存在しないため、TransitionManager は Enter 単独モードで動作（detail: §9-3）
- **opening の自己発火**: OpeningView は Enter 完了（演出アニメ完了）と同時に `Mediator.switchView("Normal/Home", Next)` を呼ぶ → 次の transition が起こり、opening は leave される
- **closing の終端**: ClosingView は Enter は即完了し、内部アニメが別途走る。自然完了で `Qt.quit()`
- **closing の中断**: 内部アニメ中（`state = Idle` で `KeyDispatcher.enabled = true`）にユーザ BACK/HOME CLICK が入ると、ClosingView 自身が `onViewKey` で受信して `closingTimer.stop()` + `switchView("Normal/Home", Back)` を呼ぶ（通常の leave/enter サイクルで HomeView に戻る）。詳細は §10-2 / §10-3


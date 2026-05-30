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
- Closing 中断は **通常の `switchView` 経由**で行うため特例は不要。ClosingView の Enter 完了で `state=Idle` に戻り `KeyDispatcher.enabled=true` に復帰した状態のまま内部 Timer が走り、BACK/HOME Click を受け付ける（§10-2 / §10-3）

### 9-8. 連続遷移と abort

遷移実行中に内部から次の遷移要求が来た場合（例: opening の onStopped → `switchView(home)` が manager の前回 transition 完了前に呼ばれる）:

- 通常はあり得ない（`KeyDispatcher.enabled = false` で外部入力は遮断、内部呼び出しは setState 順序で制御）
- 万一発生したら `abortCurrentTransition()` を内部で呼び、進行中の状態を強制完了させてから新規 transition を開始
- 「ボタン連打」「タイマー過剰発火」等に対する保険


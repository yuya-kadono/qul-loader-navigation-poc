### 9-1. 設計の根幹: 「フェード」は view の In/Out 処理の placeholder

クロスフェードを「TransitionManager がアニメーションを駆動する」と捉えると、本質を見誤る。実際は:

- view が表示準備に要する時間は、**view にしかわからない**（バックエンドリクエストの応答待ち、入ってきた経路に応じて要否が変わる、即時表示できるケースもある）
- view が退出処理に要する時間も同様（状態保存、リソース解放、即終了など）

POC で行う「ランダム時間のフェード」は、この **不定時間の In/Out 処理を opacity アニメーションに置き換えた placeholder** に過ぎない。本物のアプリでは fade duration は「データが揃うまでの時間」だったり 0 だったりする。

したがって TransitionManager は**アニメを動かさない**。やるのは:

1. view に「Enter / Leave を始めて」と通知する
2. view から「完了した」報告を受ける
3. 両方が完了したらスロット swap して終了

これが view 主導ライフサイクルの本質。

### 9-2. 責務分担

| Singleton | 責務 |
| --- | --- |
| ScreenId / ViewId | 整数 ID の enum 定義 + ファイル名/表示名解決 helper (§5-2)。不変 |
| NavDirection / ViewLifecycle / VirtualKey / VirtualEvent | 列挙値とその nameOf helper のみを持つ enum singleton |
| Mediator         | ナビゲーション意図と履歴。`currentViewId` 更新、direction 判断 |
| TransitionManager| スロット (Screen/View) 管理。view へのライフサイクル通知と完了待ち合わせ。`KeyDispatcher.enabled` 制御 |
| KeyDispatcher    | 仮想キー/イベント配送、`enabled` フラグ |
| View (各 QML)    | **自分の Enter / Leave 処理本体**（POC ではランダム時間 opacity アニメ）。完了報告 |


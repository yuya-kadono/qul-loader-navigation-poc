## 4. 本 POC のScreen/View一覧

本 POC で扱うScreen/Viewは下表のとおり。View ID は表示名の他に **bit-packed 整数** (§5-2) を割り当てる。

| Screen   | View   | 表示 ID           | 整数 ID (`(screenId<<8)\|local`) | 担当 QML | 役割 |
| ---     | ---      | ---               | ---                          | ---            | --- |
| opening | opening  | `Opening/Opening` | `0x0100`                     | OpeningView.qml | 起動時のスプラッシュ。アニメ完了で自動 `Normal/Home` へ |
| normal  | home     | `Normal/Home`     | `0x0200`                     | HomeView.qml    | **アイコンランチャー** (Menu / Shutdown タイル)、PREV/NEXT で選択、ENTER で起動 |
| normal  | menu     | `Normal/Menu`     | `0x0201`                     | MenuView.qml    | **アイコンランチャー** (Sample 1 / 2A / 2B タイル)、PREV/NEXT で選択 |
| normal  | sample1  | `Normal/Sample1`  | `0x0202`                     | Sample1View.qml | **ナビゲーション履歴表示** (`Mediator.history`) + Flickable scroll (PREV/NEXT で操作可) |
| normal  | sample2a | `Normal/Sample2a` | `0x0203`                     | **Sample2View.qml** | バリアント A。**同一 QML 多重 ID** の例 |
| normal  | sample2b | `Normal/Sample2b` | `0x0204`                     | **Sample2View.qml** | バリアント B。Sample 2A ↔ 2B の線形遷移 (PREV/NEXT、境界 no-op) |
| closing | closing  | `Closing/Closing` | `0x0300`                     | ClosingView.qml | クロージング。自然完了で `Qt.quit()`、BACK/HOME で中断 |

**注 1**: 整数 ID は `((screenId << 8) | localId)`。screen ID は `ScreenId.Opening=1`, `ScreenId.Normal=2`, `ScreenId.Closing=3` (0 は未指定 sentinel)。

**注 2**: `Normal/Sample2a` と `Normal/Sample2b` は **同じ Sample2View.qml ファイル** をロードし、`Mediator.pendingViewId` から自分の `thisViewId` を動的に取得して動作を分岐する (§9-10 ViewBase の `thisViewId` 自己取得機構)。継承で派生 view を増やすのではなく内部変数 (`isVariantA` / `isVariantB`) で振る舞いを変える方針。

**Screen共通 UI は持たない方針**とする。各Screen QML は内部に固定背景・ヘッダ等の共通要素を持たず、Screen内 view 切替時にScreen側状態を保持する必要はない。Screenという階層は「入力吸収（§8-6）と Loader 切替の境界」としてのみ機能する。

### 4-1. 遷移グラフ

遷移先の決定は **各 view の責務**（§5-3）。`ScreenId` / `ViewId` enum singleton は「ID → ファイル」マップに徹し、view 自身が `Mediator.switchView(targetId, direction)` を呼ぶ。下図は想定される遷移可能性の概念図（具体的なトリガーキーは実装段階で決定）。

```
opening/opening  ──アニメ完了──▶  normal/home
normal/home      ──ENTER─────▶  closing/closing       // 終了操作
normal/home      ──MENU──────▶  normal/menu           // NormalScreen 吸収
normal/menu      ──ENTER(cur=0)▶ normal/sample1
normal/menu      ──ENTER(cur=1)▶ normal/sample2a       ┐
normal/menu      ──ENTER(cur=2)▶ normal/sample2b       ┘ (同じ Sample2View.qml)
normal/sample1   ──BACK──────▶  normal/menu
normal/sample2a  ──BACK──────▶  normal/menu (cursor=1 復元)
normal/sample2b  ──BACK──────▶  normal/menu (cursor=2 復元)
normal/menu      ──BACK──────▶  normal/home
normal/*         ──HOME──────▶  normal/home           // NormalScreen 吸収
closing/closing  ──アニメ完了──▶  Qt.quit()
closing/closing  ──BACK/HOME─▶  normal/home          // 中断 (§10-2)
```

各 view は必要に応じて `Mediator.previousViewId` / `Mediator.history` を参照し、戻り先のカーソル位置等を決定する（§6-2）。MenuView の cursor 復元 (sample2a/sample2b それぞれに対応) はこの仕組みの実例。

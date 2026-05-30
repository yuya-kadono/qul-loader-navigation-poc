# 設計ドキュメント

このファイルは目次のみです。実体は [`docs/design/`](design/README.md) 配下に章単位で分割されています。

## 目次

- [1. QUL Loader の制約まとめ](design/01-qul-loader-constraints.md)
- [2. 制約を回避する 2 つのパターン](design/02-mediator-pattern.md)
- [3. ナビゲーション構造](design/03-navigation-structure.md)
- [4. 本 POC のScreen/View一覧](design/04-screens-views.md)
- [5. View ID とナビゲーションテーブル](design/05-view-id-registry.md)
- [6. Mediator API と履歴トラッキング](design/06-mediator-api.md)
- [7. 遷移フロー](design/07-transition-flow.md)
- [8. 仮想キー入力層](design/08-key-dispatcher.md)
- [9. View 主導ライフサイクルと TransitionManager](design/09-lifecycle/README.md)
- [10. Opening / Closing: 統一ライフサイクル上での実装パターン](design/10-opening-closing.md)
- [11. 検証したいポイント](design/11-verification.md)
- [12. 参考](design/12-references.md)

## 編集時の注意

各章は独立した `.md` ファイルになっています。編集する時は該当章だけを開き、
他章を巻き込まないように注意。Edit ツールではなく Python ヒアドキュメントを使うのが原則です
(プロジェクトルートの [`CLAUDE.md`](../CLAUDE.md) 参照)。

# 設計ドキュメント (章別)


このドキュメントは、QUL Loader の制約下で実現するScreen/View切り替えナビゲーションの設計方針をまとめたもの。


## 目次

- [1. QUL Loader の制約まとめ](01-qul-loader-constraints.md)
- [2. 制約を回避する 2 つのパターン](02-mediator-pattern.md)
- [3. ナビゲーション構造](03-navigation-structure.md)
- [4. 本 POC のScreen/View一覧](04-screens-views.md)
- [5. View ID とナビゲーションテーブル](05-view-id-registry.md)
- [6. Mediator API と履歴トラッキング](06-mediator-api.md)
- [7. 遷移フロー](07-transition-flow.md)
- [8. 仮想キー入力層](08-key-dispatcher.md)
- [9. View 主導ライフサイクルと TransitionManager](09-lifecycle/README.md)
- [10. Opening / Closing: 統一ライフサイクル上での実装パターン](10-opening-closing.md)
- [11. 検証したいポイント](11-verification.md)
- [12. 参考](12-references.md)

---

## このドキュメントの編集に関する注意 (Claude 向け)

各章は独立ファイルになっている。編集する時は該当章のファイルだけを開き、
他章を巻き込まないこと。Edit ツールではなく Python heredoc を使うのが原則 
(プロジェクトルートの [CLAUDE.md](../../CLAUDE.md) 参照)。
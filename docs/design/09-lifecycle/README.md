## 9. View 主導ライフサイクルと TransitionManager


### この章の構成

- [9-1. 設計の根幹: 「フェード」は view の In/Out 処理の placeholder](01-essence.md)
- [9-2. 責務分担](01-essence.md)
- [9-3. TransitionManager の公開状態と API](03-transition-manager.md)
- [9-4. View ライフサイクル契約](04-contract.md)
- [9-5. シナリオ: 同Screen内 view 遷移 (例: home → menu)](05-08-scenarios-and-abort.md)
- [9-6. シナリオ: Screen跨ぎ遷移 (例: opening/opening → normal/home)](05-08-scenarios-and-abort.md)
- [9-7. KeyDispatcher.enabled の制御](05-08-scenarios-and-abort.md)
- [9-8. 連続遷移と abort](05-08-scenarios-and-abort.md)
- [9-9. View スロットと「active screen」の関係 (screen-filtered binding 必須)](09-screen-filtered-binding.md)
- [9-10. 基底コンポーネント (ScreenBase / ViewBase / Logger)](10-base-components.md)
- [9-11. `Component.onCompleted` と `Loader.status` の使い分け](11-onCompleted-vs-status.md)

### 9-4. View ライフサイクル契約

各 view は以下のプロトコルに従う:

1. 自身のView ID (`thisViewId`) を保持
2. `TransitionManager.lifecycleOf(thisViewId)` をバインドして購読
3. `ViewLifecycle.Entering` への変化を検知したら **Enter 処理開始**（データ取得、アニメ、即完了など何でもよい）
4. Enter 処理完了で `TransitionManager.reportEnterComplete(thisViewId)` を呼ぶ
5. `ViewLifecycle.Leaving` への変化を検知したら **Leave 処理開始**
6. Leave 処理完了で `TransitionManager.reportLeaveComplete(thisViewId)` を呼ぶ
7. 必要なら `directionOf(thisViewId)` と `partnerOf(thisViewId)` を読んで挙動を分岐する

```qml
// View ライフサイクル契約の最小形 (素朴な実装、参考用)
Item {
    id: root
    readonly property int thisViewId: ViewId.NormalMenu
    readonly property int myLifecycle: TransitionManager.lifecycleOf(thisViewId)
    readonly property int myDirection: TransitionManager.directionOf(thisViewId)
    readonly property int myPartnerId: TransitionManager.partnerOf(thisViewId)

    opacity: 0   // 初期は不可視

    NumberAnimation {
        id: enterAnim
        target: root; property: "opacity"
        from: 0; to: 1
        onStopped: TransitionManager.reportEnterComplete(root.thisViewId)
    }
    NumberAnimation {
        id: leaveAnim
        target: root; property: "opacity"
        from: 1; to: 0
        onStopped: TransitionManager.reportLeaveComplete(root.thisViewId)
    }

    onMyLifecycleChanged: {
        switch (myLifecycle) {
            case ViewLifecycle.Entering:
                // 本物アプリならここでバックエンドリクエスト等。
                // POC: ランダム duration の fade-in に置き換え
                enterAnim.duration = 200 + Math.floor(Math.random() * 600)
                enterAnim.start()
                break
            case ViewLifecycle.Leaving:
                leaveAnim.duration = 200 + Math.floor(Math.random() * 600)
                leaveAnim.start()
                break
        }
    }
}
```

実装では上記の骨格を **ViewBase.qml** (§9-10) に括り出してあり、派生 View は `thisViewId`/`displayName`/`backgroundColor` を指定し、必要に応じて `onEntering` / `performEnter` / `onViewKey` 等のフックを override するだけでよい。ViewBase は加えて以下も担う:
- `_reactedInitial` ガード ＋ `Component.onCompleted` 保険で初期 binding 評価を確実に検知
- KeyDispatcher 監視 (§8-3 の property-token + binding パターン)
- 上部の情報 Column 表示（`showInfo: false` で抑制可）
- 20% 0 確率 duration ＋ `Qt.callLater` 遅延 (§9-3-2)

§9-4 のサンプルはあくまで「契約の最小形を示すための説明用」。実コードでは ViewBase 派生型を使う。


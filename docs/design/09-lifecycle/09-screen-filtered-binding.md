### 9-9. View スロットと「active screen」の関係 (screen-filtered binding 必須)

View スロット (`viewSlotA/B`) の物理 Loader は **各 Screen QML 内部に存在する**（§3-2、screen-local）。TransitionManager 上の `viewSlot*` プロパティはグローバル singleton だが、それを参照する Loader は screen 内にいる。

cross-screen 遷移中は **旧 Screen と新 Screen が同時に alive** になる。両者の ViewLoader が同じ singleton プロパティ (`viewSlotASource`, `viewSlotAViewId` 等) を見て同じ view を load しようとすると衝突する。

→ 各 Screen の ViewLoader は **「current view の所属 screen が自分かどうか」を `ViewId.screenOf` 経由で確認するフィルタを binding に組み込む** 必要がある (ScreenBase で実装、§9-10):

```qml
// ScreenBase.qml の ViewLoader (抜粋)
Loader {
    id: viewSlotA
    anchors.fill: parent
    source: {
        var vid = TransitionManager.viewSlotAViewId
        if (vid === 0) return ""
        if (ViewId.screenOf(vid) === screen.thisScreenId) {
            return TransitionManager.viewSlotASource
        }
        return ""
    }
    active: source !== ""
}
```

このフィルタにより:
- 同Screen内遷移: 両 ViewLoader が同 Screen 内で動く（screen 一致なのでフィルタ通過、両方 active）
- cross-screen 遷移: 旧 Screen の Loader は **screen 不一致でフィルタ NG → source=""** になり、自分の view (旧 view) を保持し続ける（source 不変だから unload しない）。新 Screen の Loader だけが新 view を load する

これにより 1 つの singleton プロパティに 2 つの Loader がぶら下がっていても衝突せず、各 screen が自分の責任範囲だけ反映する。


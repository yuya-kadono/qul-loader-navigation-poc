# フロー図集 (mermaid)

このドキュメントは [`design.md`](design.md) の補足。  
画面切り替えと仮想キー通知の流れを mermaid 図で可視化する。  
同じ内容を [`flows.pptx`](flows.pptx) にもまとめてある。

> 表記注: 図中では可読性のため enum 値を `ViewId.NormalHome` のように短縮表記する。  
> 実 QML での正式な書き方は `ViewId.ViewId.NormalHome` (`<TypeName>.<EnumName>.<Value>` の 3 段、QUL 2.9 の QML enum 構文)。詳細は §10。

---

## 1. アーキテクチャ俯瞰

主要 singleton と Scene / View の依存関係。

```mermaid
flowchart TB
    subgraph enums[Enum + helper singletons]
        SId[SceneId<br>enum + fileOf/nameOf]
        VId[ViewId<br>enum + fileOf/nameOf/sceneOf]
        Dir[Direction<br>enum + nameOf]
        Lc[Lifecycle<br>enum + nameOf]
        K[Key<br>enum + nameOf]
        Ev[Event<br>enum + nameOf]
    end
    subgraph singletons[Behavior singletons]
        Med[Mediator<br>ナビゲーション意図 / 履歴]
        TM[TransitionManager<br>スロット管理 / lifecycle 通知]
        KD[KeyDispatcher<br>仮想キー配送]
        Log[Logger<br>統一ログ]
    end

    Main[Main.qml<br>Window + Keys + SceneSlot ペア]
    SB[SceneBase<br>ViewSlot ペア + 入力吸収]
    VB[ViewBase<br>lifecycle 契約 + フック]

    SceneI[OpeningScene / NormalScene / ClosingScene]
    ViewI[OpeningView / HomeView / MenuView /<br>Sample1View / Sample2View / ClosingView]

    Main -->|key 変換| KD
    Main -->|kickoff| Med
    Main -->|SceneSlot bind| TM

    SB -->|sceneEventGen bind| KD
    SB -->|scene フィルタ binding| TM
    SB -->|sceneOf| VId

    VB -->|viewEventGen bind| KD
    VB -->|lifecycle bind| TM
    VB -->|nextLoadingViewId 取得| Med
    VB -->|nameOf| VId

    SceneI -.派生.-> SB
    ViewI -.派生.-> VB

    Med -->|startTransition| TM
    TM -->|fileOf| SId
    TM -->|fileOf / sceneOf| VId
    TM -->|enabled toggle| KD
```

---

## 2. 仮想キー通知の流れ (全体像)

物理キー → 仮想キー → Scene → View の 2 段配送。

```mermaid
flowchart LR
    Phys[物理キー<br>A/S/D/Z/X/C]
    Phys -->|Keys.onPressed/Released| Main[Main.qml<br>physicalToVirtual]
    Main -->|dispatchToScene<br>vk, PRESS/RELEASE/CLICK| KD[KeyDispatcher]
    KD -->|sceneEventGen++| SB[SceneBase<br>onSceneEventGenChanged]
    SB -->|handleAbsorb true| Absorbed((吸収して終了))
    SB -->|handleAbsorb false| Forward[KeyDispatcher.dispatchToView]
    Forward -->|viewEventGen++| VB[ViewBase<br>onViewEventGenChanged]
    VB -->|onViewKey vk, ev| Action((view 固有処理))
```

---

## 3. 仮想キー通知 シーケンス: HOME (X) で normal/home へ

NormalScene が HOME CLICK を吸収する例。

```mermaid
sequenceDiagram
    actor User
    participant Main as Main.qml
    participant KD as KeyDispatcher
    participant NS as NormalScene
    participant Cur as 現 View<br>(例: Sample 2A)
    participant Med as Mediator

    User->>Main: Keys.onPressed (Qt.Key_X)
    Main->>KD: dispatchToScene(HOME, PRESS)
    KD->>KD: sceneEventGen++
    KD-->>NS: onSceneEventGenChanged
    NS->>NS: handleAbsorb(HOME, PRESS) → false (PRESS は吸収せず)
    NS->>KD: dispatchToView(HOME, PRESS)
    KD->>KD: viewEventGen++
    KD-->>Cur: onViewEventGenChanged
    Cur->>Cur: onViewKey(HOME, PRESS) → 何もしない

    User->>Main: Keys.onReleased
    Main->>KD: dispatchToScene(HOME, RELEASE)
    Note over KD,Cur: 同じ流れで RELEASE 配送

    Main->>Main: CLICK 合成 (PRESS/RELEASE 対が成立)
    Main->>KD: dispatchToScene(HOME, CLICK)
    KD-->>NS: onSceneEventGenChanged
    NS->>NS: handleAbsorb(HOME, CLICK) → true (吸収)
    NS->>Med: requestNavigate(ViewId.NormalHome, Next)
    Note right of Med: View には届かない (吸収済み)
```

---

## 4. 画面切替 概観: Mediator → TransitionManager → Views

```mermaid
flowchart TB
    Trig[操作 / 自己発火] -->|requestNavigate viewId, direction| Med[Mediator]
    Med -->|currentViewId 更新<br>history push<br>nextLoadingViewId 公開| Med
    Med -->|startTransition| TM[TransitionManager]
    TM -->|KeyDispatcher.enabled=false<br>state=InProgress| Block((入力一時停止))
    TM -->|scene 変化なら scene QML ロード| SL[SceneSlot A/B]
    TM -->|incoming view metadata 設定| MetaI[Slot X = Entering]
    TM -->|leaving view metadata 設定| MetaL[Slot Y = Leaving]
    TM -->|incoming view source 設定 ★最後| LoadV[View QML ロード → Component.onCompleted]
    MetaI -->|myLifecycle 変化| EnterV[新 View: performEnter]
    MetaL -->|myLifecycle 変化| LeaveV[旧 View: performLeave]
    EnterV -->|完了| RepE[reportEnterComplete]
    LeaveV -->|完了| RepL[reportLeaveComplete]
    RepE --> WaitBoth{両方<br>完了?}
    RepL --> WaitBoth
    WaitBoth -->|yes| Final[finalizeTransition<br>旧スロット解放 / 状態 swap]
    Final -->|enabled=true<br>finishedGen++| Done((遷移完了))
```

---

## 5. 同シーン内遷移 シーケンス: home → menu

`MENU` 吸収後の流れ。

```mermaid
sequenceDiagram
    participant NS as NormalScene
    participant Med as Mediator
    participant TM as TransitionManager
    participant Home as HomeView (current)
    participant Menu as MenuView (incoming)
    participant Loader as NormalScene 内 ViewSlot B

    NS->>Med: requestNavigate(ViewId.NormalMenu, Next)
    Med->>Med: nextLoadingViewId = ViewId.NormalMenu<br>history.push, currentViewId 更新
    Med->>TM: startTransition(ViewId.NormalMenu, Next)
    TM->>TM: enabled=false / state=InProgress
    Note over TM: scene 同じ → SceneSlot 触らず

    TM->>TM: viewSlotBViewId/Direction/Partner 設定<br>viewSlotBLifecycle = Entering
    TM->>TM: viewSlotAPartnerId/Direction 設定<br>viewSlotALifecycle = Leaving
    Home-->>Home: myLifecycle = Leaving → performLeave
    Home->>Home: leaveAnim.start (random 0-800ms)

    TM->>Loader: viewSlotBSource = "MenuView.qml" ★ 最後
    Loader->>Menu: 構築 → Component.onCompleted
    Menu->>Menu: onEntering で cursor 復元
    Menu->>Menu: performEnter → enterAnim.start

    Home-->>TM: leaveAnim.onStopped → reportLeaveComplete
    Menu-->>TM: enterAnim.onStopped → reportEnterComplete
    TM->>TM: 両完了確認 → finalizeTransition
    TM->>TM: HomeView 解放 (slot A クリア)<br>viewAIsCurrent = false
    TM->>TM: enabled=true / finishedGen++
```

---

## 6. シーン跨ぎ遷移 シーケンス: home → closing

新シーン QML のロード + view 切替が並走する。

```mermaid
sequenceDiagram
    participant Home as HomeView
    participant Med as Mediator
    participant TM as TransitionManager
    participant SS as SceneSlot B (Main)
    participant CS as ClosingScene (new)
    participant CV as ClosingView (new)

    Home->>Med: requestNavigate(ViewId.ClosingClosing, Next)
    Med->>Med: history クリア<br>closingAborted = false<br>nextLoadingViewId 公開
    Med->>TM: startTransition(ViewId.ClosingClosing, Next)
    TM->>TM: enabled=false / state=InProgress

    TM->>SS: sceneSourceB = "ClosingScene.qml"
    SS->>CS: 構築 (同期)
    Note over CS: ClosingScene のリスナ登録完了

    TM->>TM: viewSlot*ViewId/Direction/Partner 設定<br>Closing slot = Entering / Home slot = Leaving
    Home-->>Home: myLifecycle = Leaving → leaveAnim.start

    TM->>CS: viewSlot*Source = "ClosingView.qml"
    Note over CS,CV: ClosingScene の scene-filtered binding が反応<br>(NormalScene 側は scene 不一致でスキップ)
    CS->>CV: 構築
    CV->>CV: performEnter (即完了パターン)<br>opacity=1, Qt.callLater(emitEnterComplete)<br>internalAnim.start (3 秒)
    CV-->>TM: deferred reportEnterComplete

    Home-->>TM: leaveAnim.onStopped → reportLeaveComplete
    TM->>TM: finalizeTransition
    TM->>TM: HomeView 解放 → NormalScene 解放 (sceneSourceA="")<br>sceneAIsCurrent = false
    TM->>TM: enabled=true / finishedGen++

    Note over CV: 内部アニメ走行中 (state=Idle)<br>ユーザ入力受付可能
    CV-->>CV: internalAnim.onStopped → Qt.quit()<br>(closingAborted=false の場合)
```

---

## 7. Closing 中断シーケンス: BACK CLICK で home へ復帰

`Mediator.closingAborted` フラグと `forceUnloadCurrentView` の組み合わせ。

```mermaid
sequenceDiagram
    actor User
    participant Main
    participant KD as KeyDispatcher
    participant CS as ClosingScene
    participant Med as Mediator
    participant TM as TransitionManager
    participant CV as ClosingView
    participant Home as HomeView (new)

    Note over CV: 内部アニメ走行中 (state=Idle, enabled=true)
    User->>Main: BACK (C) PRESS/RELEASE/CLICK
    Main->>KD: dispatchToScene(BACK, CLICK)
    KD-->>CS: onSceneEventGenChanged
    CS->>CS: handleAbsorb(BACK, CLICK) → 中断手順

    rect rgb(255, 240, 240)
    Note over CS,TM: 順序が重要 (§10-2-1)
    CS->>Med: closingAborted = true ① 自然完了側を抑止
    CS->>TM: forceUnloadCurrentView() ② current 強制アンロード
    TM->>CV: slot 解放 → 破棄
    CS->>Med: requestNavigate(ViewId.NormalHome, Back) ③ 新規遷移
    end

    Med->>TM: startTransition(ViewId.NormalHome, Back)
    Note over TM: hasLeavingView=false<br>(forceUnload 直後で空)
    TM->>TM: Home slot = Entering 設定
    TM->>Home: Loader が HomeView 構築
    Home->>Home: performEnter
    Home-->>TM: reportEnterComplete
    TM->>TM: finalizeTransition
    TM->>TM: ClosingScene 解放 (sceneSourceB="")
    Note over Home: home 復帰完了
```

---

## 8. 同一 QML 多重 ID パターン: Sample2View が a/b 両対応

`Mediator.nextLoadingViewId` 経由で `thisViewId` を動的取得する仕組み。

```mermaid
flowchart TB
    subgraph User操作[ユーザ操作]
        Op[MenuView で cursor=2 → ENTER CLICK]
    end

    Op -->|requestNavigate ViewId.NormalSample2b, Next| Med[Mediator]

    subgraph Med-処理[Mediator]
        Med1[nextLoadingViewId = ViewId.NormalSample2b]
        Med2[currentViewId, previousViewId, history 更新]
        Med1 --> Med2
    end

    Med2 -->|startTransition| TM[TransitionManager]

    subgraph TM-処理[TransitionManager]
        TM1[ViewId.fileOf ViewId.NormalSample2b<br>→ Sample2View.qml]
        TM2[viewSlot* metadata 設定<br>viewSlotXViewId = ViewId.NormalSample2b]
        TM3[viewSlot*Source = Sample2View.qml]
        TM1 --> TM2 --> TM3
    end

    TM3 -->|Loader.source 変化| L[NormalScene 内 ViewSlot Loader]
    L --> View[Sample2View インスタンス生成]

    subgraph ViewBase-onCompleted[Sample2View Component.onCompleted - in ViewBase]
        V1{thisViewId === 0?}
        V1 -->|yes| V2[thisViewId = Mediator.nextLoadingViewId<br>= ViewId.NormalSample2b]
        V2 --> V3[isVariantB = true]
        V3 --> V4[displayName = SAMPLE 2B<br>backgroundColor = 藍色]
    end

    View --> V1
```

別途、Sample2View が sample2a 用にロードされた場合:

```mermaid
flowchart LR
    A[Mediator.requestNavigate ViewId.NormalSample2a] -->|nextLoadingViewId = ViewId.NormalSample2a| B[Sample2View 構築]
    B -->|thisViewId 自己取得| C[isVariantA = true]
    C --> D[displayName = SAMPLE 2A / 紫色]

    E[Mediator.requestNavigate ViewId.NormalSample2b] -->|nextLoadingViewId = ViewId.NormalSample2b| F[Sample2View 構築]
    F -->|thisViewId 自己取得| G[isVariantB = true]
    G --> H[displayName = SAMPLE 2B / 藍色]
```

---

## 9. property-token 通知パターン (signal の代替)

QUL では `Connections { target: singleton }` を避けるため、singleton 側で **世代カウンタを incr**、受け手がローカル binding + `on*Changed` + `ready` ガードで監視する。

```mermaid
sequenceDiagram
    participant Sender as Singleton<br>(KeyDispatcher / TransitionManager)
    participant Recv as 受け手<br>(SceneBase / ViewBase / Main)

    Note over Recv: 初期化時に property を singleton に bind
    Recv->>Recv: property int localGen: Singleton.someGen<br>property bool ready: false
    Recv->>Recv: Component.onCompleted: ready = true

    Note over Sender: イベント発生
    Sender->>Sender: lastArg1 = ..., lastArg2 = ...<br>someGen = someGen + 1
    Sender-->>Recv: binding 経由で localGen 更新

    Recv->>Recv: onLocalGenChanged 発火
    Recv->>Recv: if (!ready) return  // 初期 binding 評価ガード
    Recv->>Sender: lastArg1, lastArg2 を read
    Recv->>Recv: 処理実行
```

採用ケース:
- `KeyDispatcher.sceneEventGen` / `viewEventGen` → SceneBase / ViewBase が監視
- `TransitionManager.finishedGen` / `lastFinishedViewId` → Main.qml が監視

---

## 10. ID 表現と整数化

ビュー ID は **bit-packed 整数**で管理:

```mermaid
flowchart LR
    Hex["viewId int 16bit<br>例: 0x0203"]
    Hex -->|"上位 8bit = sceneId"| Sid["SceneId.Normal = 2"]
    Hex -->|"下位 8bit = local"| LocalId["3 (sample2a)"]
    Sid -->|"SceneId.fileOf"| SceneFile["NormalScene.qml"]
    Hex -->|"ViewId.fileOf"| ViewFile["Sample2View.qml"]
    Hex -->|"ViewId.nameOf"| Name["normal/sample2a"]
```

ID 一覧 (`ViewId.qml` 内の `enum ViewId`、QUL 2.9 の QML enum 構文)。アクセスは `<TypeName>.<EnumName>.<Value>` の 3 段:

| ID 定数 (使う側の表記) | hex 値 | 担当 QML |
| --- | --- | --- |
| `ViewId.ViewId.OpeningOpening` | `0x0100` | OpeningView.qml |
| `ViewId.ViewId.NormalHome`     | `0x0200` | HomeView.qml |
| `ViewId.ViewId.NormalMenu`     | `0x0201` | MenuView.qml |
| `ViewId.ViewId.NormalSample1`  | `0x0202` | Sample1View.qml |
| `ViewId.ViewId.NormalSample2a` | `0x0203` | **Sample2View.qml** |
| `ViewId.ViewId.NormalSample2b` | `0x0204` | **Sample2View.qml** (同 QML) |
| `ViewId.ViewId.ClosingClosing` | `0x0300` | ClosingView.qml |

---

## 関連ドキュメント

- [design.md](design.md) — 設計の根拠と詳細
- [README.md](../README.md) — ビルド/動作確認の手順
- [flows.pptx](flows.pptx) — 同内容のスライドショー

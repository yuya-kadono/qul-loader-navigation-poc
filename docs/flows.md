# フロー図集 (mermaid)

このドキュメントは [`design.md`](design.md) の補足。  
画面切り替えと仮想キー通知の流れを mermaid 図で可視化する。  
同じ内容を [`flows.pptx`](flows.pptx) にもまとめてある。

> 表記注: 図中の enum 値は `ViewId.NormalHome` の 2 段形式 (`<Type>.<value>`)。
> QUL 2.x の QML enum 構文に従う (cf. `Loader.Ready`)。詳細は [`design.md`](design.md) §5。

---

## 1. アーキテクチャ俯瞰

主要 singleton と Screen / View の依存関係。

```mermaid
flowchart TB
    subgraph constants[Constants module (enum + helper)]
        SId[ScreenId<br>enum + nameOf]
        VId[ViewId<br>enum + nameOf + screenOf]
        Dir[NavDirection<br>enum + nameOf]
        Lc[ViewLifecycle<br>enum + nameOf]
        VK[VirtualKey<br>enum + nameOf]
        VE[VirtualEvent<br>enum + nameOf]
    end
    subgraph mediator[Mediator module (behavior singletons)]
        Med[Mediator<br>ナビゲーション意図 / 履歴]
        TM[TransitionManager<br>スロット管理 / lifecycle 通知]
        KD[KeyDispatcher<br>仮想キー配送]
        Log[Logger<br>統一ログ]
    end

    Main[Main.qml<br>Window + Keys + ScreenSlot ペア]
    SR[ScreenRegistry<br>screenUrlOf / viewUrlOf<br>(qrc URL マップ)]
    SB[ScreenBase<br>ViewSlot ペア + 入力吸収]
    VB[ViewBase<br>lifecycle 契約 + フック]

    ScreenI[OpeningScreen / NormalScreen / ClosingScreen]
    ViewI[OpeningView / HomeView / MenuView /<br>Sample1View / Sample2View / ClosingView]

    Main -->|key 変換| KD
    Main -->|kickoff: switchView| Med
    Main -->|ScreenSlot bind| TM
    Main -->|DI: screenRegistry =| TM

    SB -->|screenEventGen bind| KD
    SB -->|screen フィルタ binding| TM
    SB -->|screenOf| VId

    VB -->|viewEventGen bind| KD
    VB -->|lifecycle bind| TM
    VB -->|pendingViewId 取得| Med
    VB -->|nameOf| VId

    ScreenI -.派生.-> SB
    ViewI -.派生.-> VB

    Med -->|startTransition| TM
    TM -->|screenUrlOf / viewUrlOf| SR
    SR -.データ参照.-> SId
    SR -.データ参照.-> VId
    TM -->|enabled toggle| KD
```

---

## 2. 仮想キー通知の流れ (全体像)

物理キー → 仮想キー → Screen → View の 2 段配送。

```mermaid
flowchart LR
    Phys[物理キー<br>A/S/D/Z/X/C]
    Phys -->|Keys.onPressed/Released| Main[Main.qml<br>physicalToVirtual]
    Main -->|dispatchToScreen<br>vk, PRESS/RELEASE/CLICK| KD[KeyDispatcher]
    KD -->|screenEventGen++| SB[ScreenBase<br>onScreenEventGenChanged]
    SB -->|handleAbsorb true| Absorbed((吸収して終了))
    SB -->|handleAbsorb false| Forward[KeyDispatcher.dispatchToView]
    Forward -->|viewEventGen++| VB[ViewBase<br>onViewEventGenChanged]
    VB -->|onViewKey vk, ev| Action((view 固有処理))
```

---

## 3. 仮想キー通知 シーケンス: HOME (X) で normal/home へ

NormalScreen が HOME CLICK を吸収する例。

```mermaid
sequenceDiagram
    actor User
    participant Main as Main.qml
    participant KD as KeyDispatcher
    participant NS as NormalScreen
    participant Cur as 現 View<br>(例: Sample 2A)
    participant Med as Mediator

    User->>Main: Keys.onPressed (Qt.Key_X)
    Main->>KD: dispatchToScreen(HOME, PRESS)
    KD->>KD: screenEventGen++
    KD-->>NS: onScreenEventGenChanged
    NS->>NS: handleAbsorb(HOME, PRESS) → false (PRESS は吸収せず)
    NS->>KD: dispatchToView(HOME, PRESS)
    KD->>KD: viewEventGen++
    KD-->>Cur: onViewEventGenChanged
    Cur->>Cur: onViewKey(HOME, PRESS) → 何もしない

    User->>Main: Keys.onReleased
    Main->>KD: dispatchToScreen(HOME, RELEASE)
    Note over KD,Cur: 同じ流れで RELEASE 配送

    Main->>Main: CLICK 合成 (PRESS/RELEASE 対が成立)
    Main->>KD: dispatchToScreen(HOME, CLICK)
    KD-->>NS: onScreenEventGenChanged
    NS->>NS: handleAbsorb(HOME, CLICK) → true (吸収)
    NS->>Med: switchView(ViewId.NormalHome, Next)
    Note right of Med: View には届かない (吸収済み)
```

---

## 4. 画面切替 概観: Mediator → TransitionManager → Views

```mermaid
flowchart TB
    Trig[操作 / 自己発火] -->|switchView viewId, direction| Med[Mediator]
    Med -->|currentViewId 更新<br>debugHistory push<br>pendingViewId 公開| Med
    Med -->|startTransition| TM[TransitionManager]
    TM -->|KeyDispatcher.enabled=false<br>state=InProgress| Block((入力一時停止))
    TM -->|screen 変化なら screen QML ロード| SL[ScreenSlot A/B]
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
    participant NS as NormalScreen
    participant Med as Mediator
    participant TM as TransitionManager
    participant Home as HomeView (current)
    participant Menu as MenuView (incoming)
    participant Loader as NormalScreen 内 ViewSlot B

    NS->>Med: switchView(ViewId.NormalMenu, Next)
    Med->>Med: pendingViewId = ViewId.NormalMenu<br>debugHistory.push, currentViewId 更新
    Med->>TM: startTransition(ViewId.NormalMenu, Next)
    TM->>TM: enabled=false / state=InProgress
    Note over TM: screen 同じ → ScreenSlot 触らず

    TM->>TM: viewSlotBViewId/NavDirection/Partner 設定<br>viewSlotBLifecycle = Entering
    TM->>TM: viewSlotAPartnerId/NavDirection 設定<br>viewSlotALifecycle = Leaving
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
    participant SS as ScreenSlot B (Main)
    participant CS as ClosingScreen (new)
    participant CV as ClosingView (new)

    Home->>Med: switchView(ViewId.ClosingClosing, Next)
    Med->>Med: debugHistory クリア<br>pendingViewId 公開
    Med->>TM: startTransition(ViewId.ClosingClosing, Next)
    TM->>TM: enabled=false / state=InProgress

    TM->>SS: screenSourceB = "ClosingScreen.qml"
    SS->>CS: 構築 (同期)
    Note over CS: ClosingScreen のリスナ登録完了

    TM->>TM: viewSlot*ViewId/NavDirection/Partner 設定<br>Closing slot = Entering / Home slot = Leaving
    Home-->>Home: myLifecycle = Leaving → leaveAnim.start

    TM->>CS: viewSlot*Source = "ClosingView.qml"
    Note over CS,CV: ClosingScreen の screen-filtered binding が反応<br>(NormalScreen 側は screen 不一致でスキップ)
    CS->>CV: 構築
    CV->>CV: performEnter (即完了パターン)<br>opacity=1, Qt.callLater(reportEnterCompleteDeferred)<br>closingTimer.start (3 秒)
    CV-->>TM: deferred reportEnterComplete

    Home-->>TM: leaveAnim.onStopped → reportLeaveComplete
    TM->>TM: finalizeTransition
    TM->>TM: HomeView 解放 → NormalScreen 解放 (screenSourceA="")<br>screenAIsCurrent = false
    TM->>TM: enabled=true / finishedGen++

    Note over CV: 内部アニメ走行中 (state=Idle)<br>ユーザ入力受付可能
    CV-->>CV: closingTimer.onTriggered → Qt.quit()<br>(中断されなかった = 自然完了)
```

---

## 7. Closing 中断シーケンス: BACK CLICK で home へ復帰

ClosingView 自身が `onViewKey` で BACK/HOME を受信し、内部 Timer を止めて通常の `switchView` を発火する。Mediator / TransitionManager / ClosingScreen 側に中断専用 API は持たない（`closingAborted` フラグも `forceUnloadCurrentView` も不要）。

```mermaid
sequenceDiagram
    actor User
    participant Main
    participant KD as KeyDispatcher
    participant CS as ClosingScreen
    participant CV as ClosingView
    participant Med as Mediator
    participant TM as TransitionManager
    participant Home as HomeView (new)

    Note over CV: 内部 Timer 走行中 (state=Idle, enabled=true)
    User->>Main: BACK (C) PRESS/RELEASE/CLICK
    Main->>KD: dispatchToScreen(BACK, CLICK)
    KD-->>CS: onScreenEventGenChanged
    CS->>CS: handleAbsorb(BACK, CLICK)<br>→ false (default 素通し)
    CS->>KD: dispatchToView(BACK, CLICK)
    KD-->>CV: onViewEventGenChanged
    CV->>CV: onViewKey(BACK, CLICK)<br>→ abort 判定

    rect rgb(240, 255, 240)
    Note over CV,Med: 中断 = 2 step
    CV->>CV: closingTimer.stop()<br>① Qt.quit を未然に防ぐ
    CV->>Med: switchView(NormalHome, Back)<br>② 通常のナビ
    end

    Med->>TM: startTransition(NormalHome, Back)
    Note over TM: 通常の cross-screen 遷移
    TM->>TM: ScreenSlot A に NormalScreen 構築<br>HomeView を ViewSlot にロード
    TM->>CV: lifecycle = Leaving
    CV->>CV: performLeave (instant, Qt.callLater)
    Home->>Home: performEnter
    CV-->>TM: reportLeaveComplete
    Home-->>TM: reportEnterComplete
    TM->>TM: finalizeTransition
    CV->>CV: Component.onDestruction<br>(保険: timer.running なら stop)
    TM->>TM: ClosingScreen / ClosingView 解放
    Note over Home: home 復帰完了
```

---

## 8. 同一 QML 多重 ID パターン: Sample2View が a/b 両対応

`Mediator.pendingViewId` 経由で `thisViewId` を動的取得する仕組み。

```mermaid
flowchart TB
    subgraph User操作[ユーザ操作]
        Op[MenuView で cursor=2 → ENTER CLICK]
    end

    Op -->|switchView ViewId.NormalSample2b, Next| Med[Mediator]

    subgraph Med-処理[Mediator]
        Med1[pendingViewId = ViewId.NormalSample2b]
        Med2[currentViewId, previousViewId, debugHistory 更新]
        Med1 --> Med2
    end

    Med2 -->|startTransition| TM[TransitionManager]

    subgraph TM-処理[TransitionManager]
        TM1[ScreenRegistry.viewUrlOf ViewId.NormalSample2b<br>→ Sample2View.qml]
        TM2[viewSlot* metadata 設定<br>viewSlotXViewId = ViewId.NormalSample2b]
        TM3[viewSlot*Source = Sample2View.qml]
        TM1 --> TM2 --> TM3
    end

    TM3 -->|Loader.source 変化| L[NormalScreen 内 ViewSlot Loader]
    L --> View[Sample2View インスタンス生成]

    subgraph ViewBase-onCompleted[Sample2View Component.onCompleted - in ViewBase]
        V1{thisViewId === 0?}
        V1 -->|yes| V2[thisViewId = Mediator.pendingViewId<br>= ViewId.NormalSample2b]
        V2 --> V3[isVariantB = true]
        V3 --> V4[displayName = SAMPLE 2B<br>backgroundColor = 藍色]
    end

    View --> V1
```

別途、Sample2View が sample2a 用にロードされた場合:

```mermaid
flowchart LR
    A[Mediator.switchView ViewId.NormalSample2a] -->|pendingViewId = ViewId.NormalSample2a| B[Sample2View 構築]
    B -->|thisViewId 自己取得| C[isVariantA = true]
    C --> D[displayName = SAMPLE 2A / 紫色]

    E[Mediator.switchView ViewId.NormalSample2b] -->|pendingViewId = ViewId.NormalSample2b| F[Sample2View 構築]
    F -->|thisViewId 自己取得| G[isVariantB = true]
    G --> H[displayName = SAMPLE 2B / 藍色]
```

---

## 9. property-token 通知パターン (signal の代替)

QUL では `Connections { target: singleton }` を避けるため、singleton 側で **世代カウンタを incr**、受け手がローカル binding + `on*Changed` + `ready` ガードで監視する。

```mermaid
sequenceDiagram
    participant Sender as Singleton<br>(KeyDispatcher / TransitionManager)
    participant Recv as 受け手<br>(ScreenBase / ViewBase / Main)

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
- `KeyDispatcher.screenEventGen` / `viewEventGen` → ScreenBase / ViewBase が監視
- `TransitionManager.finishedGen` / `lastFinishedViewId` → Main.qml が監視

---

## 10. ID 表現と整数化

ビュー ID は **bit-packed 整数**で管理:

```mermaid
flowchart LR
    Hex["viewId int 16bit<br>例: 0x0203"]
    Hex -->|"上位 8bit = screenId"| Sid["ScreenId.Normal = 2"]
    Hex -->|"下位 8bit = local"| LocalId["3 (sample2a)"]
    Sid -->|"ScreenRegistry.screenUrlOf"| ScreenFile["NormalScreen.qml"]
    Hex -->|"ScreenRegistry.viewUrlOf"| ViewFile["Sample2View.qml"]
    Hex -->|"ViewId.nameOf"| Name["Normal/Sample2a"]
```

ID 一覧 (`ViewId.qml` 内の `enum ViewId`、QUL 2.9 の QML enum 構文)。アクセスは `<TypeName>.<EnumName>.<Value>` の 3 段:

| ID 定数 (使う側の表記) | hex 値 | 担当 QML |
| --- | --- | --- |
| `ViewId.ViewId.OpeningOpening` | `0x0100` | OpeningView.qml |
| `ViewId.ViewId.NormalHome`     | `0x0200` | HomeView.qml |
| `ViewId.ViewId.NormalMenu`     | `0x0201` | MenuView.qml |
| `ViewId.ViewId.NormalSample1`  | `0x0202` | Sample1View.qml |
| `ViewId.ViewId.NormalSample2a` | `0x0203` | **Sam
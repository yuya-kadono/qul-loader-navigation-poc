/* flows/app.js
   SVG ステージ描画 + アクター/group box + メッセージアニメーションエンジン。
   scenarios.js のグローバル ACTORS / SCENARIOS を参照する。

   アクターのライフサイクル:
     - シナリオ開始時: pre-instantiated 系 (singleton / Main.qml / Window 直下 Loader) は
       silent 配置済み。それ以外のアクター (lazy load 系: Screen / View) は非表示。
     - 各 step の from/to に登場する lazy アクターが**初参照されたタイミング**で fade-in spawn
     - 一度 spawn されたアクターはシナリオ終了まで残る
     - リセット / シナリオ変更 → 全アクター除去
     - シーク → 過去 step 群を辿って「そこまでに登場済み」のアクターを silent 再構築

   再生モデル:
     state.stepIdx = 「次に再生する step の index」(0..steps.length)
     - 連続再生 ▶: stepIdx から末尾まで chain 再生
     - 1 step 進む ▶|: stepIdx の step を 1 回再生して stepIdx++
     - 1 step 戻る ◀: stepIdx-- して、その step を再生 (= 直前を見直す)
     - シークバー: 任意 idx へジャンプ、scene を再構築して位置だけ移動 (input) or 再生 (dblclick)
     - 一時停止 ⏸: 連続再生中だけ effective。in-flight bubble は pause で停止
     - リセット ⟲: stepIdx=0、全アクター/バブル/タイマー破棄

   状態クリーンアップ (seek / reset / scenario change 時):
     - state.pendingTimers の setTimeout 全部 clear
     - SVG ステージから .msg-bubble 全部除去
     - state.playing = false、state.resumeFn = null
*/
'use strict';

const SVG_NS = 'http://www.w3.org/2000/svg';
const stage = document.getElementById('stage');
const logBody = document.getElementById('logBody');
const statusText = document.getElementById('statusText');
const seekBar = document.getElementById('seekBar');
const seekText = document.getElementById('seekText');

// ============================================================
// アプリ状態
// ============================================================
const state = {
    scenario: 'startup',
    playing: false,
    speed: 1,
    stepIdx: 0,
    resumeFn: null,
    pendingTimers: [],
};

let actorEls = {};  // id → SVG <g> element (現在表示中のアクター)
let groupEls = {};  // group id → SVG <g> element (現在表示中の group box)
let actorStates = {};  // actor id → { key: value, ... } の persistent state map

// ============================================================
// SVG helper
// ============================================================
function ce(tag, attrs) {
    const e = document.createElementNS(SVG_NS, tag);
    if (attrs) for (const k in attrs) e.setAttribute(k, attrs[k]);
    return e;
}

function escapeHtml(s) {
    return s.replace(/[&<>"']/g, c => ({
        '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
    }[c]));
}

function setTimer(fn, delay) {
    const id = setTimeout(() => {
        const idx = state.pendingTimers.indexOf(id);
        if (idx >= 0) state.pendingTimers.splice(idx, 1);
        fn();
    }, delay);
    state.pendingTimers.push(id);
    return id;
}

function clearAllTimers() {
    state.pendingTimers.forEach(id => clearTimeout(id));
    state.pendingTimers = [];
}

function clearAllBubbles() {
    const bubbles = stage.querySelectorAll('.msg-bubble');
    bubbles.forEach(b => { if (b.parentNode) b.parentNode.removeChild(b); });
}

// 最初からインスタンスが存在する (= 遅延ロードしない) コンポーネントの
// 現在情報を actorStates に seed する。シナリオロード時 / リセット時に
// 呼ばれ、シングルトン群と Main.qml と Window 直下 Loader の状態が
// 常時 debug panel に表示される状態を保証する。
function seedInitialStates() {
    if (typeof ACTORS === 'undefined') return;
    for (const id in ACTORS) {
        const a = ACTORS[id];
        if (a.preInstantiated && a.initialState) {
            actorStates[id] = Object.assign({}, a.initialState);
        }
    }
}

// 最初からインスタンスが存在するコンポーネント (singleton + Window root +
// Window 直下 Loader) は scenario 開始時から actor box もステージ上に存在させる
// (silent spawn = fade-in せず即配置)。属する group box も同時に出る。
function spawnPreInstantiatedActors() {
    if (typeof ACTORS === 'undefined') return;
    for (const id in ACTORS) {
        if (ACTORS[id].preInstantiated) {
            silentSpawnActor(id);
        }
    }
}

function clearAllActors() {
    while (stage.firstChild) stage.removeChild(stage.firstChild);
    actorEls = {};
    groupEls = {};
    actorStates = {};
    seedInitialStates();              // pre-instantiated コンポーネントの state を再 seed
    spawnPreInstantiatedActors();     // pre-instantiated の actor box も最初から配置
    renderDebugPanel();
}

// ============================================================
// 内包関係を示す group box (薄い破線矩形 + ラベル)
//
// 設計方針:
//   - シナリオ開始時には **どの group box も表示しない**。
//   - 各アクターが初参照で fade-in spawn される時に、そのアクターが属する
//     group の box がまだ無ければ box の方も fade-in で先に出す。
//   - これで「世界の地図を最初から提示」せず、アクター登場と同時に
//     「あ、ここは ScreenSlot A の中なんだ」と気付ける流れにする。
//   - z-order は group box が最背面、actor がその上、bubble が最前面。
// ============================================================

// SVG <g> 要素を作る (実描画はせず DOM 要素だけ返す)
// ラベルは box の **外側 (上)** に 2 行で配置:
//   main label : y = grp.y - 20  (上の行)
//   sub  label : y = grp.y - 6   (box の真上)
// 水平に「label · sub」を並べると sub が長文だと隣の group の label に
// かぶる (sub だけで box 幅を超えがち) ので、縦に積む方式に統一。
// → box 内部はアクター専有 (内部衝突なし)、box 外も縦に伸びるだけなので
//   隣接 group との水平衝突なし。
function buildGroupBoxElement(gid) {
    const grp = GROUPS[gid];
    const boxG = ce('g', { class: 'group-box', 'data-group': gid });
    boxG.appendChild(ce('rect', {
        x: grp.x, y: grp.y, width: grp.w, height: grp.h, rx: 8, ry: 8,
    }));
    // group が actor によって表現される場合 (representedByActor):
    // → 左上にその actor box が重なって配置されているので、group 独自の
    //   label/sub は描画しない (重複ノイズ防止)
    if (grp.representedByActor) return boxG;
    const lblMain = ce('text', { x: grp.x + 10, y: grp.y - 20 });
    lblMain.textContent = grp.label;
    boxG.appendChild(lblMain);
    if (grp.sub) {
        const lblSub = ce('text', {
            x: grp.x + 10, y: grp.y - 6, class: 'group-sub',
        });
        lblSub.textContent = grp.sub;
        boxG.appendChild(lblSub);
    }
    return boxG;
}

// アクター id が所属する group id を返す (無ければ null)
function findGroupOf(actorId) {
    if (typeof GROUPS === 'undefined') return null;
    // actor を contains する全 group を集めて、parentGroup chain が最も深いものを返す
    const candidates = [];
    for (const gid in GROUPS) {
        if (GROUPS[gid].contains.indexOf(actorId) >= 0) candidates.push(gid);
    }
    if (candidates.length === 0) return null;
    function depthOf(gid) {
        let d = 0; let cur = gid;
        while (GROUPS[cur] && GROUPS[cur].parentGroup) {
            d++; cur = GROUPS[cur].parentGroup;
        }
        return d;
    }
    candidates.sort((a, b) => depthOf(b) - depthOf(a));
    return candidates[0];
}

// fade-in 付きで group box を出す (既に居れば no-op)
function ensureGroupBox(gid) {
    if (groupEls[gid]) return;
    // 親 group があれば先に ensure (cascade up)
    const parentGid = GROUPS[gid] && GROUPS[gid].parentGroup;
    if (parentGid) ensureGroupBox(parentGid);
    const boxG = buildGroupBoxElement(gid);
    // group box は最背面に置く: 現在の stage 先頭の前に insertBefore
    if (stage.firstChild) stage.insertBefore(boxG, stage.firstChild);
    else stage.appendChild(boxG);
    groupEls[gid] = boxG;

    // fade-in (アクター fade-in より少しゆっくり、最終 opacity 0.9 で控えめ)
    boxG.setAttribute('opacity', '0');
    const dur = 600 / state.speed;
    const start = performance.now();
    function frame(now) {
        const t = Math.min((now - start) / dur, 1);
        const eased = 1 - Math.pow(1 - t, 3);
        boxG.setAttribute('opacity', eased * 0.9);
        if (t < 1) requestAnimationFrame(frame);
    }
    requestAnimationFrame(frame);
}

// silent 版 (シーク再構築用、fade 無し)
function silentEnsureGroupBox(gid) {
    if (groupEls[gid]) return;
    const parentGid = GROUPS[gid] && GROUPS[gid].parentGroup;
    if (parentGid) silentEnsureGroupBox(parentGid);
    const boxG = buildGroupBoxElement(gid);
    if (stage.firstChild) stage.insertBefore(boxG, stage.firstChild);
    else stage.appendChild(boxG);
    boxG.setAttribute('opacity', '0.9');
    groupEls[gid] = boxG;
}

// ============================================================
// アクター描画 / spawn
// ============================================================
function drawActor(id, info) {
    const g = ce('g', {
        class: 'actor ' + info.cls,
        transform: `translate(${info.x},${info.y})`,
        'data-actor': id,
    });
    const r = ce('rect', { width: info.w, height: info.h, rx: 6, ry: 6 });
    // label の y を actor の h に応じて動的計算 (小さい box で sub がはみ出さないように)
    //   h=50 で main=22, sub=38 (従来 default)
    //   h=35 で main=15, sub=29
    //   h=30 で main=12, sub=25
    const mainY = Math.max(12, Math.min(22, info.h * 0.45 - 1));
    const subY  = Math.max(mainY + 12, Math.min(38, info.h - 6));
    const tLabel = ce('text', { x: info.w / 2, y: mainY, 'text-anchor': 'middle' });
    tLabel.textContent = info.label;
    const tSub = ce('text', { x: info.w / 2, y: subY, 'text-anchor': 'middle', class: 'sub' });
    tSub.textContent = info.sub;
    g.appendChild(r);
    g.appendChild(tLabel);
    g.appendChild(tSub);
    return g;
}

// 初参照時の spawn (fade-in 付き)。既に居れば no-op。
function ensureActor(id) {
    if (actorEls[id]) return;
    const info = ACTORS[id];
    if (!info) {
        console.warn('Unknown actor id:', id);
        return;
    }
    // ★ このアクターが属する group があれば、先に group box を出す (背面に fade-in)
    const gid = findGroupOf(id);
    if (gid) ensureGroupBox(gid);

    const g = drawActor(id, info);
    // アクターは group box より前面、bubble より後ろ。
    // 描画順: [group boxes (insertBefore で先頭) ... actors (append) ... bubbles (append)]
    stage.appendChild(g);
    actorEls[id] = g;

    // spawn アニメ: opacity 0→1 + 「ここに来たよ」の枠ハイライト
    g.setAttribute('opacity', '0');
    const dur = 500 / state.speed;
    const start = performance.now();
    function frame(now) {
        const t = Math.min((now - start) / dur, 1);
        const eased = 1 - Math.pow(1 - t, 3);   // ease-out cubic
        g.setAttribute('opacity', eased);
        if (t < 1) requestAnimationFrame(frame);
    }
    requestAnimationFrame(frame);
    // 少し遅れて hi-light を入れる ("新登場" の合図)
    setTimer(() => highlightActor(id, '#e0e0e0', 700 / state.speed), 200);
    // 過去の setState が既にあれば spawn 直後に表示反映
    renderDebugPanel();
}

// シークで過去 step 群の参照アクターを silent (no anim) に出す
function silentSpawnActor(id) {
    if (actorEls[id]) return;
    const info = ACTORS[id];
    if (!info) return;
    const gid = findGroupOf(id);
    if (gid) silentEnsureGroupBox(gid);
    const g = drawActor(id, info);
    stage.appendChild(g);
    actorEls[id] = g;
    renderDebugPanel();
}

// step.destroy で指定された actor を fade-out しながら DOM 除去 + actorEls から削除。
// 「QML 側で Loader.active=false → 中身破棄」を視覚化するため。
// 削除済み id は次の ensureActor で再 spawn 可能 (= 同一 actor の再登場対応)。
function fadeOutActor(id, dur) {
    const g = actorEls[id];
    if (!g) return;
    delete actorEls[id];
    delete actorStates[id];
    renderDebugPanel();
    const start = performance.now();
    function frame(now) {
        if (!g.parentNode) return;
        const t = Math.min((now - start) / dur, 1);
        g.setAttribute('opacity', 1 - Math.pow(t, 2));   // ease-in (急 fade)
        if (t < 1) {
            requestAnimationFrame(frame);
        } else if (g.parentNode) {
            g.parentNode.removeChild(g);
        }
    }
    requestAnimationFrame(frame);
}

// シーン状態を「step idx 直前」まで再構築 (silent)。
// → idx 未満の全 step の from/to をアクター集合として展開して silent 配置。
function rebuildSceneTo(idx) {
    clearAllTimers();
    clearAllBubbles();
    clearAllActors();
    // group box は silentSpawnActor 内で必要に応じて silent に出るので、
    // ここで明示的に描画しない (= idx 直前までに登場した group box だけが残る)
    const sc = SCENARIOS[state.scenario];
    // precondition を再適用 (clearAllActors で actorStates が初期化されたので)
    if (sc.precondition) applySetState(sc.precondition);
    if (sc.preSpawned) sc.preSpawned.forEach(silentSpawnActor);
    for (let i = 0; i < idx; i++) {
        const s = sc.steps[i];
        silentSpawnActor(s.from);
        silentSpawnActor(s.to);
        // 過去 step の setState は silent に再適用
        if (s.setState) applySetState(s.setState);
        // 過去 step で destroy された actor は silent に除去
        if (s.destroy) {
            s.destroy.forEach(function (aid) {
                const el = actorEls[aid];
                if (el && el.parentNode) el.parentNode.removeChild(el);
                delete actorEls[aid];
                delete actorStates[aid];
            });
        }
    }
    renderDebugPanel();
}

// ============================================================
// 永続 state 表示 (各アクター直下に key=value を行表示)
//
// step.setState で渡された情報を actorStates に merge し、対応アクターの
// 下に SVG text として描画する。アクターが destroy されたら state も消える。
// シーク時は過去 step の setState を順次再適用して同じ画面に復元。
// ============================================================
function applySetState(setStateObj) {
    if (!setStateObj) return;
    for (const aid in setStateObj) {
        if (!actorStates[aid]) actorStates[aid] = {};
        const upd = setStateObj[aid];
        for (const k in upd) actorStates[aid][k] = upd[k];
    }
    renderDebugPanel();
}

// 右上 debug overlay 全体を再描画 (現存 actor の state を全部一覧表示)
function renderDebugPanel() {
    const dp = document.getElementById('debugPanel');
    if (!dp) return;
    // actorStates に登録があり、かつ現在 actor が live なものだけ表示
    const ids = Object.keys(actorStates).filter(function (id) {
        const a = ACTORS[id];
        const hasState = Object.keys(actorStates[id]).length > 0;
        // pre-instantiated は actorEls 不要 (panel に常時表示)、
        // lazy load 系は spawn 後 (= actorEls[id] あり) のみ表示
        return hasState && (a && a.preInstantiated ? true : !!actorEls[id]);
    });
    let html = '<div class="dp-header">component state</div>';
    if (ids.length === 0) {
        html += '<div class="dp-empty">(まだ state なし)</div>';
        dp.innerHTML = html;
        return;
    }
    ids.forEach(function (id) {
        const info = ACTORS[id];
        const name = info ? info.label : id;
        html += '<div class="dp-actor">';
        html += '<div class="dp-actor-name">' + escapeHtml(name) + '</div>';
        const st = actorStates[id];
        for (const k in st) {
            html += '<div class="dp-row">'
                  + '<span class="dp-key">' + escapeHtml(k) + ':</span>'
                  + '<span class="dp-val">' + escapeHtml(String(st[k])) + '</span>'
                  + '</div>';
        }
        html += '</div>';
    });
    dp.innerHTML = html;
}

// ============================================================
// シナリオ完了演出 (ステージ背景を一瞬チカッと色替えするだけ)
//   原色 #131313 → 黒 #000 → 灰 #3a3a3a → 原色 (CSS @keyframes で滑らかに)
// ============================================================
function showCompletionBanner() {
    stage.classList.add('flash-complete');
    setTimer(function () {
        stage.classList.remove('flash-complete');
    }, 850);
}

function actorCenter(id) {
    const a = ACTORS[id];
    return { x: a.x + a.w / 2, y: a.y + a.h / 2 };
}

function highlightActor(id, color, duration) {
    const g = actorEls[id];
    if (!g) return;
    const rect = g.querySelector('rect');
    const origStroke = rect.getAttribute('stroke');
    const origWidth = rect.getAttribute('stroke-width') || '1';
    rect.setAttribute('stroke', color || '#ffeb3b');
    rect.setAttribute('stroke-width', '3');
    setTimer(() => {
        rect.setAttribute('stroke', origStroke);
        rect.setAttribute('stroke-width', origWidth);
    }, duration !== undefined ? duration : 600 / state.speed);
}

// ============================================================
// メッセージバブルアニメーション
// ============================================================
// done(cancelled) を呼ぶ。cancelled=true なら chain 中断シグナル。
// 3 フェーズ: travel → hold → fadeOut
function sendMessage(fromId, toId, label, kind, done) {
    const fromInfo = ACTORS[fromId];
    const isSelf = fromId === toId;

    // bubble サイズ計算を先行 (sx/sy 計算で bubble.w を使うため)
    const lines = label.split('\n');
    const lineH = 15;
    const padding = 8;
    const maxLen = Math.max(...lines.map(l => l.length));
    const charW = 7.0;
    const w = Math.min(320, maxLen * charW + padding * 2);
    const h = lines.length * lineH + padding * 2 - 2;

    let sx, sy, tx, ty;
    // self-msg の bubble 位置:
    //   default: 上方向 arc (mediator/main/transMgr 等、上にスペースあり)
    //   compact (h <= 40 or cls='view'): bubble の完全な右側に水平配置
    //     (Loader/Screen/View は sibling actor が上にあって up-arc がかぶる)
    const isCompactSelf = isSelf && (fromInfo.h <= 40 || fromInfo.cls === 'view');
    if (isCompactSelf) {
        // bubble 左端が actor 右端から 20px 離れるよう sx を計算
        sx = fromInfo.x + fromInfo.w + 20 + w / 2;
        sy = fromInfo.y + fromInfo.h / 2;
        tx = sx + 50;
        ty = sy;
    } else if (isSelf) {
        sx = fromInfo.x + fromInfo.w * 0.75;
        sy = fromInfo.y;
        tx = fromInfo.x + fromInfo.w * 0.25;
        ty = fromInfo.y;
    } else {
        const from = actorCenter(fromId);
        const to = actorCenter(toId);
        sx = from.x; sy = from.y;
        tx = to.x;   ty = to.y;
    }

    const g = ce('g', { class: 'msg-bubble ' + (kind || ''), opacity: 0 });

    const rect = ce('rect', {
        x: -w / 2, y: -h / 2, width: w, height: h, rx: 4, ry: 4,
    });
    g.appendChild(rect);
    lines.forEach((line, i) => {
        const t = ce('text', {
            x: 0,
            y: -h / 2 + padding + lineH * (i + 0.7),
            'text-anchor': 'middle',
        });
        t.textContent = line;
        g.appendChild(t);
    });

    g.setAttribute('transform', `translate(${sx},${sy})`);
    stage.appendChild(g);   // バブルはアクターより上に来る (insertBefore でなく append)

    // スピードはメッセージ開始時に固定 (再生中の速度変更は次メッセージから反映)
    const speed = state.speed;
    const travelDur = (isSelf ? 1400 : 2200) / speed;
    const holdDur   = (isSelf ? 1700 : 2800) / speed;
    const fadeIn    = 300 / speed;
    const fadeOut   = 450 / speed;
    const totalDur  = travelDur + holdDur + fadeOut;

    const hlColor =
        kind === 'warn'   ? '#f44336' :
        kind === 'action' ? '#ffa726' :
        kind === 'key'    ? '#ffeb3b' :
        kind === 'quiet'  ? '#66bb6a' :
                            '#64b5f6';

    let highlighted = false;
    const start = performance.now();

    function frame(now) {
        if (!g.parentNode) {
            if (done) done(true);
            return;
        }
        if (!state.playing) {
            state.resumeFn = () => requestAnimationFrame(frame);
            return;
        }
        const elapsed = now - start;

        let t, op;
        if (elapsed < travelDur) {
            t = elapsed / travelDur;
            op = elapsed < fadeIn ? Math.min(1, elapsed / fadeIn) : 1;
        } else if (elapsed < travelDur + holdDur) {
            t = 1;
            op = 1;
            if (!highlighted) {
                highlightActor(toId, hlColor, holdDur);
                highlighted = true;
            }
        } else if (elapsed < totalDur) {
            t = 1;
            const fadeProgress = (elapsed - travelDur - holdDur) / fadeOut;
            op = Math.max(0, 1 - fadeProgress);
        } else {
            if (g.parentNode) g.parentNode.removeChild(g);
            if (done) done(false);
            return;
        }

        g.setAttribute('opacity', op);

        let x, y;
        if (isCompactSelf) {
            // 右側横移動 + 軽く上下 wave
            const wave = 5;
            x = sx + (tx - sx) * t;
            y = sy + wave * Math.sin(Math.PI * t * 2);
        } else if (isSelf) {
            const arcHeight = 40;
            x = sx + (tx - sx) * t;
            y = sy - arcHeight * Math.sin(Math.PI * t) - 20;
        } else {
            const eased = t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t;
            x = sx + (tx - sx) * eased;
            y = sy + (ty - sy) * eased;
        }
        // バブル中心位置を viewBox 内に clamp (見切れ防止)
        const vb = stage.viewBox.baseVal;
        const halfW = w / 2;
        const halfH = h / 2;
        const pad = 5;
        x = Math.max(vb.x + halfW + pad, Math.min(x, vb.x + vb.width  - halfW - pad));
        y = Math.max(vb.y + halfH + pad, Math.min(y, vb.y + vb.height - halfH - pad));
        g.setAttribute('transform', `translate(${x},${y})`);

        requestAnimationFrame(frame);
    }
    requestAnimationFrame(frame);
}

// step 1 個を再生 (from/to の spawn を含む)
function playStep(step, doneCb) {
    ensureActor(step.from);
    ensureActor(step.to);
    sendMessage(step.from, step.to, step.label, step.kind, function (cancelled) {
        if (!cancelled) {
            // setState を先に適用 → 表示更新
            if (step.setState) applySetState(step.setState);
            // 続いて destroy 指定の actor を fade-out 除去
            if (step.destroy && step.destroy.length) {
                step.destroy.forEach(function (aid) {
                    fadeOutActor(aid, 500 / state.speed);
                });
            }
        }
        if (doneCb) doneCb(cancelled);
    });
}

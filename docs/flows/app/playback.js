/* flows/app/playback.js
   進行ログパネル + シナリオ再生制御 + シーク制御。
   engine.js の関数 (ensureActor, playStep, rebuildSceneTo, clearAll*) を
   利用する。グローバル状態 state は engine.js 側で宣言済み。

   公開関数 (app.js の UI 配線から呼ばれる):
     loadScenario(name)        - シナリオ切り替え
     runScenario()             - 連続再生開始
     pauseScenario()           - 一時停止
     resetScenario()           - 最初に戻す
     playOneStepForward()      - 1 step 進める
     playOneStepBackward()     - 1 step 戻る
     seekTo(idx, playStepFlag) - 任意 step へジャンプ
*/
'use strict';

// ============================================================
function renderLog(scenarioName) {
    const steps = SCENARIOS[scenarioName].steps;
    logBody.innerHTML = '';
    steps.forEach((s, i) => {
        const d = document.createElement('div');
        d.className = 'entry';
        d.id = 'log-' + i;
        const label = s.label.replace(/\n/g, ' / ');
        d.innerHTML =
            `<span class="step-num">${i + 1}.</span> ` +
            `<span style="color:#bbb">${s.from}</span> → ` +
            `<span style="color:#bbb">${s.to}</span>: ${escapeHtml(label)}`;
        d.style.cursor = 'pointer';
        d.addEventListener('click', () => seekTo(i, true));
        logBody.appendChild(d);
    });
}

function markLogStepCurrent(idx) {
    const all = logBody.querySelectorAll('.entry');
    all.forEach((e, i) => {
        e.classList.remove('current');
        if (i < idx) {
            e.classList.add('done');
        } else if (i === idx) {
            e.classList.add('current');
            e.classList.remove('done');
            e.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
        }
    });
}

function updateLogMarks() {
    const all = logBody.querySelectorAll('.entry');
    all.forEach((e, i) => {
        e.classList.remove('current', 'done');
        if (i < state.stepIdx - 1) {
            e.classList.add('done');
        } else if (i === state.stepIdx - 1) {
            e.classList.add('current');
            e.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
        }
    });
}

function updateSeekBar() {
    const total = SCENARIOS[state.scenario].steps.length;
    seekBar.max = total;
    seekBar.value = state.stepIdx;
    seekText.textContent = state.stepIdx + ' / ' + total;
}

function updatePrevNextButtons() {
    const total = SCENARIOS[state.scenario].steps.length;
    document.getElementById('prevBtn').disabled = state.stepIdx <= 0;
    document.getElementById('nextBtn').disabled = state.stepIdx >= total;
}

// ============================================================
// シナリオロード / 再生制御
// ============================================================
function loadScenario(name) {
    clearAllTimers();
    clearAllBubbles();
    clearAllActors();

    state.scenario = name;
    state.stepIdx = 0;
    state.playing = false;
    state.resumeFn = null;

    // group box とアクターは step 進行に応じて順次 fade-in 登場 (空ステージで開始)

    const sc = SCENARIOS[name];
    // シナリオが precondition を持つ場合: 開始時 state スナップショットを適用
    // (= シナリオ開始前にアプリが既にその状態だった、と仮定)
    if (sc.precondition) {
        applySetState(sc.precondition);
    }
    // シナリオ前提として既にロード済みの lazy actor を silent 配置
    if (sc.preSpawned) {
        sc.preSpawned.forEach(silentSpawnActor);
    }
    renderLog(name);
    updateLogMarks();
    updateSeekBar();
    document.getElementById('scenarioDesc').innerHTML =
        '<strong>' + sc.title + '</strong>: ' + sc.desc;
    statusText.style.color = '';
    statusText.style.fontWeight = '';
    statusText.textContent = '待機中 (' + sc.steps.length + ' steps)';
    document.getElementById('playBtn').disabled = false;
    document.getElementById('playBtn').textContent = '▶ 再生';
    updatePrevNextButtons();
}

function runScenario() {
    const sc = SCENARIOS[state.scenario];
    state.playing = true;
    document.getElementById('playBtn').disabled = false;
    document.getElementById('playBtn').textContent = '⏸ 一時停止';

    if (state.stepIdx === 0) {
        logBody.querySelectorAll('.entry').forEach(e => {
            e.classList.remove('current', 'done');
        });
    }

    function next() {
        if (!state.playing) {
            state.resumeFn = next;
            return;
        }
        if (state.stepIdx >= sc.steps.length) {
            statusText.textContent = '✓ 完了 (' + sc.steps.length + ' steps)';
            statusText.style.color = '#81c784';
            statusText.style.fontWeight = '700';
            showCompletionBanner();
            state.playing = false;
            document.getElementById('playBtn').disabled = false;
            document.getElementById('playBtn').textContent = '▶ 最初から再生';
            updateLogMarks();
            updateSeekBar();
            updatePrevNextButtons();
            return;
        }
        const step = sc.steps[state.stepIdx];
        markLogStepCurrent(state.stepIdx);
        statusText.textContent = `Step ${state.stepIdx + 1}/${sc.steps.length}: ${step.from} → ${step.to}`;
        playStep(step, (cancelled) => {
            if (cancelled) return;
            state.stepIdx++;
            updateLogMarks();
            updateSeekBar();
            updatePrevNextButtons();
            const interStepDelay = 550 / state.speed;
            setTimer(next, interStepDelay);
        });
    }
    next();
}

function pauseScenario() {
    state.playing = false;
    const sc = SCENARIOS[state.scenario];
    statusText.textContent = `一時停止 (Step ${state.stepIdx + 1}/${sc.steps.length})`;
    document.getElementById('playBtn').disabled = false;
    document.getElementById('playBtn').textContent = '▶ 続き再生';
}

function resetScenario() {
    clearAllTimers();
    clearAllBubbles();
    loadScenario(state.scenario);
}

// 単 step 進む: stepIdx の step を再生して stepIdx++
function playOneStepForward() {
    const sc = SCENARIOS[state.scenario];
    if (state.stepIdx >= sc.steps.length) return;

    clearAllTimers();
    clearAllBubbles();
    state.playing = true;
    state.resumeFn = null;

    const step = sc.steps[state.stepIdx];
    markLogStepCurrent(state.stepIdx);
    statusText.textContent = `(単 step) ${state.stepIdx + 1}/${sc.steps.length}: ${step.from} → ${step.to}`;
    playStep(step, (cancelled) => {
        if (!cancelled) {
            state.stepIdx++;
            state.playing = false;
            updateLogMarks();
            updateSeekBar();
            updatePrevNextButtons();
            document.getElementById('playBtn').disabled = false;
        }
    });
    updatePrevNextButtons();
}

// 単 step 戻る: stepIdx-- して その step を再生
function playOneStepBackward() {
    if (state.stepIdx <= 0) return;

    state.stepIdx--;
    // シーン状態を「step stepIdx 直前」に巻き戻す (= idx 未満のアクターは silent 再構築)
    rebuildSceneTo(state.stepIdx);
    state.playing = true;
    state.resumeFn = null;

    const sc = SCENARIOS[state.scenario];
    const step = sc.steps[state.stepIdx];
    markLogStepCurrent(state.stepIdx);
    statusText.textContent = `(戻り) ${state.stepIdx + 1}/${sc.steps.length}: ${step.from} → ${step.to}`;
    playStep(step, (cancelled) => {
        if (!cancelled) {
            state.stepIdx++;
            state.playing = false;
            updateLogMarks();
            updateSeekBar();
            updatePrevNextButtons();
            document.getElementById('playBtn').disabled = false;
        }
    });
    updateSeekBar();
    updatePrevNextButtons();
}

// 任意位置にシーク (シーン状態も再構築)
function seekTo(idx, playStepFlag) {
    const sc = SCENARIOS[state.scenario];
    const total = sc.steps.length;
    idx = Math.max(0, Math.min(total, idx));

    state.playing = false;
    state.resumeFn = null;

    if (idx >= total) {
        rebuildSceneTo(total);
        state.stepIdx = total;
        statusText.textContent = '完了位置 (' + total + ' steps)';
        document.getElementById('playBtn').disabled = false;
        document.getElementById('playBtn').textContent = '▶ 最初から再生';
        updateLogMarks();
        updateSeekBar();
        updatePrevNextButtons();
        return;
    }

    // シーン状態を idx 直前まで再構築
    rebuildSceneTo(idx);

    if (playStepFlag) {
        state.stepIdx = idx;
        state.playing = true;
        const step = sc.steps[idx];
        markLogStepCurrent(idx);
        statusText.textContent = `(seek) ${idx + 1}/${total}: ${step.from} → ${step.to}`;
        playStep(step, (cancelled) => {
            if (!cancelled) {
                state.stepIdx = idx + 1;
                state.playing = false;
                updateLogMarks();
                updateSeekBar();
                updatePrevNextButtons();
                document.getElementById('playBtn').disabled = false;
                document.getElementById('playBtn').textContent =
                    state.stepIdx >= total ? '▶ 最初から再生' : '▶ 続き再生';
            }
        });
        updateSeekBar();
        updatePrevNextButtons();
    } else {
        // silent jump (再生せず位置だけセット)
        state.stepIdx = idx;
        markLogStepCurrent(idx);
        statusText.textContent = `Step ${idx + 1}/${total} 待機中`;
        document.getElementById('playBtn').disabled = false;
        document.getElementById('playBtn').textContent = '▶ ここから再生';
        updateSeekBar();
        updatePrevNextButtons();
    }
}

// ============================================================

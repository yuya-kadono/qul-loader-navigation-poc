/* flows/app/app.js
   UI 配線 (event listener 接続) + heartbeat (server 自動終了用) + 初期化。
   engine.js / playback.js / scenarios.js の関数・グローバルを利用する。

   <script> 読み込み順:
     scenarios.js → engine.js → playback.js → app.js
*/
'use strict';

// UI 配線
// ============================================================
document.getElementById('scenarioSel').addEventListener('change', e => {
    loadScenario(e.target.value);
});
document.getElementById('playBtn').addEventListener('click', () => {
    // 再生中なら一時停止トグル
    if (state.playing) {
        pauseScenario();
        return;
    }
    if (state.resumeFn) {
        const fn = state.resumeFn;
        state.resumeFn = null;
        state.playing = true;
        document.getElementById('playBtn').textContent = '⏸ 一時停止';
        const sc = SCENARIOS[state.scenario];
        statusText.textContent = `Step ${state.stepIdx + 1}/${sc.steps.length}`;
        fn();
    } else {
        if (state.stepIdx >= SCENARIOS[state.scenario].steps.length) {
            // 完了済みからの再生 → リセットして頭から
            rebuildSceneTo(0);
            state.stepIdx = 0;
            logBody.querySelectorAll('.entry').forEach(function (e) {
                e.classList.remove('current', 'done');
            });
            updateSeekBar();
        }
        runScenario();
    }
});
document.getElementById('prevBtn').addEventListener('click', playOneStepBackward);
document.getElementById('nextBtn').addEventListener('click', playOneStepForward);
document.getElementById('resetBtn').addEventListener('click', resetScenario);
document.getElementById('speedSlider').addEventListener('input', function (e) {
    state.speed = parseFloat(e.target.value);
    document.getElementById('speedVal').textContent = state.speed.toFixed(2) + '×';
});

// シークバー: input (ドラッグ中) で silent jump、ダブルクリックでその step を再生
seekBar.addEventListener('input', function (e) {
    var idx = parseInt(e.target.value, 10);
    seekTo(idx, false);
});
seekBar.addEventListener('dblclick', function (e) {
    var idx = parseInt(e.target.value, 10);
    seekTo(idx, true);
});

// ============================================================
// 初期化
// ============================================================
loadScenario('startup');

// ============================================================
// サーバー heartbeat (server.py の自動終了用)
//   - 3 秒毎に /__ping__ を送信
//   - タブを閉じる時は /__shutdown__ に sendBeacon で即時通知
//   - file:// で開いた時は両方失敗するがエラーは無視
// ============================================================
setInterval(function () {
    fetch('/__ping__', { cache: 'no-store' }).catch(function () {});
}, 3000);

window.addEventListener('beforeunload', function () {
    try {
        navigator.sendBeacon('/__shutdown__', '');
    } catch (e) { /* file:// 等で失敗しても無視 */ }
});
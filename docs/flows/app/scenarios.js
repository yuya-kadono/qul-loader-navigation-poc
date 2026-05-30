/* flows/app/scenarios.js
   シナリオ集約。実体は scenarios/NN-*.js に分割されており、
   各ファイルが `SCENARIOS.<id> = { ... }` の形で代入する。
   ここでは空オブジェクトを先に作るだけ。

   <script> 読み込み順 (index.html):
     actors.js → groups.js → scenarios.js → scenarios/01-startup.js → ... → scenarios/05-sample2.js
       → engine.js → playback.js → app.js

   各 step は { from, to, label, kind } 形式。
   kind = 'key' | 'msg' | 'action' | 'warn' | 'quiet' | 'self'
       (self は from===to の同アクター内処理。CSS で色分け)
*/
'use strict';

const SCENARIOS = {};

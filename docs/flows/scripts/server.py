"""flows/scripts/server.py
カスタムローカル HTTP サーバー (POC アニメ専用):
  - flows/app/ フォルダの静的ファイルを配信 (このスクリプトの親の app/)
  - /__ping__       : ブラウザからの heartbeat 受信、最終受信時刻を更新
  - /__shutdown__   : ブラウザ tab 閉じ時の即時終了要求 (sendBeacon 経由)
  - watchdog thread : 10 秒間 ping 無しなら自動終了
                       (ブラウザを閉じ忘れて放置してもプロセスが残らない)

起動: python server.py (普通は ../start_app.bat / ./start_app.sh 経由)
"""

import http.server
import socketserver
import threading
import time
import os
import sys

PORT = 8765
PING_TIMEOUT_SEC = 10  # 最後の ping からこの秒数経過で自動終了

# 起動直後はまだ ping が来ていないので、起動時刻を基準にして grace 期間を作る
last_ping_time = time.time()
ping_lock = threading.Lock()


class Handler(http.server.SimpleHTTPRequestHandler):
    """flows/ を root として配信する HTTP handler。
    特別な path (/__ping__ / /__shutdown__) は管理 API として扱う。
    """

    # ★ 全レスポンスに no-store を付与 → ブラウザの強キャッシュを抑止
    #    (POC 開発中に app.js / scenarios.js を頻繁に書き換えるため、
    #     リロード時に必ず最新を取得させる)
    def end_headers(self):
        self.send_header('Cache-Control', 'no-store, no-cache, must-revalidate')
        self.send_header('Pragma', 'no-cache')
        self.send_header('Expires', '0')
        super().end_headers()

    # 標準のアクセスログを抑制 (ping が毎秒来るので noisy)
    def log_message(self, format, *args):
        path = self.path if hasattr(self, 'path') else ''
        if path.startswith('/__'):
            return  # 管理 API のログは出さない
        # それ以外は通常ログ
        sys.stderr.write("%s - %s\n" % (self.address_string(), format % args))

    def do_GET(self):
        global last_ping_time

        if self.path == '/__ping__':
            # heartbeat 受信
            with ping_lock:
                last_ping_time = time.time()
            self.send_response(204)  # No Content
            self.send_header('Cache-Control', 'no-store')
            self.end_headers()
            return

        if self.path == '/__shutdown__':
            # 即時終了要求 (sendBeacon は GET でも飛んでくる)
            self._do_shutdown()
            return

        # 通常の静的ファイル配信
        super().do_GET()

    def do_POST(self):
        # sendBeacon は通常 POST で来る
        if self.path == '/__shutdown__':
            self._do_shutdown()
            return
        self.send_error(404)

    def _do_shutdown(self):
        print('\n[server] shutdown request from browser')
        self.send_response(204)
        self.send_header('Cache-Control', 'no-store')
        self.end_headers()
        # レスポンスを送ってから少し待って exit
        threading.Thread(target=lambda: (time.sleep(0.3), os._exit(0)),
                         daemon=True).start()


def watchdog():
    """2 秒毎に最終 ping 時刻をチェック。タイムアウト超えたら自動終了。"""
    while True:
        time.sleep(2)
        with ping_lock:
            elapsed = time.time() - last_ping_time
        if elapsed > PING_TIMEOUT_SEC:
            print(f'\n[server] no heartbeat for {elapsed:.1f}s '
                  f'(timeout {PING_TIMEOUT_SEC}s) — shutting down')
            os._exit(0)


def main():
    # このスクリプト (flows/scripts/server.py) の親フォルダの app/ を配信ルートにする
    #   = flows/app/index.html, app.js, style.css, scenarios.js
    script_dir = os.path.dirname(os.path.abspath(__file__))
    app_dir = os.path.join(script_dir, '..', 'app')
    os.chdir(app_dir)

    # SO_REUSEADDR で再起動時の Address already in use を回避
    socketserver.TCPServer.allow_reuse_address = True

    try:
        server = socketserver.TCPServer(('127.0.0.1', PORT), Handler)
    except OSError as e:
        print(f'[server] failed to bind port {PORT}: {e}', file=sys.stderr)
        sys.exit(1)

    threading.Thread(target=watchdog, daemon=True).start()
    print(f'[server] serving flows/app/ at http://localhost:{PORT}/')
    print(f'[server] auto-shutdown after {PING_TIMEOUT_SEC}s without browser heartbeat')
    print(f'[server] (ブラウザでタブを閉じると自動で終了します。Ctrl+C で手動終了も可)')

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print('\n[server] Ctrl+C, shutting down')
        sys.exit(0)


if __name__ == '__main__':
    main()

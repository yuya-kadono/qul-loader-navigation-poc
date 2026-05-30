#!/usr/bin/env bash
# ============================================================
# flows アニメーションをブラウザで開く (macOS / Linux)
#
# 動作:
#   1. server.py をバックグラウンド起動 (同フォルダ内、../app を配信)
#   2. 既定ブラウザで http://localhost:8765/ を開く
#   3. ブラウザのタブを閉じると server.py 側の watchdog が
#      heartbeat 切れを検知して自動終了する (10 秒後)
#
# 必要: Python 3
# 起動: flows/ で  ./scripts/start_app.sh
#   (またはこの scripts/ フォルダ内で  ./start_app.sh)
# 手動終了: Ctrl+C
# ============================================================
cd "$(dirname "$0")"  # scripts/ に固定
echo
echo "flows animation を http://localhost:8765/ で配信します"
echo "ブラウザのタブを閉じると自動でサーバーも終了します"
echo "(手動終了は Ctrl+C)"
echo

# 既定ブラウザで開く (バックグラウンドで)
if command -v open >/dev/null 2>&1; then
    open "http://localhost:8765/"
elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "http://localhost:8765/"
fi

python3 server.py

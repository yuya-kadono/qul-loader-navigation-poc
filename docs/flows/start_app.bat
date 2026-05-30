@echo off
REM ============================================================
REM flows アニメーションをブラウザで開く (Windows)
REM
REM 動作:
REM   1. scripts/server.py をバックグラウンド起動
REM      (server.py 自身が ../app に chdir して app/ を配信)
REM   2. 既定ブラウザで http://localhost:8765/ を開く
REM   3. ブラウザのタブを閉じると server.py 側の watchdog が
REM      heartbeat 切れを検知して自動終了する (10 秒後)
REM
REM 必要: Python 3 (PATH に通っていること)
REM 起動: このバッチファイルをダブルクリック
REM 手動終了: コマンドプロンプトのウィンドウで Ctrl+C
REM ============================================================
cd /d "%~dp0"
echo.
echo  flows animation を http://localhost:8765/ で配信します
echo  ブラウザのタブを閉じると自動でサーバーも終了します
echo  [手動終了は Ctrl+C]
echo.
start "" "http://localhost:8765/"
python scripts\server.py

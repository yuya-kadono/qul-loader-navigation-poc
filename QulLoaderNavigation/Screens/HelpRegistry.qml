// HelpRegistry.qml — メインモジュール所属 singleton
// viewId → 操作ヘルプ文字列マップ。Main.qml の左上 overlay が表示する。
//
// 設計上の役割:
//   操作ヘルプ (例: "BACK(C): menu へ戻る") は元々各 view の bottom Text に書いていたが、
//   debug overlay と同じ思想で「画面中央には情報を出さず overlay に集約」する。
//   Main.qml が `HelpRegistry.helpFor(Mediator.currentViewId)` でライブに表示する。
//
//   ScreenRegistry と同じ理由で、Constants の ViewId enum は値だけを持ち、
//   ヘルプ文字列は知らない (依存方向の一方向性維持)。
//
// 画面の操作ロジックを変更したらこのファイルも更新する (sync 必要)。
// 「ヘルプを変えたいが view 側を触りたくない」場合はこのファイルだけ編集すれば済む。

pragma Singleton
import QtQml
import Constants

QtObject {
    function helpFor(viewId) {
        switch (viewId) {
            case ViewId.OpeningOpening:
                return ""   // 入力受付なし
            case ViewId.NormalHome:
                return "ENTER(S): closing | MENU(Z): menu"
            case ViewId.NormalMenu:
                return "PREV(A) / NEXT(D): カーソル | ENTER(S): 決定 | BACK(C): home"
            case ViewId.NormalSample1:
                return "BACK(C): menu | HOME(X): home"
            case ViewId.NormalSample2a:
                return "BACK(C): menu | HOME(X): home"
            case ViewId.NormalSample2b:
                return "BACK(C): menu | HOME(X): home"
            case ViewId.ClosingClosing:
                return "BACK(C) または HOME(X): 中断"
        }
        return ""
    }
}

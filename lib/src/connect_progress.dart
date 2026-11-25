/// 鄉民端點了看板之後，連線進行到哪一步。順序就是宣告的順序。
enum ConnectStage {
  /// 還在連看板端，加入要求還沒送出去。
  reaching,

  /// 已經送出加入要求，在等看板端的連線資訊。
  waitingForOffer,

  /// 收到看板端的連線資訊了，雙方正在交換網路路徑。
  exchangingPaths,

  /// 看板端說它的網路路徑全部送完了。
  pathsComplete,
}

/// 等到逾時畫面還是沒出來的原因。
enum ConnectFailure {
  /// 連不到看板端。
  boardUnreachable,

  /// 連到了，但看板端一直沒有送連線資訊過來。
  boardSilent,

  /// 交換網路路徑到一半就沒有下文。
  exchangeStalled,

  /// 看板端的網路路徑都送完了，卻沒有一條連得通。
  /// 重試沒有用，要換網路；常見原因是熱點不允許裝置互相連線。
  noWorkingPath,
}

/// 從點了看板到畫面出現，最多等多久。
///
/// 兩端只在同一個區域網路內連線，正常情況很快就會連上，所以不需要久等。
/// 這段時間包含看板端開鏡頭（第一個鄉民端加入時才開）。
///
/// 2026-11-25 在一般 Wi-Fi 上用實機量了五次，花了 0.9～2.2 秒，
/// 5 秒是最慢那次的兩倍以上。重新量的方法見 README 的整合測試。
const Duration connectTimeout = Duration(seconds: 5);

/// 記錄連線進行到哪一步，逾時的時候據此判斷原因。
///
/// 逾時本身（計時）由 app 那一層做；這裡只管「逾時當下該怪誰」。
class ConnectProgress {
  ConnectStage _stage = ConnectStage.reaching;

  ConnectStage get stage => _stage;

  /// 連線又往前一步。只會往前：晚到或重複的通知不會讓進度倒退。
  void advanceTo(ConnectStage stage) {
    if (stage.index > _stage.index) _stage = stage;
  }

  /// 如果現在逾時，原因是什麼。
  ConnectFailure get failureOnTimeout => switch (_stage) {
    ConnectStage.reaching => ConnectFailure.boardUnreachable,
    ConnectStage.waitingForOffer => ConnectFailure.boardSilent,
    ConnectStage.exchangingPaths => ConnectFailure.exchangeStalled,
    ConnectStage.pathsComplete => ConnectFailure.noWorkingPath,
  };
}

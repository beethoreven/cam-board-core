// 「卡住時自己救回來」的規則。
//
// 網路有時會讓某一條連線幾乎不通（2026-11-27 在使用者家裡的 Wi-Fi 上查到：基地台
// 會把手機往電腦的某一條連線幾乎全部丟掉，同時其他連線正常）。這種時候兩端不能
// 默默卡著：鄉民端要發現、換一條新的連線接回來；救不回來就明確結束。

/// 鄉民端多久問看板端一次「你還在嗎」。
const Duration heartbeatInterval = Duration(seconds: 1);

/// 問了之後這麼久都沒有任何回應，就當成這條連線卡住了，換一條新的。
const Duration heartbeatTimeout = Duration(seconds: 3);

/// 看板端說要傳照片之後，資料這麼久還沒到，就換一條新的連線請它再送一次。
/// 正常情況不到一秒。
const Duration shotDataTimeout = Duration(seconds: 3);

/// 一張照片最多補送幾次。
const int maxShotResends = 3;

/// 一張照片從第一次送出起，這麼久還沒被確認就放棄，並告訴看板端的使用者。
const Duration shotGiveUpAfter = Duration(seconds: 10);

/// 看板端為了補送而留在記憶體裡、還沒被確認的照片，最多佔多少。
const int maxPendingShotBytes = 20 * 1024 * 1024;

/// 鄉民端連續這麼久沒有解出新畫面，就把視訊連線整條重建。
/// 掉幾個封包、頓一兩秒不算，那是視訊自己會處理的。
const Duration videoStallTimeout = Duration(seconds: 5);

/// 連續救幾次都沒救回來就放棄（視訊重建、換連線各自計算）。
const int maxRecoveryAttempts = 3;

/// 鄉民端的連線斷掉之後，看板端這麼久之內還讓它接回來；過了就當成離開。
const Duration resumeGrace = Duration(seconds: 10);

/// 連續失敗幾次的計數：救成功就歸零，連續失敗 [limit] 次就該放棄。
class RecoveryAttempts {
  RecoveryAttempts({this.limit = maxRecoveryAttempts});

  final int limit;
  int _failed = 0;

  /// 已經連續失敗幾次。
  int get failedInARow => _failed;

  /// 這一次沒有救回來。
  void failed() => _failed++;

  /// 救回來了，之後再壞就重新算。
  void succeeded() => _failed = 0;

  /// 該放棄了。
  bool get exhausted => _failed >= limit;
}

/// 判斷鄉民端的畫面是不是停住了：解出來的張數有增加就是有在動。
///
/// 時間由呼叫端給（從任一個固定起點算起的經過時間），這裡不看時鐘，才測得了。
class VideoStallDetector {
  VideoStallDetector({this.timeout = videoStallTimeout});

  final Duration timeout;
  int _frames = 0;
  Duration? _lastProgress;

  /// 目前的視訊連線解出過畫面了。重建之後要等這個變成 true 才算救回來。
  bool get hasPicture => _frames > 0;

  /// 視訊連線剛建好（或剛重建）：張數從零算起，從現在開始等畫面。
  void connectionStarted(Duration now) {
    _frames = 0;
    _lastProgress = now;
  }

  /// 讀到一次統計：到目前為止解出 [framesDecoded] 張。回傳畫面是不是停住了。
  bool sample(int framesDecoded, Duration now) {
    _lastProgress ??= now;
    if (framesDecoded > _frames) {
      _frames = framesDecoded;
      _lastProgress = now;
      return false;
    }
    return now - _lastProgress! >= timeout;
  }
}

/// 鄉民端確認看板端還有回應：定時送出一個編號，看板端要原樣回覆。
///
/// 只要收到看板端的任何東西（不限於回覆）都算有回應，因為要確認的是
/// 「看板端到鄉民端這個方向還通」。
class Heartbeat {
  Heartbeat({this.timeout = heartbeatTimeout});

  final Duration timeout;
  int _next = 0;
  Duration? _waitingSince;

  /// 要送出下一次詢問了，回傳要帶的編號。
  int ask(Duration now) {
    _waitingSince ??= now;
    return ++_next;
  }

  /// 收到看板端的任何訊息或資料。
  void heard() => _waitingSince = null;

  /// 問了卻太久沒有任何回應：這條連線卡住了。
  bool silent(Duration now) {
    final since = _waitingSince;
    return since != null && now - since >= timeout;
  }

  /// 換了一條新的連線，重新開始算。
  void reset() => _waitingSince = null;
}

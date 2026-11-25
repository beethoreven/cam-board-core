import 'signal_message.dart';

/// 鄉民端目前的狀態。
enum ViewerState {
  /// 在看板清單，還沒看任何看板。
  browsing,

  /// 點了看板，正在連線。
  connecting,

  /// 正在看畫面。
  watching,
}

/// 鄉民端「一次只看一個看板」的規則。
///
/// 只管狀態能不能這樣轉換；實際的網路連線由 app 那一層做，
/// 做之前先問這裡，就不會出現「同時連兩個看板」這類狀況。
class ViewerSession {
  ViewerState _state = ViewerState.browsing;
  ByeReason? _lastEndReason;

  ViewerState get state => _state;

  /// 上一次觀看是怎麼結束的。連線中斷或逾時（沒有任何一方說結束）時是 null。
  ByeReason? get lastEndReason => _lastEndReason;

  /// 點了清單上的一個看板。
  void startConnecting() {
    _require(ViewerState.browsing, '已經在看一個看板了，要先按「不看了」');
    _state = ViewerState.connecting;
    _lastEndReason = null;
  }

  /// 收到第一張畫面。
  void videoArrived() {
    _require(ViewerState.connecting, '還沒開始連線就收到畫面');
    _state = ViewerState.watching;
  }

  /// 結束觀看，回到看板清單。連線中或觀看中都可以結束。
  ///
  /// [reason] 是明確的結束原因；連線中斷、逾時這類沒有人說「結束」的情況給 null。
  void end(ByeReason? reason) {
    if (_state == ViewerState.browsing) return;
    _state = ViewerState.browsing;
    _lastEndReason = reason;
  }

  void _require(ViewerState expected, String message) {
    if (_state != expected) throw StateError(message);
  }
}

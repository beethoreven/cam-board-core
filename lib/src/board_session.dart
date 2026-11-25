import 'board_info.dart';

/// 鄉民端送出「我要看」之後，看板端最多等多久它回覆連線資訊。
/// 超過就當它不看了：鏡頭不能為了一個沒有下文的連線一直開著。
/// 正常的鄉民端自己只等 5 秒（見 `connect_progress.dart`），這裡留了餘裕。
const Duration answerTimeout = Duration(seconds: 10);

/// 看板端目前的狀態。
enum BoardState {
  /// 還沒註冊，鄉民端看不到這個看板。
  unregistered,

  /// 已註冊，在看板清單上等候，還沒有人在看。
  waiting,

  /// 至少有一個鄉民端正在看。
  showing,
}

/// 看板端的規則：註冊、撤銷註冊、誰正在看。
///
/// 一個看板可以同時給多個鄉民端看，所以這裡記的是「正在看的鄉民端」的集合。
class BoardSession {
  String? _name;
  final Set<String> _viewers = {};

  /// 註冊時取的名字；沒註冊時是 null。
  String? get name => _name;

  /// 正在看的鄉民端數量。
  int get viewerCount => _viewers.length;

  BoardState get state {
    if (_name == null) return BoardState.unregistered;
    return _viewers.isEmpty ? BoardState.waiting : BoardState.showing;
  }

  /// 註冊看板。名字不合規定時丟 [BoardNameException]。
  void register(String name) {
    if (_name != null) throw StateError('已經註冊了，要先撤銷註冊');
    _name = validateBoardName(name);
  }

  /// 一個鄉民端連上來了。註冊本身就代表同意，所以不需要再確認。
  void viewerJoined(String viewerId) {
    if (_name == null) throw StateError('還沒註冊，不能被觀看');
    _viewers.add(viewerId);
  }

  /// 一個鄉民端離開了（按「不看了」或斷線）。
  void viewerLeft(String viewerId) => _viewers.remove(viewerId);

  /// 按「不給看了」：所有鄉民端都結束觀看，看板仍然留在清單上等候。
  /// 回傳被結束的鄉民端，讓 app 那一層去通知它們。
  Set<String> stopShowing() {
    final stopped = Set.of(_viewers);
    _viewers.clear();
    return stopped;
  }

  /// 撤銷註冊：從清單上消失，正在看的鄉民端也一併結束。
  /// 回傳被結束的鄉民端。
  Set<String> unregister() {
    final stopped = stopShowing();
    _name = null;
    return stopped;
  }
}

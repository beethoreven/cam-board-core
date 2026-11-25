// 「抄錄」的規則：看板端按拍照，抄錄中的鄉民端各自把那張照片存下來。

/// 把名稱變成可以當資料夾或檔案名稱的樣子。
///
/// macOS 和 Windows 不能用在檔名裡的字元（`/ \ : * ? " < > |` 與控制字元）
/// 換成底線；Windows 不允許結尾是句點或空白，所以一併去掉。
/// 什麼都不剩時用「看板」。
String safeFileName(String name) {
  final replaced = name.replaceAll(RegExp(r'[/\\:*?"<>|\x00-\x1f]'), '_');
  final trimmed = replaced.trim().replaceAll(RegExp(r'[. ]+$'), '');
  return trimmed.isEmpty ? '看板' : trimmed;
}

/// 一次抄錄用的資料夾名稱：`{看板名稱}抄錄紀錄_26-11-25-14-30-05`。
String recordingFolderName(String boardName, DateTime startedAt) {
  String two(int value) => (value % 100).toString().padLeft(2, '0');
  final time = [
    startedAt.year,
    startedAt.month,
    startedAt.day,
    startedAt.hour,
    startedAt.minute,
    startedAt.second,
  ].map(two).join('-');
  return '${safeFileName(boardName)}抄錄紀錄_$time';
}

/// 一次抄錄裡第 [number] 張照片的檔名，從 1 開始：`001.png`。
String shotFileName(int number) => '${number.toString().padLeft(3, '0')}.png';

/// 鄉民端這一邊的抄錄狀態。
class ViewerRecording {
  String? _folder;
  int _saved = 0;

  bool get active => _folder != null;

  /// 這次抄錄存放照片的資料夾。沒有在抄錄時是 null。
  String? get folder => _folder;

  /// 這次抄錄已經存了幾張。
  int get savedCount => _saved;

  /// 開始抄錄，照片存到 [folder]。
  void start(String folder) {
    if (active) throw StateError('已經在抄錄了，要先按「抄錄完了」');
    _folder = folder;
    _saved = 0;
  }

  /// 下一張照片該用的檔名。
  String nextFileName() {
    if (!active) throw StateError('沒有在抄錄');
    return shotFileName(_saved + 1);
  }

  /// 剛才那張存好了。
  void saved() {
    if (active) _saved++;
  }

  /// 抄錄完了。沒有在抄錄時不做任何事。
  void stop() => _folder = null;
}

/// 看板端這一邊：記錄每個鄉民端的名稱，以及哪些正在抄錄。
class BoardRecorders {
  final Map<String, String> _names = {};
  final Set<String> _recording = {};

  /// 一個鄉民端加入了。
  void joined(String viewerId, String name) => _names[viewerId] = name;

  /// 一個鄉民端離開了。它如果在抄錄，也跟著結束。
  void left(String viewerId) {
    _names.remove(viewerId);
    _recording.remove(viewerId);
  }

  /// 鄉民端開始抄錄。還沒加入的鄉民端不算。
  void started(String viewerId) {
    if (_names.containsKey(viewerId)) _recording.add(viewerId);
  }

  /// 鄉民端抄錄完了。
  void stopped(String viewerId) => _recording.remove(viewerId);

  /// 正在抄錄的鄉民端，拍照時要把照片傳給它們。
  Set<String> get recording => Set.unmodifiable(_recording);

  bool isRecording(String viewerId) => _recording.contains(viewerId);

  /// 鄉民端的名稱。不認得這個鄉民端時是 null。
  String? nameOf(String viewerId) => _names[viewerId];

  /// 全部清掉（不給看了、撤銷註冊）。
  void clear() {
    _names.clear();
    _recording.clear();
  }
}

/// 看板端顯示的提示：誰把這張照片存下來了。
String shotSavedNotice(String viewerName) => '$viewerName抄錄了這個內容';

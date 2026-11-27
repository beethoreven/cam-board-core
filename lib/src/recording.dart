// 「抄錄」的規則：看板端按拍照，抄錄中的鄉民端各自把那張照片存下來。

import 'raw_frame.dart';
import 'recovery.dart';

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

/// 鄉民名稱最多幾個字。它會顯示在看板端的提示裡。
const int maxViewerNameLength = 30;

/// 整理鄉民端報上來的名稱：去掉控制字元和頭尾空白，太長就截短。
String cleanViewerName(String name) {
  final cleaned = name.replaceAll(RegExp(r'[\x00-\x1f\x7f]'), ' ').trim();
  final characters = cleaned.runes.toList();
  if (characters.length <= maxViewerNameLength) return cleaned;
  return String.fromCharCodes(characters.take(maxViewerNameLength)).trim();
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

  /// 這次抄錄已經收過的照片編號。照片卡住時看板端會補送，補送的那一張
  /// 可能其實已經收過了（只是回報沒送到），不能再存一次。
  final Set<int> _received = {};

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
    _received.clear();
  }

  /// 收到編號 [shotId] 的照片。第一次收到回傳 true（要存）；
  /// 已經收過回傳 false（只要再回報一次收到，不要再存）。
  bool firstTime(int shotId) => _received.add(shotId);

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

  /// 每個鄉民端還沒回報「收到了」的照片，照編號排。畫面留著是為了補送：
  /// 鄉民端沒拿到時，看板端要能把同一張再給一次。
  final Map<String, Map<int, PendingShot>> _awaiting = {};

  /// 一個鄉民端加入了。
  void joined(String viewerId, String name) => _names[viewerId] = name;

  /// 一個鄉民端離開了。它如果在抄錄，也跟著結束。
  void left(String viewerId) {
    _names.remove(viewerId);
    _recording.remove(viewerId);
    _awaiting.remove(viewerId);
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

  /// 編號 [shotId] 的照片傳給這個鄉民端了，等它回報收到。
  /// 有給 [frame] 的話留著，之後才能補送。
  void shotSent(String viewerId, int shotId, [RawFrame? frame]) {
    if (_names.containsKey(viewerId)) {
      _awaiting.putIfAbsent(viewerId, () => {})[shotId] = PendingShot._(
        shotId,
        frame,
      );
    }
  }

  /// 還沒被確認的照片總共佔多少記憶體。同一張傳給好幾個鄉民端只算一次，
  /// 因為它們共用同一份畫面。
  int get pendingBytes {
    final sizes = <int, int>{};
    for (final shots in _awaiting.values) {
      for (final shot in shots.values) {
        final frame = shot.frame;
        if (frame != null) sizes[shot.id] = frame.i420.length;
      }
    }
    return sizes.values.fold(0, (sum, size) => sum + size);
  }

  /// 再留一張 [bytes] 這麼大的照片，會不會超過上限（[maxPendingShotBytes]）。
  /// 會的話這一次不能拍：前面的還沒送到，再拍只會越積越多。
  bool hasRoomFor(int bytes) => pendingBytes + bytes <= maxPendingShotBytes;

  /// 這個鄉民端接回來了：回傳要補送給它的照片（照編號），並各記一次補送。
  /// 已經補送過 [maxShotResends] 次的不再送，等時間到了由 [giveUp] 放棄。
  List<PendingShot> resend(String viewerId) {
    final shots = _awaiting[viewerId];
    if (shots == null) return const [];
    final ids = shots.keys.toList()..sort();
    return [
      for (final id in ids)
        if (shots[id]!.frame != null && shots[id]!._resends < maxShotResends)
          shots[id]!.._resends += 1,
    ];
  }

  /// 編號 [shotId] 的照片等太久了，不再等這個鄉民端。它還沒回報的話回傳它的名稱
  /// （用來告訴使用者誰沒收到）；已經回報過或已經離開就回傳 null。
  String? giveUp(String viewerId, int shotId) {
    if (_awaiting[viewerId]?.remove(shotId) == null) return null;
    return _names[viewerId];
  }

  /// 鄉民端回報收到編號 [shotId] 的照片。真的傳過這一張給它、而且它還沒回報過，
  /// 才回傳它的名稱（用來顯示誰抄錄了）；其他情況回傳 null，不能顯示提示：
  /// 沒在抄錄的鄉民端、亂編的編號、重複回報，都不代表有人抄錄了。
  String? shotConfirmed(String viewerId, int shotId) {
    final awaiting = _awaiting[viewerId];
    if (awaiting == null || awaiting.remove(shotId) == null) return null;
    return _names[viewerId];
  }

  /// 鄉民端的名稱。不認得這個鄉民端時是 null。
  String? nameOf(String viewerId) => _names[viewerId];

  /// 全部清掉（不給看了、撤銷註冊）。
  void clear() {
    _names.clear();
    _recording.clear();
    _awaiting.clear();
  }
}

/// 一張送出去、還在等鄉民端回報的照片。
class PendingShot {
  PendingShot._(this.id, this.frame);

  final int id;

  /// 這張照片的畫面。沒有留（不打算補送）時是 null。
  final RawFrame? frame;
  int _resends = 0;

  /// 已經補送過幾次。
  int get resends => _resends;
}

/// 看板端顯示的提示：誰把這張照片存下來了。
String shotSavedNotice(String viewerName) => '$viewerName抄錄了這個內容';

/// 看板端顯示的提示：補送到最後，這位鄉民還是沒收到這一張。
String shotLostNotice(String viewerName) => '$viewerName沒收到這張，請再拍一次';

/// 看板端顯示的提示：前面的照片還沒送到，暫存滿了，這一次不拍。
const String shotsBackedUpNotice = '前面的照片還在傳，請等一下再拍';

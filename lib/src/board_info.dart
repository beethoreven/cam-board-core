import 'dart:convert';

/// 看板端在區域網路上廣播的服務種類（mDNS／Bonjour）。
const String boardServiceType = '_cam-board._tcp';

/// 看板端預設開的連線埠。被佔用時看板端可以改用別的，
/// 實際的埠會跟著廣播出去，也會顯示在看板端畫面上給手動輸入用。
const int defaultBoardPort = 47800;

/// mDNS 規定服務名稱最長 63 個位元組（不是 63 個字）。
/// 中文一個字佔 3 個位元組，所以純中文名稱最多 21 個字。
const int maxBoardNameBytes = 63;

/// 看板名稱不合規定。[message] 可以直接顯示給使用者。
class BoardNameException implements Exception {
  const BoardNameException(this.message);

  final String message;

  @override
  String toString() => 'BoardNameException: $message';
}

/// 整理並檢查使用者輸入的看板名稱，回傳可以拿去廣播的名稱。
String validateBoardName(String input) {
  final name = input.trim();
  if (name.isEmpty) throw const BoardNameException('請幫看板取個名字');
  if (utf8.encode(name).length > maxBoardNameBytes) {
    throw const BoardNameException('名字太長了（中文最多 21 個字）');
  }
  return name;
}

/// 鄉民端看到的一個看板：名稱，加上連過去需要的位址。
class BoardInfo {
  const BoardInfo({
    required this.name,
    required this.host,
    required this.port,
    this.protocol,
  });

  final String name;
  final String host;
  final int port;

  /// 看板端廣播時附上的通訊協定版本。手動輸入位址、或廣播裡沒有時是 null，
  /// 這時要等連上之後看 `hello` 才知道。
  final int? protocol;

  /// 連到這個看板的 WebSocket 位址。
  Uri get signalUri => Uri(scheme: 'ws', host: host, port: port);

  /// 顯示在看板端畫面上、給鄉民端手動輸入的位址。
  String get address => '$host:$port';

  /// 解析鄉民端手動輸入的位址，例如 `192.168.43.1` 或 `192.168.43.1:47800`。
  /// 沒寫埠就用 [defaultBoardPort]。格式不對時丟 [FormatException]。
  static BoardInfo parseAddress(String input) {
    final text = input.trim();
    if (text.isEmpty) throw const FormatException('請輸入看板端顯示的位址');
    final parts = text.split(':');
    if (parts.length > 2 || parts.first.isEmpty) {
      throw FormatException('位址格式不對：$text');
    }
    final host = parts.first;
    var port = defaultBoardPort;
    if (parts.length == 2) {
      final parsed = int.tryParse(parts[1]);
      if (parsed == null || parsed < 1 || parsed > 65535) {
        throw FormatException('埠必須是 1 到 65535 的數字：${parts[1]}');
      }
      port = parsed;
    }
    return BoardInfo(name: host, host: host, port: port);
  }

  @override
  bool operator ==(Object other) =>
      other is BoardInfo &&
      other.name == name &&
      other.host == host &&
      other.port == port &&
      other.protocol == protocol;

  @override
  int get hashCode => Object.hash(name, host, port, protocol);

  @override
  String toString() => 'BoardInfo($name @ $address)';
}

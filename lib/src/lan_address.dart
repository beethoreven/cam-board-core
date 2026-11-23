/// 一張網路介面上的一個 IPv4 位址。
typedef InterfaceAddress = ({String interfaceName, String address});

/// 從手機的所有網路位址裡，挑出鄉民端連得到的那一個。
///
/// 手機同時可能有 Wi-Fi、自己開的熱點、行動網路的位址。鄉民端只能連到
/// 區域網路的位址，所以只挑私有網段，並且避開行動網路的介面。
/// 挑不到（例如沒連任何網路）時回傳 null。
String? pickLanAddress(Iterable<InterfaceAddress> candidates) {
  final usable = candidates
      .where((c) => _isPrivate(c.address) && !_isCellular(c.interfaceName))
      .toList();
  if (usable.isEmpty) return null;
  usable.sort(
    (a, b) => _rank(a.interfaceName).compareTo(_rank(b.interfaceName)),
  );
  return usable.first.address;
}

/// 私有網段：10.x.x.x、172.16～31.x.x、192.168.x.x。
bool _isPrivate(String address) {
  final parts = address.split('.').map(int.tryParse).toList();
  if (parts.length != 4 || parts.contains(null)) return false;
  final a = parts[0]!;
  final b = parts[1]!;
  return a == 10 || (a == 172 && b >= 16 && b <= 31) || (a == 192 && b == 168);
}

/// Android 行動網路的介面名稱（rmnet、ccmni、pdp 開頭）。
bool _isCellular(String name) =>
    name.startsWith('rmnet') ||
    name.startsWith('ccmni') ||
    name.startsWith('pdp');

/// 數字越小越優先：Wi-Fi 與熱點的介面排在其他介面前面。
int _rank(String name) {
  const wifiPrefixes = ['wlan', 'ap', 'swlan', 'softap', 'en'];
  return wifiPrefixes.any(name.startsWith) ? 0 : 1;
}

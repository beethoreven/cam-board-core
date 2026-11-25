import 'board_info.dart';

/// 鄉民端的看板清單。
///
/// 看板有兩個來源：自動搜尋到的，和使用者手動輸入位址加進來的。
/// 同一個看板（同一個位址）只會在清單上出現一次，自動搜尋到的優先，
/// 因為它會跟著看板端的註冊與撤銷即時更新。
class BoardDirectory {
  /// 自動搜尋到的看板。鍵是搜尋機制給的識別名稱，看板消失時靠它移除。
  final Map<String, BoardInfo> _discovered = {};

  /// 手動加入的看板，照加入的順序排。
  final List<BoardInfo> _manual = [];

  /// 目前要顯示的清單：自動搜尋到的照名稱排在前面，手動加入的排在後面。
  List<BoardInfo> get boards {
    final discovered = _discovered.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final discoveredAddresses = discovered.map((b) => b.address).toSet();
    return [
      ...discovered,
      ..._manual.where((b) => !discoveredAddresses.contains(b.address)),
    ];
  }

  bool get isEmpty => boards.isEmpty;

  /// 自動搜尋到一個看板，或它的資訊更新了。
  void found(String id, BoardInfo board) => _discovered[id] = board;

  /// 自動搜尋到的看板消失了（看板端撤銷註冊或離開網路）。
  void lost(String id) => _discovered.remove(id);

  /// 手動加入一個看板。已經在清單上（不論來源）就不重複加，回傳 false。
  bool addManual(BoardInfo board) {
    if (boards.any((b) => b.address == board.address)) return false;
    _manual.add(board);
    return true;
  }

  /// 這個看板是不是手動加入的（而且沒有被自動搜尋到）。只有這種可以由使用者移除。
  bool isManual(BoardInfo board) =>
      _manual.any((b) => b.address == board.address) &&
      !_discovered.values.any((b) => b.address == board.address);

  /// 移除一個手動加入的看板。自動搜尋到的不能這樣移除，它們由搜尋機制管理。
  void removeManual(BoardInfo board) =>
      _manual.removeWhere((b) => b.address == board.address);
}

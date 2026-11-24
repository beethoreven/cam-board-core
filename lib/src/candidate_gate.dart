import 'signal_message.dart';

/// 把太早到的網路路徑先留著，等連線準備好再交出去。
///
/// 兩端交換連線資訊時，對方會在送出連線資訊之後緊接著送出好幾條網路路徑
/// （[CandidateMessage]）。視訊連線要先處理完對方的連線資訊才能接受網路路徑，
/// 而處理需要時間，第一次連線時尤其久。這段時間內到達的網路路徑如果直接交給
/// 視訊連線會出錯，丟掉又可能連不上，所以先留著。
class CandidateGate {
  CandidateGate(this._deliver);

  final Future<void> Function(CandidateMessage candidate) _deliver;
  final List<CandidateMessage> _held = [];
  bool _open = false;

  /// 還留著、沒交出去的數量。
  int get heldCount => _held.length;

  /// 收到一條網路路徑。連線準備好了就直接交出去，否則先留著。
  Future<void> add(CandidateMessage candidate) async {
    if (_open) {
      await _handOver(candidate);
    } else {
      _held.add(candidate);
    }
  }

  /// 連線準備好了：把留著的照收到的順序交出去，之後收到的直接交出去。
  Future<void> open() async {
    _open = true;
    final held = List.of(_held);
    _held.clear();
    for (final candidate in held) {
      await _handOver(candidate);
    }
  }

  /// 單獨一條網路路徑有問題時跳過它。兩端通常各有好幾條路徑可以用，
  /// 不能因為其中一條不能用就放棄整個連線。
  Future<void> _handOver(CandidateMessage candidate) async {
    try {
      await _deliver(candidate);
    } catch (_) {}
  }
}

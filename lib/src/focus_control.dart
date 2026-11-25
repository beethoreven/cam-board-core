// 看板端「自動對焦」開關的規則。
//
// 拍手寫紙、拍劇本的距離是固定的，連續自動對焦反而會在拍照那一刻把畫面弄糊，
// 所以對焦要能鎖住。

/// 要鏡頭做的對焦動作。
sealed class FocusCommand {
  const FocusCommand();
}

/// 持續自動對焦。
final class ContinuousFocus extends FocusCommand {
  const ContinuousFocus();
}

/// 停在目前的對焦位置，不再自己重新對焦。
final class HoldFocus extends FocusCommand {
  const HoldFocus();
}

/// 對畫面上的一點對焦一次，然後停在那裡。[x]、[y] 是 0 到 1 的比例。
final class PointFocus extends FocusCommand {
  const PointFocus(this.x, this.y);

  final double x;
  final double y;

  @override
  bool operator ==(Object other) =>
      other is PointFocus && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'PointFocus($x, $y)';
}

/// 直接把對焦設在之前鎖住的距離。
final class DistanceFocus extends FocusCommand {
  const DistanceFocus(this.distance);

  final double distance;

  @override
  bool operator ==(Object other) =>
      other is DistanceFocus && other.distance == distance;

  @override
  int get hashCode => distance.hashCode;

  @override
  String toString() => 'DistanceFocus($distance)';
}

/// 「自動對焦」開著時點擊對焦，手動對到的位置維持多久才恢復自動對焦。
const Duration tapFocusHold = Duration(seconds: 5);

/// 對焦開關的狀態，以及每個操作該讓鏡頭做什麼。
///
/// - 開關每次註冊後都是開的。
/// - 開著時點擊畫面：對那一點對焦，維持 [tapFocusHold]，之後恢復自動對焦。
/// - 關著時點擊畫面：對那一點對焦，然後一直停在那裡。
/// - 關掉開關：停在目前的位置。
/// - 開關和鎖住的對焦在註冊期間記著，鏡頭重開時套回去。
///
/// 計時由 app 那一層做：[tapped] 之後如果 [holdingTap] 是 true，
/// 就在 [tapFocusHold] 之後呼叫 [tapHoldExpired]。
class FocusControl {
  bool _autoFocus = true;
  bool _holdingTap = false;
  double? _lockedDistance;

  /// 「自動對焦」開關。
  bool get autoFocus => _autoFocus;

  /// 開關開著，但正處於點擊對焦之後的那幾秒，暫時沒有在自動對焦。
  bool get holdingTap => _holdingTap;

  /// 目前鎖住的對焦距離。沒有鎖住，或鏡頭沒回報時是 null。
  double? get lockedDistance => _lockedDistance;

  /// 重新註冊：回到開著。
  void reset() {
    _autoFocus = true;
    _holdingTap = false;
    _lockedDistance = null;
  }

  /// 切換開關。
  FocusCommand setAutoFocus(bool on) {
    _autoFocus = on;
    _holdingTap = false;
    _lockedDistance = null;
    return on ? const ContinuousFocus() : const HoldFocus();
  }

  /// 點了畫面上的一點。
  FocusCommand tapped(double x, double y) {
    _holdingTap = _autoFocus;
    _lockedDistance = null;
    return PointFocus(x, y);
  }

  /// 鏡頭回報鎖住的對焦距離（點擊對焦完成，或關掉開關之後）。
  ///
  /// 回傳接下來要讓鏡頭做的事：有距離可用時，改成直接把鏡頭固定在那個距離。
  /// 只把相機設成「不觸發就不對焦」是不夠的：實機上（OPPO Reno5 5G）畫面內容
  /// 一變，相機還是會自己重新對焦，所以要用固定距離才真的鎖得住。
  /// 不需要鎖、或相機沒有回報距離時回傳 null。
  FocusCommand? locked(double? distance) {
    if (_autoFocus && !_holdingTap) return null;
    _lockedDistance = distance;
    return distance == null ? null : DistanceFocus(distance);
  }

  /// 點擊對焦後的等待時間到了。開關還開著就恢復自動對焦，否則不用做事。
  FocusCommand? tapHoldExpired() {
    if (!_holdingTap) return null;
    _holdingTap = false;
    _lockedDistance = null;
    return const ContinuousFocus();
  }

  /// 目前的狀態對應的對焦動作，而且不會觸發新的對焦。
  /// 只改變縮放、或鏡頭重開時用這個把對焦維持在原本的樣子。
  FocusCommand get current {
    if (_autoFocus && !_holdingTap) return const ContinuousFocus();
    final distance = _lockedDistance;
    return distance == null ? const HoldFocus() : DistanceFocus(distance);
  }

  /// 鏡頭重開之後該做什麼。
  ///
  /// 開著：自動對焦。關著而且記得距離：設回那個距離。
  /// 關著但不記得距離：鏡頭重開後位置已經不見了，對畫面中央對焦一次再鎖住。
  FocusCommand afterCameraOpened() {
    _holdingTap = false;
    if (_autoFocus) return const ContinuousFocus();
    final distance = _lockedDistance;
    return distance == null
        ? const PointFocus(0.5, 0.5)
        : DistanceFocus(distance);
  }

  /// 切換了前後鏡頭。另一顆鏡頭的對焦距離不能沿用。
  FocusCommand afterCameraSwitched() {
    _holdingTap = false;
    _lockedDistance = null;
    return _autoFocus ? const ContinuousFocus() : const PointFocus(0.5, 0.5);
  }
}

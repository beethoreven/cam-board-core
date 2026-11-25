import 'package:cam_board_core/cam_board_core.dart';
import 'package:test/test.dart';

void main() {
  late FocusControl focus;

  setUp(() => focus = FocusControl());

  test('一開始開關是開的，鏡頭自動對焦', () {
    expect(focus.autoFocus, isTrue);
    expect(focus.current, isA<ContinuousFocus>());
  });

  test('點擊後手動對焦維持 5 秒', () {
    expect(tapFocusHold, const Duration(seconds: 5));
  });

  group('開關開著時點擊畫面', () {
    test('對那一點對焦，並進入暫時不自動對焦的期間', () {
      expect(focus.tapped(0.3, 0.7), const PointFocus(0.3, 0.7));
      expect(focus.holdingTap, isTrue);
      expect(focus.autoFocus, isTrue);
    });

    test('時間到了恢復自動對焦', () {
      focus.tapped(0.3, 0.7);
      focus.locked(2.5);

      expect(focus.tapHoldExpired(), isA<ContinuousFocus>());
      expect(focus.holdingTap, isFalse);
      expect(focus.current, isA<ContinuousFocus>());
    });

    test('等待期間只改縮放時，對焦留在剛才鎖住的距離', () {
      focus.tapped(0.3, 0.7);
      focus.locked(2.5);

      expect(focus.current, const DistanceFocus(2.5));
    });

    test('鏡頭沒回報距離時，等待期間用「停在目前位置」', () {
      focus.tapped(0.3, 0.7);
      focus.locked(null);

      expect(focus.current, isA<HoldFocus>());
    });
  });

  group('關掉開關', () {
    test('停在目前的位置', () {
      expect(focus.setAutoFocus(false), isA<HoldFocus>());
      expect(focus.autoFocus, isFalse);
    });

    test('點擊畫面：對那一點對焦，然後一直停在那裡', () {
      focus.setAutoFocus(false);

      expect(focus.tapped(0.5, 0.5), const PointFocus(0.5, 0.5));
      expect(focus.holdingTap, isFalse);
      expect(focus.tapHoldExpired(), isNull);
    });

    test('點擊對焦的等待期間關掉開關，時間到了也不會恢復自動對焦', () {
      focus.tapped(0.5, 0.5);
      focus.setAutoFocus(false);

      expect(focus.tapHoldExpired(), isNull);
      expect(focus.autoFocus, isFalse);
    });

    test('再打開：恢復自動對焦', () {
      focus.setAutoFocus(false);
      focus.locked(3);

      expect(focus.setAutoFocus(true), isA<ContinuousFocus>());
      expect(focus.lockedDistance, isNull);
    });
  });

  group('鏡頭重開', () {
    test('開關開著：自動對焦', () {
      expect(focus.afterCameraOpened(), isA<ContinuousFocus>());
    });

    test('開關關著而且記得距離：設回那個距離', () {
      focus.setAutoFocus(false);
      focus.tapped(0.2, 0.2);
      focus.locked(4.2);

      expect(focus.afterCameraOpened(), const DistanceFocus(4.2));
    });

    test('開關關著但不記得距離：對畫面中央對焦一次再鎖住', () {
      focus.setAutoFocus(false);
      focus.locked(null);

      expect(focus.afterCameraOpened(), const PointFocus(0.5, 0.5));
    });

    test('點擊對焦的等待期間鏡頭重開：直接回到自動對焦', () {
      focus.tapped(0.2, 0.2);
      focus.locked(4.2);

      expect(focus.afterCameraOpened(), isA<ContinuousFocus>());
      expect(focus.tapHoldExpired(), isNull);
    });
  });

  group('切換前後鏡頭', () {
    test('另一顆鏡頭不沿用鎖住的距離，對畫面中央重新對焦', () {
      focus.setAutoFocus(false);
      focus.locked(4.2);

      expect(focus.afterCameraSwitched(), const PointFocus(0.5, 0.5));
      expect(focus.lockedDistance, isNull);
    });

    test('開關開著時維持自動對焦', () {
      expect(focus.afterCameraSwitched(), isA<ContinuousFocus>());
    });
  });

  test('開關開著、也沒有在等待時，鏡頭回報的距離不記', () {
    focus.locked(9);
    expect(focus.lockedDistance, isNull);
  });

  group('鎖住之後要把鏡頭固定在那個距離', () {
    test('開關關著：回傳固定距離的指令', () {
      focus.setAutoFocus(false);
      expect(focus.locked(4.2), const DistanceFocus(4.2));
    });

    test('點擊對焦後的等待期間：回傳固定距離的指令', () {
      focus.tapped(0.3, 0.7);
      expect(focus.locked(2.5), const DistanceFocus(2.5));
    });

    test('鏡頭沒回報距離：沒有指令', () {
      focus.setAutoFocus(false);
      expect(focus.locked(null), isNull);
    });

    test('開關開著、也沒有在等待：沒有指令', () {
      expect(focus.locked(9), isNull);
    });
  });

  test('重新註冊：回到開著，忘掉鎖住的距離', () {
    focus.setAutoFocus(false);
    focus.locked(4.2);
    focus.reset();

    expect(focus.autoFocus, isTrue);
    expect(focus.lockedDistance, isNull);
    expect(focus.current, isA<ContinuousFocus>());
  });
}

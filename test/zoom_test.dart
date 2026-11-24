import 'package:cam_board_core/cam_board_core.dart';
import 'package:test/test.dart';

void main() {
  group('clampZoom', () {
    test('範圍內的倍率不變', () {
      expect(clampZoom(1), 1);
      expect(clampZoom(3.5), 3.5);
      expect(clampZoom(maxZoom), maxZoom);
    });

    test('小於 1 倍時當成 1 倍', () {
      expect(clampZoom(0.2), minZoom);
      expect(clampZoom(-3), minZoom);
    });

    test('超過上限時當成上限', () {
      expect(clampZoom(50), maxZoom);
    });
  });

  group('zoomForPinch', () {
    test('兩指沒動時倍率不變', () {
      expect(zoomForPinch(startZoom: 2, scale: 1), 2);
    });

    test('兩指張開放大', () {
      expect(zoomForPinch(startZoom: 1, scale: 2.5), 2.5);
    });

    test('從上一次的倍率接續，不是從 1 倍重來', () {
      expect(zoomForPinch(startZoom: 2, scale: 1.5), 3);
    });

    test('兩指捏合縮小，但不會小於 1 倍', () {
      expect(zoomForPinch(startZoom: 2, scale: 0.75), 1.5);
      expect(zoomForPinch(startZoom: 1.2, scale: 0.1), minZoom);
    });

    test('放大不會超過上限', () {
      expect(zoomForPinch(startZoom: 6, scale: 4), maxZoom);
    });
  });
}

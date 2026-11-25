import 'dart:typed_data';

import 'package:cam_board_core/cam_board_core.dart';
import 'package:test/test.dart';

/// 做一張 [width]×[height] 的畫面：亮度一個像素一個值，色差整張都一樣。
RawFrame frame(
  int width,
  int height,
  List<int> luma, {
  int u = 128,
  int v = 128,
  int rotation = 0,
}) {
  final chroma = (width ~/ 2) * (height ~/ 2);
  return RawFrame(
    width: width,
    height: height,
    rotation: rotation,
    i420: Uint8List.fromList([
      ...luma,
      ...List.filled(chroma, u),
      ...List.filled(chroma, v),
    ]),
  );
}

void main() {
  group('畫面的大小', () {
    test('寬×高×1.5', () {
      expect(RawFrame.byteLength(1920, 1080), 3110400);
      expect(RawFrame.byteLength(2, 2), 6);
    });

    test('資料長度不對就不收', () {
      expect(
        () => RawFrame(width: 2, height: 2, rotation: 0, i420: Uint8List(5)),
        throwsArgumentError,
      );
    });

    test('寬或高是奇數、零或負數都不收', () {
      expect(RawFrame.isValidSize(1920, 1080), isTrue);
      expect(RawFrame.isValidSize(3, 2), isFalse);
      expect(RawFrame.isValidSize(2, 0), isFalse);
      expect(RawFrame.isValidSize(-2, 2), isFalse);
    });

    test('大得不合理的不收', () {
      expect(RawFrame.isValidSize(RawFrame.maxSide, RawFrame.maxSide), isTrue);
      expect(RawFrame.isValidSize(RawFrame.maxSide + 2, 2), isFalse);
      expect(RawFrame.isValidSize(2, RawFrame.maxSide + 2), isFalse);
    });

    test('角度只能是四個方向', () {
      for (final ok in [0, 90, 180, 270]) {
        expect(RawFrame.isValidRotation(ok), isTrue);
      }
      expect(RawFrame.isValidRotation(45), isFalse);
      expect(RawFrame.isValidRotation(360), isFalse);
    });
  });

  group('換成紅綠藍', () {
    test('沒有顏色時：亮度 16 是全黑、235 是全白、中間是灰', () {
      final rgba = frame(2, 2, [16, 235, 126, 0]).toRgba();
      expect(rgba.sublist(0, 4), [0, 0, 0, 255]);
      expect(rgba.sublist(4, 8), [255, 255, 255, 255]);
      expect(rgba.sublist(8, 12), [128, 128, 128, 255]);
      // 比全黑還暗的值不會變成負數。
      expect(rgba.sublist(12, 16), [0, 0, 0, 255]);
    });

    test('純紅、純綠、純藍（整數換算，容許差 1）', () {
      void expectColor(RawFrame frame, List<int> color) {
        final pixel = frame.toRgba().sublist(0, 4);
        for (var i = 0; i < 4; i++) {
          expect(pixel[i], closeTo(color[i], 1), reason: '$pixel 應該接近 $color');
        }
      }

      expectColor(frame(2, 2, List.filled(4, 81), u: 90, v: 240), [
        255,
        0,
        0,
        255,
      ]);
      expectColor(frame(2, 2, List.filled(4, 145), u: 54, v: 34), [
        0,
        255,
        0,
        255,
      ]);
      expectColor(frame(2, 2, List.filled(4, 41), u: 240, v: 110), [
        0,
        0,
        255,
        255,
      ]);
    });

    test('色差每 2×2 個像素共用一個值，不會拿錯格', () {
      // 4×2：左半邊的色差是紅的，右半邊沒有顏色。
      final rgba = RawFrame(
        width: 4,
        height: 2,
        rotation: 0,
        i420: Uint8List.fromList([
          81, 81, 126, 126, //
          81, 81, 126, 126, //
          90, 128, // U
          240, 128, // V
        ]),
      ).toRgba();
      List<int> pixel(int row, int column) {
        final at = (row * 4 + column) * 4;
        return rgba.sublist(at, at + 4);
      }

      expect(pixel(0, 0), [255, 0, 0, 255]);
      expect(pixel(1, 1), [255, 0, 0, 255]);
      expect(pixel(0, 2), [128, 128, 128, 255]);
      expect(pixel(1, 3), [128, 128, 128, 255]);
    });

    test('方向不變：轉正是存檔那一步的事', () {
      final rgba = frame(2, 4, List.filled(8, 126), rotation: 90).toRgba();
      expect(rgba.length, 2 * 4 * 4);
    });
  });
}

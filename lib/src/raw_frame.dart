import 'dart:typed_data';

/// 鏡頭的一格畫面，還沒壓縮，也還沒換成紅綠藍。
///
/// 內容是視訊用的「亮度＋色差」格式（I420）：先是每個像素一個亮度值，
/// 再是兩塊色差，色差每 2×2 個像素共用一個值，所以大小固定是寬×高×1.5。
/// 看板端拍照時直接送這個，換成紅綠藍和壓成 PNG 都交給鄉民端：
/// 手機做這些事要一秒多，電腦快得多。
final class RawFrame {
  RawFrame({
    required this.width,
    required this.height,
    required this.rotation,
    required this.i420,
  }) {
    if (!isValidSize(width, height)) {
      throw ArgumentError('畫面的寬和高必須是正的偶數：$width×$height');
    }
    if (!isValidRotation(rotation)) {
      throw ArgumentError('畫面的角度只能是 0、90、180、270：$rotation');
    }
    if (i420.length != byteLength(width, height)) {
      throw ArgumentError(
        '畫面的資料應該有 ${byteLength(width, height)} bytes，實際是 ${i420.length}',
      );
    }
  }

  /// 資料裡的寬和高（還沒轉正）。
  final int width;
  final int height;

  /// 要順時針轉幾度才是正的：0、90、180 或 270。手機直著拿時鏡頭給的畫面是橫的。
  final int rotation;

  /// 亮度、色差 U、色差 V 依序接在一起，每一列之間沒有多餘的空位。
  final Uint8List i420;

  /// 色差每 2×2 個像素共用一個值，所以寬和高都要是偶數。
  static bool isValidSize(int width, int height) =>
      width > 0 && height > 0 && width.isEven && height.isEven;

  static bool isValidRotation(int rotation) =>
      rotation == 0 || rotation == 90 || rotation == 180 || rotation == 270;

  /// 一張 [width]×[height] 的畫面有多少 bytes。
  static int byteLength(int width, int height) => width * height * 3 ~/ 2;

  /// 換成紅綠藍：每個像素四個 bytes，依序是紅、綠、藍、不透明度（固定 255）。
  /// 方向不變，還是 [width]×[height]。
  ///
  /// 鏡頭給的是 BT.601、有限範圍（亮度 16～235）。
  Uint8List toRgba() {
    final out = Uint8List(width * height * 4);
    final chromaWidth = width ~/ 2;
    final uStart = width * height;
    final vStart = uStart + chromaWidth * (height ~/ 2);
    var o = 0;
    for (var row = 0; row < height; row++) {
      final yRow = row * width;
      final chromaRow = (row ~/ 2) * chromaWidth;
      for (var column = 0; column < width; column++) {
        final chroma = chromaRow + (column >> 1);
        final c = 298 * (i420[yRow + column] - 16) + 128;
        final d = i420[uStart + chroma] - 128;
        final e = i420[vStart + chroma] - 128;
        out[o++] = _byte((c + 409 * e) >> 8);
        out[o++] = _byte((c - 100 * d - 208 * e) >> 8);
        out[o++] = _byte((c + 516 * d) >> 8);
        out[o++] = 255;
      }
    }
    return out;
  }

  static int _byte(int value) => value < 0 ? 0 : (value > 255 ? 255 : value);
}

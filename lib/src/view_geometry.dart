/// 鄉民端對畫面做的旋轉。只影響鄉民端自己的顯示。
enum ViewRotation {
  deg0(0),
  deg90(90),
  deg180(180),
  deg270(270);

  const ViewRotation(this.degrees);

  final int degrees;

  /// 再順時針轉 90 度。轉到 270 之後回到 0。
  ViewRotation get next => values[(index + 1) % values.length];

  /// 這個角度會不會讓畫面的寬和高對調。
  bool get swapsSides => this == deg90 || this == deg270;
}

/// 一個寬高。core 不依賴 Flutter，所以不用 Flutter 的 Size。
class Dimensions {
  const Dimensions(this.width, this.height)
    : assert(width > 0, '寬必須大於 0'),
      assert(height > 0, '高必須大於 0');

  final double width;
  final double height;

  double get aspectRatio => width / height;

  @override
  bool operator ==(Object other) =>
      other is Dimensions && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(width, height);

  @override
  String toString() => 'Dimensions($width x $height)';
}

/// 視窗在螢幕上的位置和大小。
class WindowFrame {
  const WindowFrame({
    required this.left,
    required this.top,
    required this.size,
  });

  final double left;
  final double top;
  final Dimensions size;

  @override
  String toString() => 'WindowFrame($left, $top, $size)';
}

/// 旋轉之後，畫面顯示出來的寬高。90／270 度時寬高對調。
Dimensions displayedDimensions(Dimensions video, ViewRotation rotation) =>
    rotation.swapsSides ? Dimensions(video.height, video.width) : video;

/// 「不用留黑」的核心計算：在 [screen] 內，維持畫面比例能放到的最大視窗，並置中。
///
/// 直屏畫面會頂到螢幕上下、左右空出來；橫屏畫面會頂到左右、上下空出來。
/// 視窗剛好等於畫面大小，所以沒有黑邊，空出來的地方看得到後面的桌面。
WindowFrame fitWindowToScreen({
  required Dimensions video,
  required ViewRotation rotation,
  required Dimensions screen,
}) {
  final shown = displayedDimensions(video, rotation);
  final scale = _min(screen.width / shown.width, screen.height / shown.height);
  final size = Dimensions(shown.width * scale, shown.height * scale);
  return WindowFrame(
    left: (screen.width - size.width) / 2,
    top: (screen.height - size.height) / 2,
    size: size,
  );
}

double _min(double a, double b) => a < b ? a : b;

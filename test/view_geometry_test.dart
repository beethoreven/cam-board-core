import 'package:cam_board_core/cam_board_core.dart';
import 'package:test/test.dart';

void main() {
  const landscape = Dimensions(1920, 1080);
  const portrait = Dimensions(1080, 1920);
  const screen = Dimensions(1920, 1080);

  group('ViewRotation', () {
    test('連按四次旋轉會回到原本的角度', () {
      var rotation = ViewRotation.deg0;
      final seen = <int>[];
      for (var i = 0; i < 4; i++) {
        rotation = rotation.next;
        seen.add(rotation.degrees);
      }
      expect(seen, [90, 180, 270, 0]);
    });

    test('只有 90 與 270 度會讓寬高對調', () {
      expect(ViewRotation.deg0.swapsSides, isFalse);
      expect(ViewRotation.deg90.swapsSides, isTrue);
      expect(ViewRotation.deg180.swapsSides, isFalse);
      expect(ViewRotation.deg270.swapsSides, isTrue);
    });
  });

  group('displayedDimensions', () {
    test('0 與 180 度維持原本的寬高', () {
      expect(displayedDimensions(landscape, ViewRotation.deg0), landscape);
      expect(displayedDimensions(landscape, ViewRotation.deg180), landscape);
    });

    test('90 與 270 度寬高對調', () {
      expect(displayedDimensions(landscape, ViewRotation.deg90), portrait);
      expect(displayedDimensions(landscape, ViewRotation.deg270), portrait);
    });
  });

  group('fitWindowToScreen', () {
    test('橫屏畫面在同比例的螢幕上剛好填滿', () {
      final frame = fitWindowToScreen(
        video: landscape,
        rotation: ViewRotation.deg0,
        screen: screen,
      );
      expect(frame.size, screen);
      expect(frame.left, 0);
      expect(frame.top, 0);
    });

    test('直屏畫面頂到上下，左右空出來並置中', () {
      final frame = fitWindowToScreen(
        video: portrait,
        rotation: ViewRotation.deg0,
        screen: screen,
      );
      expect(frame.size.height, 1080);
      expect(frame.size.width, closeTo(607.5, 0.001));
      expect(frame.top, 0);
      expect(frame.left, closeTo((1920 - 607.5) / 2, 0.001));
    });

    test('橫屏畫面在比較方的螢幕上頂到左右，上下空出來並置中', () {
      final frame = fitWindowToScreen(
        video: landscape,
        rotation: ViewRotation.deg0,
        screen: const Dimensions(1600, 1200),
      );
      expect(frame.size.width, 1600);
      expect(frame.size.height, 900);
      expect(frame.left, 0);
      expect(frame.top, 150);
    });

    test('橫屏畫面轉 90 度後當成直屏處理', () {
      final rotated = fitWindowToScreen(
        video: landscape,
        rotation: ViewRotation.deg90,
        screen: screen,
      );
      final native = fitWindowToScreen(
        video: portrait,
        rotation: ViewRotation.deg0,
        screen: screen,
      );
      expect(rotated.size, native.size);
      expect(rotated.left, native.left);
    });

    test('比螢幕小的畫面會放大，視窗比例仍等於畫面比例', () {
      const small = Dimensions(640, 480);
      final frame = fitWindowToScreen(
        video: small,
        rotation: ViewRotation.deg0,
        screen: screen,
      );
      expect(frame.size.height, 1080);
      expect(frame.size.aspectRatio, closeTo(small.aspectRatio, 0.0001));
    });
  });

  group('pointInFittedContent', () {
    test('畫面和框的比例一樣時，位置就是框上的比例', () {
      final point = pointInFittedContent(
        box: const Dimensions(400, 800),
        contentAspect: 0.5,
        dx: 100,
        dy: 600,
      );
      expect(point.x, closeTo(0.25, 1e-9));
      expect(point.y, closeTo(0.75, 1e-9));
    });

    test('框比畫面寬：畫面在中間，左右是空的', () {
      // 框 800×800，畫面是直的（寬高比 0.5），所以畫面寬 400，從 x=200 開始。
      const box = Dimensions(800, 800);
      final leftEdge = pointInFittedContent(
        box: box,
        contentAspect: 0.5,
        dx: 200,
        dy: 0,
      );
      final center = pointInFittedContent(
        box: box,
        contentAspect: 0.5,
        dx: 400,
        dy: 400,
      );
      expect(leftEdge.x, closeTo(0, 1e-9));
      expect(center.x, closeTo(0.5, 1e-9));
      expect(center.y, closeTo(0.5, 1e-9));
    });

    test('框比畫面高：畫面在中間，上下是空的', () {
      // 框 800×800，畫面是橫的（寬高比 2），所以畫面高 400，從 y=200 開始。
      final point = pointInFittedContent(
        box: const Dimensions(800, 800),
        contentAspect: 2,
        dx: 800,
        dy: 600,
      );
      expect(point.x, closeTo(1, 1e-9));
      expect(point.y, closeTo(1, 1e-9));
    });

    test('點在空白處時超出 0 到 1，由呼叫的人決定怎麼處理', () {
      final point = pointInFittedContent(
        box: const Dimensions(800, 800),
        contentAspect: 0.5,
        dx: 100,
        dy: 400,
      );
      expect(point.x, lessThan(0));
    });
  });
}

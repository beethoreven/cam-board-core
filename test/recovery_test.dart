import 'package:cam_board_core/cam_board_core.dart';
import 'package:test/test.dart';

void main() {
  Duration s(num seconds) => Duration(milliseconds: (seconds * 1000).round());

  group('連續失敗的計數', () {
    test('連續失敗到上限才該放棄', () {
      final attempts = RecoveryAttempts();
      attempts.failed();
      attempts.failed();
      expect(attempts.exhausted, isFalse);
      attempts.failed();
      expect(attempts.exhausted, isTrue);
    });

    test('救回來一次就重新算', () {
      final attempts = RecoveryAttempts();
      attempts.failed();
      attempts.failed();
      attempts.succeeded();
      attempts.failed();
      attempts.failed();
      expect(attempts.failedInARow, 2);
      expect(attempts.exhausted, isFalse);
    });
  });

  group('畫面有沒有停住', () {
    test('張數一直增加就沒有停住', () {
      final detector = VideoStallDetector()..connectionStarted(s(0));
      for (var second = 1; second <= 20; second++) {
        expect(detector.sample(second * 30, s(second)), isFalse);
      }
    });

    test('頓一兩秒不算，連續 5 秒沒有新畫面才算停住', () {
      final detector = VideoStallDetector()..connectionStarted(s(0));
      detector.sample(30, s(1));
      expect(detector.sample(30, s(3)), isFalse);
      expect(detector.sample(30, s(5.9)), isFalse);
      expect(detector.sample(30, s(6)), isTrue);
    });

    test('中途又有新畫面就重新開始等', () {
      final detector = VideoStallDetector()..connectionStarted(s(0));
      detector.sample(30, s(1));
      detector.sample(30, s(5));
      expect(detector.sample(31, s(5.5)), isFalse);
      expect(detector.sample(31, s(10)), isFalse);
      expect(detector.sample(31, s(10.5)), isTrue);
    });

    test('剛建好的連線一直沒有畫面，也算停住', () {
      final detector = VideoStallDetector()..connectionStarted(s(0));
      expect(detector.sample(0, s(4)), isFalse);
      expect(detector.hasPicture, isFalse);
      expect(detector.sample(0, s(5)), isTrue);
    });

    test('重建之後張數從零算起，要真的解出畫面才算有畫面', () {
      final detector = VideoStallDetector()..connectionStarted(s(0));
      detector.sample(900, s(30));
      detector.connectionStarted(s(40));
      expect(detector.hasPicture, isFalse);
      // 新連線的張數比舊連線少，仍然算有進展。
      expect(detector.sample(3, s(41)), isFalse);
      expect(detector.hasPicture, isTrue);
    });
  });

  group('確認看板端還有回應', () {
    test('有回應就不算卡住', () {
      final heartbeat = Heartbeat();
      for (var second = 0; second < 10; second++) {
        heartbeat.ask(s(second));
        heartbeat.heard();
        expect(heartbeat.silent(s(second + 0.5)), isFalse);
      }
    });

    test('問了 3 秒都沒有任何回應就是卡住', () {
      final heartbeat = Heartbeat();
      heartbeat.ask(s(0));
      heartbeat.ask(s(1));
      heartbeat.ask(s(2));
      expect(heartbeat.silent(s(2.9)), isFalse);
      expect(heartbeat.silent(s(3)), isTrue);
    });

    test('每次詢問的編號都不同', () {
      final heartbeat = Heartbeat();
      expect(heartbeat.ask(s(0)), isNot(heartbeat.ask(s(1))));
    });

    test('收到看板端的任何東西都算有回應', () {
      final heartbeat = Heartbeat();
      heartbeat.ask(s(0));
      heartbeat.ask(s(2));
      heartbeat.heard();
      heartbeat.ask(s(2.5));
      expect(heartbeat.silent(s(5)), isFalse);
      expect(heartbeat.silent(s(5.5)), isTrue);
    });

    test('換了新的連線就重新開始算', () {
      final heartbeat = Heartbeat();
      heartbeat.ask(s(0));
      heartbeat.reset();
      expect(heartbeat.silent(s(10)), isFalse);
    });
  });
}

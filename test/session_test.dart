import 'package:cam_board_core/cam_board_core.dart';
import 'package:test/test.dart';

void main() {
  group('ViewerSession（鄉民端）', () {
    test('正常流程：清單 → 連線中 → 觀看中 → 按「不看了」回到清單', () {
      final session = ViewerSession();
      expect(session.state, ViewerState.browsing);

      session.startConnecting();
      expect(session.state, ViewerState.connecting);

      session.videoArrived();
      expect(session.state, ViewerState.watching);

      session.end(ByeReason.viewerLeft);
      expect(session.state, ViewerState.browsing);
      expect(session.lastEndReason, ByeReason.viewerLeft);
    });

    test('一次只能看一個看板', () {
      final session = ViewerSession()..startConnecting();
      expect(session.startConnecting, throwsStateError);

      session.videoArrived();
      expect(session.startConnecting, throwsStateError);
    });

    test('沒有在連線時收到畫面是錯誤', () {
      expect(ViewerSession().videoArrived, throwsStateError);
    });

    test('連線中被看板端結束，會記下原因', () {
      final session = ViewerSession()
        ..startConnecting()
        ..end(ByeReason.boardStopped);
      expect(session.state, ViewerState.browsing);
      expect(session.lastEndReason, ByeReason.boardStopped);
    });

    test('在清單時結束不做任何事', () {
      final session = ViewerSession()..end(ByeReason.viewerLeft);
      expect(session.state, ViewerState.browsing);
      expect(session.lastEndReason, isNull);
    });

    test('重新連線會清掉上一次的結束原因', () {
      final session = ViewerSession()
        ..startConnecting()
        ..end(ByeReason.boardStopped)
        ..startConnecting();
      expect(session.lastEndReason, isNull);
    });
  });

  group('BoardSession（看板端）', () {
    test('註冊後等候，有人看時變成顯示中', () {
      final session = BoardSession();
      expect(session.state, BoardState.unregistered);

      session.register(' 教室白板 ');
      expect(session.name, '教室白板');
      expect(session.state, BoardState.waiting);

      session.viewerJoined('mac-1');
      expect(session.state, BoardState.showing);
    });

    test('名字不合規定時註冊失敗，狀態不變', () {
      final session = BoardSession();
      expect(() => session.register('  '), throwsA(isA<BoardNameException>()));
      expect(session.state, BoardState.unregistered);
    });

    test('不能重複註冊', () {
      final session = BoardSession()..register('A');
      expect(() => session.register('B'), throwsStateError);
    });

    test('沒註冊時不能被觀看', () {
      expect(() => BoardSession().viewerJoined('mac-1'), throwsStateError);
    });

    test('多個鄉民端可以同時看，全部離開後回到等候', () {
      final session = BoardSession()
        ..register('A')
        ..viewerJoined('mac-1')
        ..viewerJoined('mac-2');
      expect(session.viewerCount, 2);

      session.viewerLeft('mac-1');
      expect(session.state, BoardState.showing);

      session.viewerLeft('mac-2');
      expect(session.state, BoardState.waiting);
    });

    test('同一個鄉民端重複加入只算一個', () {
      final session = BoardSession()
        ..register('A')
        ..viewerJoined('mac-1')
        ..viewerJoined('mac-1');
      expect(session.viewerCount, 1);
    });

    test('「不給看了」結束所有鄉民端，但仍留在清單上', () {
      final session = BoardSession()
        ..register('A')
        ..viewerJoined('mac-1')
        ..viewerJoined('mac-2');

      expect(session.stopShowing(), {'mac-1', 'mac-2'});
      expect(session.state, BoardState.waiting);
      expect(session.name, 'A');
    });

    test('撤銷註冊會結束所有鄉民端並從清單消失', () {
      final session = BoardSession()
        ..register('A')
        ..viewerJoined('mac-1');

      expect(session.unregister(), {'mac-1'});
      expect(session.state, BoardState.unregistered);
      expect(session.name, isNull);
    });
  });
}

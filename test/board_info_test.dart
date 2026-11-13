import 'package:cam_board_core/cam_board_core.dart';
import 'package:test/test.dart';

void main() {
  group('validateBoardName', () {
    test('去掉前後空白', () {
      expect(validateBoardName('  教室白板 '), '教室白板');
    });

    test('空的或只有空白時拒絕', () {
      expect(() => validateBoardName(''), throwsA(isA<BoardNameException>()));
      expect(
        () => validateBoardName('   '),
        throwsA(isA<BoardNameException>()),
      );
    });

    test('中文 21 個字可以，22 個字太長', () {
      expect(validateBoardName('板' * 21), '板' * 21);
      expect(
        () => validateBoardName('板' * 22),
        throwsA(isA<BoardNameException>()),
      );
    });

    test('英數 63 個字可以，64 個字太長', () {
      expect(validateBoardName('a' * 63), 'a' * 63);
      expect(
        () => validateBoardName('a' * 64),
        throwsA(isA<BoardNameException>()),
      );
    });
  });

  group('BoardInfo', () {
    test('signalUri 與 address', () {
      const board = BoardInfo(name: '教室白板', host: '192.168.43.1', port: 47800);
      expect(board.signalUri.toString(), 'ws://192.168.43.1:47800');
      expect(board.address, '192.168.43.1:47800');
    });

    test('內容相同就視為同一個看板', () {
      const a = BoardInfo(name: 'A', host: '10.0.0.2', port: 1);
      const b = BoardInfo(name: 'A', host: '10.0.0.2', port: 1);
      const c = BoardInfo(name: 'A', host: '10.0.0.3', port: 1);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });

  group('BoardInfo.parseAddress', () {
    test('只寫位址時用預設埠', () {
      final board = BoardInfo.parseAddress(' 192.168.43.1 ');
      expect(board.host, '192.168.43.1');
      expect(board.port, defaultBoardPort);
    });

    test('位址加埠', () {
      final board = BoardInfo.parseAddress('192.168.43.1:5000');
      expect(board.host, '192.168.43.1');
      expect(board.port, 5000);
    });

    test('格式不對時丟 FormatException', () {
      for (final bad in [
        '',
        ':5000',
        '1.2.3.4:abc',
        '1.2.3.4:0',
        '1.2.3.4:70000',
        '1.2.3.4:1:2',
      ]) {
        expect(
          () => BoardInfo.parseAddress(bad),
          throwsFormatException,
          reason: '輸入：「$bad」',
        );
      }
    });
  });
}

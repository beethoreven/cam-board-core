import 'package:cam_board_core/cam_board_core.dart';
import 'package:test/test.dart';

void main() {
  const a = BoardInfo(name: '甲班', host: '192.168.1.10', port: 47800);
  const b = BoardInfo(name: '乙班', host: '192.168.1.11', port: 47800);

  test('一開始是空的', () {
    expect(BoardDirectory().isEmpty, isTrue);
  });

  test('搜尋到的看板照名稱排序', () {
    final directory = BoardDirectory()
      ..found('id-b', b)
      ..found('id-a', a);
    expect(directory.boards, [b, a]..sort((x, y) => x.name.compareTo(y.name)));
  });

  test('看板消失後從清單移除', () {
    final directory = BoardDirectory()
      ..found('id-a', a)
      ..found('id-b', b)
      ..lost('id-a');
    expect(directory.boards, [b]);
  });

  test('同一個識別名稱再次出現是更新，不會變成兩個', () {
    const moved = BoardInfo(name: '甲班', host: '192.168.1.99', port: 47800);
    final directory = BoardDirectory()
      ..found('id-a', a)
      ..found('id-a', moved);
    expect(directory.boards, [moved]);
  });

  test('移除不存在的看板不會出錯', () {
    final directory = BoardDirectory()..lost('nobody');
    expect(directory.isEmpty, isTrue);
  });

  group('手動加入', () {
    test('排在搜尋到的看板後面', () {
      final directory = BoardDirectory()..found('id-a', a);
      expect(directory.addManual(b), isTrue);
      expect(directory.boards, [a, b]);
    });

    test('同一個位址不重複加入', () {
      final directory = BoardDirectory();
      expect(directory.addManual(a), isTrue);
      expect(directory.addManual(a), isFalse);
      expect(directory.boards, hasLength(1));
    });

    test('位址已經被搜尋到時不加入', () {
      final directory = BoardDirectory()..found('id-a', a);
      const sameAddress = BoardInfo(
        name: '192.168.1.10',
        host: '192.168.1.10',
        port: 47800,
      );
      expect(directory.addManual(sameAddress), isFalse);
      expect(directory.boards, [a]);
    });

    test('手動加入之後才被搜尋到，清單上只留搜尋到的那一個', () {
      const manual = BoardInfo(
        name: '手動的名字',
        host: '192.168.1.10',
        port: 47800,
      );
      final directory = BoardDirectory()
        ..addManual(manual)
        ..found('id-a', a);
      expect(directory.boards, [a]);
    });

    test('搜尋到的看板消失後，同位址的手動看板會重新出現', () {
      const manual = BoardInfo(
        name: '手動的名字',
        host: '192.168.1.10',
        port: 47800,
      );
      final directory = BoardDirectory()
        ..addManual(manual)
        ..found('id-a', a)
        ..lost('id-a');
      expect(directory.boards, [manual]);
    });

    test('分得出哪些是手動加入的', () {
      final directory = BoardDirectory()
        ..found('id-a', a)
        ..addManual(const BoardInfo(name: '手動', host: '10.0.0.9', port: 47800));
      expect(directory.isManual(directory.boards.last), isTrue);
      expect(directory.isManual(a), isFalse);
    });

    test('可以移除', () {
      final directory = BoardDirectory()
        ..addManual(a)
        ..removeManual(a);
      expect(directory.isEmpty, isTrue);
    });
  });
}

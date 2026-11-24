import 'package:cam_board_core/cam_board_core.dart';
import 'package:test/test.dart';

void main() {
  const a = CandidateMessage(candidate: 'a');
  const b = CandidateMessage(candidate: 'b');
  const c = CandidateMessage(candidate: 'c');

  late List<CandidateMessage> delivered;
  late CandidateGate gate;

  setUp(() {
    delivered = [];
    gate = CandidateGate((candidate) async => delivered.add(candidate));
  });

  test('連線還沒準備好時，收到的網路路徑先留著', () async {
    await gate.add(a);
    await gate.add(b);

    expect(delivered, isEmpty);
    expect(gate.heldCount, 2);
  });

  test('準備好之後，留著的照收到的順序交出去', () async {
    await gate.add(a);
    await gate.add(b);
    await gate.open();

    expect(delivered, [a, b]);
    expect(gate.heldCount, 0);
  });

  test('準備好之後才收到的直接交出去', () async {
    await gate.open();
    await gate.add(c);

    expect(delivered, [c]);
  });

  test('先留著的排在後來才到的前面', () async {
    await gate.add(a);
    await gate.open();
    await gate.add(b);

    expect(delivered, [a, b]);
  });

  test('沒有留著任何東西時，準備好也不會出錯', () async {
    await gate.open();
    expect(delivered, isEmpty);
  });

  test('其中一條不能用時跳過它，其他的照樣交出去', () async {
    gate = CandidateGate((candidate) async {
      if (candidate == b) throw StateError('這條路徑不能用');
      delivered.add(candidate);
    });

    await gate.add(a);
    await gate.add(b);
    await gate.add(c);
    await gate.open();

    expect(delivered, [a, c]);
  });

  test('準備好之後才到的那一條不能用，也不會丟出錯誤', () async {
    gate = CandidateGate((_) async => throw StateError('這條路徑不能用'));
    await gate.open();

    await expectLater(gate.add(a), completes);
  });
}

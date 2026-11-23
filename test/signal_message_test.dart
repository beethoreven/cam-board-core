import 'package:cam_board_core/cam_board_core.dart';
import 'package:test/test.dart';

void main() {
  group('編碼後再解析會得到同樣的訊息', () {
    test('hello', () {
      final decoded = SignalMessage.decode(
        const HelloMessage(name: '教室白板').encode(),
      );
      decoded as HelloMessage;
      expect(decoded.name, '教室白板');
      expect(decoded.isCompatible, isTrue);
    });

    test('join', () {
      final decoded = SignalMessage.decode(const JoinMessage().encode());
      expect(decoded, isA<JoinMessage>());
      expect((decoded as JoinMessage).protocol, protocolVersion);
      expect(decoded.isCompatible, isTrue);
    });

    test('offer 與 answer', () {
      final offer = SignalMessage.decode(
        const OfferMessage(sdp: 'v=0').encode(),
      );
      final answer = SignalMessage.decode(
        const AnswerMessage(sdp: 'v=1').encode(),
      );
      expect((offer as OfferMessage).sdp, 'v=0');
      expect((answer as AnswerMessage).sdp, 'v=1');
    });

    test('candidate，包含可以省略的欄位', () {
      final full = SignalMessage.decode(
        const CandidateMessage(
          candidate: 'candidate:1',
          sdpMid: '0',
          sdpMLineIndex: 0,
        ).encode(),
      );
      full as CandidateMessage;
      expect(full.candidate, 'candidate:1');
      expect(full.sdpMid, '0');
      expect(full.sdpMLineIndex, 0);

      final bare = SignalMessage.decode(
        const CandidateMessage(candidate: 'candidate:2').encode(),
      );
      bare as CandidateMessage;
      expect(bare.sdpMid, isNull);
      expect(bare.sdpMLineIndex, isNull);
    });

    test('bye 的每一種原因', () {
      for (final reason in ByeReason.values) {
        final decoded = SignalMessage.decode(ByeMessage(reason).encode());
        expect((decoded as ByeMessage).reason, reason);
      }
    });
  });

  test('版本不同的 join 會被判定為不相容', () {
    final decoded = SignalMessage.decode('{"type":"join","protocol":999}');
    expect((decoded as JoinMessage).isCompatible, isFalse);
  });

  group('格式不對的訊息丟 FormatException', () {
    final badInputs = {
      '不是 JSON': 'hello',
      '不是物件': '[1,2,3]',
      '沒有 type': '{"sdp":"v=0"}',
      '未知的 type': '{"type":"dance"}',
      'hello 缺名字': '{"type":"hello","protocol":1}',
      'offer 缺 sdp': '{"type":"offer"}',
      'sdp 不是字串': '{"type":"answer","sdp":5}',
      'join 的 protocol 不是整數': '{"type":"join","protocol":"1"}',
      'bye 的原因未知': '{"type":"bye","reason":"bored"}',
    };
    badInputs.forEach((name, raw) {
      test(name, () {
        expect(() => SignalMessage.decode(raw), throwsFormatException);
      });
    });
  });
}

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

    test('join 帶著鄉民名稱', () {
      final decoded = SignalMessage.decode(
        const JoinMessage(name: '阿明的 Mac').encode(),
      );
      expect((decoded as JoinMessage).name, '阿明的 Mac');
    });

    test('舊版沒有名稱的 join 仍然解析得出來，才能回覆版本不同', () {
      final decoded = SignalMessage.decode('{"type":"join","protocol":2}');
      decoded as JoinMessage;
      expect(decoded.name, '');
      expect(decoded.isCompatible, isFalse);
    });

    test('抄錄的開始與結束', () {
      expect(
        SignalMessage.decode(const RecordStartMessage().encode()),
        isA<RecordStartMessage>(),
      );
      expect(
        SignalMessage.decode(const RecordStopMessage().encode()),
        isA<RecordStopMessage>(),
      );
    });

    test('照片與收到了', () {
      final shot = SignalMessage.decode(
        const ShotMessage(
          id: 7,
          width: 1920,
          height: 1080,
          rotation: 90,
        ).encode(),
      );
      shot as ShotMessage;
      expect(shot.id, 7);
      expect((shot.width, shot.height, shot.rotation), (1920, 1080, 90));
      // 後面那筆畫面資料的大小：寬×高×1.5。
      expect(shot.bytes, 3110400);

      final saved = SignalMessage.decode(
        const ShotReceivedMessage(id: 7).encode(),
      );
      expect((saved as ShotReceivedMessage).id, 7);
    });

    test('candidates_done', () {
      final decoded = SignalMessage.decode(
        const CandidatesDoneMessage().encode(),
      );
      expect(decoded, isA<CandidatesDoneMessage>());
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
      'shot 沒有尺寸': '{"type":"shot","id":1,"bytes":10}',
      'shot 的寬是奇數': '{"type":"shot","id":1,"width":3,"height":2,"rotation":0}',
      'shot 的角度不是四個方向':
          '{"type":"shot","id":1,"width":4,"height":2,"rotation":45}',
      'join 的 protocol 不是整數': '{"type":"join","protocol":"1"}',
      'bye 的原因未知': '{"type":"bye","reason":"bored"}',
      'shot 缺大小': '{"type":"shot","id":1}',
      'shot_received 的編號不是整數': '{"type":"shot_received","id":"1"}',
    };
    badInputs.forEach((name, raw) {
      test(name, () {
        expect(() => SignalMessage.decode(raw), throwsFormatException);
      });
    });
  });
}

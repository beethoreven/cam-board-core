import 'dart:typed_data';

import 'package:cam_board_core/cam_board_core.dart';
import 'package:test/test.dart';

void main() {
  group('資料夾與檔案名稱', () {
    test('資料夾名稱是看板名稱加上開始的時間', () {
      expect(
        recordingFolderName('教室白板', DateTime(2026, 11, 25, 14, 30, 5)),
        '教室白板抄錄紀錄_26-11-25-14-30-05',
      );
    });

    test('個位數的月日時分秒補零', () {
      expect(
        recordingFolderName('甲', DateTime(2027, 1, 2, 3, 4, 5)),
        '甲抄錄紀錄_27-01-02-03-04-05',
      );
    });

    test('看板名稱裡不能當檔名的字元換成底線', () {
      expect(safeFileName('一年/甲班:白板?'), '一年_甲班_白板_');
      expect(safeFileName(r'a\b*c"d<e>f|g'), 'a_b_c_d_e_f_g');
    });

    test('結尾的句點和空白去掉，什麼都不剩時用「看板」', () {
      expect(safeFileName('白板. .'), '白板');
      expect(safeFileName('  '), '看板');
      expect(safeFileName('...'), '看板');
    });

    test('照片檔名是三位數的流水號', () {
      expect(shotFileName(1), '001.png');
      expect(shotFileName(42), '042.png');
      expect(shotFileName(1234), '1234.png');
    });

    test('照片檔名前面加上這次抄錄開始的時間', () {
      final startedAt = DateTime(2026, 11, 27, 11, 31, 10);
      expect(shotFileName(1, startedAt), '2026_11_27_11_31_10_001.png');
      expect(shotFileName(42, startedAt), '2026_11_27_11_31_10_042.png');
      // 個位數的月、日、時、分、秒補成兩位。
      expect(
        shotFileName(3, DateTime(2027, 1, 2, 3, 4, 5)),
        '2027_01_02_03_04_05_003.png',
      );
    });
  });

  group('鄉民端的抄錄', () {
    late ViewerRecording recording;

    setUp(() => recording = ViewerRecording());

    test('一開始沒有在抄錄', () {
      expect(recording.active, isFalse);
      expect(recording.folder, isNull);
    });

    test('開始後記得資料夾，檔名從 001 開始', () {
      recording.start('/tmp/甲抄錄紀錄');

      expect(recording.active, isTrue);
      expect(recording.folder, '/tmp/甲抄錄紀錄');
      expect(recording.nextFileName(), '001.png');
    });

    test('存好一張之後才換下一個檔名', () {
      recording.start('/tmp/a');
      expect(recording.nextFileName(), '001.png');
      expect(recording.nextFileName(), '001.png');

      recording.saved();

      expect(recording.nextFileName(), '002.png');
      expect(recording.savedCount, 1);
    });

    test('抄錄中不能再開始一次', () {
      recording.start('/tmp/a');
      expect(() => recording.start('/tmp/b'), throwsStateError);
    });

    test('抄錄完了之後再開始，檔名重新從 001 算', () {
      recording.start('/tmp/a');
      recording.saved();
      recording.stop();
      recording.start('/tmp/b');

      expect(recording.nextFileName(), '001.png');
    });

    test('沒有在抄錄時問檔名會出錯，按抄錄完了不會', () {
      expect(recording.nextFileName, throwsStateError);
      recording.stop();
      expect(recording.active, isFalse);
    });
  });

  group('看板端記錄誰在抄錄', () {
    late BoardRecorders recorders;

    setUp(() => recorders = BoardRecorders());

    test('只有說了開始抄錄的鄉民端才算', () {
      recorders.joined('a', '阿明');
      recorders.joined('b', '小華');
      recorders.started('b');

      expect(recorders.recording, {'b'});
      expect(recorders.isRecording('a'), isFalse);
    });

    test('抄錄完了就不再算', () {
      recorders.joined('a', '阿明');
      recorders.started('a');
      recorders.stopped('a');

      expect(recorders.recording, isEmpty);
    });

    test('鄉民端離開時，它的抄錄也跟著結束', () {
      recorders.joined('a', '阿明');
      recorders.started('a');
      recorders.left('a');

      expect(recorders.recording, isEmpty);
      expect(recorders.nameOf('a'), isNull);
    });

    test('還沒加入的鄉民端說要抄錄，不理它', () {
      recorders.started('stranger');
      expect(recorders.recording, isEmpty);
    });

    test('記得每個鄉民端的名稱', () {
      recorders.joined('a', '阿明');
      expect(recorders.nameOf('a'), '阿明');
    });

    test('傳過照片給它，它回報收到，才知道是誰抄錄了', () {
      recorders.joined('a', '阿明');
      recorders.started('a');
      recorders.shotSent('a', 7);

      expect(recorders.shotConfirmed('a', 7), '阿明');
    });

    test('同一張只算一次', () {
      recorders.joined('a', '阿明');
      recorders.shotSent('a', 7);
      recorders.shotConfirmed('a', 7);

      expect(recorders.shotConfirmed('a', 7), isNull);
    });

    test('沒傳過的編號、沒傳給它的照片，回報了也不算', () {
      recorders.joined('a', '阿明');
      recorders.joined('b', '小華');
      recorders.shotSent('a', 7);

      expect(recorders.shotConfirmed('a', 8), isNull);
      expect(recorders.shotConfirmed('b', 7), isNull);
      expect(recorders.shotConfirmed('stranger', 7), isNull);
    });

    test('全部清掉', () {
      recorders.joined('a', '阿明');
      recorders.started('a');
      recorders.clear();

      expect(recorders.recording, isEmpty);
      expect(recorders.nameOf('a'), isNull);
    });
  });

  test('提示的文字', () {
    expect(shotSavedNotice('阿明'), '阿明抄錄了這個內容');
  });

  group('看板端留著還沒確認的照片', () {
    RawFrame frame([int width = 4, int height = 2]) => RawFrame(
      width: width,
      height: height,
      rotation: 0,
      i420: Uint8List(RawFrame.byteLength(width, height)),
    );

    BoardRecorders withA() => BoardRecorders()
      ..joined('a', '阿明')
      ..started('a');

    test('接回來時把還沒確認的照片照編號補送', () {
      final recorders = withA();
      recorders.shotSent('a', 2, frame());
      recorders.shotSent('a', 1, frame());
      recorders.shotSent('a', 3, frame());
      recorders.shotConfirmed('a', 2);
      expect(recorders.resend('a').map((shot) => shot.id), [1, 3]);
    });

    test('一張最多補送 3 次', () {
      final recorders = withA();
      recorders.shotSent('a', 1, frame());
      for (var i = 0; i < maxShotResends; i++) {
        expect(recorders.resend('a'), hasLength(1));
      }
      expect(recorders.resend('a'), isEmpty);
    });

    test('沒有留畫面的照片不能補送', () {
      final recorders = withA();
      recorders.shotSent('a', 1);
      expect(recorders.resend('a'), isEmpty);
    });

    test('等太久放棄時，回傳沒收到的那位鄉民的名稱', () {
      final recorders = withA();
      recorders.shotSent('a', 1, frame());
      expect(recorders.giveUp('a', 1), '阿明');
      // 放棄之後它才回報：不算數，也不能再放棄一次。
      expect(recorders.shotConfirmed('a', 1), isNull);
      expect(recorders.giveUp('a', 1), isNull);
    });

    test('已經確認的照片放棄不了', () {
      final recorders = withA();
      recorders.shotSent('a', 1, frame());
      recorders.shotConfirmed('a', 1);
      expect(recorders.giveUp('a', 1), isNull);
    });

    test('同一張傳給兩個鄉民端只佔一份記憶體，都確認了才釋放', () {
      final recorders = withA()
        ..joined('b', '小華')
        ..started('b');
      final shared = frame();
      recorders.shotSent('a', 1, shared);
      recorders.shotSent('b', 1, shared);
      expect(recorders.pendingBytes, shared.i420.length);
      recorders.shotConfirmed('a', 1);
      expect(recorders.pendingBytes, shared.i420.length);
      recorders.shotConfirmed('b', 1);
      expect(recorders.pendingBytes, 0);
    });

    test('暫存超過 20 MB 就沒有位置再留一張', () {
      final recorders = withA();
      final big = frame(1920, 1080);
      var id = 0;
      while (recorders.hasRoomFor(big.i420.length)) {
        recorders.shotSent('a', ++id, big);
      }
      expect(id, maxPendingShotBytes ~/ big.i420.length);
      recorders.shotConfirmed('a', 1);
      expect(recorders.hasRoomFor(big.i420.length), isTrue);
    });

    test('滿了就丟最舊的那一張，並回報誰沒收到', () {
      final recorders = withA()
        ..joined('b', '小華')
        ..started('b');
      final shared = frame();
      recorders.shotSent('a', 3, shared);
      recorders.shotSent('b', 3, shared);
      recorders.shotSent('a', 5, frame());
      // b 已經收到 3 了，只有 a 還在等。
      recorders.shotConfirmed('b', 3);

      expect(recorders.dropOldest(), [(viewerId: 'a', name: '阿明', id: 3)]);
      // 被丟掉的不能再補送，也不能再被確認。
      expect(recorders.resend('a').map((shot) => shot.id), [5]);
      expect(recorders.shotConfirmed('a', 3), isNull);
    });

    test('同一張好幾個人都沒收到：一起丟，每個人都回報', () {
      final recorders = withA()
        ..joined('b', '小華')
        ..started('b');
      final shared = frame();
      recorders.shotSent('a', 1, shared);
      recorders.shotSent('b', 1, shared);

      expect(recorders.dropOldest().map((lost) => lost.name), ['阿明', '小華']);
      expect(recorders.pendingBytes, 0);
    });

    test('沒有照片可丟時什麼都不做', () {
      expect(withA().dropOldest(), isEmpty);
    });

    test('鄉民端離開後，它沒確認的照片不再佔記憶體', () {
      final recorders = withA();
      recorders.shotSent('a', 1, frame());
      recorders.left('a');
      expect(recorders.pendingBytes, 0);
      expect(recorders.resend('a'), isEmpty);
    });
  });

  group('鄉民端不重複存同一張', () {
    test('同一個編號第二次收到時不用再存', () {
      final recording = ViewerRecording()..start('/tmp/x');
      expect(recording.firstTime(5), isTrue);
      expect(recording.firstTime(5), isFalse);
      expect(recording.firstTime(6), isTrue);
    });

    test('同一次抄錄的每一張都用開始的時間，不是存檔當下的時間', () {
      final recording = ViewerRecording()
        ..start('/tmp/x', DateTime(2026, 11, 27, 11, 31, 10));
      expect(recording.nextFileName(), '2026_11_27_11_31_10_001.png');
      recording.saved();
      expect(recording.nextFileName(), '2026_11_27_11_31_10_002.png');
    });

    test('新的一次抄錄重新算（看板端重開後編號會從頭來）', () {
      final recording = ViewerRecording()..start('/tmp/x');
      recording.firstTime(1);
      recording
        ..stop()
        ..start('/tmp/y');
      expect(recording.firstTime(1), isTrue);
    });
  });
}

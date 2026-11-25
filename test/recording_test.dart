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
}

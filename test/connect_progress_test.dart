import 'package:cam_board_core/cam_board_core.dart';
import 'package:test/test.dart';

void main() {
  late ConnectProgress progress;

  setUp(() => progress = ConnectProgress());

  group('逾時的原因看連線進行到哪一步', () {
    test('加入要求還沒送出去：連不到看板端', () {
      expect(progress.failureOnTimeout, ConnectFailure.boardUnreachable);
    });

    test('送出加入要求後沒收到連線資訊：看板端沒有回應', () {
      progress.advanceTo(ConnectStage.waitingForOffer);
      expect(progress.failureOnTimeout, ConnectFailure.boardSilent);
    });

    test('收到連線資訊、沒收到送完了：交換到一半沒有下文', () {
      progress.advanceTo(ConnectStage.waitingForOffer);
      progress.advanceTo(ConnectStage.exchangingPaths);
      expect(progress.failureOnTimeout, ConnectFailure.exchangeStalled);
    });

    test('看板端的路徑都送完了還是沒畫面：兩台裝置之間不通', () {
      progress.advanceTo(ConnectStage.waitingForOffer);
      progress.advanceTo(ConnectStage.exchangingPaths);
      progress.advanceTo(ConnectStage.pathsComplete);
      expect(progress.failureOnTimeout, ConnectFailure.noWorkingPath);
    });
  });

  test('晚到或重複的通知不會讓進度倒退', () {
    progress.advanceTo(ConnectStage.pathsComplete);
    progress.advanceTo(ConnectStage.waitingForOffer);
    progress.advanceTo(ConnectStage.pathsComplete);

    expect(progress.stage, ConnectStage.pathsComplete);
  });

  test('區域網路內連線，不需要久等', () {
    expect(connectTimeout, lessThanOrEqualTo(const Duration(seconds: 15)));
  });
}

import 'package:cam_board_core/cam_board_core.dart';
import 'package:test/test.dart';

void main() {
  test('沒有任何位址時回傳 null', () {
    expect(pickLanAddress([]), isNull);
  });

  test('連 Wi-Fi 時挑 Wi-Fi 的位址', () {
    expect(
      pickLanAddress([(interfaceName: 'wlan0', address: '192.168.1.23')]),
      '192.168.1.23',
    );
  });

  test('避開行動網路，即使它是私有網段', () {
    expect(
      pickLanAddress([
        (interfaceName: 'rmnet_data0', address: '10.80.3.4'),
        (interfaceName: 'wlan0', address: '192.168.1.23'),
      ]),
      '192.168.1.23',
    );
  });

  test('只有行動網路時回傳 null', () {
    expect(
      pickLanAddress([(interfaceName: 'rmnet_data0', address: '10.80.3.4')]),
      isNull,
    );
  });

  test('自己開熱點時挑熱點的位址', () {
    expect(
      pickLanAddress([
        (interfaceName: 'rmnet_data0', address: '10.80.3.4'),
        (interfaceName: 'ap0', address: '192.168.43.1'),
      ]),
      '192.168.43.1',
    );
  });

  test('不挑公開的位址', () {
    expect(
      pickLanAddress([(interfaceName: 'wlan0', address: '8.8.8.8')]),
      isNull,
    );
  });

  test('172 網段只有 16 到 31 算私有', () {
    expect(
      pickLanAddress([(interfaceName: 'wlan0', address: '172.20.10.2')]),
      '172.20.10.2',
    );
    expect(
      pickLanAddress([(interfaceName: 'wlan0', address: '172.32.0.1')]),
      isNull,
    );
  });

  test('Wi-Fi 介面優先於名稱不認得的介面', () {
    expect(
      pickLanAddress([
        (interfaceName: 'tun0', address: '10.8.0.2'),
        (interfaceName: 'wlan0', address: '192.168.1.23'),
      ]),
      '192.168.1.23',
    );
  });

  test('格式不對的位址被忽略', () {
    expect(
      pickLanAddress([(interfaceName: 'wlan0', address: 'fe80::1')]),
      isNull,
    );
  });

  group('isLanPeer', () {
    test('私有網段、同一台裝置、自動取得的位址都算區域網路', () {
      for (final ok in [
        '192.168.43.7',
        '10.0.0.5',
        '172.20.1.1',
        '127.0.0.1',
        '169.254.10.2',
        '::ffff:192.168.1.5',
      ]) {
        expect(isLanPeer(ok), isTrue, reason: ok);
      }
    });

    test('公開的位址和看不懂的位址不算', () {
      for (final bad in ['8.8.8.8', '172.32.0.1', '100.64.0.1', '::1', 'abc']) {
        expect(isLanPeer(bad), isFalse, reason: bad);
      }
    });
  });
}

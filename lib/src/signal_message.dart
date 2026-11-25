import 'dart:convert';

import 'board_info.dart';
import 'raw_frame.dart';
import 'recording.dart';

/// 通訊協定版本。兩端版本不同時，鄉民端在 [JoinMessage] 就會被拒絕，
/// 不會等到畫面出不來才發現。
///
/// 版本 2：新增 [CandidatesDoneMessage]。
/// 版本 3：[JoinMessage] 帶上鄉民名稱；新增抄錄用的 [RecordStartMessage]、
/// [RecordStopMessage]、[ShotMessage]、[ShotReceivedMessage]。
/// 版本 4：照片改送還沒壓縮的畫面（見 [RawFrame]），[ShotMessage] 改帶寬、高和角度；
/// 壓成 PNG 改由鄉民端做。`shot_saved` 改成 `shot_received`：鄉民端收完整就回報，
/// 不等存檔。
const int protocolVersion = 4;

/// 結束觀看的原因。
enum ByeReason {
  /// 鄉民端按了「不看了」。
  viewerLeft('viewer_left'),

  /// 看板端按了「不給看了」。
  boardStopped('board_stopped'),

  /// 看板端撤銷註冊。
  boardUnregistered('board_unregistered'),

  /// 兩端的通訊協定版本不同。
  versionMismatch('version_mismatch');

  const ByeReason(this.wire);

  /// 在網路上傳送時用的字串。
  final String wire;

  /// 不認得的原因（對方比較新）當成 [boardStopped]：重點是「結束了」，
  /// 不能因為看不懂原因就把整則結束訊息丟掉，否則這一端會以為還在看。
  static ByeReason fromWire(String wire) => values.firstWhere(
    (r) => r.wire == wire,
    orElse: () => ByeReason.boardStopped,
  );
}

/// 兩端透過 WebSocket 交換的訊息。每則訊息是一個 JSON 物件，`type` 決定種類。
///
/// 流程：鄉民端一連上，看板端先送 [HelloMessage] 報上名字 →
/// 鄉民端要看畫面時送 [JoinMessage] → 看板端回 [OfferMessage] →
/// 鄉民端回 [AnswerMessage]；期間雙方互送 [CandidateMessage]，
/// 看板端的網路路徑全部送完時再送一則 [CandidatesDoneMessage]；
/// 任一方送 [ByeMessage] 就結束。
///
/// 抄錄：鄉民端開始和結束時送 [RecordStartMessage]、[RecordStopMessage]；
/// 看板端按拍照時，對抄錄中的鄉民端送 [ShotMessage]，後面緊接著一筆二進位資料
/// （那張照片還沒壓縮的畫面，見 [RawFrame]）；鄉民端確認收完整就回 [ShotReceivedMessage]。
sealed class SignalMessage {
  const SignalMessage();

  Map<String, Object?> toJson();

  /// 編成可以直接送進 WebSocket 的字串。
  String encode() => jsonEncode(toJson());

  /// 解析收到的字串。格式不對時丟 [FormatException]，
  /// 呼叫端應該丟棄這則訊息，而不是讓整條連線壞掉。
  static SignalMessage decode(String raw) {
    final Object? json;
    try {
      json = jsonDecode(raw);
    } on FormatException {
      throw const FormatException('訊息不是合法的 JSON');
    }
    if (json is! Map<String, Object?>) {
      throw const FormatException('訊息必須是 JSON 物件');
    }
    final type = json['type'];
    return switch (type) {
      'hello' => HelloMessage(
        name: _boardName(json),
        protocol: _int(json, 'protocol'),
      ),
      'join' => JoinMessage(
        protocol: _int(json, 'protocol'),
        // 舊版的鄉民端不會帶名稱。這裡不能因此丟掉整則訊息，
        // 否則看板端沒辦法回覆它「版本不同」。
        // 名稱是對方給的，會顯示在看板端畫面上，所以先整理過（長度、控制字元）。
        name: json['name'] is String
            ? cleanViewerName(json['name'] as String)
            : '',
      ),
      'offer' => OfferMessage(sdp: _string(json, 'sdp')),
      'answer' => AnswerMessage(sdp: _string(json, 'sdp')),
      'candidate' => CandidateMessage(
        candidate: _string(json, 'candidate'),
        sdpMid: json['sdpMid'] as String?,
        sdpMLineIndex: json['sdpMLineIndex'] as int?,
      ),
      'candidates_done' => const CandidatesDoneMessage(),
      'record_start' => const RecordStartMessage(),
      'record_stop' => const RecordStopMessage(),
      'shot' => ShotMessage.checked(
        id: _int(json, 'id'),
        width: _int(json, 'width'),
        height: _int(json, 'height'),
        rotation: _int(json, 'rotation'),
      ),
      'shot_received' => ShotReceivedMessage(id: _int(json, 'id')),
      'bye' => ByeMessage(ByeReason.fromWire(_string(json, 'reason'))),
      _ => throw FormatException('未知的訊息種類：$type'),
    };
  }

  /// 看板名稱是對方給的，會顯示在清單上、也會用來取資料夾名稱。
  /// 看板端自己註冊時就不能超過 [maxBoardNameBytes]，超過的不是正常的看板。
  static String _boardName(Map<String, Object?> json) {
    final name = _string(json, 'name');
    if (utf8.encode(name).length > maxBoardNameBytes) {
      throw const FormatException('看板名稱太長');
    }
    return name;
  }

  static String _string(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! String) throw FormatException('欄位 $key 必須是字串');
    return value;
  }

  static int _int(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! int) throw FormatException('欄位 $key 必須是整數');
    return value;
  }
}

/// 看板端：連線一建立就送出，報上看板名稱與通訊協定版本。
///
/// 鄉民端手動輸入位址時，靠這則訊息確認對方真的是看板，並取得名稱。
final class HelloMessage extends SignalMessage {
  const HelloMessage({required this.name, this.protocol = protocolVersion});

  final String name;
  final int protocol;

  bool get isCompatible => protocol == protocolVersion;

  @override
  Map<String, Object?> toJson() => {
    'type': 'hello',
    'name': name,
    'protocol': protocol,
  };
}

/// 鄉民端：我要看這個看板。
final class JoinMessage extends SignalMessage {
  const JoinMessage({this.protocol = protocolVersion, this.name = ''});

  final int protocol;

  /// 鄉民的名稱，看板端用來顯示「誰抄錄了這個內容」。
  final String name;

  bool get isCompatible => protocol == protocolVersion;

  @override
  Map<String, Object?> toJson() => {
    'type': 'join',
    'protocol': protocol,
    'name': name,
  };
}

/// 看板端：這是我的畫面連線資訊。
final class OfferMessage extends SignalMessage {
  const OfferMessage({required this.sdp});

  final String sdp;

  @override
  Map<String, Object?> toJson() => {'type': 'offer', 'sdp': sdp};
}

/// 鄉民端：收到，這是我的連線資訊。
final class AnswerMessage extends SignalMessage {
  const AnswerMessage({required this.sdp});

  final String sdp;

  @override
  Map<String, Object?> toJson() => {'type': 'answer', 'sdp': sdp};
}

/// 任一方：這是一條可以連到我的網路路徑。
final class CandidateMessage extends SignalMessage {
  const CandidateMessage({
    required this.candidate,
    this.sdpMid,
    this.sdpMLineIndex,
  });

  final String candidate;
  final String? sdpMid;
  final int? sdpMLineIndex;

  @override
  Map<String, Object?> toJson() => {
    'type': 'candidate',
    'candidate': candidate,
    'sdpMid': sdpMid,
    'sdpMLineIndex': sdpMLineIndex,
  };
}

/// 看板端：我的網路路徑全部送完了，不會再有新的。
///
/// 鄉民端收到之後如果畫面還是連不上，就知道問題出在兩台裝置之間的網路，
/// 不是還有路徑沒到。規則見 `connect_progress.dart`。
final class CandidatesDoneMessage extends SignalMessage {
  const CandidatesDoneMessage();

  @override
  Map<String, Object?> toJson() => {'type': 'candidates_done'};
}

/// 鄉民端：我開始抄錄了，之後拍的照片請傳給我。
final class RecordStartMessage extends SignalMessage {
  const RecordStartMessage();

  @override
  Map<String, Object?> toJson() => {'type': 'record_start'};
}

/// 鄉民端：我抄錄完了，之後拍的照片不用再傳給我。
final class RecordStopMessage extends SignalMessage {
  const RecordStopMessage();

  @override
  Map<String, Object?> toJson() => {'type': 'record_stop'};
}

/// 看板端：拍了一張照片。緊接在這則訊息後面的那一筆二進位資料就是它的畫面
/// （還沒壓縮，格式見 [RawFrame]）。
final class ShotMessage extends SignalMessage {
  const ShotMessage({
    required this.id,
    required this.width,
    required this.height,
    required this.rotation,
  });

  /// 收到的訊息用這個建立：尺寸或角度不合理時當成格式錯誤。
  factory ShotMessage.checked({
    required int id,
    required int width,
    required int height,
    required int rotation,
  }) {
    if (!RawFrame.isValidSize(width, height)) {
      throw FormatException('照片的寬和高不合理：$width×$height');
    }
    if (!RawFrame.isValidRotation(rotation)) {
      throw FormatException('照片的角度只能是 0、90、180、270：$rotation');
    }
    return ShotMessage(
      id: id,
      width: width,
      height: height,
      rotation: rotation,
    );
  }

  /// 這張照片的編號，鄉民端回覆 [ShotReceivedMessage] 時帶回來。
  final int id;

  /// 畫面資料裡的寬和高（還沒轉正）。
  final int width;
  final int height;

  /// 要順時針轉幾度才是正的。
  final int rotation;

  /// 後面那筆畫面資料的大小，鄉民端用來確認收到的資料是完整的。
  int get bytes => RawFrame.byteLength(width, height);

  @override
  Map<String, Object?> toJson() => {
    'type': 'shot',
    'id': id,
    'width': width,
    'height': height,
    'rotation': rotation,
  };
}

/// 鄉民端：編號 [id] 的照片完整收到了。看板端收到這則就顯示誰抄錄了；
/// 轉成 PNG 和存檔是鄉民端之後自己的事，不讓看板端等。
final class ShotReceivedMessage extends SignalMessage {
  const ShotReceivedMessage({required this.id});

  final int id;

  @override
  Map<String, Object?> toJson() => {'type': 'shot_received', 'id': id};
}

/// 任一方：結束觀看。
final class ByeMessage extends SignalMessage {
  const ByeMessage(this.reason);

  final ByeReason reason;

  @override
  Map<String, Object?> toJson() => {'type': 'bye', 'reason': reason.wire};
}

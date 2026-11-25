/// cam-board 兩端（看板端、鄉民端）共用的純 Dart 邏輯。
///
/// 這裡不依賴 Flutter，也不碰網路或鏡頭，只放「可以單獨測試的規則」：
/// 兩端怎麼互相說話、看板怎麼在區域網路上被描述、鄉民端視窗該多大。
library;

export 'src/board_directory.dart';
export 'src/board_info.dart';
export 'src/board_session.dart';
export 'src/candidate_gate.dart';
export 'src/connect_progress.dart';
export 'src/focus_control.dart';
export 'src/lan_address.dart';
export 'src/recording.dart';
export 'src/signal_message.dart';
export 'src/view_geometry.dart';
export 'src/viewer_session.dart';
export 'src/zoom.dart';

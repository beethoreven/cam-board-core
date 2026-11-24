/// 看板端鏡頭縮放的倍率範圍。
///
/// 視訊套件沒有提供查詢鏡頭實際上限的方法，所以用固定的範圍。
/// 超過鏡頭能力的倍率會由手機自己限制在它做得到的最大值。
const double minZoom = 1.0;
const double maxZoom = 8.0;

/// 把倍率限制在 [minZoom] 到 [maxZoom] 之間。
double clampZoom(double zoom) => zoom.clamp(minZoom, maxZoom).toDouble();

/// 雙指縮放手勢進行中，鏡頭該用的倍率。
///
/// [startZoom] 是手勢開始那一刻的倍率，[scale] 是手勢回報的兩指距離比例
/// （1.0 代表沒動，2.0 代表兩指距離變成兩倍）。用手勢開始時的倍率去乘，
/// 連續兩次手勢才會接續上一次的結果，而不是每次都從 1 倍重來。
double zoomForPinch({required double startZoom, required double scale}) =>
    clampZoom(startZoom * scale);

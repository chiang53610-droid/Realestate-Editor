import '../models/clip_timeline.dart';

/// Mock AI 分析服務
///
/// 模擬 AI 分析影片內容並回傳建議的時間軸
/// 目前使用假資料，未來可替換成真實 AI API
class MockAIAnalysisService {
  /// 預設片段標籤
  static const _labels = [
    '開場全景',
    '客廳特寫',
    '廚房導覽',
    '臥室展示',
    '衛浴設施',
    '陽台景觀',
    '社區環境',
    '總結畫面',
  ];

  /// 分析影片列表，回傳建議的剪輯時間軸
  ///
  /// [videoPaths] — 使用者選擇的影片路徑列表
  /// 回傳 — 每段影片建議保留的時間區間
  Future<List<ClipTimeline>> analyze(List<String> videoPaths) async {
    // 模擬 AI 分析需要 2~3 秒
    await Future.delayed(const Duration(seconds: 2));

    final timelines = <ClipTimeline>[];

    for (int i = 0; i < videoPaths.length; i++) {
      // 模擬 AI 建議：保留每段影片的 1~4 秒
      timelines.add(ClipTimeline(
        videoPath: videoPaths[i],
        startSeconds: 1.0,
        endSeconds: 4.0,
        label: _labels[i % _labels.length],
      ));
    }

    return timelines;
  }
}

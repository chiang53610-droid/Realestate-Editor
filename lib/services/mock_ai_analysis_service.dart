import '../models/clip_timeline.dart';
import 'gemini_service.dart';

/// AI 智能分析服務
///
/// 有 Gemini API Key → 呼叫真實 Gemini 1.5 Flash 分析影片
/// 沒有 API Key → 使用 Mock 模擬（回傳固定 1~4 秒）
class MockAIAnalysisService {
  final GeminiService? _gemini;

  /// 預設片段標籤（Mock 模式使用）
  static const _defaultLabels = [
    '開場全景',
    '客廳特寫',
    '廚房導覽',
    '臥室展示',
    '衛浴設施',
    '陽台景觀',
    '社區環境',
    '總結畫面',
  ];

  MockAIAnalysisService({GeminiService? geminiService})
      : _gemini = geminiService;

  bool get isRealAI => _gemini != null && _gemini.isConfigured;

  /// 分析影片列表，回傳建議的剪輯時間軸
  Future<List<ClipTimeline>> analyze(List<String> videoPaths) async {
    if (!isRealAI) return _mockAnalyze(videoPaths);

    try {
      return await _realAnalyze(videoPaths);
    } catch (e) {
      // Gemini 失敗時回退到 Mock
      // ignore: avoid_print
      print('[AIAnalysisService] Gemini 分析失敗，改用模擬模式：$e');
      return _mockAnalyze(videoPaths);
    }
  }

  /// 真實 Gemini 分析
  Future<List<ClipTimeline>> _realAnalyze(List<String> videoPaths) async {
    final allTimelines = <ClipTimeline>[];

    for (final path in videoPaths) {
      final timelines = await _gemini!.analyzeForAutoEdit(path);
      allTimelines.addAll(timelines);
    }

    // 如果 Gemini 回傳空結果，退回 Mock
    if (allTimelines.isEmpty) {
      return _mockAnalyze(videoPaths);
    }

    return allTimelines;
  }

  /// Mock 模擬分析（固定回傳每段 1~4 秒）
  Future<List<ClipTimeline>> _mockAnalyze(List<String> videoPaths) async {
    await Future.delayed(const Duration(seconds: 2));

    final timelines = <ClipTimeline>[];
    for (int i = 0; i < videoPaths.length; i++) {
      timelines.add(ClipTimeline(
        videoPath: videoPaths[i],
        startSeconds: 1.0,
        endSeconds: 4.0,
        label: _defaultLabels[i % _defaultLabels.length],
      ));
    }
    return timelines;
  }
}

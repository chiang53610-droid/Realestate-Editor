import 'gemini_service.dart';
import 'video_export_service.dart';

/// 單句字幕資料
class SubtitleEntry {
  final int index;
  final double startTime;
  final double endTime;
  final String text;

  SubtitleEntry({
    required this.index,
    required this.startTime,
    required this.endTime,
    required this.text,
  });
}

/// AI 處理結果
class AiResult {
  final bool success;
  final String message;
  final String outputPath;
  final List<SubtitleEntry>? subtitles; // 字幕資料（僅 generateSubtitles 使用）

  AiResult({
    required this.success,
    required this.message,
    required this.outputPath,
    this.subtitles,
  });
}

/// AI API 服務
///
/// 有 Gemini API Key → 呼叫真實 Gemini 2.0 Flash
/// 沒有 API Key → 使用 Mock 模擬
class AiApiService {
  final GeminiService? _gemini;
  final VideoExportService _exportService;

  AiApiService({
    GeminiService? geminiService,
    VideoExportService? exportService,
  })  : _gemini = geminiService,
        _exportService = exportService ?? VideoExportService();

  bool get isRealAI => _gemini != null && _gemini.isConfigured;

  // ========== AI 去冗言 ==========

  Future<AiResult> removeFillerWords(String videoPath) async {
    if (!isRealAI) return _mockRemoveFillerWords(videoPath);

    try {
      final result = await _gemini!.analyzeFillerWords(videoPath);

      // 解析 fillerWords 時間戳陣列
      final rawFillers = (result['fillerWords'] as List?) ?? [];
      if (rawFillers.isEmpty) {
        return AiResult(
          success: true,
          message: result['summary'] as String? ?? '未偵測到冗言',
          outputPath: videoPath,
        );
      }

      final fillerSegments = rawFillers
          .map((f) => {
                'startTime': (f['startTime'] as num?)?.toDouble() ?? 0.0,
                'endTime': (f['endTime'] as num?)?.toDouble() ?? 0.0,
              })
          .where((f) => f['endTime']! > f['startTime']!)
          .toList();

      // 用 FFmpeg 切除 filler 片段
      final cutResult = await _exportService.cutFillerSegments(
        videoPath: videoPath,
        fillerSegments: fillerSegments,
      );

      return AiResult(
        success: cutResult.success,
        message: cutResult.message,
        outputPath: cutResult.outputPath ?? videoPath,
      );
    } catch (e) {
      return AiResult(
        success: false,
        message: 'AI 去冗言失敗：$e',
        outputPath: videoPath,
      );
    }
  }

  // ========== AI 字幕 ==========

  Future<AiResult> generateSubtitles(String videoPath) async {
    if (!isRealAI) return _mockGenerateSubtitles(videoPath);

    try {
      final result = await _gemini!.generateSubtitles(videoPath);
      final rawSubs = (result['subtitles'] as List?) ?? [];
      final subtitles = rawSubs
          .map((s) => SubtitleEntry(
                index: (s['index'] as num?)?.toInt() ?? 0,
                startTime: (s['startTime'] as num?)?.toDouble() ?? 0.0,
                endTime: (s['endTime'] as num?)?.toDouble() ?? 0.0,
                text: (s['text'] as String?) ?? '',
              ))
          .where((s) => s.text.isNotEmpty)
          .toList();

      return AiResult(
        success: true,
        message: '已生成 ${subtitles.length} 句字幕',
        outputPath: videoPath,
        subtitles: subtitles,
      );
    } catch (e) {
      return AiResult(
        success: false,
        message: 'AI 字幕失敗：$e',
        outputPath: videoPath,
      );
    }
  }

  // ========== 名片片尾 ==========

  Future<AiResult> generateBusinessCard({
    required String videoPath,
    required String agentName,
    required String phone,
    String title = '',
    String company = '',
  }) async {
    if (!isRealAI) return _mockGenerateBusinessCard(videoPath, agentName);

    // 直接用 FFmpeg 合成名片片尾（不需要 Gemini 生成文案）
    try {
      final result = await _exportService.appendBusinessCardEnding(
        videoPath: videoPath,
        name: agentName,
        title: title,
        company: company,
        phone: phone,
      );
      return AiResult(
        success: result.success,
        message: result.message,
        outputPath: result.outputPath ?? videoPath,
      );
    } catch (e) {
      return AiResult(
        success: false,
        message: '名片片尾失敗：$e',
        outputPath: videoPath,
      );
    }
  }

  // ========== Mock 方法（無 API Key 時使用） ==========

  Future<AiResult> _mockRemoveFillerWords(String videoPath) async {
    await Future.delayed(const Duration(seconds: 2));
    return AiResult(
      success: true,
      message: '已移除 12 處冗言贅詞（模擬模式）',
      outputPath: videoPath,
    );
  }

  Future<AiResult> _mockGenerateSubtitles(String videoPath) async {
    await Future.delayed(const Duration(seconds: 3));
    final mockSubs = [
      SubtitleEntry(index: 1, startTime: 0.0, endTime: 2.5, text: '歡迎來到這間精美的房子'),
      SubtitleEntry(index: 2, startTime: 2.5, endTime: 5.0, text: '首先我們來看客廳'),
      SubtitleEntry(index: 3, startTime: 5.0, endTime: 8.0, text: '這裡的採光非常好'),
    ];
    return AiResult(
      success: true,
      message: '已生成 ${mockSubs.length} 句字幕（模擬模式）',
      outputPath: videoPath,
      subtitles: mockSubs,
    );
  }

  Future<AiResult> _mockGenerateBusinessCard(
      String videoPath, String name) async {
    await Future.delayed(const Duration(seconds: 2));
    return AiResult(
      success: true,
      message: '已生成 $name 的名片片尾（模擬模式）',
      outputPath: videoPath,
    );
  }
}

import 'gemini_service.dart';

/// AI 處理結果
class AiResult {
  final bool success;
  final String message;
  final String outputPath;

  AiResult({
    required this.success,
    required this.message,
    required this.outputPath,
  });
}

/// AI API 服務
///
/// 有 Gemini API Key → 呼叫真實 Gemini 1.5 Flash
/// 沒有 API Key → 使用 Mock 模擬
class AiApiService {
  final GeminiService? _gemini;

  AiApiService({GeminiService? geminiService}) : _gemini = geminiService;

  bool get isRealAI => _gemini != null && _gemini.isConfigured;

  // ========== AI 去冗言 ==========

  Future<AiResult> removeFillerWords(String videoPath) async {
    if (!isRealAI) return _mockRemoveFillerWords(videoPath);

    try {
      final result = await _gemini!.analyzeFillerWords(videoPath);
      final summary = result['summary'] as String? ?? '分析完成';
      return AiResult(success: true, message: summary, outputPath: videoPath);
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
      final totalLines = result['totalLines'] as int? ?? 0;
      return AiResult(
        success: true,
        message: '已生成 $totalLines 句字幕',
        outputPath: videoPath,
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

    try {
      await _gemini!.generateBusinessCardScript(
        agentName: agentName,
        title: title,
        company: company,
        phone: phone,
      );
      return AiResult(
        success: true,
        message: '已生成 $agentName 的名片片尾',
        outputPath: videoPath,
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
    return AiResult(
      success: true,
      message: '已生成 45 句字幕（模擬模式）',
      outputPath: videoPath,
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

// 這是 Mock API 服務
// 目前用「假等待 + 假回應」模擬後端 AI 處理
// 未來只要把 _mock 方法換成真正的 http 呼叫即可

class AiApiService {
  // 模擬 AI 去冗言
  Future<AiResult> removeFillerWords(String videoPath) async {
    // 模擬等待後端處理 2 秒
    await Future.delayed(const Duration(seconds: 2));
    return AiResult(
      success: true,
      message: '已移除 12 處冗言贅詞',
      outputPath: videoPath, // 未來會是處理後的新影片路徑
    );
  }

  // 模擬 AI 上字幕
  Future<AiResult> generateSubtitles(String videoPath) async {
    await Future.delayed(const Duration(seconds: 3));
    return AiResult(
      success: true,
      message: '已生成 45 句字幕',
      outputPath: videoPath,
    );
  }

  // 模擬生成房仲名片片尾
  Future<AiResult> generateBusinessCard({
    required String videoPath,
    required String agentName,
    required String phone,
  }) async {
    await Future.delayed(const Duration(seconds: 2));
    return AiResult(
      success: true,
      message: '已生成 $agentName 的名片片尾',
      outputPath: videoPath,
    );
  }

  // 模擬匯出完整影片
  Future<AiResult> exportVideo({
    required List<String> videoPaths,
    required bool removeFiller,
    required bool addSubtitles,
    required bool addBusinessCard,
  }) async {
    // 模擬較長的處理時間
    await Future.delayed(const Duration(seconds: 4));
    return AiResult(
      success: true,
      message: '影片匯出完成！',
      outputPath: videoPaths.first,
    );
  }
}

// AI 處理結果的資料模型
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

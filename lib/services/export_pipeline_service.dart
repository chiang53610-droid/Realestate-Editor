import 'dart:io';
import 'package:gal/gal.dart';
import '../models/text_overlay.dart';
import '../models/work_item.dart';
import 'ai_api_service.dart';
import 'video_export_service.dart';
import 'storage_service.dart';

/// 匯出管線執行結果
class ExportPipelineResult {
  final bool success;
  final String message;
  final String? outputPath;
  final bool savedToGallery;

  const ExportPipelineResult({
    required this.success,
    required this.message,
    this.outputPath,
    this.savedToGallery = false,
  });
}

/// 一鍵匯出管線服務
///
/// 封裝完整的 4 步驟 AI 處理管線，讓 EditorScreen 和 OneTapScreen 共用同一套邏輯：
///   Step 1: 影片合併 / 裁剪（VideoExportService）
///   Step 2: AI 去冗言（AiApiService → VideoExportService.cutFillerSegments）
///   Step 3: AI 字幕生成 + 燒錄（AiApiService → VideoExportService.burnSubtitles）
///   Step 4: 名片片尾合成（AiApiService）
///   Final:  儲存相簿 + 寫入作品集紀錄
///
/// UI 回呼：
///   [onStepChange]  每個步驟開始時呼叫，傳入步驟說明文字（用於進度畫面）
///   [onMessage]     每個步驟完成時呼叫，傳入結果訊息（用於 SnackBar / toast）
class ExportPipelineService {
  final VideoExportService _exportService;
  final AiApiService _aiService;
  final StorageService _storageService;

  ExportPipelineService({
    VideoExportService? exportService,
    AiApiService? aiService,
    StorageService? storageService,
  })  : _exportService = exportService ?? VideoExportService(),
        _aiService = aiService ?? AiApiService(),
        _storageService = storageService ?? StorageService();

  /// 執行完整匯出管線
  ///
  /// [videoPaths]    要處理的影片路徑列表
  /// [trimRanges]    裁剪區間 {index: [startRatio, endRatio]}，null 表示不裁剪
  /// [removeFiller]  是否執行 AI 去冗言
  /// [subtitle]      是否生成 AI 字幕
  /// [textOverlays]  自訂文字疊加列表（與字幕在同一 FFmpeg pass 燒錄）
  /// [businessCard]  是否加入名片片尾
  /// [onStepChange]  步驟切換回呼（Step 說明文字）
  /// [onMessage]     訊息回呼（每步驟結果）
  Future<ExportPipelineResult> runPipeline({
    required List<String> videoPaths,
    Map<int, List<double>>? trimRanges,
    bool removeFiller = false,
    bool subtitle = true,
    List<TextOverlay> textOverlays = const [],
    bool businessCard = true,
    void Function(String step)? onStepChange,
    void Function(String message)? onMessage,
  }) async {
    // ── Step 1: 合併 / 裁剪 ─────────────────────────────
    onStepChange?.call('影片合併中...');

    final mergeResult = await _exportService.mergeAndExport(
      videoPaths: videoPaths,
      trimRanges: trimRanges,
    );

    if (!mergeResult.success) {
      return ExportPipelineResult(
        success: false,
        message: mergeResult.message,
      );
    }

    var outputPath = mergeResult.outputPath ?? videoPaths.first;

    // ── Step 2: AI 去冗言 ────────────────────────────────
    if (removeFiller) {
      onStepChange?.call('AI 去冗言處理中...');
      final result = await _aiService.removeFillerWords(outputPath);
      onMessage?.call(result.message);
      if (result.success) outputPath = result.outputPath;
    }

    // ── Step 3: AI 字幕 + 文字疊加（單次 FFmpeg pass）──────
    final validOverlays = textOverlays.where((o) => o.isValid).toList();
    final needsBurn = subtitle || validOverlays.isNotEmpty;

    if (needsBurn) {
      List<SubtitleEntry> subtitles = [];

      if (subtitle) {
        onStepChange?.call('AI 字幕生成中...');
        final subResult = await _aiService.generateSubtitles(outputPath);
        if (subResult.success &&
            subResult.subtitles != null &&
            subResult.subtitles!.isNotEmpty) {
          subtitles = subResult.subtitles!;
        } else {
          onMessage?.call(subResult.message);
        }
      }

      if (subtitles.isNotEmpty || validOverlays.isNotEmpty) {
        onStepChange?.call('字幕與文字標示燒錄中...');
        final burnResult = await _exportService.burnSubtitlesAndOverlays(
          videoPath: outputPath,
          subtitles: subtitles,
          textOverlays: validOverlays,
        );
        if (burnResult.success && burnResult.outputPath != null) {
          outputPath = burnResult.outputPath!;
          onMessage?.call(burnResult.message);
        } else {
          onMessage?.call('燒錄失敗：${burnResult.message}');
        }
      }
    }

    // ── Step 4: 名片片尾 ─────────────────────────────────
    if (businessCard) {
      onStepChange?.call('名片片尾生成中...');
      final card = await _storageService.loadBusinessCard();
      if (!card.isEmpty) {
        final result = await _aiService.generateBusinessCard(
          videoPath: outputPath,
          agentName: card.name,
          phone: card.phone,
          title: card.title,
          company: card.company,
        );
        onMessage?.call(result.message);
        if (result.success) outputPath = result.outputPath;
      }
    }

    // ── Final: 儲存相簿 + 寫入作品集 ────────────────────
    onStepChange?.call('儲存中...');

    // 儲存前驗證輸出檔案存在且不為空
    final outputFile = File(outputPath);
    if (!outputFile.existsSync() || outputFile.lengthSync() == 0) {
      return ExportPipelineResult(
        success: false,
        message: '匯出失敗：輸出檔案不存在或為空，請重試',
      );
    }

    bool savedToGallery = false;
    if (Platform.isIOS || Platform.isAndroid) {
      try {
        await Gal.putVideo(outputPath);
        savedToGallery = true;
      } catch (_) {
        // 儲存失敗不阻擋流程
      }
    }

    final now = DateTime.now();
    final work = WorkItem(
      id: now.millisecondsSinceEpoch.toString(),
      title:
          '房仲影片 ${now.month}/${now.day} ${now.hour}:${now.minute.toString().padLeft(2, '0')}',
      date: '${now.year}/${now.month}/${now.day}',
      videoCount: videoPaths.length,
      usedRemoveFiller: removeFiller,
      usedSubtitle: subtitle,
      usedBusinessCard: businessCard,
      outputPath: outputPath,
    );
    await _storageService.saveWork(work);

    return ExportPipelineResult(
      success: true,
      message: '匯出完成',
      outputPath: outputPath,
      savedToGallery: savedToGallery,
    );
  }
}

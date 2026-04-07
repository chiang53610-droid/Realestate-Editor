import 'dart:io';
import 'package:ffmpeg_kit_flutter_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_min/return_code.dart';
import 'package:path_provider/path_provider.dart';
import '../models/clip_timeline.dart';
import 'video_export_service.dart'; // 共用 ExportResult

/// 智能匯出服務 — 使用 FFmpeg filter_complex 精準裁切拼接
///
/// 根據 AI 分析的 ClipTimeline 進行逐段 trim + concat，
/// 產出一支完整的成品影片。
///
/// 編碼設定：-c:v libx264 -preset ultrafast（開發階段求速度）
class SmartExportService {
  /// 根據 AI 時間軸匯出合併影片
  ///
  /// [timelines] — AI 分析後的時間軸列表
  /// 回傳 — ExportResult 包含成功/失敗資訊與輸出路徑
  Future<ExportResult> exportFromTimelines(List<ClipTimeline> timelines) async {
    // 桌面平台使用 Mock
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      return _mockExport(timelines);
    }

    try {
      final dir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = '${dir.path}/smart_$timestamp.mp4';

      if (timelines.isEmpty) {
        return ExportResult(success: false, message: '沒有可匯出的片段');
      }

      // 單段影片 → 簡單 trim
      if (timelines.length == 1) {
        return _trimSingle(timelines.first, outputPath);
      }

      // 多段影片 → filter_complex trim + concat
      return _filterComplexExport(timelines, outputPath);
    } catch (e) {
      return ExportResult(success: false, message: '智能匯出失敗：$e');
    }
  }

  /// 單段影片直接裁切
  Future<ExportResult> _trimSingle(ClipTimeline tl, String outputPath) async {
    final cmd = '-i "${tl.videoPath}" '
        '-ss ${tl.startSeconds} -to ${tl.endSeconds} '
        '-c:v libx264 -preset ultrafast -c:a aac '
        '"$outputPath"';

    debugLog('FFmpeg 單段裁切指令: $cmd');

    final session = await FFmpegKit.execute(cmd);
    return _handleResult(session, outputPath, 1);
  }

  /// 使用 filter_complex 進行多段精準裁切 + 拼接
  Future<ExportResult> _filterComplexExport(
    List<ClipTimeline> timelines,
    String outputPath,
  ) async {
    final n = timelines.length;

    // 組裝 -i 輸入列表
    final inputs = timelines.map((tl) => '-i "${tl.videoPath}"').join(' ');

    // 組裝 filter_complex：逐段 trim + setpts，最後 concat
    final filterParts = <String>[];
    final concatInputs = StringBuffer();

    for (int i = 0; i < n; i++) {
      final tl = timelines[i];
      // 影片 trim
      filterParts.add(
        '[$i:v]trim=start=${tl.startSeconds}:end=${tl.endSeconds},'
        'setpts=PTS-STARTPTS[v$i]',
      );
      // 音訊 trim
      filterParts.add(
        '[$i:a]atrim=start=${tl.startSeconds}:end=${tl.endSeconds},'
        'asetpts=PTS-STARTPTS[a$i]',
      );
      concatInputs.write('[v$i][a$i]');
    }

    // concat filter
    filterParts.add(
      '${concatInputs}concat=n=$n:v=1:a=1[outv][outa]',
    );

    final filterComplex = filterParts.join('; ');

    final cmd = '$inputs '
        '-filter_complex "$filterComplex" '
        '-map "[outv]" -map "[outa]" '
        '-c:v libx264 -preset ultrafast -c:a aac '
        '"$outputPath"';

    debugLog('FFmpeg filter_complex 指令: $cmd');

    final session = await FFmpegKit.execute(cmd);
    return _handleResult(session, outputPath, n);
  }

  /// 處理 FFmpeg 執行結果，包含完整錯誤記錄
  Future<ExportResult> _handleResult(
    dynamic session,
    String outputPath,
    int clipCount,
  ) async {
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      debugLog('FFmpeg 成功完成，returnCode: $returnCode');
      return ExportResult(
        success: true,
        message: '$clipCount 段影片智能合併完成！',
        outputPath: outputPath,
      );
    } else {
      // 完整錯誤日誌
      final logs = await session.getLogsAsString() ?? '無日誌';
      final failTrace = await session.getFailStackTrace() ?? '無堆疊追蹤';

      debugLog('===== FFmpeg 智能匯出失敗 =====');
      debugLog('returnCode: $returnCode');
      debugLog('logs: $logs');
      debugLog('failStackTrace: $failTrace');
      debugLog('================================');

      return ExportResult(
        success: false,
        message: '智能合併失敗（代碼 $returnCode）',
      );
    }
  }

  /// 桌面平台 Mock 匯出
  Future<ExportResult> _mockExport(List<ClipTimeline> timelines) async {
    debugLog('桌面 Mock 模式：模擬智能匯出 ${timelines.length} 段影片');
    await Future.delayed(const Duration(seconds: 3));

    return ExportResult(
      success: true,
      message: '${timelines.length} 段影片智能合併完成！（桌面版模擬）',
      outputPath: timelines.isNotEmpty ? timelines.first.videoPath : null,
    );
  }

  /// 印出除錯日誌到 console
  void debugLog(String msg) {
    // ignore: avoid_print
    print('[SmartExportService] $msg');
  }
}

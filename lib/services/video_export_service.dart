import 'dart:io';
import 'package:ffmpeg_kit_flutter_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_min/return_code.dart';
import 'package:path_provider/path_provider.dart';

/// 影片匯出結果
class ExportResult {
  final bool success;
  final String message;
  final String? outputPath;

  ExportResult({required this.success, required this.message, this.outputPath});
}

/// 影片合併匯出服務 — 使用 FFmpeg 進行真實的影片處理
///
/// ⚠️ 平台限制：
/// - 僅支援 iOS / Android（ffmpeg_kit_flutter 不支援 macOS 桌面版）
/// - macOS 上會使用 Mock 模式模擬匯出
class VideoExportService {
  /// 合併多段影片（含裁剪）
  ///
  /// [videoPaths] — 要合併的影片路徑列表
  /// [trimRanges] — 每段影片的裁剪區間 {index: [startRatio, endRatio]}
  Future<ExportResult> mergeAndExport({
    required List<String> videoPaths,
    Map<int, List<double>>? trimRanges,
  }) async {
    // macOS 桌面版不支援 FFmpeg → 使用 Mock
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      return _mockExport(videoPaths);
    }

    try {
      if (videoPaths.length == 1 && (trimRanges == null || trimRanges.isEmpty)) {
        // 只有一段且沒有裁剪 → 直接回傳原檔
        return ExportResult(
          success: true,
          message: '影片匯出完成！',
          outputPath: videoPaths.first,
        );
      }

      final dir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      if (videoPaths.length == 1) {
        // 單段影片裁剪
        return _trimSingle(videoPaths.first, trimRanges?[0], dir.path, timestamp);
      }

      // 多段影片：先各自裁剪，再合併
      final trimmedPaths = <String>[];

      for (int i = 0; i < videoPaths.length; i++) {
        final range = trimRanges?[i];
        if (range != null) {
          // 有裁剪 → 先裁剪出片段
          final trimResult = await _trimSingle(
            videoPaths[i], range, dir.path, timestamp + i,
          );
          if (!trimResult.success) return trimResult;
          trimmedPaths.add(trimResult.outputPath!);
        } else {
          trimmedPaths.add(videoPaths[i]);
        }
      }

      // 建立 concat 檔案列表
      final concatFile = File('${dir.path}/concat_$timestamp.txt');
      final lines = trimmedPaths.map((p) => "file '$p'").join('\n');
      await concatFile.writeAsString(lines);

      // FFmpeg 合併指令
      final outputPath = '${dir.path}/merged_$timestamp.mp4';
      final cmd = '-f concat -safe 0 -i "${concatFile.path}" -c copy "$outputPath"';

      final session = await FFmpegKit.execute(cmd);
      final returnCode = await session.getReturnCode();

      // 清理暫存的 concat 檔案
      if (await concatFile.exists()) await concatFile.delete();

      if (ReturnCode.isSuccess(returnCode)) {
        return ExportResult(
          success: true,
          message: '${videoPaths.length} 段影片合併完成！',
          outputPath: outputPath,
        );
      } else {
        final log = await session.getOutput();
        return ExportResult(
          success: false,
          message: '合併失敗：${log ?? "未知錯誤"}',
        );
      }
    } catch (e) {
      return ExportResult(success: false, message: '匯出失敗：$e');
    }
  }

  /// 裁剪單段影片
  Future<ExportResult> _trimSingle(
    String inputPath,
    List<double>? range,
    String dirPath,
    int timestamp,
  ) async {
    if (range == null || (range[0] == 0.0 && range[1] == 1.0)) {
      return ExportResult(success: true, message: '無需裁剪', outputPath: inputPath);
    }

    final outputPath = '$dirPath/trimmed_$timestamp.mp4';

    // 取得影片時長，將比例換算成秒數
    final durationSec = await _getVideoDuration(inputPath);
    if (durationSec <= 0) {
      return ExportResult(success: false, message: '無法讀取影片時長');
    }

    final startSec = range[0] * durationSec;
    final endSec = range[1] * durationSec;

    final cmd = '-ss $startSec -to $endSec -i "$inputPath" -c copy "$outputPath"';
    final session = await FFmpegKit.execute(cmd);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      return ExportResult(success: true, message: '裁剪完成', outputPath: outputPath);
    } else {
      return ExportResult(success: false, message: '裁剪失敗');
    }
  }

  /// 取得影片時長（秒）
  Future<double> _getVideoDuration(String path) async {
    final cmd = '-i "$path" -f null -';
    final session = await FFmpegKit.execute(cmd);
    final log = await session.getOutput() ?? '';

    // 從 FFmpeg 輸出中解析 Duration: HH:MM:SS.ms
    final match = RegExp(r'Duration:\s*(\d+):(\d+):(\d+)\.(\d+)').firstMatch(log);
    if (match == null) return 0;

    final hours = int.parse(match.group(1)!);
    final minutes = int.parse(match.group(2)!);
    final seconds = int.parse(match.group(3)!);
    final ms = int.parse(match.group(4)!.padRight(3, '0').substring(0, 3));

    return hours * 3600.0 + minutes * 60.0 + seconds + ms / 1000.0;
  }

  /// macOS 桌面版的 Mock 匯出
  Future<ExportResult> _mockExport(List<String> videoPaths) async {
    await Future.delayed(const Duration(seconds: 3));
    return ExportResult(
      success: true,
      message: '${videoPaths.length} 段影片匯出完成！（桌面版模擬）',
      outputPath: videoPaths.first,
    );
  }
}

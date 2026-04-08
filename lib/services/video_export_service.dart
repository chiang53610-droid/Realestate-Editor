import 'dart:io';
import 'package:ffmpeg_kit_flutter_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_min/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'ai_api_service.dart';

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

  // ========== 字幕燒錄 ==========

  /// 將字幕燒錄進影片
  ///
  /// 桌面版：呼叫系統 ffmpeg（需 brew install ffmpeg）
  /// 手機版：使用 FFmpegKit drawtext filter
  Future<ExportResult> burnSubtitles({
    required String videoPath,
    required List<SubtitleEntry> subtitles,
  }) async {
    if (subtitles.isEmpty) {
      return ExportResult(
        success: true,
        message: '無字幕可燒錄',
        outputPath: videoPath,
      );
    }

    try {
      final dir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = '${dir.path}/subtitled_$timestamp.mp4';

      // 產生 SRT 字幕檔
      final srtPath = '${dir.path}/subs_$timestamp.srt';
      await File(srtPath).writeAsString(_generateSrt(subtitles));

      ExportResult result;

      if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
        // 桌面版：呼叫系統 ffmpeg
        result = await _burnWithSystemFFmpeg(
            videoPath, srtPath, outputPath, subtitles);
      } else {
        // 手機版：使用 FFmpegKit drawtext
        result = await _burnWithDrawtext(
            videoPath, subtitles, outputPath);
      }

      // 清理暫存 SRT
      try { await File(srtPath).delete(); } catch (_) {}

      return result;
    } catch (e) {
      return ExportResult(
        success: false,
        message: '字幕燒錄異常：$e',
        outputPath: videoPath,
      );
    }
  }

  /// 桌面版：使用系統安裝的 ffmpeg 指令
  Future<ExportResult> _burnWithSystemFFmpeg(
    String videoPath,
    String srtPath,
    String outputPath,
    List<SubtitleEntry> subtitles,
  ) async {
    try {
      // 先確認系統有 ffmpeg
      final check = await Process.run('which', ['ffmpeg']);
      if (check.exitCode != 0) {
        return ExportResult(
          success: false,
          message: '桌面版需要安裝 ffmpeg 才能燒字幕。\n請執行：brew install ffmpeg',
          outputPath: videoPath,
        );
      }

      // 使用 subtitles filter（系統 ffmpeg 通常包含 libass）
      final escapedSrt = srtPath.replaceAll("'", "'\\''");
      final result = await Process.run('ffmpeg', [
        '-y',
        '-i', videoPath,
        '-vf',
        "subtitles='$escapedSrt':force_style='FontSize=24,PrimaryColour=&H00FFFFFF,OutlineColour=&H00000000,Outline=2,MarginV=30'",
        '-c:a', 'copy',
        '-preset', 'ultrafast',
        outputPath,
      ]).timeout(const Duration(minutes: 5));

      if (result.exitCode == 0 && await File(outputPath).exists()) {
        return ExportResult(
          success: true,
          message: '${subtitles.length} 句字幕已燒錄進影片',
          outputPath: outputPath,
        );
      }

      // subtitles filter 失敗 → 嘗試 drawtext fallback
      // ignore: avoid_print
      print('[VideoExportService] subtitles filter 失敗，嘗試 drawtext: ${result.stderr}');
      return _burnWithSystemDrawtext(
          videoPath, subtitles, outputPath);
    } catch (e) {
      return ExportResult(
        success: false,
        message: '系統 ffmpeg 執行失敗：$e',
        outputPath: videoPath,
      );
    }
  }

  /// 桌面版 fallback：用系統 ffmpeg + drawtext
  Future<ExportResult> _burnWithSystemDrawtext(
    String videoPath,
    List<SubtitleEntry> subtitles,
    String outputPath,
  ) async {
    final fontFile = await _findSystemFont();
    final vf = _buildDrawtextFilter(subtitles, fontFile);

    final result = await Process.run('ffmpeg', [
      '-y',
      '-i', videoPath,
      '-vf', vf,
      '-c:a', 'copy',
      '-preset', 'ultrafast',
      outputPath,
    ]).timeout(const Duration(minutes: 5));

    if (result.exitCode == 0 && await File(outputPath).exists()) {
      return ExportResult(
        success: true,
        message: '${subtitles.length} 句字幕已燒錄進影片',
        outputPath: outputPath,
      );
    }

    // ignore: avoid_print
    print('[VideoExportService] drawtext 也失敗: ${result.stderr}');
    return ExportResult(
      success: false,
      message: '字幕燒錄失敗，請確認 ffmpeg 已正確安裝',
      outputPath: videoPath,
    );
  }

  /// 手機版：使用 FFmpegKit drawtext filter
  Future<ExportResult> _burnWithDrawtext(
    String videoPath,
    List<SubtitleEntry> subtitles,
    String outputPath,
  ) async {
    final fontFile = await _findSystemFont();
    final vf = _buildDrawtextFilter(subtitles, fontFile);

    final cmd = '-y -i "$videoPath" -vf "$vf" -c:a copy -preset ultrafast "$outputPath"';

    // ignore: avoid_print
    print('[VideoExportService] drawtext 指令長度: ${cmd.length}');

    final session = await FFmpegKit.execute(cmd);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      return ExportResult(
        success: true,
        message: '${subtitles.length} 句字幕已燒錄進影片',
        outputPath: outputPath,
      );
    }

    final log = await session.getOutput();
    // ignore: avoid_print
    print('[VideoExportService] drawtext 燒錄失敗: $log');
    return ExportResult(
      success: false,
      message: '字幕燒錄失敗（drawtext）',
      outputPath: videoPath,
    );
  }

  /// 建構 drawtext filter 字串（多句字幕以逗號串接）
  String _buildDrawtextFilter(List<SubtitleEntry> subtitles, String fontFile) {
    final parts = <String>[];
    for (final sub in subtitles) {
      // 轉義 FFmpeg drawtext 特殊字元
      final escaped = sub.text
          .replaceAll('\\', '\\\\')
          .replaceAll("'", "\u2019")  // 用全形引號取代，避免轉義問題
          .replaceAll(':', '\\:')
          .replaceAll('%', '%%');

      final dt = "drawtext="
          "fontfile='$fontFile':"
          "text='$escaped':"
          "fontsize=24:"
          "fontcolor=white:"
          "borderw=2:"
          "bordercolor=black:"
          "x=(w-text_w)/2:"
          "y=h-th-40:"
          "enable='between(t\\,${sub.startTime}\\,${sub.endTime})'";
      parts.add(dt);
    }
    return parts.join(',');
  }

  /// 尋找系統中可用的 CJK 字型檔
  Future<String> _findSystemFont() async {
    final candidates = Platform.isIOS
        ? [
            '/System/Library/Fonts/PingFang.ttc',
            '/System/Library/Fonts/STHeiti Light.ttc',
            '/System/Library/Fonts/Helvetica.ttc',
          ]
        : Platform.isMacOS
            ? [
                '/System/Library/Fonts/PingFang.ttc',
                '/System/Library/Fonts/STHeiti Light.ttc',
                '/Library/Fonts/Arial Unicode.ttf',
                '/System/Library/Fonts/Helvetica.ttc',
              ]
            : [
                // Android
                '/system/fonts/NotoSansCJK-Regular.ttc',
                '/system/fonts/NotoSansSC-Regular.otf',
                '/system/fonts/DroidSansFallback.ttf',
                '/system/fonts/Roboto-Regular.ttf',
              ];

    for (final path in candidates) {
      if (await File(path).exists()) return path;
    }

    // 如果都找不到，回傳第一個（FFmpeg 會用內建字型）
    return candidates.first;
  }

  /// 產生 SRT 格式字幕內容
  String _generateSrt(List<SubtitleEntry> subtitles) {
    final buffer = StringBuffer();
    for (int i = 0; i < subtitles.length; i++) {
      final sub = subtitles[i];
      buffer.writeln('${i + 1}');
      buffer.writeln('${_formatSrtTime(sub.startTime)} --> ${_formatSrtTime(sub.endTime)}');
      buffer.writeln(sub.text);
      buffer.writeln();
    }
    return buffer.toString();
  }

  /// 秒數轉 SRT 時間格式 (HH:MM:SS,mmm)
  String _formatSrtTime(double seconds) {
    final h = (seconds ~/ 3600).toString().padLeft(2, '0');
    final m = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = ((seconds % 60).toInt()).toString().padLeft(2, '0');
    final ms = ((seconds * 1000 % 1000).toInt()).toString().padLeft(3, '0');
    return '$h:$m:$s,$ms';
  }
}

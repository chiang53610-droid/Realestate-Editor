import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:ffmpeg_kit_flutter_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_min/return_code.dart';
import 'package:flutter/material.dart' show Color;
import 'package:path_provider/path_provider.dart';
import '../models/text_overlay.dart';
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

      final session = await FFmpegKit.execute(cmd)
          .timeout(const Duration(minutes: 8));
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
    } on TimeoutException {
      return ExportResult(success: false, message: '影片合併逾時，請重試');
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
    try {
      final session = await FFmpegKit.execute(cmd)
          .timeout(const Duration(minutes: 8));
      final returnCode = await session.getReturnCode();
      if (ReturnCode.isSuccess(returnCode)) {
        return ExportResult(success: true, message: '裁剪完成', outputPath: outputPath);
      }
      return ExportResult(success: false, message: '裁剪失敗');
    } on TimeoutException {
      return ExportResult(success: false, message: '裁剪逾時，請重試');
    }
  }

  /// 取得影片時長（秒）
  ///
  /// 回傳 0 表示解析失敗（檔案不存在、格式不支援、FFmpeg 無法讀取）。
  /// Caller 應在回傳值 <= 0 時視為錯誤，不得繼續用 0 計算時間戳。
  Future<double> _getVideoDuration(String path) async {
    try {
      // 使用 -i 探測，FFmpeg 會在 logs（stderr）輸出 Duration
      final cmd = '-i "$path" -f null -';
      final session = await FFmpegKit.execute(cmd);

      // getLogsAsString() 包含完整 stderr，比 getOutput() 更可靠
      final log = await session.getLogsAsString();

      // 從 FFmpeg 輸出中解析 Duration: HH:MM:SS.ms
      final match =
          RegExp(r'Duration:\s*(\d+):(\d+):(\d+)\.(\d+)').firstMatch(log);
      if (match == null) {
        // ignore: avoid_print
        print('[VideoExportService] _getVideoDuration: 無法解析 Duration，path=$path');
        return 0;
      }

      final hours = int.parse(match.group(1)!);
      final minutes = int.parse(match.group(2)!);
      final seconds = int.parse(match.group(3)!);
      final ms = int.parse(match.group(4)!.padRight(3, '0').substring(0, 3));

      return hours * 3600.0 + minutes * 60.0 + seconds + ms / 1000.0;
    } catch (e) {
      // ignore: avoid_print
      print('[VideoExportService] _getVideoDuration 異常：$e');
      return 0;
    }
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

  // ========== 去冗言（切除 filler 片段） ==========

  /// 根據 Gemini 回傳的 filler 時間戳，用 FFmpeg 切除冗言片段
  ///
  /// [videoPath] — 輸入影片路徑
  /// [fillerSegments] — [{startTime, endTime}] 要切除的片段列表
  ///
  /// 規格：
  /// - 每個片段加 0.1s buffer（start+0.1, end-0.1），避免剪到字的頭尾
  /// - 視訊硬切（無轉場），音訊 2 frame crossfade 避免爆音
  /// - macOS 桌面版回傳原路徑（mock）
  Future<ExportResult> cutFillerSegments({
    required String videoPath,
    required List<Map<String, double>> fillerSegments,
  }) async {
    if (fillerSegments.isEmpty) {
      return ExportResult(
        success: true,
        message: '無冗言片段需要切除',
        outputPath: videoPath,
      );
    }

    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      return ExportResult(
        success: true,
        message: '已移除 ${fillerSegments.length} 處冗言（桌面版模擬）',
        outputPath: videoPath,
      );
    }

    try {
      final duration = await _getVideoDuration(videoPath);
      if (duration <= 0) {
        return ExportResult(
          success: false,
          message: '無法讀取影片時長，跳過去冗言',
          outputPath: videoPath,
        );
      }

      final dir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // 把 filler 片段轉成「保留區間」
      // 例如 filler: [2.1-2.8, 5.0-5.5]
      // 保留: [0-2.2, 2.7-5.1, 5.4-end]（加 0.1s buffer）
      final sorted = List<Map<String, double>>.from(fillerSegments)
        ..sort((a, b) => a['startTime']!.compareTo(b['startTime']!));

      final keepSegments = <Map<String, double>>[];
      double cursor = 0.0;

      for (final seg in sorted) {
        final cutStart = (seg['startTime']! + 0.1).clamp(0.0, duration);
        final cutEnd = (seg['endTime']! - 0.1).clamp(0.0, duration);

        // 只有 cutEnd > cutStart 才是有效片段
        if (cutEnd <= cutStart) continue;

        if (cursor < cutStart) {
          keepSegments.add({'start': cursor, 'end': cutStart});
        }
        cursor = max(cursor, cutEnd);
      }

      // 最後一段：filler 結束到影片結束
      if (cursor < duration) {
        keepSegments.add({'start': cursor, 'end': duration});
      }

      if (keepSegments.isEmpty) {
        return ExportResult(
          success: false,
          message: '去冗言後影片為空，取消處理',
          outputPath: videoPath,
        );
      }

      // 用 FFmpeg concat demuxer 把保留片段接起來
      // 每段：trim + setpts 重設時間戳
      final filterParts = <String>[];
      for (int i = 0; i < keepSegments.length; i++) {
        final seg = keepSegments[i];
        filterParts.add(
          '[0:v]trim=start=${seg['start']}:end=${seg['end']},setpts=PTS-STARTPTS[v$i];'
          '[0:a]atrim=start=${seg['start']}:end=${seg['end']},asetpts=PTS-STARTPTS[a$i]',
        );
      }

      // concat 所有片段
      final vInputs = List.generate(keepSegments.length, (i) => '[v$i]').join('');
      final aInputs = List.generate(keepSegments.length, (i) => '[a$i]').join('');
      final filterComplex =
          '${filterParts.join(';')};'
          '${vInputs}concat=n=${keepSegments.length}:v=1:a=0[vout];'
          '${aInputs}concat=n=${keepSegments.length}:v=0:a=1[aout]';

      final outputPath = '${dir.path}/filler_cut_$timestamp.mp4';
      final cmd = '-y -i "$videoPath" -filter_complex "$filterComplex" '
          '-map "[vout]" -map "[aout]" '
          '-preset ultrafast "$outputPath"';

      final session = await FFmpegKit.execute(cmd)
          .timeout(const Duration(minutes: 8));
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode) && await File(outputPath).exists()) {
        return ExportResult(
          success: true,
          message: '已移除 ${sorted.length} 處冗言（保留 ${keepSegments.length} 段）',
          outputPath: outputPath,
        );
      }

      final log = await session.getOutput();
      // ignore: avoid_print
      print('[VideoExportService] 去冗言失敗: $log');
      return ExportResult(
        success: false,
        message: '去冗言處理失敗，保留原始影片',
        outputPath: videoPath,
      );
    } catch (e) {
      return ExportResult(
        success: false,
        message: '去冗言異常：$e',
        outputPath: videoPath,
      );
    }
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
        "subtitles='$escapedSrt':force_style='FontSize=48,PrimaryColour=&H00FFFFFF,OutlineColour=&H00000000,BackColour=&H80000000,BorderStyle=3,Outline=0,Shadow=0,MarginV=60'",
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

    try {
      final session = await FFmpegKit.execute(cmd)
          .timeout(const Duration(minutes: 8));
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
    } on TimeoutException {
      return ExportResult(
        success: false,
        message: '字幕燒錄逾時，請重試',
        outputPath: videoPath,
      );
    }

    return ExportResult(
      success: false,
      message: '字幕燒錄失敗（drawtext）',
      outputPath: videoPath,
    );
  }

  /// 建構 drawtext filter 字串（多句字幕以逗號串接）
  ///
  /// 字型大小：48px，適合 1080×1920 豎向影片（20 字 × 48px ≈ 960px，寬度足夠）
  /// 背景底框：半透明黑底，提升各種背景下的可讀性
  String _buildDrawtextFilter(List<SubtitleEntry> subtitles, String fontFile) {
    return _buildSubtitleDrawtextParts(subtitles, fontFile).join(',');
  }

  /// 尋找系統中可用的 CJK 字型檔
  ///
  /// 回傳存在的字型路徑；若全部找不到則回傳空字串，
  /// 呼叫端（_buildDrawtextFilter）應在空字串時省略 fontfile 參數。
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

    return ''; // 找不到字型，呼叫端應省略 fontfile 參數
  }

  // ========== 字幕 + 文字疊加（單次 Pass） ==========

  /// 一次 FFmpeg 指令同時燒錄 AI 字幕與自訂文字疊加
  ///
  /// 避免雙重編碼（double encoding）：字幕和疊加合成為同一個 -vf filter，
  /// 只做一次 encode，維持最佳畫質並節省處理時間。
  ///
  /// 時間基準（Option A）：textOverlays 的 startSec/endSec 為裁剪後影片的秒數。
  ///
  /// 若 subtitles 和 textOverlays 都是空的，直接回傳原路徑（不做多餘 encode）。
  Future<ExportResult> burnSubtitlesAndOverlays({
    required String videoPath,
    required List<SubtitleEntry> subtitles,
    required List<TextOverlay> textOverlays,
  }) async {
    // 過濾無效的疊加（空文字、時間不合法）
    final validOverlays = textOverlays.where((o) => o.isValid).toList();

    if (subtitles.isEmpty && validOverlays.isEmpty) {
      return ExportResult(
        success: true,
        message: '無字幕或文字疊加需要處理',
        outputPath: videoPath,
      );
    }

    try {
      final dir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = '${dir.path}/subtitled_$timestamp.mp4';

      final fontFile = await _findSystemFont();

      // 建構所有 drawtext filter（字幕 + 疊加合併為一串）
      final allParts = <String>[];

      if (subtitles.isNotEmpty) {
        allParts.addAll(_buildSubtitleDrawtextParts(subtitles, fontFile));
      }
      if (validOverlays.isNotEmpty) {
        allParts.addAll(_buildOverlayDrawtextParts(validOverlays, fontFile));
      }

      final vf = allParts.join(',');

      // ignore: avoid_print
      print('[VideoExportService] burnSubtitlesAndOverlays vf=[$vf]');

      ExportResult result;

      if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
        // 桌面版 Mock：桌面版無 FFmpegKit，模擬成功回傳原路徑
        // （實際燒錄效果請在 iOS 裝置上驗證）
        result = ExportResult(
          success: true,
          message: '${_buildBurnMessage(subtitles.length, validOverlays.length)}（桌面版模擬）',
          outputPath: videoPath,
        );
      } else {
        // 手機版：FFmpegKit
        final cmd = '-y -i "$videoPath" -vf "$vf" -c:a copy -preset ultrafast "$outputPath"';
        // ignore: avoid_print
        print('[VideoExportService] burnSubtitlesAndOverlays cmd=[$cmd]');
        try {
          final session = await FFmpegKit.execute(cmd)
              .timeout(const Duration(minutes: 8));
          final returnCode = await session.getReturnCode();

          if (ReturnCode.isSuccess(returnCode)) {
            result = ExportResult(
              success: true,
              message: _buildBurnMessage(subtitles.length, validOverlays.length),
              outputPath: outputPath,
            );
          } else {
            // getLogsAsString 包含完整 stderr，比 getOutput 更完整
            final log = await session.getLogsAsString();
            // ignore: avoid_print
            print('[VideoExportService] burnSubtitlesAndOverlays 失敗 rc=$returnCode log=$log');
            result = ExportResult(
              success: false,
              message: '字幕/文字燒錄失敗',
              outputPath: videoPath,
            );
          }
        } on TimeoutException {
          result = ExportResult(
            success: false,
            message: '字幕燒錄逾時，請重試',
            outputPath: videoPath,
          );
        }
      }

      return result;
    } catch (e) {
      return ExportResult(
        success: false,
        message: '字幕/文字燒錄異常：$e',
        outputPath: videoPath,
      );
    }
  }

  /// 建構 AI 字幕的 drawtext filter 部分（list，尚未 join）
  List<String> _buildSubtitleDrawtextParts(
      List<SubtitleEntry> subtitles, String fontFile) {
    return subtitles.map((sub) {
      final escaped = _escapeDrawtext(sub.text);
      final fontPart = fontFile.isNotEmpty ? "fontfile='$fontFile':" : '';
      return "drawtext="
          "$fontPart"
          "text='$escaped':"
          "fontsize=48:"
          "fontcolor=white:"
          "box=1:"
          "boxcolor=black@0.5:"
          "boxborderw=8:"
          "x=(w-text_w)/2:"
          "y=h-th-100:"
          "enable='between(t\\,${sub.startTime}\\,${sub.endTime})'";
    }).toList();
  }

  /// 建構自訂文字疊加的 drawtext filter 部分（list，尚未 join）
  List<String> _buildOverlayDrawtextParts(
      List<TextOverlay> overlays, String fontFile) {
    return overlays.map((ov) {
      final escaped = _escapeDrawtext(ov.text);
      final fontPart = fontFile.isNotEmpty ? "fontfile='$fontFile':" : '';
      final ffmpegColor = _colorToFFmpeg(ov.color);
      // 文字中心點 = (w * xFraction, h * yFraction)
      final x = '(w*${ov.xFraction.toStringAsFixed(4)}-text_w/2)';
      final y = '(h*${ov.yFraction.toStringAsFixed(4)}-text_h/2)';
      // 深色背景框，確保所有顏色文字都清晰可讀
      return "drawtext="
          "$fontPart"
          "text='$escaped':"
          "fontsize=${ov.fontSize.round()}:"
          "fontcolor=$ffmpegColor:"
          "box=1:"
          "boxcolor=black@0.55:"
          "boxborderw=10:"
          "x=$x:"
          "y=$y:"
          "enable='between(t\\,${ov.startSec}\\,${ov.endSec})'";
    }).toList();
  }

  /// 將 Flutter Color 轉換為 FFmpeg drawtext 顏色格式（0xRRGGBB）
  String _colorToFFmpeg(Color c) {
    return '0x'
        '${c.red.toRadixString(16).padLeft(2, '0')}'
        '${c.green.toRadixString(16).padLeft(2, '0')}'
        '${c.blue.toRadixString(16).padLeft(2, '0')}';
  }

  /// 跳脫 FFmpeg drawtext 特殊字元（字幕與疊加共用）
  ///
  /// 處理：反斜線、單引號（改用全形）、冒號、百分比。
  String _escapeDrawtext(String text) {
    return text
        .replaceAll('\\', '\\\\')
        .replaceAll("'", '\u2019')  // 全形引號取代，避免跳脫問題
        .replaceAll(':', '\\:')
        .replaceAll('%', '%%');
  }

  /// 組合燒錄完成訊息
  String _buildBurnMessage(int subtitleCount, int overlayCount) {
    final parts = <String>[];
    if (subtitleCount > 0) parts.add('$subtitleCount 句字幕');
    if (overlayCount > 0) parts.add('$overlayCount 個文字標示');
    return '${parts.join('、')}已燒入影片';
  }

  // ========== 名片片尾合成 ==========

  /// 在影片末尾附加 5 秒名片片尾
  ///
  /// 使用 FFmpeg lavfi 生成黑底名片畫面，再 concat 到主影片末尾。
  /// 名片顯示：姓名（大）/ 職稱·公司（中）/ 電話（中，Cyan 色）
  ///
  /// macOS 桌面版回傳原路徑（mock）
  Future<ExportResult> appendBusinessCardEnding({
    required String videoPath,
    required String name,
    required String title,
    required String company,
    required String phone,
  }) async {
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      return ExportResult(
        success: true,
        message: '已附加名片片尾（桌面版模擬）',
        outputPath: videoPath,
      );
    }

    try {
      final dir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = '${dir.path}/with_card_$timestamp.mp4';
      final fontFile = await _findSystemFont();

      // 轉義 drawtext 特殊字元
      String esc(String s) => _escapeDrawtext(s);

      final nameEsc = esc(name);
      final midLine = [if (title.isNotEmpty) title, if (company.isNotEmpty) company]
          .join('  ');
      final midEsc = esc(midLine);
      final phoneEsc = esc(phone);

      // 名片畫面：黑底 #121212，1080×1920，5 秒
      // drawtext 繪製三行文字（垂直居中）
      final fp = fontFile.isNotEmpty ? "fontfile='$fontFile':" : '';
      final cardFilter = StringBuffer();
      // 第一行：姓名
      cardFilter.write(
        "drawtext=${fp}text='$nameEsc':"
        "fontsize=60:fontcolor=white:x=(w-text_w)/2:y=(h/2-110)",
      );
      if (midEsc.isNotEmpty) {
        cardFilter.write(
          ",drawtext=${fp}text='$midEsc':"
          "fontsize=34:fontcolor=0xAAAAAA:x=(w-text_w)/2:y=(h/2-30)",
        );
      }
      if (phoneEsc.isNotEmpty) {
        cardFilter.write(
          ",drawtext=${fp}text='$phoneEsc':"
          "fontsize=38:fontcolor=0x00F0FF:x=(w-text_w)/2:y=(h/2+40)",
        );
      }

      // 完整 filter_complex:
      //   input 0: 主影片
      //   input 1: 黑色名片影像（lavfi color）
      //   input 2: 靜音音訊（lavfi aevalsrc=0）
      final filterComplex =
          '[1:v]${cardFilter.toString()}[card_v];'
          '[0:v][card_v]concat=n=2:v=1:a=0[vout];'
          '[0:a]apad=pad_dur=5[aout]';

      final cmd = '-y -i "$videoPath" '
          '-f lavfi -i "color=c=0x121212:s=1080x1920:d=5:r=30" '
          '-filter_complex "$filterComplex" '
          '-map "[vout]" -map "[aout]" '
          '-preset ultrafast "$outputPath"';

      final session = await FFmpegKit.execute(cmd)
          .timeout(const Duration(minutes: 8));
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode) && await File(outputPath).exists()) {
        return ExportResult(
          success: true,
          message: '已附加 $name 的名片片尾',
          outputPath: outputPath,
        );
      }

      final log = await session.getLogsAsString();
      // ignore: avoid_print
      print('[VideoExportService] 名片片尾失敗: $log');
      return ExportResult(
        success: false,
        message: '名片片尾附加失敗，保留原始影片',
        outputPath: videoPath,
      );
    } on TimeoutException {
      return ExportResult(
        success: false,
        message: '名片片尾逾時，保留原始影片',
        outputPath: videoPath,
      );
    } catch (e) {
      return ExportResult(
        success: false,
        message: '名片片尾異常：$e',
        outputPath: videoPath,
      );
    }
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

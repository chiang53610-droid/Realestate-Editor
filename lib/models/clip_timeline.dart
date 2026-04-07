/// AI 分析後的片段時間軸
///
/// 代表每段素材影片中，AI 建議保留的時間區間
class ClipTimeline {
  final String videoPath;    // 影片路徑
  final double startSeconds; // 建議保留的起始秒數
  final double endSeconds;   // 建議保留的結束秒數
  final String label;        // 片段標籤（例如「客廳全景」）

  ClipTimeline({
    required this.videoPath,
    required this.startSeconds,
    required this.endSeconds,
    this.label = '',
  });

  /// 片段長度（秒）
  double get durationSeconds => endSeconds - startSeconds;

  @override
  String toString() =>
      'ClipTimeline($label: ${startSeconds.toStringAsFixed(1)}s ~ ${endSeconds.toStringAsFixed(1)}s)';
}

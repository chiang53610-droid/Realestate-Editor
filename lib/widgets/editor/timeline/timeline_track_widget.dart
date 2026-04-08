import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../theme/editor_theme.dart';

// ═══════════════════════════════════════════════════════
//  軌道類型
// ═══════════════════════════════════════════════════════
enum TrackType { video, audio, subtitle }

// ═══════════════════════════════════════════════════════
//  單個 Clip 的資料模型
// ═══════════════════════════════════════════════════════
class TimelineClipData {
  final int index;
  final String label;
  final bool hasTrim;
  final bool isSelected;

  const TimelineClipData({
    required this.index,
    required this.label,
    this.hasTrim = false,
    this.isSelected = false,
  });
}

// ═══════════════════════════════════════════════════════
//  軌道列 (Track Row)
//  高度固定 48px，內含多個 Clip 長條
// ═══════════════════════════════════════════════════════
class TimelineTrackWidget extends StatelessWidget {
  final TrackType type;
  final List<TimelineClipData> clips;
  final double clipWidth;       // 每個 clip 的像素寬度
  final double totalWidth;      // 整條軌道的總寬度
  final ValueChanged<int>? onClipTap;

  static const double trackHeight = 48.0;
  static const double clipPadV = 5.0; // 垂直 padding
  static const double clipRadius = 6.0;

  const TimelineTrackWidget({
    super.key,
    required this.type,
    required this.clips,
    required this.clipWidth,
    required this.totalWidth,
    this.onClipTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: trackHeight,
      width: totalWidth,
      color: EditorTheme.bg,
      child: Stack(
        children: [
          // ── 軌道底層網格線 ─────────────────────────
          const _TrackGridLine(),

          // ── Clip 長條 ─────────────────────────────
          Row(
            children: [
              for (final clip in clips) ...[
                _ClipBlock(
                  data: clip,
                  width: clipWidth,
                  type: type,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onClipTap?.call(clip.index);
                  },
                ),
                const SizedBox(width: 2), // clip 間距
              ],
            ],
          ),

          // ── 空白佔位 Placeholder（無 clip 時）─────
          if (clips.isEmpty) _buildPlaceholder(),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: clipPadV),
      decoration: BoxDecoration(
        color: _trackBg.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(clipRadius),
        border: Border.all(
          color: _trackBg.withValues(alpha: 0.4),
          style: BorderStyle.solid,
        ),
      ),
    );
  }

  Color get _trackBg {
    switch (type) {
      case TrackType.video:
        return EditorTheme.videoTrackBg;
      case TrackType.audio:
        return EditorTheme.audioTrackBg;
      case TrackType.subtitle:
        return EditorTheme.subtitleTrackBg;
    }
  }
}

// ═══════════════════════════════════════════════════════
//  單一 Clip 長條塊
// ═══════════════════════════════════════════════════════
class _ClipBlock extends StatefulWidget {
  final TimelineClipData data;
  final double width;
  final TrackType type;
  final VoidCallback onTap;

  const _ClipBlock({
    required this.data,
    required this.width,
    required this.type,
    required this.onTap,
  });

  @override
  State<_ClipBlock> createState() => _ClipBlockState();
}

class _ClipBlockState extends State<_ClipBlock> {
  bool _pressed = false;

  Gradient get _gradient {
    switch (widget.type) {
      case TrackType.video:
        return EditorTheme.videoClipGradient;
      case TrackType.audio:
        return EditorTheme.audioClipGradient;
      case TrackType.subtitle:
        return LinearGradient(
          colors: [
            EditorTheme.subtitleTrackBg,
            EditorTheme.subtitleTrackBg.withValues(alpha: 0.6),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        );
    }
  }

  Color get _highlightColor {
    switch (widget.type) {
      case TrackType.video:
        return EditorTheme.videoTrackHighlight;
      case TrackType.audio:
        return EditorTheme.audioTrackHighlight;
      case TrackType.subtitle:
        return EditorTheme.subtitleTrackHighlight;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.data.isSelected;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedOpacity(
        opacity: _pressed ? 0.75 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: Container(
          width: widget.width - 2,
          height: TimelineTrackWidget.trackHeight -
              TimelineTrackWidget.clipPadV * 2,
          margin: const EdgeInsets.symmetric(
              vertical: TimelineTrackWidget.clipPadV),
          decoration: BoxDecoration(
            gradient: _gradient,
            borderRadius:
                BorderRadius.circular(TimelineTrackWidget.clipRadius),
            border: Border.all(
              color: isSelected
                  ? _highlightColor
                  : _highlightColor.withValues(alpha: 0.35),
              width: isSelected ? 1.5 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: _highlightColor.withValues(alpha: 0.3),
                      blurRadius: 6,
                    )
                  ]
                : null,
          ),
          child: Stack(
            children: [
              // ── 波形/影格裝飾線（模擬） ───────────
              if (widget.type == TrackType.audio)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                        TimelineTrackWidget.clipRadius - 1),
                    child: const _WaveformDecoration(),
                  ),
                ),

              // ── 左側粗邊框（Trim handle 暗示） ─────
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 4,
                child: Container(
                  decoration: BoxDecoration(
                    color: EditorTheme.trimHandle.withValues(alpha: 0.5),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(
                          TimelineTrackWidget.clipRadius),
                      bottomLeft: Radius.circular(
                          TimelineTrackWidget.clipRadius),
                    ),
                  ),
                ),
              ),

              // ── 右側粗邊框（Trim handle 暗示） ─────
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: 4,
                child: Container(
                  decoration: BoxDecoration(
                    color: EditorTheme.trimHandle.withValues(alpha: 0.5),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(
                          TimelineTrackWidget.clipRadius),
                      bottomRight: Radius.circular(
                          TimelineTrackWidget.clipRadius),
                    ),
                  ),
                ),
              ),

              // ── Clip 標籤 + 剪輯圖示 ───────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        widget.data.label,
                        style: EditorTheme.trackLabel.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.data.hasTrim) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.content_cut_rounded,
                        color: EditorTheme.accentGold,
                        size: 10,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  軌道底層格線
// ═══════════════════════════════════════════════════════
class _TrackGridLine extends StatelessWidget {
  const _TrackGridLine();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 0.5,
        color: EditorTheme.divider,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  音訊軌波形裝飾（CustomPaint 模擬）
// ═══════════════════════════════════════════════════════
class _WaveformDecoration extends StatelessWidget {
  const _WaveformDecoration();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _WaveformPainter());
  }
}

class _WaveformPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const barWidth = 3.0;
    const gap = 2.5;
    final centerY = size.height / 2;

    // 用固定的假波形高度序列模擬波形
    const heights = [
      0.3, 0.7, 0.5, 0.9, 0.4, 0.8, 0.6, 0.3, 0.7, 0.5,
      0.9, 0.4, 0.6, 0.8, 0.3, 0.7, 0.5, 0.9, 0.4, 0.8,
    ];

    double x = barWidth;
    int i = 0;
    while (x < size.width - barWidth) {
      final h = heights[i % heights.length] * (size.height * 0.42);
      canvas.drawLine(
        Offset(x, centerY - h),
        Offset(x, centerY + h),
        paint,
      );
      x += barWidth + gap;
      i++;
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) => false;
}

// ═══════════════════════════════════════════════════════
//  時間刻度尺 (Time Ruler)
// ═══════════════════════════════════════════════════════
class TimeRuler extends StatelessWidget {
  final double totalWidth;
  final double pixelsPerSecond;
  final Duration totalDuration;

  static const double rulerHeight = 24.0;

  const TimeRuler({
    super.key,
    required this.totalWidth,
    required this.pixelsPerSecond,
    required this.totalDuration,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: rulerHeight,
      width: totalWidth,
      color: EditorTheme.surface,
      child: CustomPaint(
        painter: _RulerPainter(
          totalWidth: totalWidth,
          pixelsPerSecond: pixelsPerSecond,
          totalSeconds: totalDuration.inMilliseconds / 1000.0,
        ),
      ),
    );
  }
}

class _RulerPainter extends CustomPainter {
  final double totalWidth;
  final double pixelsPerSecond;
  final double totalSeconds;

  _RulerPainter({
    required this.totalWidth,
    required this.pixelsPerSecond,
    required this.totalSeconds,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final tickPaint = Paint()
      ..color = EditorTheme.textHint
      ..strokeWidth = 1.0;

    final labelStyle = TextStyle(
      color: EditorTheme.textHint,
      fontSize: 9,
      fontWeight: FontWeight.w500,
      fontFamily: 'monospace',
    );

    // 每秒一個主刻度，每0.5秒一個次刻度
    final totalSecs = totalSeconds > 0 ? totalSeconds : (totalWidth / pixelsPerSecond);
    const subInterval = 0.5;
    final step = subInterval;
    int i = 0;

    for (double t = 0; t <= totalSecs + step; t += step) {
      final x = t * pixelsPerSecond;
      if (x > totalWidth + 4) break;

      final isMain = i % 2 == 0; // 每整秒是主刻度
      final tickH = isMain ? 10.0 : 5.0;

      canvas.drawLine(
        Offset(x, size.height - tickH),
        Offset(x, size.height),
        tickPaint,
      );

      if (isMain && t > 0) {
        final label = _formatTime(t);
        final tp = TextPainter(
          text: TextSpan(text: label, style: labelStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, 2));
      }
      i++;
    }
  }

  String _formatTime(double seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toInt().toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  bool shouldRepaint(_RulerPainter old) =>
      old.totalWidth != totalWidth ||
      old.pixelsPerSecond != pixelsPerSecond ||
      old.totalSeconds != totalSeconds;
}

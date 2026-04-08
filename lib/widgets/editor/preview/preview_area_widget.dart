import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../../theme/editor_theme.dart';

/// 沉浸式影片預覽區
///
/// - 黑底 + ClipRRect 圓角底部邊緣
/// - 微陰影提升層次感
/// - 裁剪模式時頂角顯示時間區間徽章
/// - 點擊切換播放 / 暫停（附漸隱動畫）
class PreviewAreaWidget extends StatefulWidget {
  final VideoPlayerController? controller;
  final bool isReady;
  final bool isTrimMode;
  final double trimStart; // 0.0 ~ 1.0
  final double trimEnd;   // 0.0 ~ 1.0
  final VoidCallback? onTap;
  final String Function(Duration)? formatDuration;

  const PreviewAreaWidget({
    super.key,
    this.controller,
    this.isReady = false,
    this.isTrimMode = false,
    this.trimStart = 0.0,
    this.trimEnd = 1.0,
    this.onTap,
    this.formatDuration,
  });

  @override
  State<PreviewAreaWidget> createState() => _PreviewAreaWidgetState();
}

class _PreviewAreaWidgetState extends State<PreviewAreaWidget>
    with SingleTickerProviderStateMixin {
  // 播放圖示的漸隱動畫控制器
  late final AnimationController _iconAnim;
  late final Animation<double> _iconFade;

  @override
  void initState() {
    super.initState();
    _iconAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _iconFade = CurvedAnimation(parent: _iconAnim, curve: Curves.easeOut);

    // 監聽播放狀態，播放後淡出圖示
    widget.controller?.addListener(_onControllerUpdate);
  }

  @override
  void didUpdateWidget(PreviewAreaWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onControllerUpdate);
      widget.controller?.addListener(_onControllerUpdate);
    }
  }

  void _onControllerUpdate() {
    if (!mounted) return;
    final playing = widget.controller?.value.isPlaying ?? false;
    if (playing) {
      // 播放中：圖示淡出
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _iconAnim.reverse();
      });
    } else {
      // 暫停：圖示淡入
      _iconAnim.forward();
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onControllerUpdate);
    _iconAnim.dispose();
    super.dispose();
  }

  String _fmtDur(Duration d) {
    if (widget.formatDuration != null) return widget.formatDuration!(d);
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        boxShadow: EditorTheme.cardShadow,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(12),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(12),
        ),
        child: SizedBox(
          height: 240,
          width: double.infinity,
          child: widget.isReady && widget.controller != null
              ? _buildPlayerContent()
              : _buildLoadingState(),
        ),
      ),
    );
  }

  // ── 播放內容層 ───────────────────────────────────────
  Widget _buildPlayerContent() {
    final ctrl = widget.controller!;

    return GestureDetector(
      onTap: () {
        widget.onTap?.call();
        _iconAnim.forward(from: 0); // 點擊時圖示短暫亮起
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 影片畫面
          Center(
            child: AspectRatio(
              aspectRatio: ctrl.value.aspectRatio,
              child: VideoPlayer(ctrl),
            ),
          ),

          // 播放/暫停圖示（漸隱）
          FadeTransition(
            opacity: _iconFade,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                shape: BoxShape.circle,
              ),
              child: Icon(
                ctrl.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 38,
              ),
            ),
          ),

          // 裁剪模式：右上角時間區間徽章
          if (widget.isTrimMode) _buildTrimBadge(ctrl),
        ],
      ),
    );
  }

  // ── 載入狀態 ─────────────────────────────────────────
  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        color: EditorTheme.accent,
        strokeWidth: 2.5,
      ),
    );
  }

  // ── 裁剪模式徽章 ─────────────────────────────────────
  Widget _buildTrimBadge(VideoPlayerController ctrl) {
    final total = ctrl.value.duration;
    final start = Duration(
      milliseconds: (widget.trimStart * total.inMilliseconds).round(),
    );
    final end = Duration(
      milliseconds: (widget.trimEnd * total.inMilliseconds).round(),
    );
    final trimDuration = end - start;

    return Positioned(
      top: 10,
      right: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.70),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: EditorTheme.accent.withValues(alpha: 0.6),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.content_cut_rounded,
                color: EditorTheme.accent, size: 12),
            const SizedBox(width: 5),
            Text(
              '${_fmtDur(start)} – ${_fmtDur(end)}  (${_fmtDur(trimDuration)})',
              style: EditorTheme.timecode.copyWith(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

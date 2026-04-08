import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../../../theme/editor_theme.dart';

/// 播放控制列
///
/// 佈局（由上到下）：
///   1. 進度刮擦條（含裁剪遮罩）
///   2. 控制列：[↩ 復原] [↪ 重做]  時間碼  [倍速] [⛶ 全螢幕]
///   3. 中央超大播放/暫停鍵
///
/// 預留狀態：
///   - [isUndoEnabled] / [isRedoEnabled] — 後續接 UndoManager
///   - [playbackSpeed] — 後續接倍速控制
///   - [isFullscreen] — 後續接全螢幕邏輯
class PlaybackControlBar extends StatefulWidget {
  final VideoPlayerController? controller;
  final bool isReady;
  final bool isTrimMode;
  final double trimStart;
  final double trimEnd;
  final VoidCallback? onPlayPause;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final ValueChanged<double>? onSeek; // 0.0 ~ 1.0 比例
  final String Function(Duration)? formatDuration;

  // ── 預留狀態 (State-Ready) ──────────────────────────
  final bool isUndoEnabled;   // 後續接 UndoManager
  final bool isRedoEnabled;
  final double playbackSpeed; // 後續接倍速
  final bool isFullscreen;

  const PlaybackControlBar({
    super.key,
    this.controller,
    this.isReady = false,
    this.isTrimMode = false,
    this.trimStart = 0.0,
    this.trimEnd = 1.0,
    this.onPlayPause,
    this.onUndo,
    this.onRedo,
    this.onSeek,
    this.formatDuration,
    this.isUndoEnabled = false,
    this.isRedoEnabled = false,
    this.playbackSpeed = 1.0,
    this.isFullscreen = false,
  });

  @override
  State<PlaybackControlBar> createState() => _PlaybackControlBarState();
}

class _PlaybackControlBarState extends State<PlaybackControlBar> {
  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_onTick);
  }

  @override
  void didUpdateWidget(PlaybackControlBar old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller?.removeListener(_onTick);
      widget.controller?.addListener(_onTick);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onTick);
    super.dispose();
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  String _fmt(Duration d) {
    if (widget.formatDuration != null) return widget.formatDuration!(d);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    final position = ctrl?.value.position ?? Duration.zero;
    final duration = ctrl?.value.duration ?? Duration.zero;
    final isPlaying = ctrl?.value.isPlaying ?? false;

    return Container(
      color: EditorTheme.bg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── 1. 刮擦條 ─────────────────────────────────
          _buildScrubber(ctrl, position, duration),

          // ── 2. 控制列 ─────────────────────────────────
          _buildControlRow(position, duration, isPlaying),

          // ── 3. 中央播放鍵 ─────────────────────────────
          _buildPlayButton(isPlaying),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  1. 刮擦條（含裁剪遮罩）
  // ═══════════════════════════════════════════════════
  Widget _buildScrubber(
    VideoPlayerController? ctrl,
    Duration position,
    Duration duration,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: widget.isReady && ctrl != null
          ? Stack(
              children: [
                // 底層進度條
                VideoProgressIndicator(
                  ctrl,
                  allowScrubbing: !widget.isTrimMode,
                  padding: EdgeInsets.zero,
                  colors: const VideoProgressColors(
                    playedColor: EditorTheme.accent,
                    bufferedColor: Color(0xFF334455),
                    backgroundColor: EditorTheme.surfaceRaised,
                  ),
                ),

                // 裁剪遮罩
                if (widget.isTrimMode)
                  Positioned.fill(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final w = constraints.maxWidth;
                        return Stack(
                          children: [
                            Positioned(
                              left: 0, top: 0, bottom: 0,
                              width: w * widget.trimStart,
                              child: Container(
                                color: Colors.black.withValues(alpha: 0.55),
                              ),
                            ),
                            Positioned(
                              right: 0, top: 0, bottom: 0,
                              width: w * (1.0 - widget.trimEnd),
                              child: Container(
                                color: Colors.black.withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
              ],
            )
          : const LinearProgressIndicator(
              backgroundColor: EditorTheme.surfaceRaised,
              color: EditorTheme.accent,
            ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  2. 控制列：復原/重做 + 時間碼 + 倍速 + 全螢幕
  // ═══════════════════════════════════════════════════
  Widget _buildControlRow(
    Duration position,
    Duration duration,
    bool isPlaying,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          // ── 復原 ────────────────────────────────────
          _ControlIcon(
            icon: Icons.undo_rounded,
            enabled: widget.isUndoEnabled,
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onUndo?.call();
            },
          ),

          // ── 重做 ────────────────────────────────────
          const SizedBox(width: 4),
          _ControlIcon(
            icon: Icons.redo_rounded,
            enabled: widget.isRedoEnabled,
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onRedo?.call();
            },
          ),

          const Spacer(),

          // ── 時間碼 ──────────────────────────────────
          RichText(
            text: TextSpan(
              style: EditorTheme.timecode,
              children: [
                TextSpan(
                  text: _fmt(position),
                  style: const TextStyle(color: EditorTheme.textPrimary),
                ),
                const TextSpan(
                  text: ' / ',
                  style: TextStyle(color: EditorTheme.textHint),
                ),
                TextSpan(
                  text: _fmt(duration),
                  style: const TextStyle(color: EditorTheme.textSecondary),
                ),
              ],
            ),
          ),

          const Spacer(),

          // ── 倍速（預留）────────────────────────────
          _SpeedBadge(speed: widget.playbackSpeed),

          const SizedBox(width: 8),

          // ── 全螢幕（預留）──────────────────────────
          _ControlIcon(
            icon: widget.isFullscreen
                ? Icons.fullscreen_exit_rounded
                : Icons.fullscreen_rounded,
            enabled: true,
            onTap: () {
              HapticFeedback.lightImpact();
              // TODO: 接全螢幕邏輯
            },
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  3. 大型播放/暫停按鈕
  // ═══════════════════════════════════════════════════
  Widget _buildPlayButton(bool isPlaying) {
    return _PulsePlayButton(
      isPlaying: isPlaying,
      onTap: () {
        HapticFeedback.mediumImpact();
        widget.onPlayPause?.call();
      },
    );
  }
}

// ════════════════════════════════════════════════════
//  子 Widget：控制圖示按鈕
// ════════════════════════════════════════════════════
class _ControlIcon extends StatefulWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _ControlIcon({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  State<_ControlIcon> createState() => _ControlIconState();
}

class _ControlIconState extends State<_ControlIcon> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: widget.enabled
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap();
            }
          : null,
      onTapCancel: () => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedOpacity(
        opacity: _pressed ? 0.5 : (widget.enabled ? 1.0 : 0.3),
        duration: const Duration(milliseconds: 80),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            widget.icon,
            color: EditorTheme.textSecondary,
            size: 20,
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════
//  子 Widget：倍速徽章（預留）
// ════════════════════════════════════════════════════
class _SpeedBadge extends StatelessWidget {
  final double speed;

  const _SpeedBadge({required this.speed});

  @override
  Widget build(BuildContext context) {
    final label = speed == 1.0 ? '1×' : '${speed}x';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: EditorTheme.surfaceRaised,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: EditorTheme.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: EditorTheme.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════
//  子 Widget：大型播放鍵（含脈衝縮放動畫）
// ════════════════════════════════════════════════════
class _PulsePlayButton extends StatefulWidget {
  final bool isPlaying;
  final VoidCallback onTap;

  const _PulsePlayButton({required this.isPlaying, required this.onTap});

  @override
  State<_PulsePlayButton> createState() => _PulsePlayButtonState();
}

class _PulsePlayButtonState extends State<_PulsePlayButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.88)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _handleTap() async {
    await _anim.forward();
    await _anim.reverse();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTap: _handleTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: EditorTheme.exportGradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: EditorTheme.accent.withValues(alpha: 0.3),
                blurRadius: 14,
                spreadRadius: 0,
              ),
            ],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              widget.isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              key: ValueKey(widget.isPlaying),
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}

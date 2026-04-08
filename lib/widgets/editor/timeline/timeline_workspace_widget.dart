import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../../theme/editor_theme.dart';
import 'timeline_track_widget.dart';
import 'playhead_widget.dart';

/// 旗艦級多軌時間軸
///
/// 架構：
///   Left panel (固定 52px) | 可橫向捲動的軌道區
///
/// 軌道：
///   - 影片軌：每個 clip 一個長條（深藍漸層 + 裁剪把手暗示）
///   - 音訊軌：單一佔位塊（深紫漸層 + 波形裝飾）
///   - 字幕軌：佔位（深綠，需啟用 AI 字幕後顯示實際資料）
///
/// 播放指針：
///   CustomPaint 繪製的紅色垂直線 + 倒三角，
///   根據 controller.position / duration 計算位置並自動跟隨捲動。
class TimelineWorkspaceWidget extends StatefulWidget {
  final VideoPlayerController? controller;

  /// 所有影片素材的路徑（決定 clip 數量）
  final List<String> clipPaths;

  /// 目前選中的 clip 索引
  final int selectedClipIndex;

  /// 哪些 clip 設有裁剪 {index: [start, end]}
  final Map<int, List<double>> trimRanges;

  /// 是否顯示字幕軌（AI 字幕啟用時為 true）
  final bool showSubtitleTrack;

  /// 切換選中的 clip
  final ValueChanged<int>? onClipTap;

  /// 新增 clip 按鈕
  final VoidCallback? onAddClip;

  // ── 預留狀態 (State-Ready) ──────────────────────────
  /// 縮放比例（每秒幾 px），預留給 pinch-to-zoom
  final double pixelsPerSecond;

  const TimelineWorkspaceWidget({
    super.key,
    this.controller,
    this.clipPaths = const [],
    this.selectedClipIndex = 0,
    this.trimRanges = const {},
    this.showSubtitleTrack = false,
    this.onClipTap,
    this.onAddClip,
    this.pixelsPerSecond = 80.0,
  });

  @override
  State<TimelineWorkspaceWidget> createState() =>
      _TimelineWorkspaceWidgetState();
}

class _TimelineWorkspaceWidgetState extends State<TimelineWorkspaceWidget> {
  final ScrollController _scrollCtrl = ScrollController();

  // ── 版面尺寸常數 ──────────────────────────────────
  static const double _leftPanelWidth = 52.0;
  static const double _rulerHeight = TimeRuler.rulerHeight;
  static const double _trackHeight = TimelineTrackWidget.trackHeight;
  static const double _addBtnWidth = 44.0;

  double get _totalTrackCount =>
      2.0 + (widget.showSubtitleTrack ? 1.0 : 0.0);

  double get _totalHeight =>
      _rulerHeight + _trackHeight * _totalTrackCount;

  // 每個 clip 的寬度（以 pixelsPerSecond 為基準，最小 100px）
  double get _clipWidth {
    final dur = widget.controller?.value.duration ?? Duration.zero;
    final secs = dur.inMilliseconds > 0
        ? dur.inMilliseconds / 1000.0
        : 5.0; // 未知時用 5 秒估算
    return (secs * widget.pixelsPerSecond).clamp(100.0, 300.0);
  }

  double get _totalContentWidth {
    final clipsWidth = widget.clipPaths.isEmpty
        ? _clipWidth
        : widget.clipPaths.length * (_clipWidth + 2); // +2 間距
    return clipsWidth + _addBtnWidth + 16;
  }

  Duration get _totalDuration {
    final dur = widget.controller?.value.duration ?? Duration.zero;
    if (dur.inMilliseconds > 0) return dur;
    // 估算：每 clip 5 秒
    return Duration(seconds: widget.clipPaths.length * 5);
  }

  // ── 播放指針 x 座標 ─────────────────────────────
  double _playheadX(double viewportWidth) {
    final ctrl = widget.controller;
    if (ctrl == null) return 0;
    final total = ctrl.value.duration.inMilliseconds;
    if (total == 0) return 0;
    final pos = ctrl.value.position.inMilliseconds;
    // 整體 timeline 位置：先找 clip 基準，再加上 clip 內的進度
    final clipBase =
        widget.selectedClipIndex * (_clipWidth + 2);
    final progress = pos / total;
    return clipBase + progress * _clipWidth;
  }

  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_onTick);
  }

  @override
  void didUpdateWidget(TimelineWorkspaceWidget old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller?.removeListener(_onTick);
      widget.controller?.addListener(_onTick);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onTick);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  // ── 自動讓播放指針維持在可視範圍 ────────────────
  void _autoScroll(double phX, double viewportWidth) {
    if (!_scrollCtrl.hasClients) return;
    final offset = _scrollCtrl.offset;
    final visible = phX - offset;
    if (visible > viewportWidth * 0.75) {
      _scrollCtrl.animateTo(
        phX - viewportWidth * 0.25,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    } else if (visible < 16) {
      _scrollCtrl.animateTo(
        (phX - 16).clamp(0.0, _scrollCtrl.position.maxScrollExtent),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _totalHeight,
      color: EditorTheme.bg,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 左側固定面板（軌道標籤） ───────────────
          _buildLeftPanel(),

          // ── 右側可捲動軌道區 ──────────────────────
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final viewportW = constraints.maxWidth;
                final phX = _playheadX(viewportW);

                // 非同步觸發自動捲動（避免 build 中 setState）
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _autoScroll(phX, viewportW);
                });

                return ClipRect(
                  child: Stack(
                    children: [
                      // ── 可捲動的軌道內容 ───────────
                      SingleChildScrollView(
                        controller: _scrollCtrl,
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: _totalContentWidth,
                          height: _totalHeight,
                          child: Column(
                            children: [
                              // 時間刻度尺
                              TimeRuler(
                                totalWidth: _totalContentWidth,
                                pixelsPerSecond: widget.pixelsPerSecond,
                                totalDuration: _totalDuration,
                              ),

                              // 影片軌
                              TimelineTrackWidget(
                                type: TrackType.video,
                                clips: _buildVideoClips(),
                                clipWidth: _clipWidth,
                                totalWidth: _totalContentWidth,
                                onClipTap: widget.onClipTap,
                              ),

                              // 音訊軌
                              TimelineTrackWidget(
                                type: TrackType.audio,
                                clips: _buildAudioClips(),
                                clipWidth: _totalContentWidth - _addBtnWidth - 16,
                                totalWidth: _totalContentWidth,
                              ),

                              // 字幕軌（選用）
                              if (widget.showSubtitleTrack)
                                TimelineTrackWidget(
                                  type: TrackType.subtitle,
                                  clips: _buildSubtitleClips(),
                                  clipWidth: _totalContentWidth - _addBtnWidth - 16,
                                  totalWidth: _totalContentWidth,
                                ),
                            ],
                          ),
                        ),
                      ),

                      // ── 播放指針 ─────────────────────
                      ValueListenableBuilder<VideoPlayerValue>(
                        valueListenable: widget.controller ??
                            _dummyNotifier,
                        builder: (context, value, _) {
                          final offset = _scrollCtrl.hasClients
                              ? _scrollCtrl.offset
                              : 0.0;
                          final screenX = phX - offset;
                          if (screenX < -10 || screenX > viewportW + 10) {
                            return const SizedBox.shrink();
                          }
                          return PlayheadWidget(
                            x: screenX,
                            totalHeight: _totalHeight,
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── 左側固定面板 ───────────────────────────────────
  Widget _buildLeftPanel() {
    final tracks = [
      _TrackLabel(icon: Icons.videocam_rounded, label: 'Video', type: TrackType.video),
      _TrackLabel(icon: Icons.music_note_rounded, label: 'Audio', type: TrackType.audio),
      if (widget.showSubtitleTrack)
        _TrackLabel(icon: Icons.subtitles_rounded, label: 'Subs', type: TrackType.subtitle),
    ];

    return Container(
      width: _leftPanelWidth,
      height: _totalHeight,
      decoration: const BoxDecoration(
        color: EditorTheme.surface,
        border: Border(
          right: BorderSide(color: EditorTheme.border, width: 0.5),
        ),
      ),
      child: Column(
        children: [
          // Ruler 對齊空白
          SizedBox(height: _rulerHeight),
          // 軌道標籤
          ...tracks.map((t) => SizedBox(height: _trackHeight, child: t)),
        ],
      ),
    );
  }

  // ── Clip 資料建構 ─────────────────────────────────
  List<TimelineClipData> _buildVideoClips() {
    if (widget.clipPaths.isEmpty) {
      return [
        TimelineClipData(
          index: 0,
          label: '片段 1',
          isSelected: true,
        ),
      ];
    }

    return List.generate(widget.clipPaths.length, (i) {
      final name = widget.clipPaths[i].split('/').last;
      final shortName = name.length > 10
          ? '${name.substring(0, 8)}…'
          : name;
      return TimelineClipData(
        index: i,
        label: '片段 ${i + 1}  $shortName',
        hasTrim: widget.trimRanges.containsKey(i),
        isSelected: i == widget.selectedClipIndex,
      );
    });
  }

  List<TimelineClipData> _buildAudioClips() {
    // 音訊軌佔位（整個 timeline 寬度的一個 block）
    return [
      const TimelineClipData(index: 0, label: '原始音訊'),
    ];
  }

  List<TimelineClipData> _buildSubtitleClips() {
    return [
      const TimelineClipData(index: 0, label: 'AI 字幕'),
    ];
  }

  // 備用空 notifier（當 controller == null 時）
  static final _dummyNotifier =
      ValueNotifier(const VideoPlayerValue(duration: Duration.zero));
}

// ════════════════════════════════════════════════════
//  左側軌道標籤行
// ════════════════════════════════════════════════════
class _TrackLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final TrackType type;

  const _TrackLabel({
    required this.icon,
    required this.label,
    required this.type,
  });

  Color get _iconColor {
    switch (type) {
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
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: EditorTheme.divider, width: 0.5),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: _iconColor, size: 16),
          const SizedBox(height: 2),
          Text(label, style: EditorTheme.trackLabel),
        ],
      ),
    );
  }
}

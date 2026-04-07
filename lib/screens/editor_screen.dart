import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/video_provider.dart';
import '../models/work_item.dart';
import '../services/video_export_service.dart';
import '../services/storage_service.dart';
import 'business_card_screen.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late VideoPlayerController _controller;
  bool _isPlayerReady = false;
  int _currentVideoIndex = 0;

  final VideoExportService _exportService = VideoExportService();
  final StorageService _storageService = StorageService();
  bool _isExporting = false;
  bool _isReorderMode = false; // 排序模式

  // ====== 裁剪功能 ======
  bool _isTrimMode = false;         // 是否處於裁剪模式
  double _trimStart = 0.0;          // 裁剪起點（0.0 ~ 1.0 比例）
  double _trimEnd = 1.0;            // 裁剪終點（0.0 ~ 1.0 比例）
  // 儲存每段影片的裁剪區間
  final Map<int, List<double>> _trimRanges = {};

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    final videos = context.read<VideoProvider>().selectedVideos;
    final file = File(videos[_currentVideoIndex].path);
    _controller = VideoPlayerController.file(file);
    await _controller.initialize();
    // 加入播放位置監聽，用於裁剪模式的即時回饋
    _controller.addListener(_onPlayerTick);
    _loadTrimRange();
    setState(() => _isPlayerReady = true);
  }

  /// 載入此影片的裁剪區間（若有）
  void _loadTrimRange() {
    final range = _trimRanges[_currentVideoIndex];
    if (range != null) {
      _trimStart = range[0];
      _trimEnd = range[1];
    } else {
      _trimStart = 0.0;
      _trimEnd = 1.0;
    }
  }

  /// 儲存目前影片的裁剪區間
  void _saveTrimRange() {
    _trimRanges[_currentVideoIndex] = [_trimStart, _trimEnd];
  }

  /// 播放器每幀回調 — 裁剪模式中限制播放範圍
  void _onPlayerTick() {
    if (!mounted || !_isPlayerReady) return;

    if (_isTrimMode && _controller.value.isPlaying) {
      final total = _controller.value.duration.inMilliseconds;
      final current = _controller.value.position.inMilliseconds;
      final endMs = (_trimEnd * total).round();

      // 播放到裁剪終點時自動暫停
      if (current >= endMs) {
        _controller.pause();
        _controller.seekTo(Duration(milliseconds: (_trimStart * total).round()));
      }
    }

    // 更新 UI（播放進度）
    if (_controller.value.isPlaying) {
      setState(() {});
    }
  }

  Future<void> _switchVideo(int index) async {
    if (index == _currentVideoIndex) return;
    // 儲存當前裁剪區間
    if (_isTrimMode) _saveTrimRange();
    setState(() => _isPlayerReady = false);
    _controller.removeListener(_onPlayerTick);
    await _controller.dispose();
    _currentVideoIndex = index;
    final videos = context.read<VideoProvider>().selectedVideos;
    final file = File(videos[index].path);
    _controller = VideoPlayerController.file(file);
    await _controller.initialize();
    _controller.addListener(_onPlayerTick);
    _loadTrimRange();
    setState(() => _isPlayerReady = true);
  }

  @override
  void dispose() {
    _controller.removeListener(_onPlayerTick);
    _controller.dispose();
    super.dispose();
  }

  /// 取得影片總時長的格式化字串
  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// 根據比例值取得對應的時間
  Duration _positionFromRatio(double ratio) {
    final totalMs = _controller.value.duration.inMilliseconds;
    return Duration(milliseconds: (ratio * totalMs).round());
  }

  @override
  Widget build(BuildContext context) {
    final videoProvider = context.watch<VideoProvider>();
    final videos = videoProvider.selectedVideos;

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('AI 影片編輯'),
          ),
          body: Column(
            children: [
              // 上半部：影片 + 裁剪（可捲動，避免 overflow）
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildVideoPlayer(),
                      _buildTimeline(),
                      if (_isTrimMode && _isPlayerReady) _buildTrimControls(),
                      _buildVideoTabs(videos.length),
                      if (!_isReorderMode) _buildTrimButton(),
                    ],
                  ),
                ),
              ),

              // 下半部：固定在底部的按鈕區
              _buildAiButtons(videoProvider),
              _buildExportButton(videoProvider),
              const SizedBox(height: 20),
            ],
          ),
        ),

        // 匯出中的全螢幕載入動畫
        if (_isExporting) _buildExportingOverlay(),
      ],
    );
  }

  // 匯出中的載入覆蓋層
  Widget _buildExportingOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  color: Color(0xFF1A56DB),
                ),
              ),
              SizedBox(height: 20),
              Text(
                '影片匯出中...',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              SizedBox(height: 8),
              Text(
                '正在處理您的影片，請稍候',
                style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 影片播放器
  Widget _buildVideoPlayer() {
    return Container(
      color: Colors.black,
      height: 250,
      width: double.infinity,
      child: _isPlayerReady
          ? Stack(
              alignment: Alignment.center,
              children: [
                AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      if (_controller.value.isPlaying) {
                        _controller.pause();
                      } else {
                        // 裁剪模式下從起點開始播放
                        if (_isTrimMode) {
                          final startPos = _positionFromRatio(_trimStart);
                          _controller.seekTo(startPos);
                        }
                        _controller.play();
                      }
                    });
                  },
                  child: Icon(
                    _controller.value.isPlaying
                        ? Icons.pause_circle
                        : Icons.play_circle,
                    size: 64,
                    color: Colors.white70,
                  ),
                ),
                // 裁剪模式時顯示裁剪區間時間
                if (_isTrimMode)
                  Positioned(
                    top: 8,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_formatDuration(_positionFromRatio(_trimStart))} — ${_formatDuration(_positionFromRatio(_trimEnd))}',
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),
                  ),
              ],
            )
          : const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
    );
  }

  // 時間軸（裁剪模式下顯示裁剪範圍覆蓋層）
  Widget _buildTimeline() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: _isPlayerReady
          ? Stack(
              children: [
                VideoProgressIndicator(
                  _controller,
                  allowScrubbing: !_isTrimMode, // 裁剪模式下禁用原生拖曳
                  colors: const VideoProgressColors(
                    playedColor: Colors.blueAccent,
                    bufferedColor: Colors.lightBlueAccent,
                    backgroundColor: Colors.grey,
                  ),
                ),
                // 裁剪模式：顯示灰色遮罩（被裁掉的部分）
                if (_isTrimMode)
                  Positioned.fill(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        return Stack(
                          children: [
                            // 左側灰色遮罩
                            Positioned(
                              left: 0,
                              top: 0,
                              bottom: 0,
                              width: width * _trimStart,
                              child: Container(color: Colors.black45),
                            ),
                            // 右側灰色遮罩
                            Positioned(
                              right: 0,
                              top: 0,
                              bottom: 0,
                              width: width * (1.0 - _trimEnd),
                              child: Container(color: Colors.black45),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
              ],
            )
          : const LinearProgressIndicator(),
    );
  }

  // ====================================================
  //  裁剪操控區 — 雙滑桿 + 時間標示
  // ====================================================
  Widget _buildTrimControls() {
    final total = _controller.value.duration;
    final startTime = _formatDuration(_positionFromRatio(_trimStart));
    final endTime = _formatDuration(_positionFromRatio(_trimEnd));
    final trimDuration = _positionFromRatio(_trimEnd) - _positionFromRatio(_trimStart);
    final trimDurText = _formatDuration(trimDuration);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 標題列
          Row(
            children: [
              const Icon(Icons.content_cut, size: 18, color: Color(0xFF1A56DB)),
              const SizedBox(width: 6),
              const Text(
                '裁剪片段',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const Spacer(),
              // 裁剪後時長
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A56DB),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '保留 $trimDurText',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 起點滑桿
          Row(
            children: [
              const SizedBox(width: 50, child: Text('起點', style: TextStyle(fontSize: 13, color: Color(0xFF64748B)))),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                    activeTrackColor: Colors.green[400],
                    inactiveTrackColor: Colors.grey[300],
                    thumbColor: Colors.green,
                  ),
                  child: Slider(
                    value: _trimStart,
                    min: 0.0,
                    max: _trimEnd - 0.01, // 不能超過終點
                    onChanged: (v) {
                      setState(() => _trimStart = v);
                      _controller.seekTo(_positionFromRatio(v));
                    },
                    onChangeEnd: (_) => _saveTrimRange(),
                  ),
                ),
              ),
              SizedBox(
                width: 50,
                child: Text(startTime, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ],
          ),

          // 終點滑桿
          Row(
            children: [
              const SizedBox(width: 50, child: Text('終點', style: TextStyle(fontSize: 13, color: Color(0xFF64748B)))),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                    activeTrackColor: Colors.red[400],
                    inactiveTrackColor: Colors.grey[300],
                    thumbColor: Colors.red,
                  ),
                  child: Slider(
                    value: _trimEnd,
                    min: _trimStart + 0.01, // 不能低於起點
                    max: 1.0,
                    onChanged: (v) {
                      setState(() => _trimEnd = v);
                      _controller.seekTo(_positionFromRatio(v));
                    },
                    onChangeEnd: (_) => _saveTrimRange(),
                  ),
                ),
              ),
              SizedBox(
                width: 50,
                child: Text(endTime, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // 總時長資訊
          Text(
            '影片總長 ${_formatDuration(total)}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  // ====================================================
  //  裁剪模式切換按鈕
  // ====================================================
  Widget _buildTrimButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SizedBox(
        width: double.infinity,
        height: 44,
        child: OutlinedButton.icon(
          onPressed: _isPlayerReady
              ? () {
                  setState(() {
                    _isTrimMode = !_isTrimMode;
                    if (_isTrimMode) {
                      _controller.pause();
                      _loadTrimRange();
                    }
                  });
                }
              : null,
          icon: Icon(
            _isTrimMode ? Icons.check : Icons.content_cut,
            size: 20,
          ),
          label: Text(
            _isTrimMode ? '完成裁剪' : '裁剪影片',
            style: const TextStyle(fontSize: 15),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: _isTrimMode ? Colors.green : const Color(0xFF1A56DB),
            side: BorderSide(
              color: _isTrimMode ? Colors.green : const Color(0xFF1A56DB),
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }

  // 多段影片的切換標籤 + 排序按鈕
  Widget _buildVideoTabs(int videoCount) {
    return Column(
      children: [
        // 標籤列 + 操作按鈕
        SizedBox(
          height: 50,
          child: Row(
            children: [
              // 影片標籤（可橫向滾動）
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(left: 12),
                  itemCount: videoCount,
                  itemBuilder: (context, index) {
                    final isActive = index == _currentVideoIndex;
                    final hasTrim = _trimRanges.containsKey(index);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('片段 ${index + 1}'),
                            if (hasTrim) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.content_cut, size: 14),
                            ],
                          ],
                        ),
                        selected: isActive,
                        onSelected: _isReorderMode ? null : (_) => _switchVideo(index),
                      ),
                    );
                  },
                ),
              ),
              // 排序按鈕
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  icon: Icon(
                    _isReorderMode ? Icons.check_circle : Icons.swap_vert,
                    color: _isReorderMode ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                  ),
                  tooltip: _isReorderMode ? '完成排序' : '排列影片',
                  onPressed: () {
                    setState(() => _isReorderMode = !_isReorderMode);
                  },
                ),
              ),
              // 新增影片按鈕
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: Color(0xFF1A56DB)),
                  tooltip: '新增影片',
                  onPressed: _addMoreVideos,
                ),
              ),
            ],
          ),
        ),

        // 排序模式：可拖曳排列的列表
        if (_isReorderMode) _buildReorderPanel(),
      ],
    );
  }

  // ====================================================
  //  排序面板 — 拖曳排列影片順序
  // ====================================================
  Widget _buildReorderPanel() {
    final videos = context.read<VideoProvider>().selectedVideos;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 標題
          const Row(
            children: [
              Icon(Icons.swap_vert, size: 18, color: Color(0xFF1A56DB)),
              SizedBox(width: 6),
              Text(
                '拖曳調整影片順序',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 可拖曳列表
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: videos.length,
            onReorder: _onReorder,
            itemBuilder: (context, index) {
              final fileName = videos[index].name;
              final hasTrim = _trimRanges.containsKey(index);
              final isActive = index == _currentVideoIndex;

              return Container(
                key: ValueKey('video_$index'),
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFFEFF6FF) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isActive ? const Color(0xFF1A56DB) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.only(left: 12, right: 4),
                  leading: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isActive ? const Color(0xFF1A56DB) : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isActive ? Colors.white : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    '片段 ${index + 1}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    fileName.length > 25 ? '${fileName.substring(0, 25)}...' : fileName,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasTrim)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(Icons.content_cut, size: 16, color: Color(0xFFEA580C)),
                        ),
                      // 移除按鈕（至少保留 1 段）
                      if (videos.length > 1)
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, size: 20, color: Colors.red),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          onPressed: () => _removeVideo(index),
                        ),
                      // 拖曳手柄
                      ReorderableDragStartListener(
                        index: index,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.drag_handle, color: Color(0xFF94A3B8)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// 拖曳排序回調
  void _onReorder(int oldIndex, int newIndex) {
    final provider = context.read<VideoProvider>();

    // 同步更新裁剪區間的索引
    final newTrimRanges = <int, List<double>>{};
    final adjustedNewIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;

    // 計算每個舊索引對應的新索引
    for (final entry in _trimRanges.entries) {
      int idx = entry.key;
      if (idx == oldIndex) {
        idx = adjustedNewIndex;
      } else {
        if (oldIndex < idx && idx <= adjustedNewIndex) {
          idx--;
        } else if (adjustedNewIndex <= idx && idx < oldIndex) {
          idx++;
        }
      }
      newTrimRanges[idx] = entry.value;
    }
    _trimRanges.clear();
    _trimRanges.addAll(newTrimRanges);

    // 更新當前播放索引
    if (_currentVideoIndex == oldIndex) {
      _currentVideoIndex = adjustedNewIndex;
    } else if (oldIndex < _currentVideoIndex && _currentVideoIndex <= adjustedNewIndex) {
      _currentVideoIndex--;
    } else if (adjustedNewIndex <= _currentVideoIndex && _currentVideoIndex < oldIndex) {
      _currentVideoIndex++;
    }

    provider.reorderVideo(oldIndex, newIndex);
    setState(() {});
  }

  /// 移除單段影片
  void _removeVideo(int index) {
    final provider = context.read<VideoProvider>();
    if (provider.selectedVideos.length <= 1) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('移除影片'),
        content: Text('確定要移除片段 ${index + 1} 嗎？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);

              // 移除裁剪區間
              _trimRanges.remove(index);
              // 重新映射索引
              final newTrimRanges = <int, List<double>>{};
              for (final entry in _trimRanges.entries) {
                final newIdx = entry.key > index ? entry.key - 1 : entry.key;
                newTrimRanges[newIdx] = entry.value;
              }
              _trimRanges.clear();
              _trimRanges.addAll(newTrimRanges);

              // 調整當前播放索引
              if (_currentVideoIndex >= provider.selectedVideos.length - 1) {
                _currentVideoIndex = provider.selectedVideos.length - 2;
                if (_currentVideoIndex < 0) _currentVideoIndex = 0;
              } else if (_currentVideoIndex > index) {
                _currentVideoIndex--;
              }

              provider.removeVideo(index);

              // 重新初始化播放器
              setState(() => _isPlayerReady = false);
              _controller.removeListener(_onPlayerTick);
              await _controller.dispose();
              final videos = provider.selectedVideos;
              final file = File(videos[_currentVideoIndex].path);
              _controller = VideoPlayerController.file(file);
              await _controller.initialize();
              _controller.addListener(_onPlayerTick);
              _loadTrimRange();
              setState(() => _isPlayerReady = true);

              if (mounted) {
                _showAiMessage('已移除片段');
              }
            },
            child: const Text('確定移除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// 新增更多影片
  Future<void> _addMoreVideos() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultipleMedia();
    if (picked.isEmpty) return;

    final provider = context.read<VideoProvider>();
    int addedCount = 0;
    for (final file in picked) {
      if (file.path.endsWith('.mp4') ||
          file.path.endsWith('.mov') ||
          file.path.endsWith('.m4v') ||
          file.path.endsWith('.avi')) {
        provider.addVideo(file);
        addedCount++;
      }
    }

    if (addedCount > 0) {
      setState(() {});
      _showAiMessage('已新增 $addedCount 段影片');
    } else {
      _showAiMessage('未選擇有效的影片檔案');
    }
  }

  // 三個 AI 功能按鈕
  Widget _buildAiButtons(VideoProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildAiToggle(
            icon: Icons.auto_fix_high,
            label: 'AI 去冗言',
            isActive: provider.aiRemoveFiller,
            onTap: () {
              provider.toggleRemoveFiller();
              if (provider.aiRemoveFiller) _showAiMessage('AI 去冗言已啟用（將在匯出時處理）');
            },
          ),
          const SizedBox(width: 8),
          _buildAiToggle(
            icon: Icons.subtitles,
            label: 'AI 上字幕',
            isActive: provider.aiSubtitle,
            onTap: () {
              provider.toggleSubtitle();
              if (provider.aiSubtitle) _showAiMessage('AI 字幕已啟用（將在匯出時處理）');
            },
          ),
          const SizedBox(width: 8),
          _buildAiToggle(
            icon: Icons.contact_mail,
            label: '名片片尾',
            isActive: provider.aiBusinessCard,
            onTap: () {
              provider.toggleBusinessCard();
              if (provider.aiBusinessCard) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BusinessCardScreen()),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  // 單個 AI 功能按鈕的樣式
  Widget _buildAiToggle({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: isActive
                ? const LinearGradient(
                    colors: [Color(0xFF1A56DB), Color(0xFF3B82F6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isActive ? null : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isActive ? Colors.transparent : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isActive ? Colors.white : const Color(0xFF64748B)),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isActive ? Colors.white : const Color(0xFF64748B),
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 匯出按鈕
  Widget _buildExportButton(VideoProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton.icon(
          onPressed: _isExporting ? null : () => _handleExport(provider),
          icon: _isExporting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Icon(Icons.upload),
          label: Text(
            _isExporting ? '處理中...' : '匯出影片',
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }

  // 處理匯出流程
  Future<void> _handleExport(VideoProvider provider) async {
    // 如果正在裁剪模式，先儲存當前裁剪範圍
    if (_isTrimMode) _saveTrimRange();

    setState(() => _isExporting = true);

    final paths = provider.selectedVideos.map((v) => v.path).toList();

    // 使用 VideoExportService 進行真實影片合併/裁剪
    final exportResult = await _exportService.mergeAndExport(
      videoPaths: paths,
      trimRanges: _trimRanges.isNotEmpty ? _trimRanges : null,
    );

    if (!mounted) return;

    if (!exportResult.success) {
      setState(() => _isExporting = false);
      _showAiMessage(exportResult.message);
      return;
    }

    // 嘗試儲存到相簿（僅 iOS/Android）
    bool savedToGallery = false;
    if (exportResult.outputPath != null &&
        (Platform.isIOS || Platform.isAndroid)) {
      try {
        await Gal.putVideo(exportResult.outputPath!);
        savedToGallery = true;
      } catch (_) {
        // 儲存到相簿失敗不阻擋流程
      }
    }

    // 儲存作品紀錄
    final now = DateTime.now();
    final work = WorkItem(
      id: now.millisecondsSinceEpoch.toString(),
      title: '房仲影片 ${now.month}/${now.day} ${now.hour}:${now.minute.toString().padLeft(2, '0')}',
      date: '${now.year}/${now.month}/${now.day}',
      videoCount: paths.length,
      usedRemoveFiller: provider.aiRemoveFiller,
      usedSubtitle: provider.aiSubtitle,
      usedBusinessCard: provider.aiBusinessCard,
      outputPath: exportResult.outputPath,
    );
    await _storageService.saveWork(work);

    setState(() => _isExporting = false);
    if (!mounted) return;

    // 顯示匯出成功對話框
    _showExportSuccessDialog(
      outputPath: exportResult.outputPath,
      savedToGallery: savedToGallery,
    );
  }

  /// 匯出成功對話框 — 提供存到相簿 / 分享 / 關閉
  void _showExportSuccessDialog({
    String? outputPath,
    bool savedToGallery = false,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withAlpha(25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 24),
            ),
            const SizedBox(width: 12),
            const Text('匯出完成'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (savedToGallery)
              const Text('影片已自動儲存到您的相簿！',
                  style: TextStyle(fontSize: 15, color: Color(0xFF16A34A))),
            if (!savedToGallery && (Platform.isIOS || Platform.isAndroid))
              const Text('影片已匯出完成',
                  style: TextStyle(fontSize: 15)),
            if (!Platform.isIOS && !Platform.isAndroid)
              const Text('影片已匯出完成（桌面版模擬）',
                  style: TextStyle(fontSize: 15)),
            const SizedBox(height: 8),
            const Text('已儲存到作品集',
                style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
          ],
        ),
        actions: [
          // 分享按鈕
          if (outputPath != null && File(outputPath).existsSync())
            TextButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _shareVideo(outputPath);
              },
              icon: const Icon(Icons.share, size: 18),
              label: const Text('分享影片'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('完成'),
          ),
        ],
      ),
    );
  }

  /// 分享影片檔案
  Future<void> _shareVideo(String filePath) async {
    try {
      await Share.shareXFiles(
        [XFile(filePath)],
        text: '我用 AI 房仲剪輯製作的影片',
      );
    } catch (e) {
      _showAiMessage('分享失敗：$e');
    }
  }

  // 顯示提示訊息
  void _showAiMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }
}

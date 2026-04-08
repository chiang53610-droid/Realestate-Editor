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
import '../services/ai_api_service.dart';
import '../services/gemini_service.dart';
import '../services/storage_service.dart';
import '../theme/editor_theme.dart';
import '../widgets/editor/top_bar/editor_top_bar.dart';
import '../widgets/editor/preview/preview_area_widget.dart';
import '../widgets/editor/preview/playback_control_bar.dart';
import '../widgets/editor/timeline/timeline_workspace_widget.dart';
import '../widgets/editor/toolbar/bottom_toolbar_widget.dart';
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
  AiApiService _aiService = AiApiService(); // 預設 mock，載入 API key 後升級
  final StorageService _storageService = StorageService();
  bool _isExporting = false;
  String _exportStepText = ''; // 匯出步驟文字
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
    _loadGeminiApiKey();
  }

  /// 載入 Gemini API Key，如有則升級為真實 AI 模式
  Future<void> _loadGeminiApiKey() async {
    final key = await _storageService.loadGeminiApiKey();
    if (key.isNotEmpty) {
      _aiService = AiApiService(
        geminiService: GeminiService(apiKey: key),
      );
    }
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
          backgroundColor: EditorTheme.bg,
          appBar: EditorTopBar(
            title: 'AI 剪輯',
            isExporting: _isExporting,
            onBack: () => Navigator.of(context).pop(),
            onExport: () => _handleExport(videoProvider),
          ),
          body: Column(
            children: [
              // 上半部：影片 + 控制 + 裁剪（可捲動，避免 overflow）
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // ── 沉浸式預覽區 ────────────────
                      PreviewAreaWidget(
                        controller: _isPlayerReady ? _controller : null,
                        isReady: _isPlayerReady,
                        isTrimMode: _isTrimMode,
                        trimStart: _trimStart,
                        trimEnd: _trimEnd,
                        formatDuration: _formatDuration,
                        onTap: () {
                          setState(() {
                            if (_controller.value.isPlaying) {
                              _controller.pause();
                            } else {
                              if (_isTrimMode) {
                                _controller.seekTo(
                                    _positionFromRatio(_trimStart));
                              }
                              _controller.play();
                            }
                          });
                        },
                      ),

                      // ── 播放控制列 ──────────────────
                      PlaybackControlBar(
                        controller: _isPlayerReady ? _controller : null,
                        isReady: _isPlayerReady,
                        isTrimMode: _isTrimMode,
                        trimStart: _trimStart,
                        trimEnd: _trimEnd,
                        formatDuration: _formatDuration,
                        onPlayPause: () {
                          setState(() {
                            if (_controller.value.isPlaying) {
                              _controller.pause();
                            } else {
                              if (_isTrimMode) {
                                _controller.seekTo(
                                    _positionFromRatio(_trimStart));
                              }
                              _controller.play();
                            }
                          });
                        },
                      ),

                      if (_isTrimMode && _isPlayerReady) _buildTrimControls(),

                      // ── 多軌時間軸 ──────────────────
                      TimelineWorkspaceWidget(
                        controller: _isPlayerReady ? _controller : null,
                        clipPaths: videos.map((v) => v.path).toList(),
                        selectedClipIndex: _currentVideoIndex,
                        trimRanges: _trimRanges,
                        showSubtitleTrack: videoProvider.aiSubtitle,
                        onClipTap: (index) => _switchVideo(index),
                        onAddClip: _addMoreVideos,
                      ),

                      if (!_isReorderMode) _buildTrimButton(),
                    ],
                  ),
                ),
              ),

              // 下半部：旗艦級底部工具矩陣
              BottomToolbarWidget(
                aiFillerActive: videoProvider.aiRemoveFiller,
                aiSubtitleActive: videoProvider.aiSubtitle,
                aiCardActive: videoProvider.aiBusinessCard,
                isExporting: _isExporting,
                onTrim: () => setState(() => _isTrimMode = !_isTrimMode),
                onAddClip: _addMoreVideos,
                onToggleFiller: () {
                  videoProvider.toggleRemoveFiller();
                  if (videoProvider.aiRemoveFiller) {
                    _showAiMessage('AI 去冗言已啟用（將在匯出時處理）');
                  }
                },
                onToggleSubtitle: () {
                  videoProvider.toggleSubtitle();
                  if (videoProvider.aiSubtitle) {
                    _showAiMessage('AI 字幕已啟用（將在匯出時處理）');
                  }
                },
                onToggleCard: () {
                  videoProvider.toggleBusinessCard();
                  if (videoProvider.aiBusinessCard) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const BusinessCardScreen()),
                    );
                  }
                },
                onExport: () => _handleExport(videoProvider),
              ),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  color: Color(0xFF1A56DB),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _exportStepText.isNotEmpty ? _exportStepText : '影片匯出中...',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                '正在處理您的影片，請稍候',
                style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // _buildVideoPlayer 與 _buildTimeline 已由 PreviewAreaWidget 和
  // PlaybackControlBar 取代（Step 2 重構）。

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
  // _buildVideoTabs 與 _buildReorderPanel 已由 TimelineWorkspaceWidget 取代（Step 3）

  /// 拖曳排序回調
  // ignore: unused_element
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

  /// 移除單段影片（保留供 Step 4 工具列呼叫）
  // ignore: unused_element
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

  // _buildAiButtons / _buildAiToggle / _buildExportButton 已由 BottomToolbarWidget 取代（Step 4）

  // 更新匯出步驟文字
  void _setExportStep(String text) {
    if (mounted) setState(() => _exportStepText = text);
  }

  // 處理匯出流程（含 AI 功能整合）
  Future<void> _handleExport(VideoProvider provider) async {
    // 如果正在裁剪模式，先儲存當前裁剪範圍
    if (_isTrimMode) _saveTrimRange();

    setState(() {
      _isExporting = true;
      _exportStepText = '影片合併中...';
    });

    final paths = provider.selectedVideos.map((v) => v.path).toList();

    // Step 1: 影片合併/裁剪
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

    var outputPath = exportResult.outputPath ?? paths.first;

    // Step 2: AI 去冗言（如果啟用）
    if (provider.aiRemoveFiller) {
      _setExportStep('AI 去冗言處理中...');
      final result = await _aiService.removeFillerWords(outputPath);
      if (!mounted) return;
      _showAiMessage(result.message);
    }

    // Step 3: AI 上字幕（如果啟用）
    if (provider.aiSubtitle) {
      _setExportStep('AI 字幕生成中...');
      final subResult = await _aiService.generateSubtitles(outputPath);
      if (!mounted) return;

      if (subResult.success && subResult.subtitles != null && subResult.subtitles!.isNotEmpty) {
        // 字幕生成成功 → 燒錄進影片
        _setExportStep('字幕燒錄中...');
        final burnResult = await _exportService.burnSubtitles(
          videoPath: outputPath,
          subtitles: subResult.subtitles!,
        );
        if (!mounted) return;

        if (burnResult.success && burnResult.outputPath != null) {
          outputPath = burnResult.outputPath!;
          _showAiMessage('${subResult.subtitles!.length} 句字幕已燒入影片');
        } else {
          _showAiMessage('字幕燒錄失敗：${burnResult.message}');
        }
      } else {
        // 字幕生成失敗 → 顯示錯誤訊息
        _showAiMessage(subResult.message);
      }
    }

    // Step 4: 名片片尾（如果啟用）
    if (provider.aiBusinessCard) {
      _setExportStep('名片片尾生成中...');
      final card = await _storageService.loadBusinessCard();
      if (!card.isEmpty) {
        final result = await _aiService.generateBusinessCard(
          videoPath: outputPath,
          agentName: card.name,
          phone: card.phone,
          title: card.title,
          company: card.company,
        );
        if (!mounted) return;
        _showAiMessage(result.message);
      }
    }

    if (!mounted) return;

    _setExportStep('儲存中...');

    // 嘗試儲存到相簿（僅 iOS/Android）
    bool savedToGallery = false;
    if (Platform.isIOS || Platform.isAndroid) {
      try {
        await Gal.putVideo(outputPath);
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
      outputPath: outputPath,
    );
    await _storageService.saveWork(work);

    setState(() => _isExporting = false);
    if (!mounted) return;

    // 顯示匯出成功對話框
    _showExportSuccessDialog(
      outputPath: outputPath,
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
    // ignore: avoid_print
    print('[EditorScreen] AI 訊息: $message');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: message.contains('失敗') ? 5 : 2),
      ),
    );
  }
}

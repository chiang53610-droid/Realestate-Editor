import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';
import '../theme.dart';
import '../models/clip_timeline.dart';
import '../models/work_item.dart';
import '../services/mock_ai_analysis_service.dart';
import '../services/gemini_service.dart';
import '../services/smart_export_service.dart';
import '../services/storage_service.dart';

/// 智能成片頁面
///
/// 完整流程：選擇影片 → AI 分析 → 顯示時間軸 → 匯出 → 結果播放
class AutoEditScreen extends StatefulWidget {
  const AutoEditScreen({super.key});

  @override
  State<AutoEditScreen> createState() => _AutoEditScreenState();
}

enum _AutoEditState {
  selectVideos,  // 選擇影片
  analyzing,     // AI 分析中
  showTimeline,  // 顯示時間軸，等待確認匯出
  exporting,     // FFmpeg 匯出中
  result,        // 結果播放
}

class _AutoEditScreenState extends State<AutoEditScreen>
    with SingleTickerProviderStateMixin {
  _AutoEditState _state = _AutoEditState.selectVideos;

  // 服務
  MockAIAnalysisService _aiService = MockAIAnalysisService();
  final _exportService = SmartExportService();
  final _storageService = StorageService();
  final _picker = ImagePicker();

  // 資料
  List<XFile> _selectedVideos = [];
  List<ClipTimeline> _timelines = [];
  String? _outputPath;

  // 播放器
  VideoPlayerController? _playerController;
  bool _isPlayerReady = false;

  // Loading 動畫
  late AnimationController _animController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _loadGeminiApiKey();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _playerController?.dispose();
    super.dispose();
  }

  /// 載入 Gemini API Key，如有則升級為真實 AI 模式
  Future<void> _loadGeminiApiKey() async {
    final key = await _storageService.loadGeminiApiKey();
    if (key.isNotEmpty) {
      _aiService = MockAIAnalysisService(
        geminiService: GeminiService(apiKey: key),
      );
    }
  }

  // ======== 流程方法 ========

  /// 選擇影片
  Future<void> _pickVideos() async {
    final files = await _picker.pickMultipleMedia();
    if (files.isEmpty) return;

    // 過濾只保留影片檔案
    final videos = files.where((f) {
      final ext = f.path.toLowerCase();
      return ext.endsWith('.mp4') ||
          ext.endsWith('.mov') ||
          ext.endsWith('.m4v') ||
          ext.endsWith('.avi');
    }).toList();

    if (videos.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請選擇影片檔案')),
      );
      return;
    }

    setState(() {
      _selectedVideos = videos;
    });
  }

  /// 開始 AI 分析
  Future<void> _startAnalysis() async {
    setState(() => _state = _AutoEditState.analyzing);

    final paths = _selectedVideos.map((v) => v.path).toList();
    final timelines = await _aiService.analyze(paths);

    if (!mounted) return;
    setState(() {
      _timelines = timelines;
      _state = _AutoEditState.showTimeline;
    });
  }

  /// 開始匯出
  Future<void> _startExport() async {
    setState(() => _state = _AutoEditState.exporting);

    final result = await _exportService.exportFromTimelines(_timelines);

    if (!mounted) return;

    if (result.success && result.outputPath != null) {
      _outputPath = result.outputPath;

      // 儲存到作品集
      await _saveToPortfolio();

      // 初始化播放器
      await _initResultPlayer();

      setState(() => _state = _AutoEditState.result);
    } else {
      // 匯出失敗，回到時間軸頁面
      setState(() => _state = _AutoEditState.showTimeline);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message)),
        );
      }
    }
  }

  /// 初始化結果播放器
  Future<void> _initResultPlayer() async {
    if (_outputPath == null) return;

    _playerController?.dispose();
    _playerController = VideoPlayerController.file(File(_outputPath!));
    await _playerController!.initialize();
    _playerController!.addListener(() {
      if (mounted) setState(() {});
    });
    setState(() => _isPlayerReady = true);
  }

  /// 儲存到作品集
  Future<void> _saveToPortfolio() async {
    final work = WorkItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'AI 智能成片 — ${_selectedVideos.length} 段素材',
      date: DateTime.now().toIso8601String().substring(0, 10),
      videoCount: _selectedVideos.length,
      usedRemoveFiller: false,
      usedSubtitle: false,
      usedBusinessCard: false,
      outputPath: _outputPath,
    );
    await _storageService.saveWork(work);
  }

  /// 儲存到相簿
  Future<void> _saveToGallery() async {
    if (_outputPath == null) return;
    try {
      await Gal.putVideo(_outputPath!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已儲存到相簿！')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('儲存失敗：$e')),
      );
    }
  }

  /// 分享影片
  Future<void> _shareVideo() async {
    if (_outputPath == null) return;
    await Share.shareXFiles(
      [XFile(_outputPath!)],
      text: 'AI 智能成片影片',
    );
  }

  /// 重新開始
  void _reset() {
    _playerController?.dispose();
    _playerController = null;
    setState(() {
      _state = _AutoEditState.selectVideos;
      _selectedVideos = [];
      _timelines = [];
      _outputPath = null;
      _isPlayerReady = false;
    });
  }

  // ======== UI 建構 ========

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('智能成片'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case _AutoEditState.selectVideos:
        return _buildSelectVideos();
      case _AutoEditState.analyzing:
        return _buildLoadingScreen(
          'AI 正在分析影片...',
          _aiService.isRealAI ? 'Gemini 1.5 Flash 智能識別最佳片段' : '智能識別最佳片段（模擬模式）',
        );
      case _AutoEditState.showTimeline:
        return _buildTimelineView();
      case _AutoEditState.exporting:
        return _buildLoadingScreen('AI 魔法處理中...', '正在裁切拼接你的影片');
      case _AutoEditState.result:
        return _buildResultView();
    }
  }

  /// 選擇影片畫面
  Widget _buildSelectVideos() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 說明卡片
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.auto_awesome, size: 36, color: Colors.white),
                SizedBox(height: 10),
                Text(
                  '智能成片',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '選擇素材影片，AI 會自動分析並剪輯出專業影片',
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 選擇影片按鈕
          OutlinedButton.icon(
            onPressed: _pickVideos,
            icon: const Icon(Icons.video_library, size: 22),
            label: Text(
              _selectedVideos.isEmpty ? '從相簿選擇影片' : '重新選擇影片',
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              side: const BorderSide(color: AppTheme.primaryColor),
            ),
          ),
          const SizedBox(height: 16),

          // 已選擇的影片列表
          if (_selectedVideos.isNotEmpty) ...[
            Text(
              '已選擇 ${_selectedVideos.length} 段影片',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.separated(
                itemCount: _selectedVideos.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final video = _selectedVideos[index];
                  final name = video.name;
                  return Card(
                    child: ListTile(
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.videocam,
                            color: AppTheme.primaryColor),
                      ),
                      title: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: Text('素材 ${index + 1}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () {
                          setState(() {
                            _selectedVideos.removeAt(index);
                          });
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // 開始按鈕
            FilledButton.icon(
              onPressed: _startAnalysis,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('開始智能生成'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Loading 畫面（AI 分析中 / 匯出中）
  Widget _buildLoadingScreen(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 呼吸動畫 icon
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                    ),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.3),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 32),
          const SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
        ],
      ),
    );
  }

  /// 時間軸預覽畫面
  Widget _buildTimelineView() {
    return Column(
      children: [
        // 標題
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 20, 24, 4),
          child: Row(
            children: [
              Icon(Icons.timeline, color: AppTheme.primaryColor, size: 22),
              SizedBox(width: 8),
              Text(
                'AI 建議的剪輯時間軸',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            '以下是 AI 分析後建議保留的片段',
            style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
          ),
        ),
        const SizedBox(height: 12),

        // 時間軸列表
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: _timelines.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final tl = _timelines[index];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // 序號圓圈
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tl.label.isNotEmpty ? tl.label : '片段 ${index + 1}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${tl.startSeconds.toStringAsFixed(1)}s ~ ${tl.endSeconds.toStringAsFixed(1)}s（${tl.durationSeconds.toStringAsFixed(1)}s）',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 小時間條
                      Container(
                        width: 60,
                        height: 6,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: (tl.durationSeconds / 5.0).clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // 總時長資訊
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.timer, size: 18, color: Color(0xFF64748B)),
              const SizedBox(width: 6),
              Text(
                '預估成片長度：${_totalDuration().toStringAsFixed(1)} 秒',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        // 匯出按鈕
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          child: FilledButton.icon(
            onPressed: _startExport,
            icon: const Icon(Icons.movie_creation),
            label: const Text('開始匯出影片'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              minimumSize: const Size(double.infinity, 0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 結果播放畫面
  Widget _buildResultView() {
    return Column(
      children: [
        // 成功橫幅
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF86EFAC)),
          ),
          child: const Row(
            children: [
              Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '影片生成完成！',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF166534),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '已自動儲存到作品集',
                      style: TextStyle(fontSize: 13, color: Color(0xFF4ADE80)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 影片播放器
        Expanded(
          child: _isPlayerReady && _playerController != null
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            color: Colors.black,
                            child: Center(
                              child: AspectRatio(
                                aspectRatio:
                                    _playerController!.value.aspectRatio,
                                child: VideoPlayer(_playerController!),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 播放控制列
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // 倒退 10 秒
                          IconButton(
                            onPressed: () {
                              final pos = _playerController!.value.position;
                              _playerController!.seekTo(
                                pos - const Duration(seconds: 10),
                              );
                            },
                            icon: const Icon(Icons.replay_10, size: 30),
                          ),
                          const SizedBox(width: 16),
                          // 播放/暫停
                          IconButton(
                            onPressed: () {
                              if (_playerController!.value.isPlaying) {
                                _playerController!.pause();
                              } else {
                                _playerController!.play();
                              }
                            },
                            icon: Icon(
                              _playerController!.value.isPlaying
                                  ? Icons.pause_circle_filled
                                  : Icons.play_circle_filled,
                              size: 48,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(width: 16),
                          // 快進 10 秒
                          IconButton(
                            onPressed: () {
                              final pos = _playerController!.value.position;
                              _playerController!.seekTo(
                                pos + const Duration(seconds: 10),
                              );
                            },
                            icon: const Icon(Icons.forward_10, size: 30),
                          ),
                        ],
                      ),

                      // 進度條
                      if (_playerController!.value.duration.inMilliseconds > 0)
                        Slider(
                          value: _playerController!
                                  .value.position.inMilliseconds
                                  .toDouble()
                                  .clamp(
                                    0,
                                    _playerController!
                                        .value.duration.inMilliseconds
                                        .toDouble(),
                                  ),
                          max: _playerController!
                              .value.duration.inMilliseconds
                              .toDouble(),
                          onChanged: (v) {
                            _playerController!
                                .seekTo(Duration(milliseconds: v.round()));
                          },
                        ),
                    ],
                  ),
                )
              : const Center(child: CircularProgressIndicator()),
        ),

        // 底部操作按鈕
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Row(
            children: [
              // 儲存到相簿
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _saveToGallery,
                  icon: const Icon(Icons.save_alt, size: 20),
                  label: const Text('存到相簿'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // 分享
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _shareVideo,
                  icon: const Icon(Icons.share, size: 20),
                  label: const Text('分享'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // 重新開始
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _reset,
                  icon: const Icon(Icons.refresh, size: 20),
                  label: const Text('再做一支'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 計算總時長
  double _totalDuration() {
    return _timelines.fold(0.0, (sum, tl) => sum + tl.durationSeconds);
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../providers/video_provider.dart';
import '../services/ai_api_service.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late VideoPlayerController _controller;
  bool _isPlayerReady = false;
  int _currentVideoIndex = 0;

  final AiApiService _aiService = AiApiService();
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  // 初始化影片播放器
  Future<void> _initPlayer() async {
    final videos = context.read<VideoProvider>().selectedVideos;
    final file = File(videos[_currentVideoIndex].path);
    _controller = VideoPlayerController.file(file);
    await _controller.initialize();
    setState(() {
      _isPlayerReady = true;
    });
  }

  // 切換到另一段影片
  Future<void> _switchVideo(int index) async {
    if (index == _currentVideoIndex) return;
    setState(() {
      _isPlayerReady = false;
    });
    await _controller.dispose();
    _currentVideoIndex = index;
    final videos = context.read<VideoProvider>().selectedVideos;
    final file = File(videos[index].path);
    _controller = VideoPlayerController.file(file);
    await _controller.initialize();
    setState(() {
      _isPlayerReady = true;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final videoProvider = context.watch<VideoProvider>();
    final videos = videoProvider.selectedVideos;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 影片編輯'),
      ),
      body: Column(
        children: [
          _buildVideoPlayer(),
          _buildTimeline(),
          if (videos.length > 1) _buildVideoTabs(videos.length),
          const Spacer(),
          _buildAiButtons(videoProvider),
          _buildExportButton(videoProvider),
          const SizedBox(height: 20),
        ],
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
                      _controller.value.isPlaying
                          ? _controller.pause()
                          : _controller.play();
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
              ],
            )
          : const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
    );
  }

  // 簡易時間軸
  Widget _buildTimeline() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: _isPlayerReady
          ? VideoProgressIndicator(
              _controller,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: Colors.blueAccent,
                bufferedColor: Colors.lightBlueAccent,
                backgroundColor: Colors.grey,
              ),
            )
          : const LinearProgressIndicator(),
    );
  }

  // 多段影片的切換標籤
  Widget _buildVideoTabs(int videoCount) {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: videoCount,
        itemBuilder: (context, index) {
          final isActive = index == _currentVideoIndex;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text('片段 ${index + 1}'),
              selected: isActive,
              onSelected: (_) => _switchVideo(index),
            ),
          );
        },
      ),
    );
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
              if (provider.aiBusinessCard) _showAiMessage('名片片尾已啟用（將在匯出時處理）');
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
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isActive ? Colors.blueAccent : Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, color: isActive ? Colors.white : Colors.grey[700]),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isActive ? Colors.white : Colors.grey[700],
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
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
    setState(() => _isExporting = true);

    final paths = provider.selectedVideos.map((v) => v.path).toList();
    final result = await _aiService.exportVideo(
      videoPaths: paths,
      removeFiller: provider.aiRemoveFiller,
      addSubtitles: provider.aiSubtitle,
      addBusinessCard: provider.aiBusinessCard,
    );

    setState(() => _isExporting = false);
    _showAiMessage(result.message);
  }

  // 顯示提示訊息
  void _showAiMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }
}

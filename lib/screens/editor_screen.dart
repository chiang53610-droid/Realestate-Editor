import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../services/ai_api_service.dart';

class EditorScreen extends StatefulWidget {
  final List<XFile> videos;

  const EditorScreen({super.key, required this.videos});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late VideoPlayerController _controller;
  bool _isPlayerReady = false;
  int _currentVideoIndex = 0;

  final AiApiService _aiService = AiApiService();
  bool _isExporting = false;

  // 記錄三個 AI 功能的開關狀態
  bool _aiRemoveFiller = false;
  bool _aiSubtitle = false;
  bool _aiBusinessCard = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  // 初始化影片播放器
  Future<void> _initPlayer() async {
    final file = File(widget.videos[_currentVideoIndex].path);
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
    final file = File(widget.videos[index].path);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 影片編輯'),
      ),
      body: Column(
        children: [
          // ===== 區塊一：影片播放器 =====
          _buildVideoPlayer(),

          // ===== 區塊二：影片時間軸 =====
          _buildTimeline(),

          // ===== 區塊三：影片素材列表 =====
          if (widget.videos.length > 1) _buildVideoTabs(),

          const Spacer(),

          // ===== 區塊四：三個 AI 功能按鈕 =====
          _buildAiButtons(),

          // ===== 匯出按鈕 =====
          _buildExportButton(),

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
                // 播放/暫停按鈕
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
  Widget _buildVideoTabs() {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: widget.videos.length,
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
  Widget _buildAiButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildAiToggle(
            icon: Icons.auto_fix_high,
            label: 'AI 去冗言',
            isActive: _aiRemoveFiller,
            onTap: () {
              setState(() => _aiRemoveFiller = !_aiRemoveFiller);
              if (_aiRemoveFiller) _showAiMessage('AI 去冗言已啟用（將在匯出時處理）');
            },
          ),
          const SizedBox(width: 8),
          _buildAiToggle(
            icon: Icons.subtitles,
            label: 'AI 上字幕',
            isActive: _aiSubtitle,
            onTap: () {
              setState(() => _aiSubtitle = !_aiSubtitle);
              if (_aiSubtitle) _showAiMessage('AI 字幕已啟用（將在匯出時處理）');
            },
          ),
          const SizedBox(width: 8),
          _buildAiToggle(
            icon: Icons.contact_mail,
            label: '名片片尾',
            isActive: _aiBusinessCard,
            onTap: () {
              setState(() => _aiBusinessCard = !_aiBusinessCard);
              if (_aiBusinessCard) _showAiMessage('名片片尾已啟用（將在匯出時處理）');
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
  Widget _buildExportButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton.icon(
          onPressed: _isExporting ? null : _handleExport,
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
  Future<void> _handleExport() async {
    setState(() => _isExporting = true);

    final paths = widget.videos.map((v) => v.path).toList();
    final result = await _aiService.exportVideo(
      videoPaths: paths,
      removeFiller: _aiRemoveFiller,
      addSubtitles: _aiSubtitle,
      addBusinessCard: _aiBusinessCard,
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

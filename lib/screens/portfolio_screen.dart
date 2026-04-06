import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';
import '../models/work_item.dart';
import '../services/storage_service.dart';

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  final StorageService _storageService = StorageService();
  List<WorkItem> _works = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWorks();
  }

  Future<void> _loadWorks() async {
    final works = await _storageService.loadWorks();
    setState(() {
      _works = works;
      _isLoading = false;
    });
  }

  Future<void> _deleteWork(WorkItem work) async {
    await _storageService.deleteWork(work.id);
    _loadWorks();
  }

  /// 檢查影片檔案是否存在
  bool _videoExists(WorkItem work) {
    if (work.outputPath == null) return false;
    return File(work.outputPath!).existsSync();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('我的作品集')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的作品集'),
        actions: [
          if (_works.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: '清除全部',
              onPressed: _confirmClearAll,
            ),
        ],
      ),
      body: _works.isEmpty ? _buildEmptyState() : _buildWorksList(),
    );
  }

  // ====== 空白狀態 ======
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.video_library_outlined,
              size: 48,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '還沒有作品',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '完成影片剪輯並匯出後\n作品會出現在這裡',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  // ====== 作品列表 ======
  Widget _buildWorksList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _works.length,
      itemBuilder: (context, index) {
        final work = _works[index];
        final hasVideo = _videoExists(work);

        return Card(
          margin: const EdgeInsets.only(bottom: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: hasVideo ? () => _openPlayer(work) : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 影片縮圖預覽區
                _buildThumbnail(work, hasVideo),

                // 資訊區
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 標題
                      Text(
                        work.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // 標籤列
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _buildTag('${work.videoCount} 段影片', const Color(0xFF1A56DB)),
                          if (work.usedRemoveFiller) _buildTag('AI 去冗言', const Color(0xFF16A34A)),
                          if (work.usedSubtitle) _buildTag('AI 字幕', const Color(0xFFEA580C)),
                          if (work.usedBusinessCard) _buildTag('名片片尾', const Color(0xFF9333EA)),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // 日期 + 操作按鈕
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 14, color: Colors.grey[400]),
                          const SizedBox(width: 4),
                          Text(
                            work.date,
                            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                          ),
                          const Spacer(),
                          // 分享按鈕
                          if (hasVideo)
                            _buildActionButton(
                              icon: Icons.share,
                              label: '分享',
                              color: const Color(0xFF0891B2),
                              onTap: () => _shareVideo(work),
                            ),
                          if (hasVideo) const SizedBox(width: 2),
                          // 存到相簿
                          if (hasVideo && (Platform.isIOS || Platform.isAndroid))
                            _buildActionButton(
                              icon: Icons.save_alt,
                              label: '存相簿',
                              color: const Color(0xFF16A34A),
                              onTap: () => _saveToGallery(work),
                            ),
                          if (hasVideo) const SizedBox(width: 2),
                          // 播放按鈕
                          if (hasVideo)
                            _buildActionButton(
                              icon: Icons.play_circle_outline,
                              label: '播放',
                              color: const Color(0xFF1A56DB),
                              onTap: () => _openPlayer(work),
                            ),
                          const SizedBox(width: 2),
                          // 刪除按鈕
                          _buildActionButton(
                            icon: Icons.delete_outline,
                            label: '刪除',
                            color: Colors.red,
                            onTap: () => _confirmDelete(work),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ====== 影片縮圖 ======
  Widget _buildThumbnail(WorkItem work, bool hasVideo) {
    return Container(
      height: 180,
      width: double.infinity,
      color: const Color(0xFF0F172A),
      child: hasVideo
          ? _VideoThumbnail(videoPath: work.outputPath!)
          : const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.videocam_off_outlined, size: 40, color: Color(0xFF475569)),
                  SizedBox(height: 8),
                  Text(
                    '影片檔案不存在',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
    );
  }

  // ====== 操作按鈕 ======
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // ====== 標籤 ======
  Widget _buildTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  // ====== 分享影片 ======
  Future<void> _shareVideo(WorkItem work) async {
    if (work.outputPath == null) return;
    try {
      await Share.shareXFiles(
        [XFile(work.outputPath!)],
        text: '我用 AI 房仲剪輯製作的影片',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('分享失敗：$e'), duration: const Duration(seconds: 2)),
      );
    }
  }

  // ====== 儲存到相簿 ======
  Future<void> _saveToGallery(WorkItem work) async {
    if (work.outputPath == null) return;
    try {
      await Gal.putVideo(work.outputPath!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已儲存到相簿'), duration: Duration(seconds: 1)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('儲存失敗：$e'), duration: const Duration(seconds: 2)),
      );
    }
  }

  // ====== 播放影片 ======
  void _openPlayer(WorkItem work) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _VideoPlayerPage(
          videoPath: work.outputPath!,
          title: work.title,
        ),
      ),
    );
  }

  // ====== 確認刪除單一作品 ======
  void _confirmDelete(WorkItem work) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('刪除作品'),
        content: Text('確定要刪除「${work.title}」嗎？\n此操作無法復原。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteWork(work);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已刪除作品'), duration: Duration(seconds: 1)),
              );
            },
            child: const Text('確定刪除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ====== 確認清除全部 ======
  void _confirmClearAll() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('清除所有作品'),
        content: const Text('確定要刪除全部作品紀錄嗎？\n此操作無法復原。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              for (final w in _works) {
                await _storageService.deleteWork(w.id);
              }
              _loadWorks();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已清除所有作品'), duration: Duration(seconds: 1)),
              );
            },
            child: const Text('確定清除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ============================================================
//  影片縮圖 Widget — 擷取影片第一幀作為預覽
// ============================================================
class _VideoThumbnail extends StatefulWidget {
  final String videoPath;
  const _VideoThumbnail({required this.videoPath});

  @override
  State<_VideoThumbnail> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends State<_VideoThumbnail> {
  VideoPlayerController? _controller;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _initThumbnail();
  }

  Future<void> _initThumbnail() async {
    try {
      final file = File(widget.videoPath);
      if (!file.existsSync()) return;

      _controller = VideoPlayerController.file(file);
      await _controller!.initialize();
      // 跳到第 0.1 秒取得一幀畫面
      await _controller!.seekTo(const Duration(milliseconds: 100));
      if (mounted) setState(() => _isReady = true);
    } catch (_) {
      // 無法讀取影片時不顯示縮圖
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady || _controller == null) {
      return const Center(
        child: Icon(Icons.videocam, size: 48, color: Color(0xFF334155)),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        // 影片第一幀
        SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _controller!.value.size.width,
              height: _controller!.value.size.height,
              child: VideoPlayer(_controller!),
            ),
          ),
        ),
        // 播放按鈕覆蓋
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.black38,
            borderRadius: BorderRadius.circular(26),
          ),
          child: const Icon(Icons.play_arrow, color: Colors.white, size: 32),
        ),
      ],
    );
  }
}

// ============================================================
//  全螢幕影片播放頁面
// ============================================================
class _VideoPlayerPage extends StatefulWidget {
  final String videoPath;
  final String title;

  const _VideoPlayerPage({required this.videoPath, required this.title});

  @override
  State<_VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<_VideoPlayerPage> {
  late VideoPlayerController _controller;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    _controller = VideoPlayerController.file(File(widget.videoPath));
    await _controller.initialize();
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
    setState(() => _isReady = true);
    _controller.play();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title, style: const TextStyle(fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: '分享影片',
            onPressed: () async {
              try {
                await Share.shareXFiles(
                  [XFile(widget.videoPath)],
                  text: '我用 AI 房仲剪輯製作的影片',
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('分享失敗：$e')),
                );
              }
            },
          ),
        ],
      ),
      body: _isReady
          ? Column(
              children: [
                // 影片播放器
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    ),
                  ),
                ),

                // 進度條
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: VideoProgressIndicator(
                    _controller,
                    allowScrubbing: true,
                    colors: const VideoProgressColors(
                      playedColor: Color(0xFF3B82F6),
                      bufferedColor: Color(0xFF334155),
                      backgroundColor: Color(0xFF1E293B),
                    ),
                  ),
                ),

                // 時間 + 控制按鈕
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Row(
                    children: [
                      // 時間
                      Text(
                        _formatDuration(_controller.value.position),
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      Text(
                        ' / ${_formatDuration(_controller.value.duration)}',
                        style: const TextStyle(color: Colors.white38, fontSize: 13),
                      ),
                      const Spacer(),

                      // 後退 10 秒
                      IconButton(
                        icon: const Icon(Icons.replay_10, color: Colors.white70),
                        onPressed: () {
                          final pos = _controller.value.position - const Duration(seconds: 10);
                          _controller.seekTo(pos < Duration.zero ? Duration.zero : pos);
                        },
                      ),

                      // 播放/暫停
                      IconButton(
                        iconSize: 48,
                        icon: Icon(
                          _controller.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          if (_controller.value.isPlaying) {
                            _controller.pause();
                          } else {
                            _controller.play();
                          }
                        },
                      ),

                      // 前進 10 秒
                      IconButton(
                        icon: const Icon(Icons.forward_10, color: Colors.white70),
                        onPressed: () {
                          final pos = _controller.value.position + const Duration(seconds: 10);
                          final max = _controller.value.duration;
                          _controller.seekTo(pos > max ? max : pos);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            )
          : const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/video_picker_service.dart';
import 'editor_screen.dart';

class PickVideoScreen extends StatefulWidget {
  const PickVideoScreen({super.key});

  @override
  State<PickVideoScreen> createState() => _PickVideoScreenState();
}

class _PickVideoScreenState extends State<PickVideoScreen> {
  final VideoPickerService _pickerService = VideoPickerService();
  final List<XFile> _selectedVideos = [];

  // 從相簿選擇影片
  Future<void> _pickVideo() async {
    final video = await _pickerService.pickOneVideo();
    if (video != null) {
      setState(() {
        _selectedVideos.add(video);
      });
    }
  }

  // 移除已選的影片
  void _removeVideo(int index) {
    setState(() {
      _selectedVideos.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('選擇影片素材'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // 選擇影片的按鈕
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _pickVideo,
                icon: const Icon(Icons.video_library),
                label: const Text('從相簿選擇影片', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 24),

            // 已選影片的標題
            Row(
              children: [
                Text(
                  '已選影片 (${_selectedVideos.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 已選影片的列表
            Expanded(
              child: _selectedVideos.isEmpty
                  ? const Center(
                      child: Text(
                        '尚未選擇任何影片\n請點擊上方按鈕選擇素材',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 15),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _selectedVideos.length,
                      itemBuilder: (context, index) {
                        final video = _selectedVideos[index];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.videocam, color: Colors.blueAccent),
                            title: Text(video.name),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _removeVideo(index),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // 下一步按鈕（有選影片才能按）
            if (_selectedVideos.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditorScreen(videos: _selectedVideos),
                        ),
                      );
                    },
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('下一步：AI 剪輯', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

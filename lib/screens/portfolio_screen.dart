import 'package:flutter/material.dart';
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
      ),
      body: _works.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.video_library_outlined, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    '還沒有作品',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '完成影片剪輯並匯出後\n作品會出現在這裡',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _works.length,
              itemBuilder: (context, index) {
                final work = _works[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 標題與日期
                        Row(
                          children: [
                            const Icon(Icons.videocam, color: Colors.blueAccent),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                work.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _deleteWork(work),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // 資訊標籤
                        Row(
                          children: [
                            _buildTag('${work.videoCount} 段影片', Colors.blue),
                            if (work.usedRemoveFiller) _buildTag('AI 去冗言', Colors.green),
                            if (work.usedSubtitle) _buildTag('AI 字幕', Colors.orange),
                            if (work.usedBusinessCard) _buildTag('名片片尾', Colors.purple),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // 日期
                        Text(
                          work.date,
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildTag(String label, MaterialColor color) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: color[700]),
      ),
    );
  }
}

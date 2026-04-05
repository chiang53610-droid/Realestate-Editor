import 'package:flutter/material.dart';

class PortfolioScreen extends StatelessWidget {
  const PortfolioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 目前還沒有真正的作品，顯示空狀態
    // 未來串接後端後，這裡會從本地資料庫讀取已匯出的影片列表
    final List<Map<String, String>> works = [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的作品集'),
      ),
      body: works.isEmpty
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
              itemCount: works.length,
              itemBuilder: (context, index) {
                final work = works[index];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.videocam, color: Colors.blueAccent),
                    title: Text(work['title'] ?? ''),
                    subtitle: Text(work['date'] ?? ''),
                    trailing: const Icon(Icons.play_circle, color: Colors.blueAccent),
                  ),
                );
              },
            ),
    );
  }
}

import 'package:flutter/material.dart';
import 'pick_video_screen.dart';
import 'portfolio_screen.dart';
import 'script_guide_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 最上方的標題列
      appBar: AppBar(
        title: const Text('AI 房仲剪輯'),
        centerTitle: true,
      ),
      // 頁面主體
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 第一張卡片：拍攝腳本指引
            _buildMenuCard(
              icon: Icons.description,
              title: '拍攝腳本指引',
              subtitle: '依照指引拍出專業影片',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ScriptGuideScreen()),
                );
              },
            ),
            const SizedBox(height: 20),

            // 第二張卡片：選擇影片一鍵剪輯
            _buildMenuCard(
              icon: Icons.movie_creation,
              title: '選擇影片一鍵剪輯',
              subtitle: '從相簿選擇素材，AI 自動剪輯',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PickVideoScreen()),
                );
              },
            ),
            const SizedBox(height: 20),

            // 第三張卡片：我的作品集
            _buildMenuCard(
              icon: Icons.folder_special,
              title: '我的作品集',
              subtitle: '查看已完成的影片作品',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PortfolioScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // 這是一個「卡片產生器」，幫我們製作統一風格的選單卡片
  Widget _buildMenuCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Row(
            children: [
              Icon(icon, size: 40, color: Colors.blueAccent),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

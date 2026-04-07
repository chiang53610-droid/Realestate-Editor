import 'package:flutter/material.dart';
import '../theme.dart';
import '../utils/page_routes.dart';
import 'pick_video_screen.dart';
import 'portfolio_screen.dart';
import 'script_guide_screen.dart';
import 'business_card_screen.dart';
import 'auto_edit_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 房仲剪輯'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(context, SlideRoute(page: const SettingsScreen()));
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 歡迎區塊
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.videocam, size: 40, color: Colors.white),
                  SizedBox(height: 12),
                  Text(
                    '歡迎回來！',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '用 AI 打造專業房仲影片',
                    style: TextStyle(fontSize: 15, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // 功能區標題
            const Text(
              '開始製作',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 14),

            // 第一張卡片：拍攝腳本指引
            _buildMenuCard(
              icon: Icons.description,
              iconBgColor: const Color(0xFFEFF6FF),
              iconColor: AppTheme.primaryColor,
              title: '拍攝腳本指引',
              subtitle: '依照指引拍出專業影片',
              onTap: () {
                Navigator.push(context, FadeScaleRoute(page: const ScriptGuideScreen()));
              },
            ),
            const SizedBox(height: 12),

            // 第二張卡片：選擇影片一鍵剪輯
            _buildMenuCard(
              icon: Icons.movie_creation,
              iconBgColor: const Color(0xFFFFF7ED),
              iconColor: AppTheme.accentColor,
              title: '選擇影片一鍵剪輯',
              subtitle: '從相簿選擇素材，AI 自動剪輯',
              onTap: () {
                Navigator.push(context, FadeScaleRoute(page: const PickVideoScreen()));
              },
            ),
            const SizedBox(height: 12),

            // 第三張卡片：智能成片
            _buildMenuCard(
              icon: Icons.auto_awesome,
              iconBgColor: const Color(0xFFF5F3FF),
              iconColor: const Color(0xFF7C3AED),
              title: '智能成片',
              subtitle: 'AI 自動分析素材，一鍵生成專業影片',
              onTap: () {
                Navigator.push(context, FadeScaleRoute(page: const AutoEditScreen()));
              },
            ),
            const SizedBox(height: 12),

            // 第四張卡片：名片片尾設定
            _buildMenuCard(
              icon: Icons.contact_mail,
              iconBgColor: const Color(0xFFFDF2F8),
              iconColor: const Color(0xFFDB2777),
              title: '名片片尾設定',
              subtitle: '設定個人名片，影片結尾自動附加',
              onTap: () {
                Navigator.push(context, FadeScaleRoute(page: const BusinessCardScreen()));
              },
            ),
            const SizedBox(height: 12),

            // 第五張卡片：我的作品集
            _buildMenuCard(
              icon: Icons.folder_special,
              iconBgColor: const Color(0xFFF0FDF4),
              iconColor: const Color(0xFF16A34A),
              title: '我的作品集',
              subtitle: '查看已完成的影片作品',
              onTap: () {
                Navigator.push(context, FadeScaleRoute(page: const PortfolioScreen()));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
          child: Row(
            children: [
              // 圓形圖示背景
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 28, color: iconColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFFCBD5E1)),
            ],
          ),
        ),
      ),
    );
  }
}

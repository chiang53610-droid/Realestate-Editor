import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const _pages = [
    _PageData(
      icon: Icons.videocam_rounded,
      title: 'AI 拍攝教練',
      subtitle: '跟著腳本指引拍攝\n智能提詞機、水平儀幫你拍出專業影片',
      gradient: [Color(0xFF1A56DB), Color(0xFF3B82F6)],
    ),
    _PageData(
      icon: Icons.auto_fix_high_rounded,
      title: '一鍵智能剪輯',
      subtitle: '自動裁剪、排序、合併多段影片\nAI 去冗言、自動上字幕',
      gradient: [Color(0xFF9333EA), Color(0xFFC084FC)],
    ),
    _PageData(
      icon: Icons.share_rounded,
      title: '輕鬆分享作品',
      subtitle: '匯出後自動存入相簿\n一鍵分享到 LINE、社群媒體',
      gradient: [Color(0xFF16A34A), Color(0xFF4ADE80)],
    ),
  ];

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      _FadeRoute(page: const HomeScreen()),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 頁面內容
          PageView.builder(
            controller: _pageController,
            itemCount: _pages.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) => _buildPage(_pages[index]),
          ),

          // 底部控制區
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 頁面指示點
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _pages.length,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: i == _currentPage ? 28 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i == _currentPage
                                ? AppTheme.primaryColor
                                : const Color(0xFFCBD5E1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // 下一步 / 開始使用 按鈕
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton(
                        onPressed: _nextPage,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          _currentPage == _pages.length - 1 ? '開始使用' : '下一步',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 略過
                    if (_currentPage < _pages.length - 1)
                      TextButton(
                        onPressed: _completeOnboarding,
                        child: const Text(
                          '略過',
                          style: TextStyle(
                            fontSize: 15,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    if (_currentPage == _pages.length - 1)
                      const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(_PageData data) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 60),

          // 圖示圓圈
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: data.gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(36),
              boxShadow: [
                BoxShadow(
                  color: data.gradient[0].withAlpha(60),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Icon(data.icon, size: 64, color: Colors.white),
          ),
          const SizedBox(height: 48),

          // 標題
          Text(
            data.title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),

          // 說明文字
          Text(
            data.subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              height: 1.6,
              color: Color(0xFF64748B),
            ),
          ),

          const SizedBox(height: 120),
        ],
      ),
    );
  }
}

// 頁面資料
class _PageData {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;

  const _PageData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
  });
}

// 淡入轉場動畫
class _FadeRoute extends PageRouteBuilder {
  final Widget page;

  _FadeRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 500),
        );
}

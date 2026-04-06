import 'package:flutter/material.dart';
import '../models/business_card.dart';
import '../services/storage_service.dart';
import 'business_card_screen.dart';

/// 設定頁面
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final StorageService _storage = StorageService();
  BusinessCard _card = const BusinessCard();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final card = await _storage.loadBusinessCard();
    setState(() {
      _card = card;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ====== 個人資料卡片 ======
                _buildProfileCard(),

                const SizedBox(height: 20),

                // ====== 偏好設定 ======
                _buildSectionTitle('偏好設定'),
                const SizedBox(height: 8),
                _buildSettingItem(
                  icon: Icons.high_quality,
                  title: '影片畫質',
                  subtitle: '高畫質（1080p）',
                  onTap: () => _showQualityPicker(),
                ),
                _buildSettingItem(
                  icon: Icons.timer,
                  title: '預設拍攝秒數',
                  subtitle: '每步驟 15 秒',
                  onTap: () => _showDurationPicker(),
                ),

                const SizedBox(height: 20),

                // ====== 資料管理 ======
                _buildSectionTitle('資料管理'),
                const SizedBox(height: 8),
                _buildSettingItem(
                  icon: Icons.delete_sweep,
                  title: '清除作品紀錄',
                  subtitle: '刪除所有已儲存的作品資料',
                  iconColor: Colors.red,
                  onTap: () => _confirmClearWorks(),
                ),
                _buildSettingItem(
                  icon: Icons.restart_alt,
                  title: '重設名片資料',
                  subtitle: '清除已儲存的名片資訊',
                  iconColor: Colors.orange,
                  onTap: () => _confirmResetCard(),
                ),

                const SizedBox(height: 20),

                // ====== 關於 ======
                _buildSectionTitle('關於'),
                const SizedBox(height: 8),
                _buildSettingItem(
                  icon: Icons.info_outline,
                  title: 'AI 房仲剪輯',
                  subtitle: '版本 1.0.0',
                  onTap: () => _showAbout(),
                ),

                const SizedBox(height: 40),
              ],
            ),
    );
  }

  /// 個人資料卡片
  Widget _buildProfileCard() {
    final hasProfile = !_card.isEmpty;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BusinessCardScreen()),
          );
          _loadData(); // 返回時重新載入
        },
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // 頭像
              CircleAvatar(
                radius: 30,
                backgroundColor: const Color(0xFF1A56DB),
                child: Text(
                  hasProfile ? _card.name[0] : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // 資訊
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasProfile ? _card.name : '尚未設定個人資料',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasProfile
                          ? [_card.title, _card.company]
                              .where((s) => s.isNotEmpty)
                              .join(' · ')
                          : '點擊設定名片資訊',
                      style: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
                    ),
                    if (hasProfile && _card.phone.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        _card.phone,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                    ],
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

  /// 區塊標題
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1E293B),
        ),
      ),
    );
  }

  /// 設定項目
  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color iconColor = const Color(0xFF1A56DB),
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withAlpha(25),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
        trailing: const Icon(Icons.chevron_right, color: Color(0xFFCBD5E1), size: 20),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// 影片畫質選擇
  void _showQualityPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('影片畫質', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildQualityOption(ctx, '720p', '適合快速分享', false),
            _buildQualityOption(ctx, '1080p', '推薦，畫質與檔案大小平衡', true),
            _buildQualityOption(ctx, '4K', '最高畫質，檔案較大', false),
          ],
        ),
      ),
    );
  }

  Widget _buildQualityOption(BuildContext ctx, String label, String desc, bool isSelected) {
    return ListTile(
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(desc, style: const TextStyle(fontSize: 12)),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: Color(0xFF1A56DB))
          : const Icon(Icons.circle_outlined, color: Color(0xFFCBD5E1)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: () {
        Navigator.pop(ctx);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('畫質已設為 $label'), duration: const Duration(seconds: 1)),
        );
      },
    );
  }

  /// 預設拍攝秒數選擇
  void _showDurationPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('預設拍攝秒數', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('新增腳本步驟時的預設建議秒數', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
            const SizedBox(height: 16),
            ...[10, 15, 20, 30].map((sec) => ListTile(
                  title: Text('$sec 秒', style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: sec == 15
                      ? const Icon(Icons.check_circle, color: Color(0xFF1A56DB))
                      : const Icon(Icons.circle_outlined, color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('預設秒數已設為 $sec 秒'), duration: const Duration(seconds: 1)),
                    );
                  },
                )),
          ],
        ),
      ),
    );
  }

  /// 確認清除作品紀錄
  void _confirmClearWorks() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清除作品紀錄'),
        content: const Text('確定要刪除所有已儲存的作品紀錄嗎？此操作無法復原。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final prefs = await _storage.loadWorks();
              for (final w in prefs) {
                await _storage.deleteWork(w.id);
              }
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已清除所有作品紀錄')),
              );
            },
            child: const Text('確定清除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// 確認重設名片
  void _confirmResetCard() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重設名片資料'),
        content: const Text('確定要清除已儲存的名片資訊嗎？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _storage.saveBusinessCard(const BusinessCard());
              _loadData();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('名片已重設')),
              );
            },
            child: const Text('確定重設', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// 關於對話框
  void _showAbout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A56DB), Color(0xFF3B82F6)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.videocam, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            const Text('AI 房仲剪輯'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('版本 1.0.0', style: TextStyle(color: Color(0xFF64748B))),
            SizedBox(height: 12),
            Text(
              '專為房仲打造的 AI 影片剪輯工具。\n\n'
              '功能包含：\n'
              '• AI 拍攝教練與腳本引導\n'
              '• 智能提詞機\n'
              '• 影片裁剪與編輯\n'
              '• 名片片尾自動生成\n'
              '• AI 去冗言與字幕',
              style: TextStyle(fontSize: 14, height: 1.6),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('關閉'),
          ),
        ],
      ),
    );
  }
}

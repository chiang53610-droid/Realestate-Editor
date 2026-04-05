import 'package:flutter/material.dart';
import '../models/business_card.dart';

/// 名片片尾預覽元件 — 提供 3 種風格樣式
class BusinessCardPreview extends StatelessWidget {
  final BusinessCard card;

  const BusinessCardPreview({super.key, required this.card});

  @override
  Widget build(BuildContext context) {
    switch (card.styleIndex) {
      case 1:
        return _buildMinimalStyle();
      case 2:
        return _buildDarkStyle();
      default:
        return _buildClassicStyle();
    }
  }

  // ====== 樣式 0：經典藍 ======
  Widget _buildClassicStyle() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 32),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A56DB), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 公司名
          if (card.company.isNotEmpty)
            Text(
              card.company,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                letterSpacing: 4,
              ),
            ),
          if (card.company.isNotEmpty) const SizedBox(height: 12),

          // 姓名
          Text(
            card.name.isEmpty ? '您的姓名' : card.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),

          // 職稱
          if (card.title.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              card.title,
              style: const TextStyle(color: Colors.white60, fontSize: 15),
            ),
          ],

          const SizedBox(height: 20),

          // 分隔線
          Container(
            width: 50,
            height: 2,
            color: Colors.white38,
          ),

          const SizedBox(height: 20),

          // 聯絡資訊
          _buildContactRow(Icons.phone, card.phone, Colors.white70),
          if (card.email.isNotEmpty)
            _buildContactRow(Icons.email, card.email, Colors.white70),
          if (card.line.isNotEmpty)
            _buildContactRow(Icons.chat, 'LINE: ${card.line}', Colors.white70),
        ],
      ),
    );
  }

  // ====== 樣式 1：簡約白 ======
  Widget _buildMinimalStyle() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 32),
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 姓名
          Text(
            card.name.isEmpty ? '您的姓名' : card.name,
            style: const TextStyle(
              color: Color(0xFF1E293B),
              fontSize: 26,
              fontWeight: FontWeight.w300,
              letterSpacing: 6,
            ),
          ),

          // 職稱 + 公司
          if (card.title.isNotEmpty || card.company.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              [card.title, card.company].where((s) => s.isNotEmpty).join(' | '),
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 14,
                letterSpacing: 2,
              ),
            ),
          ],

          const SizedBox(height: 24),

          // 分隔線
          Container(
            width: 80,
            height: 1,
            color: const Color(0xFFE2E8F0),
          ),

          const SizedBox(height: 24),

          // 聯絡資訊
          _buildContactRow(Icons.phone, card.phone, const Color(0xFF64748B)),
          if (card.email.isNotEmpty)
            _buildContactRow(Icons.email, card.email, const Color(0xFF64748B)),
          if (card.line.isNotEmpty)
            _buildContactRow(Icons.chat, 'LINE: ${card.line}', const Color(0xFF64748B)),
        ],
      ),
    );
  }

  // ====== 樣式 2：質感深色 ======
  Widget _buildDarkStyle() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 32),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 公司名
          if (card.company.isNotEmpty)
            Text(
              card.company,
              style: const TextStyle(
                color: Color(0xFFF59E0B),
                fontSize: 13,
                letterSpacing: 6,
                fontWeight: FontWeight.bold,
              ),
            ),
          if (card.company.isNotEmpty) const SizedBox(height: 14),

          // 姓名
          Text(
            card.name.isEmpty ? '您的姓名' : card.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.bold,
              letterSpacing: 3,
            ),
          ),

          // 職稱
          if (card.title.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              card.title,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 15,
              ),
            ),
          ],

          const SizedBox(height: 20),

          // 金色分隔線
          Container(
            width: 50,
            height: 2,
            color: const Color(0xFFF59E0B),
          ),

          const SizedBox(height: 20),

          // 聯絡資訊
          _buildContactRow(Icons.phone, card.phone, const Color(0xFF94A3B8)),
          if (card.email.isNotEmpty)
            _buildContactRow(Icons.email, card.email, const Color(0xFF94A3B8)),
          if (card.line.isNotEmpty)
            _buildContactRow(Icons.chat, 'LINE: ${card.line}', const Color(0xFF94A3B8)),
        ],
      ),
    );
  }

  /// 單行聯絡資訊
  Widget _buildContactRow(IconData icon, String text, Color color) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(color: color, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

/// 名片樣式資訊（用於選擇樣式時顯示名稱）
class BusinessCardStyles {
  static const List<String> names = ['經典藍', '簡約白', '質感深色'];
}

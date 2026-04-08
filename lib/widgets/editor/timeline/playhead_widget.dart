import 'package:flutter/material.dart';
import '../../../theme/editor_theme.dart';

/// 播放指針 — 貫穿所有軌道的垂直紅線，頂部帶倒三角
///
/// 使用 CustomPaint 繪製，不依賴 layout，僅需要 x 偏移量。
class PlayheadWidget extends StatelessWidget {
  /// 指針的 x 座標（相對於時間軸可捲動區域左緣）
  final double x;

  /// 時間軸的總高度（包含 ruler + 所有軌道）
  final double totalHeight;

  const PlayheadWidget({
    super.key,
    required this.x,
    required this.totalHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: x - 1.0, // 置中修正（線寬 2px）
      top: 0,
      width: 18,     // 容納倒三角的寬度
      height: totalHeight,
      child: IgnorePointer(
        child: CustomPaint(
          painter: _PlayheadPainter(height: totalHeight),
        ),
      ),
    );
  }
}

class _PlayheadPainter extends CustomPainter {
  final double height;

  _PlayheadPainter({required this.height});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = EditorTheme.playheadColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.fill;

    const centerX = 9.0; // size.width / 2

    // ── 倒三角（頂部標記）──────────────────────────
    final trianglePath = Path()
      ..moveTo(centerX - 6, 0)
      ..lineTo(centerX + 6, 0)
      ..lineTo(centerX, 10)
      ..close();
    canvas.drawPath(trianglePath, paint);

    // ── 垂直線 ─────────────────────────────────────
    final linePaint = Paint()
      ..color = EditorTheme.playheadColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(centerX, 10),
      Offset(centerX, height),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(_PlayheadPainter old) => old.height != height;
}

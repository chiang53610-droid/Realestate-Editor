import 'package:flutter/material.dart';

/// AI 房仲剪輯 — 旗艦級深色設計系統
///
/// 參考 CapCut / DaVinci Resolve 的深色視覺語言，
/// 使用 #121212 近黑底色搭配 Cyan 品牌強調色。
abstract class EditorTheme {
  EditorTheme._();

  // ── Backgrounds ─────────────────────────────────────
  static const Color bg          = Color(0xFF121212); // 最底層背景
  static const Color surface     = Color(0xFF1E1E1E); // 面板/頂欄
  static const Color surfaceCard = Color(0xFF252525); // 卡片層
  static const Color surfaceRaised = Color(0xFF2C2C2C); // 浮起元素

  // ── Brand Accent ─────────────────────────────────────
  static const Color accent      = Color(0xFF00F0FF); // Cyan 主強調色
  static const Color accentGold  = Color(0xFFFFD060); // 金色（導出/重要）
  static const Color accentRed   = Color(0xFFFF3D3D); // 紅色（播放頭/刪除）
  static const Color accentGreen = Color(0xFF00E676); // 綠色（成功/字幕軌）

  // ── Track Colors ─────────────────────────────────────
  static const Color videoTrackBg    = Color(0xFF1A4D8F); // 主影片軌（深藍）
  static const Color audioTrackBg    = Color(0xFF4A2C7A); // 音訊軌（深紫）
  static const Color subtitleTrackBg = Color(0xFF1A5E3A); // 字幕軌（深綠）
  static const Color effectsTrackBg  = Color(0xFF5C3A1E); // 特效軌（深橘）

  static const Color videoTrackHighlight    = Color(0xFF2979FF);
  static const Color audioTrackHighlight    = Color(0xFF9C27B0);
  static const Color subtitleTrackHighlight = Color(0xFF00C853);

  // ── Playhead ─────────────────────────────────────────
  static const Color playheadColor = Color(0xFFFF3D3D);

  // ── Text ─────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFAAAAAA);
  static const Color textHint      = Color(0xFF555555);

  // ── Borders & Dividers ───────────────────────────────
  static const Color border      = Color(0xFF333333);
  static const Color divider     = Color(0xFF2A2A2A);
  static const Color trimHandle  = Color(0xFFFFFFFF);

  // ── Gradients ────────────────────────────────────────
  static const LinearGradient exportGradient = LinearGradient(
    colors: [Color(0xFF00C8FF), Color(0xFF0050FF)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient videoClipGradient = LinearGradient(
    colors: [Color(0xFF1E5AA8), Color(0xFF0D2E5E)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient audioClipGradient = LinearGradient(
    colors: [Color(0xFF5C3490), Color(0xFF2D1A4A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ── Shadows ──────────────────────────────────────────
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.5),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get accentGlow => [
        BoxShadow(
          color: accent.withValues(alpha: 0.35),
          blurRadius: 16,
          spreadRadius: 0,
        ),
      ];

  // ── Text Styles ──────────────────────────────────────
  static const TextStyle topBarTitle = TextStyle(
    color: textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );

  static const TextStyle qualityBadge = TextStyle(
    color: textPrimary,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.6,
  );

  static const TextStyle timecode = TextStyle(
    color: textPrimary,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    fontFamily: 'monospace',
    letterSpacing: 1.2,
  );

  static const TextStyle trackLabel = TextStyle(
    color: textSecondary,
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
  );

  static const TextStyle toolButtonLabel = TextStyle(
    color: textSecondary,
    fontSize: 10,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.3,
  );

  static const TextStyle exportButtonLabel = TextStyle(
    color: textPrimary,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.6,
  );

  static const TextStyle sheetTitle = TextStyle(
    color: textPrimary,
    fontSize: 16,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle sectionLabel = TextStyle(
    color: textSecondary,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.4,
  );
}

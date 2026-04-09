import 'package:flutter/material.dart';

/// 使用者自訂文字疊加（在影片特定時間區間顯示文字）
///
/// 時間基準：裁剪後的影片（Option A）。
/// 位置：xFraction / yFraction 為影片寬高的比例（0.0–1.0），
///       (0.5, 0.5) 為正中央。
class TextOverlay {
  final String text;
  final double startSec;
  final double endSec;

  /// 文字中心點 X（影片寬度的比例，0.0=左 ~ 1.0=右，預設 0.5）
  final double xFraction;

  /// 文字中心點 Y（影片高度的比例，0.0=上 ~ 1.0=下，預設 0.5）
  final double yFraction;

  /// 字體大小（pt），預設 56
  final double fontSize;

  /// 文字顏色（Color.value，ARGB），預設白色
  final int colorValue;

  const TextOverlay({
    required this.text,
    required this.startSec,
    required this.endSec,
    this.xFraction = 0.5,
    this.yFraction = 0.5,
    this.fontSize = 56.0,
    this.colorValue = 0xFFFFFFFF,
  });

  Color get color => Color(colorValue);

  /// 是否有效：文字非空、時間合法
  bool get isValid =>
      text.trim().isNotEmpty && startSec >= 0 && endSec > startSec;

  TextOverlay copyWith({
    String? text,
    double? startSec,
    double? endSec,
    double? xFraction,
    double? yFraction,
    double? fontSize,
    int? colorValue,
  }) {
    return TextOverlay(
      text: text ?? this.text,
      startSec: startSec ?? this.startSec,
      endSec: endSec ?? this.endSec,
      xFraction: xFraction ?? this.xFraction,
      yFraction: yFraction ?? this.yFraction,
      fontSize: fontSize ?? this.fontSize,
      colorValue: colorValue ?? this.colorValue,
    );
  }
}

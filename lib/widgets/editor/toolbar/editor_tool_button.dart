import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../theme/editor_theme.dart';

/// 工具按鈕類型
enum ToolButtonStyle {
  normal,   // 一般工具（灰色）
  active,   // 已啟用/選中（Cyan 高亮）
  ai,       // AI 功能（Cyan 漸層邊框）
  danger,   // 危險操作（紅色）
}

/// 旗艦級工具按鈕
///
/// Icon 在上，細體英文/中文 label 在下。
/// 點擊時觸發 HapticFeedback + 縮放動畫。
/// 支援 badge（例如顯示已啟用的 AI 功能計數）。
class EditorToolButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final ToolButtonStyle style;
  final VoidCallback? onTap;
  final bool showBadge;    // 右上角紅點 badge
  final bool isLoading;   // 顯示 loading indicator（匯出中用）

  const EditorToolButton({
    super.key,
    required this.icon,
    required this.label,
    this.style = ToolButtonStyle.normal,
    this.onTap,
    this.showBadge = false,
    this.isLoading = false,
  });

  @override
  State<EditorToolButton> createState() => _EditorToolButtonState();
}

class _EditorToolButtonState extends State<EditorToolButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.85)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (widget.onTap == null) return;
    HapticFeedback.lightImpact();
    await _anim.forward();
    await _anim.reverse();
    widget.onTap!();
  }

  // ── 樣式對應 ─────────────────────────────────────────
  Color get _iconColor {
    switch (widget.style) {
      case ToolButtonStyle.active:
        return EditorTheme.accent;
      case ToolButtonStyle.ai:
        return EditorTheme.accent;
      case ToolButtonStyle.danger:
        return EditorTheme.accentRed;
      case ToolButtonStyle.normal:
        return EditorTheme.textSecondary;
    }
  }

  Color get _labelColor {
    switch (widget.style) {
      case ToolButtonStyle.active:
        return EditorTheme.accent;
      case ToolButtonStyle.ai:
        return EditorTheme.textSecondary;
      case ToolButtonStyle.danger:
        return EditorTheme.accentRed.withValues(alpha: 0.8);
      case ToolButtonStyle.normal:
        return EditorTheme.textHint;
    }
  }

  BoxDecoration get _decoration {
    switch (widget.style) {
      case ToolButtonStyle.active:
        return BoxDecoration(
          color: EditorTheme.accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: EditorTheme.accent.withValues(alpha: 0.5),
          ),
        );
      case ToolButtonStyle.ai:
        return BoxDecoration(
          color: EditorTheme.surfaceCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: EditorTheme.accent.withValues(alpha: 0.25),
          ),
        );
      case ToolButtonStyle.danger:
        return BoxDecoration(
          color: EditorTheme.accentRed.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: EditorTheme.accentRed.withValues(alpha: 0.3),
          ),
        );
      case ToolButtonStyle.normal:
        return BoxDecoration(
          color: EditorTheme.surfaceCard,
          borderRadius: BorderRadius.circular(10),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _scale,
        child: SizedBox(
          width: 64,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Icon 容器 ─────────────────────────────
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 48,
                    height: 48,
                    decoration: _decoration,
                    child: widget.isLoading
                        ? Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _iconColor,
                              ),
                            ),
                          )
                        : Icon(widget.icon, color: _iconColor, size: 22),
                  ),

                  // ── 紅點 Badge ─────────────────────────
                  if (widget.showBadge)
                    Positioned(
                      top: -3,
                      right: -3,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: EditorTheme.accentRed,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: EditorTheme.bg, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 5),

              // ── Label ─────────────────────────────────
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: EditorTheme.toolButtonLabel.copyWith(color: _labelColor),
                child: Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

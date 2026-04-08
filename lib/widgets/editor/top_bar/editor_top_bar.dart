import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../theme/editor_theme.dart';

/// 旗艦級剪輯器頂部工具列
///
/// 左：返回按鈕 + 專案名稱
/// 中：解析度/幀率選擇器（下拉樣式）
/// 右：帶漸層的 Export 匯出按鈕
class EditorTopBar extends StatefulWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onBack;
  final VoidCallback? onExport;
  final bool isExporting;

  const EditorTopBar({
    super.key,
    this.title = 'AI 剪輯',
    this.onBack,
    this.onExport,
    this.isExporting = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  State<EditorTopBar> createState() => _EditorTopBarState();
}

class _EditorTopBarState extends State<EditorTopBar> {
  String _resolution = '1080P';
  int _fps = 30;

  void _showQualityPicker() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: EditorTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _QualityPickerSheet(
        resolution: _resolution,
        fps: _fps,
        onChanged: (res, fps) => setState(() {
          _resolution = res;
          _fps = fps;
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.preferredSize.height,
      decoration: BoxDecoration(
        color: EditorTheme.surface,
        border: const Border(
          bottom: BorderSide(color: EditorTheme.border, width: 0.5),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              // ── 返回按鈕 ──────────────────────────────
              _TapIcon(
                icon: Icons.arrow_back_ios_new_rounded,
                size: 18,
                onTap: () {
                  HapticFeedback.lightImpact();
                  widget.onBack?.call();
                },
              ),

              // ── 專案標題 ──────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    widget.title,
                    style: EditorTheme.topBarTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

              // ── 畫質選擇器 ────────────────────────────
              _QualityBadge(
                resolution: _resolution,
                fps: _fps,
                onTap: _showQualityPicker,
              ),

              const SizedBox(width: 8),

              // ── Export 按鈕 ───────────────────────────
              _ExportButton(
                isExporting: widget.isExporting,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  widget.onExport?.call();
                },
              ),

              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  子 Widget：可點擊 Icon 按鈕
// ════════════════════════════════════════════════════════════
class _TapIcon extends StatefulWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;

  const _TapIcon({
    required this.icon,
    required this.onTap,
    this.size = 20,
  });

  @override
  State<_TapIcon> createState() => _TapIconState();
}

class _TapIconState extends State<_TapIcon> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedOpacity(
        opacity: _pressed ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            widget.icon,
            color: EditorTheme.textPrimary,
            size: widget.size,
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  子 Widget：畫質選擇器 Badge
// ════════════════════════════════════════════════════════════
class _QualityBadge extends StatefulWidget {
  final String resolution;
  final int fps;
  final VoidCallback onTap;

  const _QualityBadge({
    required this.resolution,
    required this.fps,
    required this.onTap,
  });

  @override
  State<_QualityBadge> createState() => _QualityBadgeState();
}

class _QualityBadgeState extends State<_QualityBadge> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedOpacity(
        opacity: _pressed ? 0.6 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: EditorTheme.surfaceRaised,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: EditorTheme.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${widget.resolution}  ${widget.fps}fps',
                style: EditorTheme.qualityBadge,
              ),
              const SizedBox(width: 3),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: EditorTheme.textSecondary,
                size: 13,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  子 Widget：Export 漸層按鈕
// ════════════════════════════════════════════════════════════
class _ExportButton extends StatefulWidget {
  final bool isExporting;
  final VoidCallback onTap;

  const _ExportButton({required this.isExporting, required this.onTap});

  @override
  State<_ExportButton> createState() => _ExportButtonState();
}

class _ExportButtonState extends State<_ExportButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.isExporting ? null : (_) => setState(() => _pressed = true),
      onTapUp: widget.isExporting
          ? null
          : (_) {
              setState(() => _pressed = false);
              widget.onTap();
            },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: AnimatedOpacity(
          opacity: widget.isExporting ? 0.5 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              gradient: EditorTheme.exportGradient,
              borderRadius: BorderRadius.circular(8),
              boxShadow: _pressed ? [] : EditorTheme.accentGlow,
            ),
            child: widget.isExporting
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Export', style: EditorTheme.exportButtonLabel),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  Bottom Sheet：畫質選擇器
// ════════════════════════════════════════════════════════════
class _QualityPickerSheet extends StatefulWidget {
  final String resolution;
  final int fps;
  final void Function(String resolution, int fps) onChanged;

  const _QualityPickerSheet({
    required this.resolution,
    required this.fps,
    required this.onChanged,
  });

  @override
  State<_QualityPickerSheet> createState() => _QualityPickerSheetState();
}

class _QualityPickerSheetState extends State<_QualityPickerSheet> {
  late String _res;
  late int _fps;

  @override
  void initState() {
    super.initState();
    _res = widget.resolution;
    _fps = widget.fps;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 拖曳把手
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: EditorTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text('輸出品質', style: EditorTheme.sheetTitle),
          const SizedBox(height: 20),

          // 解析度
          const Text('解析度', style: EditorTheme.sectionLabel),
          const SizedBox(height: 10),
          Row(
            children: ['720P', '1080P', '4K']
                .map((r) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _SelectChip(
                        label: r,
                        selected: _res == r,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _res = r);
                          widget.onChanged(_res, _fps);
                        },
                      ),
                    ))
                .toList(),
          ),

          const SizedBox(height: 20),

          // 幀率
          const Text('幀率', style: EditorTheme.sectionLabel),
          const SizedBox(height: 10),
          Row(
            children: [24, 30, 60]
                .map((f) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _SelectChip(
                        label: '${f}fps',
                        selected: _fps == f,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _fps = f);
                          widget.onChanged(_res, _fps);
                        },
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _SelectChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SelectChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? EditorTheme.accent.withValues(alpha: 0.12)
              : EditorTheme.surfaceRaised,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? EditorTheme.accent : EditorTheme.border,
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? EditorTheme.accent : EditorTheme.textSecondary,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

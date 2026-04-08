import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../theme/editor_theme.dart';
import 'editor_tool_button.dart';

/// 工具分類
enum ToolCategory { edit, ai, export }

/// 單個工具項目的資料
class ToolItem {
  final IconData icon;
  final String label;
  final ToolButtonStyle style;
  final bool showBadge;
  final bool isLoading;
  final VoidCallback? onTap;
  final ToolCategory category;

  const ToolItem({
    required this.icon,
    required this.label,
    required this.category,
    this.style = ToolButtonStyle.normal,
    this.showBadge = false,
    this.isLoading = false,
    this.onTap,
  });
}

/// 旗艦級底部可滑動工具矩陣
///
/// 佈局：
///   - 分類 Tab（Edit / AI / More）
///   - 橫向可滑動的工具按鈕列
///   - 最右側固定「新增影片」＋「設定」快捷鈕
///
/// 工具清單：
///   Edit  → 裁剪、分割、倒放、速度、旋轉、濾鏡、添加音樂（預留）
///   AI    → AI 去冗言、AI 上字幕、名片片尾
///   More  → 新增片段、排序、匯出設定（預留）
class BottomToolbarWidget extends StatefulWidget {
  // ── Edit 工具 ────────────────────────────────────────
  final VoidCallback? onTrim;
  final VoidCallback? onAddClip;

  // ── AI 工具 ──────────────────────────────────────────
  final bool aiFillerActive;
  final bool aiSubtitleActive;
  final bool aiCardActive;
  final VoidCallback? onToggleFiller;
  final VoidCallback? onToggleSubtitle;
  final VoidCallback? onToggleCard;

  // ── 匯出 ─────────────────────────────────────────────
  final bool isExporting;
  final VoidCallback? onExport;

  const BottomToolbarWidget({
    super.key,
    this.onTrim,
    this.onAddClip,
    this.aiFillerActive = false,
    this.aiSubtitleActive = false,
    this.aiCardActive = false,
    this.onToggleFiller,
    this.onToggleSubtitle,
    this.onToggleCard,
    this.isExporting = false,
    this.onExport,
  });

  @override
  State<BottomToolbarWidget> createState() => _BottomToolbarWidgetState();
}

class _BottomToolbarWidgetState extends State<BottomToolbarWidget>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  static const _tabs = ['Edit', 'AI', 'More'];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  // ── 各分類工具列表 ────────────────────────────────────
  List<ToolItem> get _editTools => [
        ToolItem(
          icon: Icons.content_cut_rounded,
          label: '裁剪',
          category: ToolCategory.edit,
          onTap: widget.onTrim,
        ),
        ToolItem(
          icon: Icons.add_photo_alternate_outlined,
          label: '新增片段',
          category: ToolCategory.edit,
          onTap: widget.onAddClip,
        ),
        // ── 預留工具（State-Ready） ──────────────────
        ToolItem(
          icon: Icons.speed_rounded,
          label: '速度',
          category: ToolCategory.edit,
          onTap: null,
        ),
        ToolItem(
          icon: Icons.flip_camera_ios_rounded,
          label: '翻轉',
          category: ToolCategory.edit,
          onTap: null,
        ),
        ToolItem(
          icon: Icons.music_note_rounded,
          label: '音樂',
          category: ToolCategory.edit,
          onTap: null,
        ),
        ToolItem(
          icon: Icons.color_lens_outlined,
          label: '濾鏡',
          category: ToolCategory.edit,
          onTap: null,
        ),
        ToolItem(
          icon: Icons.format_color_text_rounded,
          label: '文字',
          category: ToolCategory.edit,
          onTap: null,
        ),
        ToolItem(
          icon: Icons.auto_awesome_rounded,
          label: '特效',
          category: ToolCategory.edit,
          onTap: null,
        ),
      ];

  List<ToolItem> get _aiTools => [
        ToolItem(
          icon: Icons.auto_fix_high_rounded,
          label: 'AI 去冗言',
          category: ToolCategory.ai,
          style: widget.aiFillerActive
              ? ToolButtonStyle.active
              : ToolButtonStyle.ai,
          showBadge: widget.aiFillerActive,
          onTap: widget.onToggleFiller,
        ),
        ToolItem(
          icon: Icons.subtitles_rounded,
          label: 'AI 字幕',
          category: ToolCategory.ai,
          style: widget.aiSubtitleActive
              ? ToolButtonStyle.active
              : ToolButtonStyle.ai,
          showBadge: widget.aiSubtitleActive,
          onTap: widget.onToggleSubtitle,
        ),
        ToolItem(
          icon: Icons.contact_mail_rounded,
          label: '名片片尾',
          category: ToolCategory.ai,
          style: widget.aiCardActive
              ? ToolButtonStyle.active
              : ToolButtonStyle.ai,
          showBadge: widget.aiCardActive,
          onTap: widget.onToggleCard,
        ),
        // ── 預留 AI 工具 ────────────────────────────
        ToolItem(
          icon: Icons.mic_rounded,
          label: 'AI 配音',
          category: ToolCategory.ai,
          style: ToolButtonStyle.ai,
          onTap: null,
        ),
        ToolItem(
          icon: Icons.remove_red_eye_rounded,
          label: 'AI 分析',
          category: ToolCategory.ai,
          style: ToolButtonStyle.ai,
          onTap: null,
        ),
      ];

  List<ToolItem> get _moreTools => [
        ToolItem(
          icon: Icons.file_upload_rounded,
          label: '匯出',
          category: ToolCategory.export,
          style: ToolButtonStyle.active,
          isLoading: widget.isExporting,
          onTap: widget.isExporting ? null : widget.onExport,
        ),
        // ── 預留工具 ────────────────────────────────
        ToolItem(
          icon: Icons.share_rounded,
          label: '分享',
          category: ToolCategory.export,
          onTap: null,
        ),
        ToolItem(
          icon: Icons.settings_rounded,
          label: '設定',
          category: ToolCategory.export,
          onTap: null,
        ),
      ];

  List<ToolItem> get _currentTools {
    switch (_tabCtrl.index) {
      case 0:
        return _editTools;
      case 1:
        return _aiTools;
      case 2:
        return _moreTools;
      default:
        return _editTools;
    }
  }

  // ── AI 功能啟用數量（用於 AI tab badge） ────────────
  int get _activeAiCount {
    int count = 0;
    if (widget.aiFillerActive) count++;
    if (widget.aiSubtitleActive) count++;
    if (widget.aiCardActive) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: EditorTheme.surface,
        border: Border(
          top: BorderSide(color: EditorTheme.border, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── 分類 Tab ─────────────────────────────
            _buildCategoryTabs(),
            // ── 工具按鈕列 ───────────────────────────
            _buildToolRow(),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════
  //  分類 Tab 列
  // ════════════════════════════════════════════════════
  Widget _buildCategoryTabs() {
    return SizedBox(
      height: 32,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: List.generate(_tabs.length, (i) {
          final isSelected = _tabCtrl.index == i;
          final showBadge = i == 1 && _activeAiCount > 0;

          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              _tabCtrl.animateTo(i);
            },
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isSelected
                        ? EditorTheme.accent
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _tabs[i],
                    style: TextStyle(
                      color: isSelected
                          ? EditorTheme.accent
                          : EditorTheme.textHint,
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w400,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (showBadge) ...[
                    const SizedBox(width: 4),
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: EditorTheme.accent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '$_activeAiCount',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  // ════════════════════════════════════════════════════
  //  橫向可滑動工具按鈕列
  // ════════════════════════════════════════════════════
  Widget _buildToolRow() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.05, 0),
            end: Offset.zero,
          ).animate(anim),
          child: child,
        ),
      ),
      child: SizedBox(
        key: ValueKey(_tabCtrl.index),
        height: 84,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          itemCount: _currentTools.length,
          separatorBuilder: (context, index) => const SizedBox(width: 6),
          itemBuilder: (_, i) {
            final tool = _currentTools[i];
            return EditorToolButton(
              icon: tool.icon,
              label: tool.label,
              style: tool.style,
              showBadge: tool.showBadge,
              isLoading: tool.isLoading,
              onTap: tool.onTap,
            );
          },
        ),
      ),
    );
  }
}

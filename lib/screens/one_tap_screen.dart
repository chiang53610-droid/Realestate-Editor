import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ffmpeg_kit_flutter_min/ffmpeg_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import '../models/text_overlay.dart';
import '../services/video_picker_service.dart';
import '../services/storage_service.dart';
import '../services/gemini_service.dart';
import '../services/ai_api_service.dart';
import '../services/export_pipeline_service.dart';
import '../theme/editor_theme.dart';
import 'business_card_screen.dart';
import 'portfolio_screen.dart';

/// 一鍵出片主畫面
///
/// UX Flow（設計文件）：
///   首頁 → 「選擇影片」
///     → AI 設定（3 個開關）
///       → 一鍵處理（進度畫面，逐步說明）
///         → 完成（預覽 + 儲存 / 分享）
///
/// 限制：
///   - 影片上限 3 分鐘 / 150MB（先觸發者為準）
///   - 支援格式：MP4、MOV
///   - 輸出：1080×1920 MP4 H.264
class OneTapScreen extends StatefulWidget {
  const OneTapScreen({super.key});

  @override
  State<OneTapScreen> createState() => _OneTapScreenState();
}

// ═══════════════════════════════════════════════
// 畫面狀態機
// ═══════════════════════════════════════════════
enum _Phase {
  selectVideo, // 選片
  aiSettings,  // AI 開關設定
  processing,  // 處理中
  done,        // 完成
}

class _OneTapScreenState extends State<OneTapScreen> {
  _Phase _phase = _Phase.selectVideo;

  // ── 影片 ─────────────────────────────────────
  String? _videoPath;
  String? _videoFileName;
  double _videoDurationSec = 0.0; // 影片實際時長（秒），用於顯示裁剪滑桿

  // ── 裁剪區間 ──────────────────────────────────
  double _trimStart = 0.0; // 比例 0.0–1.0
  double _trimEnd = 1.0;

  // ── 文字疊加 ──────────────────────────────────
  final List<TextOverlay> _textOverlays = [];

  // ── AI 開關 ───────────────────────────────────
  bool _subtitleOn = true;
  bool _fillerOn = false;
  bool _cardOn = true;
  bool _cardIsReady = false; // 名片資料是否已填寫

  // ── 網路狀態 ──────────────────────────────────
  bool _isOnline = true; // 預設樂觀，讓 initState 去更新

  // ── 處理進度 ──────────────────────────────────
  String _stepText = '';
  final List<String> _messages = [];
  bool _isCancelled = false; // 用戶取消旗標
  String _estimatedTimeText = ''; // 預計完成時間提示

  // ── 設定頁影片預覽 ────────────────────────────
  VideoPlayerController? _settingsPreviewCtrl;
  bool _settingsPreviewPlaying = false;

  // ── 完成 ─────────────────────────────────────
  String? _outputPath;
  bool _savedToGallery = false;
  VideoPlayerController? _previewController;
  bool _previewPlaying = false;

  // ── Services ──────────────────────────────────
  final _pickerService = VideoPickerService();
  final _storageService = StorageService();
  late ExportPipelineService _pipelineService;

  @override
  void initState() {
    super.initState();
    _pipelineService = ExportPipelineService(storageService: _storageService);
    _checkBusinessCard();
    _checkConnectivity();
  }

  @override
  void dispose() {
    _settingsPreviewCtrl?.dispose();
    _previewController?.dispose();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      if (mounted) {
        setState(() => _isOnline = result.isNotEmpty && result.first.rawAddress.isNotEmpty);
      }
    } catch (_) {
      if (mounted) setState(() => _isOnline = false);
    }
  }

  Future<void> _initSettingsPreview(String path) async {
    await _settingsPreviewCtrl?.dispose();
    _settingsPreviewCtrl = null;
    final ctrl = VideoPlayerController.file(File(path));
    try {
      await ctrl.initialize();
    } catch (_) {
      await ctrl.dispose();
      return;
    }
    if (!mounted) {
      await ctrl.dispose();
      return;
    }
    setState(() {
      _settingsPreviewCtrl = ctrl;
      _settingsPreviewPlaying = false;
    });
  }

  Future<void> _toggleSettingsPreview() async {
    final ctrl = _settingsPreviewCtrl;
    if (ctrl == null) return;
    if (ctrl.value.isPlaying) {
      await ctrl.pause();
      if (mounted) setState(() => _settingsPreviewPlaying = false);
    } else {
      await ctrl.play();
      if (mounted) setState(() => _settingsPreviewPlaying = true);
      ctrl.addListener(() {
        if (ctrl.value.position >= ctrl.value.duration && mounted) {
          ctrl.pause();
          ctrl.seekTo(Duration(milliseconds: (_trimStart * _videoDurationSec * 1000).round()));
          setState(() => _settingsPreviewPlaying = false);
        }
      });
    }
  }

  Future<void> _checkBusinessCard() async {
    final card = await _storageService.loadBusinessCard();
    if (mounted) setState(() => _cardIsReady = !card.isEmpty);
  }

  Future<void> _initPipelineWithApiKey() async {
    final key = await _storageService.loadGeminiApiKey();
    if (key.isNotEmpty && mounted) {
      _pipelineService = ExportPipelineService(
        storageService: _storageService,
        aiService: AiApiService(geminiService: GeminiService(apiKey: key)),
      );
    }
  }

  // ════════════════════════════════════════════════
  //  動作
  // ════════════════════════════════════════════════

  Future<void> _pickVideo() async {
    final file = await _pickerService.pickOneVideo();
    if (file == null || !mounted) return;

    // ── 格式驗證 ──────────────────────────────────
    final ext = file.path.toLowerCase();
    if (!ext.endsWith('.mp4') && !ext.endsWith('.mov')) {
      _showError('這個格式暫不支援，請用 MP4 或 MOV');
      return;
    }

    // ── 檔案大小驗證（150MB）─────────────────────
    final f = File(file.path);
    final bytes = await f.length();
    final mb = bytes / (1024 * 1024);

    if (mb > 150) {
      _showError('影片太大（${mb.toStringAsFixed(0)}MB，上限 150MB），請先壓縮後再上傳');
      return;
    }

    // ── 時長驗證（3 分鐘）────────────────────────
    // 先讀大小，超過 150MB 就不用再讀時長（避免多一次 IO）
    var videoDurSec = 0;
    final controller = VideoPlayerController.file(f);
    try {
      await controller.initialize();
      videoDurSec = controller.value.duration.inSeconds;
      if (videoDurSec > 180) {
        _showError('影片太長（${(videoDurSec / 60).toStringAsFixed(1)} 分鐘，上限 3 分鐘），請先裁短再上傳');
        return;
      }
    } finally {
      await controller.dispose();
    }

    if (!mounted) return;

    setState(() {
      _videoPath = file.path;
      _videoFileName = file.name;
      _videoDurationSec = videoDurSec.toDouble();
      // 重置裁剪 & 文字疊加（換影片時清除舊狀態，防止 GAP-7）
      _trimStart = 0.0;
      _trimEnd = 1.0;
      _textOverlays.clear();
      _phase = _Phase.aiSettings;
    });
    _initSettingsPreview(file.path);
  }

  Future<void> _startProcessing() async {
    if (_videoPath == null) return;

    // 若名片開關開但名片未填寫 → 先去填寫
    if (_cardOn && !_cardIsReady) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BusinessCardScreen()),
      );
      if (!mounted) return;
      await _checkBusinessCard();
      // 填完後讓用戶手動再點「一鍵處理」
      return;
    }

    await _initPipelineWithApiKey();

    setState(() {
      _phase = _Phase.processing;
      _stepText = '準備中...';
      _messages.clear();
      _isCancelled = false;
      _estimatedTimeText = _calcEstimatedTime();
    });

    // 只有在用戶有裁剪時才傳 trimRanges，避免不必要的 encode
    final hasTrim = _trimStart > 0.001 || _trimEnd < 0.999;

    final result = await _pipelineService.runPipeline(
      videoPaths: [_videoPath!],
      trimRanges: hasTrim ? {0: [_trimStart, _trimEnd]} : null,
      removeFiller: _isOnline && _fillerOn,
      subtitle: _isOnline && _subtitleOn,
      textOverlays: List.unmodifiable(_textOverlays),
      businessCard: _cardOn && _cardIsReady,
      onStepChange: (step) {
        if (mounted) setState(() => _stepText = step);
      },
      onMessage: (msg) {
        if (mounted) setState(() => _messages.add(msg));
      },
    );

    if (!mounted || _isCancelled) return;

    if (!result.success) {
      setState(() {
        _phase = _Phase.aiSettings;
        _stepText = '';
      });
      _showError(result.message);
      return;
    }

    setState(() {
      _phase = _Phase.done;
      _outputPath = result.outputPath;
      _savedToGallery = result.savedToGallery;
    });
    _initPreviewController(result.outputPath);
  }

  String _calcEstimatedTime() {
    final hasAi = _isOnline && (_subtitleOn || _fillerOn);
    if (!hasAi) return '預計約 30 秒內完成';
    if (_subtitleOn && _fillerOn) return '預計約 4–6 分鐘內完成';
    if (_subtitleOn) return '預計約 2–4 分鐘內完成';
    return '預計約 1–2 分鐘內完成'; // 只有去冗言
  }

  Future<void> _cancelProcessing() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EditorTheme.surfaceCard,
        title: const Text('取消處理？',
            style: TextStyle(color: EditorTheme.textPrimary)),
        content: const Text('目前進度將遺失，確定要取消嗎？',
            style: TextStyle(color: EditorTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('繼續等待',
                style: TextStyle(color: EditorTheme.accent)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('取消處理',
                style: TextStyle(
                    color: EditorTheme.accentRed.withValues(alpha: 0.9))),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      // 停止所有 FFmpeg 工作
      if (!Platform.isMacOS && !Platform.isWindows && !Platform.isLinux) {
        FFmpegKit.cancel();
      }
      // 清理暫存目錄中本次管線產生的中間檔
      try {
        final tmpDir = await getTemporaryDirectory();
        final files = tmpDir.listSync();
        for (final f in files) {
          if (f is File) {
            final name = f.path.split('/').last;
            if (name.startsWith('merged_') ||
                name.startsWith('trimmed_') ||
                name.startsWith('filler_cut_') ||
                name.startsWith('subtitled_') ||
                name.startsWith('with_card_') ||
                name.startsWith('concat_') ||
                name.startsWith('subs_')) {
              try { f.deleteSync(); } catch (_) {}
            }
          }
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _isCancelled = true;
          _phase = _Phase.aiSettings;
          _stepText = '';
          _messages.clear();
        });
      }
    }
  }

  Future<void> _initPreviewController(String? path) async {
    if (path == null || !File(path).existsSync()) return;
    final ctrl = VideoPlayerController.file(File(path));
    await ctrl.initialize();
    if (!mounted) {
      ctrl.dispose();
      return;
    }
    setState(() {
      _previewController = ctrl;
      _previewPlaying = false;
    });
  }

  Future<void> _togglePreview() async {
    final ctrl = _previewController;
    if (ctrl == null) return;
    if (ctrl.value.isPlaying) {
      await ctrl.pause();
      if (mounted) setState(() => _previewPlaying = false);
    } else {
      await ctrl.play();
      if (mounted) setState(() => _previewPlaying = true);
      ctrl.addListener(() {
        if (ctrl.value.position >= ctrl.value.duration && mounted) {
          ctrl.pause();
          ctrl.seekTo(Duration.zero);
          setState(() => _previewPlaying = false);
        }
      });
    }
  }

  void _reset() {
    _settingsPreviewCtrl?.dispose();
    _previewController?.dispose();
    setState(() {
      _phase = _Phase.selectVideo;
      _videoPath = null;
      _videoFileName = null;
      _videoDurationSec = 0.0;
      _trimStart = 0.0;
      _trimEnd = 1.0;
      _textOverlays.clear();
      _outputPath = null;
      _savedToGallery = false;
      _messages.clear();
      _stepText = '';
      _settingsPreviewCtrl = null;
      _settingsPreviewPlaying = false;
      _previewController = null;
      _previewPlaying = false;
    });
  }

  void _shareVideo() {
    if (_outputPath == null) return;
    Share.shareXFiles([XFile(_outputPath!)], text: '用 AI 房仲剪輯 App 製作');
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: EditorTheme.accentRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ════════════════════════════════════════════════
  //  Build
  // ════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EditorTheme.bg,
      appBar: AppBar(
        backgroundColor: EditorTheme.surface,
        foregroundColor: EditorTheme.textPrimary,
        elevation: 0,
        title: const Text(
          'AI 一鍵出片',
          style: TextStyle(
            color: EditorTheme.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 0.5, color: EditorTheme.border),
        ),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
          child: _buildCurrentPhase(),
        ),
      ),
    );
  }

  Widget _buildCurrentPhase() {
    switch (_phase) {
      case _Phase.selectVideo:
        return _buildSelectVideoPhase();
      case _Phase.aiSettings:
        return _buildAiSettingsPhase();
      case _Phase.processing:
        return _buildProcessingPhase();
      case _Phase.done:
        return _buildDonePhase();
    }
  }

  // ── Phase 1：選擇影片 ─────────────────────────

  Widget _buildSelectVideoPhase() {
    return Center(
      key: const ValueKey('select'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 圖示
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: EditorTheme.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: EditorTheme.accent.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.video_camera_back_rounded,
                color: EditorTheme.accent,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              '選擇要處理的影片',
              style: TextStyle(
                color: EditorTheme.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'MP4 / MOV，最長 3 分鐘，150MB 以內',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: EditorTheme.textHint,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 40),

            // 選影片按鈕
            GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                _pickVideo();
              },
              child: Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  color: EditorTheme.accent,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: EditorTheme.accentGlow,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.photo_library_rounded,
                        color: Colors.black, size: 20),
                    SizedBox(width: 10),
                    Text(
                      '從相簿選擇影片',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Phase 2：AI 設定 ──────────────────────────

  Widget _buildAiSettingsPhase() {
    return SingleChildScrollView(
      key: const ValueKey('settings'),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 已選影片卡片
          _buildVideoInfoCard(),
          const SizedBox(height: 16),

          // 裁剪滑桿
          _buildTrimSection(),
          const SizedBox(height: 16),

          // 文字疊加
          _buildTextOverlaySection(),
          const SizedBox(height: 20),

          Row(
            children: [
              const Text(
                'AI 功能設定',
                style: TextStyle(
                  color: EditorTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (!_isOnline) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: EditorTheme.accentRed.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '無網路',
                    style: TextStyle(
                      color: EditorTheme.accentRed,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (!_isOnline) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: EditorTheme.accentRed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: EditorTheme.accentRed.withValues(alpha: 0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.wifi_off_rounded, color: EditorTheme.accentRed, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '無網路連線，AI 功能已停用。仍可匯出影片（不含 AI 處理）。',
                      style: TextStyle(color: EditorTheme.accentRed, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),

          // 3 個 AI 開關（離線時自動禁用）
          _buildToggleCard(
            icon: Icons.subtitles_rounded,
            title: 'AI 字幕',
            subtitle: '自動生成中文字幕並燒入影片（約 1-2 分鐘）',
            value: _isOnline && _subtitleOn,
            onChanged: _isOnline ? (v) => setState(() => _subtitleOn = v) : null,
          ),
          const SizedBox(height: 10),
          _buildToggleCard(
            icon: Icons.auto_fix_high_rounded,
            title: 'AI 去冗言',
            subtitle: '自動剪除「嗯」「啊」等停頓詞，約 1 分鐘（BETA，建議預覽確認）',
            value: _isOnline && _fillerOn,
            onChanged: _isOnline ? (v) => setState(() => _fillerOn = v) : null,
            isBeta: true,
          ),
          const SizedBox(height: 10),
          _buildToggleCard(
            icon: Icons.contact_mail_rounded,
            title: '名片片尾',
            subtitle: _cardIsReady ? '影片結尾自動加上您的聯絡資訊（數秒）' : '請先設定名片資料',
            value: _cardOn,
            onChanged: (v) => setState(() => _cardOn = v),
            warning: !_cardIsReady && _cardOn ? '尚未設定名片，點擊「一鍵處理」後會先引導設定' : null,
          ),
          const SizedBox(height: 32),

          // 一鍵處理按鈕
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              _startProcessing();
            },
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                color: EditorTheme.accent,
                borderRadius: BorderRadius.circular(14),
                boxShadow: EditorTheme.accentGlow,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bolt_rounded, color: Colors.black, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    _isOnline ? '一鍵處理' : '處理（不含 AI）',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 返回選片
          GestureDetector(
            onTap: _reset,
            child: Container(
              width: double.infinity,
              height: 44,
              alignment: Alignment.center,
              child: const Text(
                '重新選擇影片',
                style: TextStyle(color: EditorTheme.textHint, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 裁剪滑桿區塊 ─────────────────────────────

  /// 將秒數格式化為 m:ss（e.g. 1:05）
  String _formatSec(double sec) {
    final m = (sec ~/ 60).toString();
    final s = (sec % 60).toInt().toString().padLeft(2, '0');
    return '$m:$s';
  }

  Widget _buildTrimSection() {
    final dur = _videoDurationSec;
    final startSec = _trimStart * dur;
    final endSec = _trimEnd * dur;
    final isDefault = _trimStart < 0.001 && _trimEnd > 0.999;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: EditorTheme.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDefault ? EditorTheme.border : EditorTheme.accent.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: EditorTheme.accent.withValues(alpha: isDefault ? 0.06 : 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.content_cut_rounded,
                  color: isDefault ? EditorTheme.textHint : EditorTheme.accent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '裁剪片段',
                    style: TextStyle(
                      color: EditorTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    isDefault
                        ? '拖曳滑桿選擇要保留的區間'
                        : '保留 ${_formatSec(startSec)} – ${_formatSec(endSec)}',
                    style: TextStyle(
                      color: isDefault ? EditorTheme.textHint : EditorTheme.accent,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (!isDefault)
                GestureDetector(
                  onTap: () => setState(() {
                    _trimStart = 0.0;
                    _trimEnd = 1.0;
                  }),
                  child: const Icon(Icons.restart_alt_rounded,
                      color: EditorTheme.textHint, size: 20),
                ),
            ],
          ),
          // 影片預覽
          if (_settingsPreviewCtrl != null &&
              _settingsPreviewCtrl!.value.isInitialized) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AspectRatio(
                aspectRatio: _settingsPreviewCtrl!.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    VideoPlayer(_settingsPreviewCtrl!),
                    // 播放 / 暫停 覆蓋
                    GestureDetector(
                      onTap: _toggleSettingsPreview,
                      child: AnimatedOpacity(
                        opacity: _settingsPreviewPlaying ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Icon(Icons.play_arrow_rounded,
                              color: Colors.white, size: 28),
                        ),
                      ),
                    ),
                    // 文字疊加預覽：根據播放時間決定顯示哪些標示
                    if (_textOverlays.isNotEmpty)
                      ValueListenableBuilder<VideoPlayerValue>(
                        valueListenable: _settingsPreviewCtrl!,
                        builder: (_, value, __) {
                          final posSec =
                              value.position.inMilliseconds / 1000.0;
                          final active = _textOverlays
                              .where((o) =>
                                  o.isValid &&
                                  posSec >= o.startSec &&
                                  posSec <= o.endSec)
                              .toList();
                          if (active.isEmpty) return const SizedBox.shrink();
                          return Stack(
                            fit: StackFit.expand,
                            children: active
                                .map((ov) => Align(
                                      alignment: Alignment(
                                        ov.xFraction * 2 - 1,
                                        ov.yFraction * 2 - 1,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.black
                                              .withValues(alpha: 0.55),
                                          borderRadius:
                                              BorderRadius.circular(5),
                                        ),
                                        child: Text(
                                          ov.text,
                                          style: TextStyle(
                                            color: ov.color,
                                            fontSize: ov.fontSize * 0.35,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ))
                                .toList(),
                          );
                        },
                      ),

                    // 裁剪時間標示
                    Positioned(
                      bottom: 8,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${_formatSec(startSec)} – ${_formatSec(endSec)}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: EditorTheme.accent,
              inactiveTrackColor: EditorTheme.border,
              thumbColor: EditorTheme.accent,
              overlayColor: EditorTheme.accent.withValues(alpha: 0.15),
              // 大拇指（接近 Apple HIG 44px 最小觸控目標）
              rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 12),
            ),
            child: RangeSlider(
              values: RangeValues(_trimStart, _trimEnd),
              min: 0.0,
              max: 1.0,
              onChanged: (values) {
                // GAP-5 變體：確保最小 1 秒間隔（防止把手重疊）
                final minGap = dur > 0 ? (1.0 / dur).clamp(0.01, 0.5) : 0.01;
                if (values.end - values.start < minGap) return;
                setState(() {
                  _trimStart = values.start;
                  _trimEnd = values.end;
                });
              },
              onChangeEnd: (values) {
                // 拖曳結束後 seek 到起始點，讓用戶確認裁剪位置
                final ctrl = _settingsPreviewCtrl;
                if (ctrl?.value.isInitialized == true) {
                  final seekMs = (values.start * dur * 1000).round();
                  ctrl!.seekTo(Duration(milliseconds: seekMs));
                  ctrl.pause();
                  setState(() => _settingsPreviewPlaying = false);
                }
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatSec(startSec),
                style: const TextStyle(color: EditorTheme.textHint, fontSize: 11),
              ),
              Text(
                dur > 0 ? '共 ${_formatSec(dur)}' : '',
                style: const TextStyle(color: EditorTheme.textHint, fontSize: 11),
              ),
              Text(
                _formatSec(endSec),
                style: const TextStyle(color: EditorTheme.textHint, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 文字疊加區塊 ─────────────────────────────

  Widget _buildTextOverlaySection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: EditorTheme.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _textOverlays.isEmpty
              ? EditorTheme.border
              : EditorTheme.accent.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: EditorTheme.accent.withValues(
                      alpha: _textOverlays.isEmpty ? 0.06 : 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.text_fields_rounded,
                  color: _textOverlays.isEmpty
                      ? EditorTheme.textHint
                      : EditorTheme.accent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '文字標示',
                      style: TextStyle(
                        color: EditorTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '在指定時間區間顯示文字（如「客廳」）',
                      style: TextStyle(color: EditorTheme.textHint, fontSize: 12),
                    ),
                  ],
                ),
              ),
              // 新增按鈕
              GestureDetector(
                onTap: () => _showTextOverlayEditor(null),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: EditorTheme.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: EditorTheme.accent.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, color: EditorTheme.accent, size: 14),
                      SizedBox(width: 4),
                      Text('新增',
                          style: TextStyle(
                              color: EditorTheme.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // 已新增的疊加列表
          if (_textOverlays.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...List.generate(_textOverlays.length, (i) {
              final ov = _textOverlays[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: EditorTheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: EditorTheme.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ov.text,
                              style: const TextStyle(
                                color: EditorTheme.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${_formatSec(ov.startSec)} – ${_formatSec(ov.endSec)}  '
                              '字體 ${ov.fontSize.round()}px',
                              style: const TextStyle(
                                  color: EditorTheme.textHint, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      // 編輯
                      GestureDetector(
                        onTap: () => _showTextOverlayEditor(i),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(Icons.edit_rounded,
                              color: EditorTheme.textHint, size: 16),
                        ),
                      ),
                      // 刪除
                      GestureDetector(
                        onTap: () => setState(() => _textOverlays.removeAt(i)),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(Icons.delete_outline_rounded,
                              color: EditorTheme.accentRed, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  /// 開啟文字疊加編輯 Sheet
  /// [editIndex] null = 新增；int = 編輯第 editIndex 個
  Future<void> _showTextOverlayEditor(int? editIndex) async {
    final existing = editIndex != null ? _textOverlays[editIndex] : null;
    final dur = _videoDurationSec > 0 ? _videoDurationSec : 60.0;

    final result = await showModalBottomSheet<TextOverlay>(
      context: context,
      isScrollControlled: true,
      backgroundColor: EditorTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _TextOverlayEditorSheet(
        initial: existing,
        videoDurationSec: dur,
        videoPath: _videoPath,
      ),
    );

    if (result == null || !mounted) return;

    // GAP-1 & GAP-5：isValid 已在 model 層把關，這裡只需過濾
    if (!result.isValid) return;

    setState(() {
      if (editIndex != null) {
        _textOverlays[editIndex] = result;
      } else {
        _textOverlays.add(result);
      }
    });
  }

  Widget _buildVideoInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EditorTheme.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: EditorTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: EditorTheme.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.videocam_rounded,
                color: EditorTheme.accent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _videoFileName ?? '已選擇影片',
                  style: const TextStyle(
                    color: EditorTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                const Text(
                  '準備就緒',
                  style: TextStyle(color: EditorTheme.accent, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle_rounded,
              color: EditorTheme.accent, size: 20),
        ],
      ),
    );
  }

  Widget _buildToggleCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    ValueChanged<bool>? onChanged, // null = disabled（離線時）
    bool isBeta = false,
    String? warning,
  }) {
    final isDisabled = onChanged == null;
    return Opacity(
      opacity: isDisabled ? 0.45 : 1.0,
      child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: EditorTheme.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: value
              ? EditorTheme.accent.withValues(alpha: 0.4)
              : EditorTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: value
                      ? EditorTheme.accent.withValues(alpha: 0.12)
                      : EditorTheme.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon,
                    color: value
                        ? EditorTheme.accent
                        : EditorTheme.textHint,
                    size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: value
                                ? EditorTheme.textPrimary
                                : EditorTheme.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (isBeta) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: EditorTheme.accentRed
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'BETA',
                              style: TextStyle(
                                color: EditorTheme.accentRed,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: EditorTheme.textHint,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeThumbColor: EditorTheme.accent,
                activeTrackColor: EditorTheme.accent.withValues(alpha: 0.3),
                inactiveThumbColor: EditorTheme.textHint,
                inactiveTrackColor: EditorTheme.surface,
              ),
            ],
          ),
          if (warning != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: EditorTheme.accentRed, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    warning,
                    style: const TextStyle(
                      color: EditorTheme.accentRed,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      ),
    );
  }

  // ── Phase 3：處理中 ───────────────────────────

  Widget _buildProcessingPhase() {
    return Center(
      key: const ValueKey('processing'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 轉圈動畫
            SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: EditorTheme.accent,
                backgroundColor: EditorTheme.accent.withValues(alpha: 0.15),
              ),
            ),
            const SizedBox(height: 28),

            // 預計完成時間
            if (_estimatedTimeText.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _estimatedTimeText,
                style: const TextStyle(
                  color: EditorTheme.textHint,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 20),

            // 當前步驟文字
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Text(
                _stepText,
                key: ValueKey(_stepText),
                style: const TextStyle(
                  color: EditorTheme.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),

            // 訊息列表（每步驟結果）
            if (_messages.isNotEmpty) ...[
              const SizedBox(height: 8),
              Column(
                children: _messages
                    .map((msg) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_rounded,
                                  color: EditorTheme.accent, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                msg,
                                style: const TextStyle(
                                  color: EditorTheme.textHint,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 48),

            // 取消按鈕（44pt 最小觸控目標）
            GestureDetector(
              onTap: _cancelProcessing,
              child: Container(
                height: 44,
                alignment: Alignment.center,
                child: const Text(
                  '取消',
                  style: TextStyle(
                    color: EditorTheme.textHint,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Phase 4：完成 ─────────────────────────────

  Widget _buildDonePhase() {
    return SingleChildScrollView(
      key: const ValueKey('done'),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 成功標頭
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: EditorTheme.accentGreen.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: EditorTheme.accentGreen.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: EditorTheme.accentGreen, size: 52),
                const SizedBox(height: 12),
                const Text(
                  '影片處理完成！',
                  style: TextStyle(
                    color: EditorTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _savedToGallery ? '已自動儲存到相簿' : '處理完成',
                  style: const TextStyle(
                    color: EditorTheme.accentGreen,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 影片預覽（tap 播放/暫停）
          if (_previewController != null &&
              _previewController!.value.isInitialized) ...[
            GestureDetector(
              onTap: _togglePreview,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: _previewController!.value.aspectRatio,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      VideoPlayer(_previewController!),
                      AnimatedOpacity(
                        opacity: _previewPlaying ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: const Icon(Icons.play_arrow_rounded,
                              color: Colors.white, size: 32),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 完成步驟摘要
          if (_messages.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: EditorTheme.surfaceCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: EditorTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '處理摘要',
                    style: TextStyle(
                      color: EditorTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._messages.map(
                    (msg) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_rounded,
                              color: EditorTheme.accent, size: 14),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              msg,
                              style: const TextStyle(
                                color: EditorTheme.textPrimary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // 分享按鈕（輸出檔案不存在時顯示錯誤提示）
          if (_outputPath != null && !File(_outputPath!).existsSync()) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: EditorTheme.accentRed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: EditorTheme.accentRed.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.error_outline_rounded,
                      color: EditorTheme.accentRed, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '輸出檔案無法讀取，請重新處理一次',
                      style: TextStyle(
                          color: EditorTheme.accentRed, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ] else if (_outputPath != null && File(_outputPath!).existsSync())
            GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                _shareVideo();
              },
              child: Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  color: EditorTheme.accent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.share_rounded, color: Colors.black, size: 20),
                    SizedBox(width: 10),
                    Text(
                      '分享影片',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),

          // 再製作一支
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _reset();
            },
            child: Container(
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                color: EditorTheme.surfaceCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: EditorTheme.border),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline_rounded,
                      color: EditorTheme.textSecondary, size: 18),
                  SizedBox(width: 8),
                  Text(
                    '再製作一支影片',
                    style: TextStyle(
                      color: EditorTheme.textSecondary,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 查看作品集（44pt 最小觸控目標）
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PortfolioScreen()),
              );
            },
            child: Container(
              height: 44,
              alignment: Alignment.center,
              child: const Text(
                '查看作品集',
                style: TextStyle(
                  color: EditorTheme.textHint,
                  fontSize: 13,
                  decoration: TextDecoration.underline,
                  decorationColor: EditorTheme.textHint,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// ═══════════════════════════════════════════════════════════
// 文字疊加編輯 Bottom Sheet
// ═══════════════════════════════════════════════════════════

class _TextOverlayEditorSheet extends StatefulWidget {
  final TextOverlay? initial;
  final double videoDurationSec;
  final String? videoPath;

  const _TextOverlayEditorSheet({
    required this.initial,
    required this.videoDurationSec,
    this.videoPath,
  });

  @override
  State<_TextOverlayEditorSheet> createState() =>
      _TextOverlayEditorSheetState();
}

class _TextOverlayEditorSheetState extends State<_TextOverlayEditorSheet> {
  // ── 文字內容 ──────────────────────────────────
  late final TextEditingController _textCtrl;

  // ── 時間 ─────────────────────────────────────
  late double _startSec;
  late double _endSec;

  // ── 位置（0.0–1.0 比例，預設正中央）──────────
  double _xFraction = 0.5;
  double _yFraction = 0.5;

  // ── 樣式 ─────────────────────────────────────
  double _fontSize = 56.0;
  int _colorValue = 0xFFFFFFFF; // 預設白色

  // ── 影片預覽 ──────────────────────────────────
  VideoPlayerController? _previewCtrl;
  bool _previewPlaying = false;
  final GlobalKey _videoAreaKey = GlobalKey();

  // ── 拖曳 / 縮放手勢追蹤 ──────────────────────
  Offset? _panStartFocal;
  double? _panStartX;
  double? _panStartY;
  double? _scaleStartSize;

  // ── 預設顏色列表 ──────────────────────────────
  static const _colorOptions = [
    (0xFFFFFFFF, '白'),
    (0xFFFFFF00, '黃'),
    (0xFF00F0FF, '青'),
    (0xFFFF9500, '橘'),
    (0xFFFF3B30, '紅'),
  ];

  // ── 預設字體大小列表 ──────────────────────────
  static const _sizeOptions = [
    (36.0, '小'),
    (56.0, '中'),
    (72.0, '大'),
  ];

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    _textCtrl = TextEditingController(text: init?.text ?? '');
    _startSec = init?.startSec ?? 0.0;
    _endSec = init?.endSec.clamp(0.0, widget.videoDurationSec) ??
        (widget.videoDurationSec > 3 ? 3.0 : widget.videoDurationSec);
    _xFraction = init?.xFraction ?? 0.5;
    _yFraction = init?.yFraction ?? 0.5;
    _fontSize = init?.fontSize ?? 56.0;
    _colorValue = init?.colorValue ?? 0xFFFFFFFF;
    _initPreview();
  }

  Future<void> _initPreview() async {
    final path = widget.videoPath;
    if (path == null) return;
    final ctrl = VideoPlayerController.file(File(path));
    try {
      await ctrl.initialize();
    } catch (_) {
      await ctrl.dispose();
      return;
    }
    if (!mounted) {
      await ctrl.dispose();
      return;
    }
    await ctrl.seekTo(Duration(milliseconds: (_startSec * 1000).round()));
    setState(() => _previewCtrl = ctrl);
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _previewCtrl?.dispose();
    super.dispose();
  }

  Future<void> _togglePreview() async {
    final ctrl = _previewCtrl;
    if (ctrl == null) return;
    if (ctrl.value.isPlaying) {
      await ctrl.pause();
      if (mounted) setState(() => _previewPlaying = false);
    } else {
      await ctrl.play();
      if (mounted) setState(() => _previewPlaying = true);
      ctrl.addListener(() {
        if (ctrl.value.position >=
                Duration(milliseconds: (_endSec * 1000).round()) &&
            mounted) {
          ctrl.pause();
          ctrl.seekTo(Duration(milliseconds: (_startSec * 1000).round()));
          setState(() => _previewPlaying = false);
        }
      });
    }
  }

  String _fmt(double sec) {
    final m = (sec ~/ 60).toString();
    final s = (sec % 60).toInt().toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── Build ─────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final dur = widget.videoDurationSec;
    final isNew = widget.initial == null;
    final textEmpty = _textCtrl.text.trim().isEmpty;

    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 標題列 ──────────────────────────
            Row(
              children: [
                Text(
                  isNew ? '新增文字標示' : '編輯文字標示',
                  style: const TextStyle(
                    color: EditorTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close_rounded,
                      color: EditorTheme.textHint, size: 22),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── 影片預覽（可拖曳文字）───────────
            _buildVideoPreview(),
            const SizedBox(height: 6),
            const Text(
              '拖曳文字調整位置，兩指捏合縮放大小',
              style: TextStyle(color: EditorTheme.textHint, fontSize: 11),
            ),
            const SizedBox(height: 16),

            // ── 顯示文字輸入 ─────────────────────
            const Text('顯示文字',
                style: TextStyle(
                    color: EditorTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: _textCtrl,
              style: const TextStyle(color: EditorTheme.textPrimary),
              decoration: InputDecoration(
                hintText: '例如：客廳、主臥、廚房',
                hintStyle: const TextStyle(
                    color: EditorTheme.textHint, fontSize: 14),
                filled: true,
                fillColor: EditorTheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: EditorTheme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: EditorTheme.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: EditorTheme.accent, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 18),

            // ── 顏色選項 ─────────────────────────
            Row(
              children: [
                const Text('文字顏色',
                    style: TextStyle(
                        color: EditorTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                ..._colorOptions.map((opt) {
                  final selected = _colorValue == opt.$1;
                  return GestureDetector(
                    onTap: () => setState(() => _colorValue = opt.$1),
                    child: Container(
                      width: 30,
                      height: 30,
                      margin: const EdgeInsets.only(left: 8),
                      decoration: BoxDecoration(
                        color: Color(opt.$1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? EditorTheme.accent
                              : EditorTheme.border,
                          width: selected ? 2.5 : 1.0,
                        ),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: EditorTheme.accent
                                      .withValues(alpha: 0.4),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                )
                              ]
                            : null,
                      ),
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: 14),

            // ── 字體大小選項 ─────────────────────
            Row(
              children: [
                const Text('文字大小',
                    style: TextStyle(
                        color: EditorTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
                ..._sizeOptions.map((opt) {
                  final selected = (_fontSize - opt.$1).abs() < 4.0;
                  return GestureDetector(
                    onTap: () => setState(() => _fontSize = opt.$1),
                    child: Container(
                      width: 52,
                      height: 34,
                      margin: const EdgeInsets.only(right: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected
                            ? EditorTheme.accent.withValues(alpha: 0.12)
                            : EditorTheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected
                              ? EditorTheme.accent.withValues(alpha: 0.5)
                              : EditorTheme.border,
                        ),
                      ),
                      child: Text(
                        opt.$2,
                        style: TextStyle(
                          color: selected
                              ? EditorTheme.accent
                              : EditorTheme.textSecondary,
                          fontSize: 13,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: 18),

            // ── 顯示時間 ─────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('顯示時間',
                    style: TextStyle(
                        color: EditorTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                Text(
                  '${_fmt(_startSec)} – ${_fmt(_endSec)}',
                  style: const TextStyle(
                      color: EditorTheme.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: EditorTheme.accent,
                inactiveTrackColor: EditorTheme.border,
                thumbColor: EditorTheme.accent,
                overlayColor:
                    EditorTheme.accent.withValues(alpha: 0.15),
                rangeThumbShape:
                    const RoundRangeSliderThumbShape(enabledThumbRadius: 12),
              ),
              child: RangeSlider(
                values: RangeValues(_startSec, _endSec),
                min: 0.0,
                max: dur > 0 ? dur : 60.0,
                onChanged: (values) {
                  if (values.end - values.start < 0.5) return;
                  setState(() {
                    _startSec = values.start;
                    _endSec = values.end;
                  });
                },
                onChangeEnd: (values) {
                  final ctrl = _previewCtrl;
                  if (ctrl?.value.isInitialized == true) {
                    ctrl!.seekTo(Duration(
                        milliseconds: (values.start * 1000).round()));
                    ctrl.pause();
                    setState(() => _previewPlaying = false);
                  }
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_fmt(0),
                    style: const TextStyle(
                        color: EditorTheme.textHint, fontSize: 11)),
                Text(_fmt(dur > 0 ? dur : 60),
                    style: const TextStyle(
                        color: EditorTheme.textHint, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 24),

            // ── 確認按鈕 ─────────────────────────
            GestureDetector(
              onTap: textEmpty
                  ? null
                  : () {
                      final overlay = TextOverlay(
                        text: _textCtrl.text.trim(),
                        startSec: _startSec.clamp(0, dur),
                        endSec: _endSec.clamp(0, dur),
                        xFraction: _xFraction,
                        yFraction: _yFraction,
                        fontSize: _fontSize,
                        colorValue: _colorValue,
                      );
                      Navigator.pop(context, overlay);
                    },
              child: Container(
                width: double.infinity,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color:
                      textEmpty ? EditorTheme.border : EditorTheme.accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isNew ? '新增' : '儲存',
                  style: TextStyle(
                    color: textEmpty ? EditorTheme.textHint : Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 影片預覽 + 可拖曳文字 ────────────────────────

  Widget _buildVideoPreview() {
    final ctrl = _previewCtrl;
    if (ctrl == null || !ctrl.value.isInitialized) {
      // 預覽載入中，顯示佔位框
      return Container(
        height: 160,
        decoration: BoxDecoration(
          color: EditorTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: EditorTheme.border),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            color: EditorTheme.accent,
            strokeWidth: 2,
          ),
        ),
      );
    }

    return GestureDetector(
      // 拖曳調整位置 + 捏合縮放字體
      onScaleStart: (details) {
        _panStartFocal = details.focalPoint;
        _panStartX = _xFraction;
        _panStartY = _yFraction;
        _scaleStartSize = _fontSize;
      },
      onScaleUpdate: (details) {
        final box = _videoAreaKey.currentContext?.findRenderObject()
            as RenderBox?;
        if (box == null) return;
        final delta = details.focalPoint - (_panStartFocal ?? details.focalPoint);
        setState(() {
          // 平移
          _xFraction = ((_panStartX ?? _xFraction) + delta.dx / box.size.width)
              .clamp(0.08, 0.92);
          _yFraction = ((_panStartY ?? _yFraction) + delta.dy / box.size.height)
              .clamp(0.06, 0.94);
          // 捏合縮放字體
          if (details.scale != 1.0 && _scaleStartSize != null) {
            _fontSize = (_scaleStartSize! * details.scale).clamp(24.0, 96.0);
          }
        });
      },
      child: ClipRRect(
        key: _videoAreaKey,
        borderRadius: BorderRadius.circular(10),
        child: AspectRatio(
          aspectRatio: ctrl.value.aspectRatio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 影片畫面
              VideoPlayer(ctrl),

              // 可互動的文字疊加預覽
              Align(
                alignment: Alignment(
                  _xFraction * 2 - 1,
                  _yFraction * 2 - 1,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _textCtrl.text.trim().isNotEmpty
                        ? _textCtrl.text.trim()
                        : '文字預覽',
                    style: TextStyle(
                      color: Color(_colorValue),
                      fontSize: _fontSize * 0.35, // 縮放至預覽適當大小
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              // 播放 / 暫停按鈕
              Positioned(
                bottom: 8,
                left: 8,
                child: GestureDetector(
                  onTap: _togglePreview,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      _previewPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),

              // 時間區間標示
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    '${_fmt(_startSec)} – ${_fmt(_endSec)}',
                    style: const TextStyle(
                        color: EditorTheme.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../providers/video_provider.dart';
import '../models/shooting_script.dart';

/// AI 拍攝教練 — 自定義相機頁面
///
/// ⚠️ 效能提醒：
/// - CameraController 非常耗電，務必在 dispose() 中釋放。
/// - 感測器監聽也需要在 dispose() 中取消，否則持續耗電。
/// - 離開此頁面時會自動觸發 dispose()，確保資源正確回收。
///
/// ⚠️ 平台限制：
/// - camera 套件目前只支援 iOS / Android。
/// - macOS 桌面版不支援，會顯示友善提示。
class CameraScreen extends StatefulWidget {
  final ShootingScript? script;

  const CameraScreen({super.key, this.script});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;
  bool _isRecording = false;
  bool _isFrontCamera = false;
  String? _errorMessage;

  // 錄製計時
  final Stopwatch _stopwatch = Stopwatch();
  Duration _recordDuration = Duration.zero;

  // ====== 腳本狀態機 ======
  int _currentStepIndex = 0;
  bool _showTeleprompter = true;

  // ====== 感測器（水平線 + 運鏡速度偵測） ======
  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;

  // 水平線：根據加速度計算傾斜角度（弧度）
  double _tiltAngle = 0.0; // 手機左右傾斜角度
  bool _isLevel = false;   // 是否接近水平

  // 運鏡速度偵測：根據陀螺儀旋轉速率
  double _rotationSpeed = 0.0; // 目前旋轉速率
  bool _isTooFast = false;     // 是否運鏡過快
  static const double _speedThreshold = 2.5; // 過快門檻（rad/s）
  static const double _levelThreshold = 0.05; // 水平門檻（弧度，約 3 度）

  bool get _isSupportedPlatform => Platform.isIOS || Platform.isAndroid;

  ScriptStep? get _currentStep {
    final script = widget.script;
    if (script == null) return null;
    if (_currentStepIndex >= script.steps.length) return null;
    return script.steps[_currentStepIndex];
  }

  bool get _isLastStep {
    final script = widget.script;
    if (script == null) return true;
    return _currentStepIndex >= script.steps.length - 1;
  }

  @override
  void initState() {
    super.initState();
    if (!_isSupportedPlatform) {
      _errorMessage = '相機功能僅支援 iOS / Android 手機\n請在手機上測試此功能';
      return;
    }
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
    _initSensors();
  }

  @override
  void dispose() {
    if (_isSupportedPlatform) {
      WidgetsBinding.instance.removeObserver(this);
      _cameraController?.dispose();
      _stopwatch.stop();
      // ⚠️ 重要：取消感測器監聽，避免持續耗電
      _accelSubscription?.cancel();
      _gyroSubscription?.cancel();
    }
    super.dispose();
  }

  /// 初始化感測器監聽
  void _initSensors() {
    // 加速度計 → 計算傾斜角度（用於水平線）
    _accelSubscription = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 100), // 每 100ms 取樣一次，省電
    ).listen((event) {
      if (!mounted) return;
      // 利用 x 軸與 y 軸的加速度計算左右傾斜角
      // 手機直立時 y ≈ 9.8, x ≈ 0
      final angle = math.atan2(event.x, event.y);
      setState(() {
        _tiltAngle = angle;
        _isLevel = angle.abs() < _levelThreshold;
      });
    });

    // 陀螺儀 → 偵測旋轉速率（用於運鏡速度警告）
    _gyroSubscription = gyroscopeEventStream(
      samplingPeriod: const Duration(milliseconds: 100),
    ).listen((event) {
      if (!mounted) return;
      // 計算三軸旋轉速率的總和
      final speed = math.sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      final wasTooFast = _isTooFast;
      setState(() {
        _rotationSpeed = speed;
        _isTooFast = speed > _speedThreshold;
      });

      // 剛變成「過快」時觸發震動提醒
      if (_isTooFast && !wasTooFast && _isRecording) {
        HapticFeedback.mediumImpact();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      controller.dispose();
      setState(() => _isInitialized = false);
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _errorMessage = '找不到相機裝置');
        return;
      }

      final camera = _isFrontCamera
          ? _cameras.firstWhere(
              (c) => c.lensDirection == CameraLensDirection.front,
              orElse: () => _cameras.first,
            )
          : _cameras.firstWhere(
              (c) => c.lensDirection == CameraLensDirection.back,
              orElse: () => _cameras.first,
            );

      _cameraController = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: true,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() => _errorMessage = '相機初始化失敗：$e');
    }
  }

  Future<void> _toggleCamera() async {
    if (_cameras.length < 2) return;
    setState(() {
      _isInitialized = false;
      _isFrontCamera = !_isFrontCamera;
    });
    await _cameraController?.dispose();
    await _initCamera();
  }

  Future<void> _toggleRecording() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    if (_isRecording) {
      final file = await controller.stopVideoRecording();
      _stopwatch.stop();
      setState(() {
        _isRecording = false;
        _recordDuration = Duration.zero;
      });

      if (!mounted) return;

      context.read<VideoProvider>().addVideo(file);

      if (widget.script != null && !_isLastStep) {
        setState(() => _currentStepIndex++);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('片段已儲存！進入下一站：${_currentStep?.title ?? ""}'),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.script != null
                ? '所有片段拍攝完成！可返回進行編輯'
                : '影片已儲存！可繼續拍攝或返回編輯'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      await controller.startVideoRecording();
      _stopwatch.reset();
      _stopwatch.start();
      setState(() => _isRecording = true);
      _updateTimer();
    }
  }

  void _updateTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (_isRecording && mounted) {
        setState(() => _recordDuration = _stopwatch.elapsed);
        _updateTimer();
      }
    });
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _buildCameraPreview(),
          if (_isSupportedPlatform) _buildTopBar(),
          if (_isSupportedPlatform && widget.script != null) _buildScriptGuideOverlay(),
          if (_isSupportedPlatform && widget.script != null && _showTeleprompter)
            _buildTeleprompter(),

          // ====== 水平線疊加層 ======
          if (_isSupportedPlatform && _isInitialized) _buildLevelIndicator(),

          // ====== 運鏡過快警告 ======
          if (_isSupportedPlatform && _isTooFast && _isRecording) _buildSpeedWarning(),

          if (_isSupportedPlatform) _buildBottomControls(),
        ],
      ),
    );
  }

  // ====================================================
  //  動態水平線 — 根據加速度計的傾斜角旋轉
  // ====================================================
  Widget _buildLevelIndicator() {
    // 水平時顯示綠色，傾斜時顯示白色/紅色
    final Color lineColor = _isLevel
        ? Colors.greenAccent
        : (_tiltAngle.abs() > 0.15 ? Colors.redAccent : Colors.white70);

    return Center(
      child: Transform.rotate(
        angle: _tiltAngle,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 水平線
            Container(
              width: 200,
              height: 2,
              color: lineColor,
            ),
            const SizedBox(height: 4),
            // 中心圓點
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: lineColor,
              ),
            ),
            // 水平狀態文字
            if (_isLevel)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withAlpha(60),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '水平',
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ====================================================
  //  運鏡過快警告 — 錄影中偵測到移動太快時顯示
  // ====================================================
  Widget _buildSpeedWarning() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.redAccent, width: 4),
          ),
          child: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 100),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.withAlpha(200),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.speed, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        '運鏡太快！請放慢速度',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isSupportedPlatform ? Icons.videocam_off : Icons.phone_iphone,
                size: 72,
                color: Colors.white54,
              ),
              const SizedBox(height: 20),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (_isSupportedPlatform)
                ElevatedButton(
                  onPressed: _initCamera,
                  child: const Text('重試'),
                )
              else
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('返回'),
                ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized || _cameraController == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text('正在啟動相機...', style: TextStyle(color: Colors.white70)),
          ],
        ),
      );
    }

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _cameraController!.value.previewSize?.height ?? 1,
          height: _cameraController!.value.previewSize?.width ?? 1,
          child: CameraPreview(_cameraController!),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            _buildCircleButton(
              icon: Icons.arrow_back,
              onTap: () {
                if (_isRecording) {
                  _showStopRecordingDialog();
                } else {
                  Navigator.pop(context);
                }
              },
            ),
            const Spacer(),
            if (_isRecording)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(200),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.fiber_manual_record, color: Colors.white, size: 12),
                    const SizedBox(width: 6),
                    Text(
                      _formatDuration(_recordDuration),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            const Spacer(),
            _buildCircleButton(
              icon: Icons.cameraswitch,
              onTap: _isRecording ? null : _toggleCamera,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScriptGuideOverlay() {
    final script = widget.script!;
    final step = _currentStep;
    if (step == null) return const SizedBox.shrink();

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 56, 16, 0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(160),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blueAccent.withAlpha(120)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '第 ${_currentStepIndex + 1} / ${script.steps.length} 站',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        step.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withAlpha(180),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${step.durationSecs} 秒',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  step.description,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: (_currentStepIndex + 1) / script.steps.length,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTeleprompter() {
    final step = _currentStep;
    if (step == null) return const SizedBox.shrink();

    return Positioned(
      left: 16,
      right: 16,
      bottom: 160,
      child: GestureDetector(
        onTap: () => setState(() => _showTeleprompter = !_showTeleprompter),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(140),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.amber, size: 16),
                  const SizedBox(width: 6),
                  const Text(
                    'AI 提詞機',
                    style: TextStyle(
                      color: Colors.amber,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    '點擊隱藏',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
              const Divider(color: Colors.white24, height: 16),
              Text(
                step.promptText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  height: 1.6,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _isRecording ? '點擊停止錄影' : '點擊開始錄影',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (widget.script != null)
                    _buildCircleButton(
                      icon: _showTeleprompter ? Icons.subtitles : Icons.subtitles_off,
                      onTap: () => setState(() => _showTeleprompter = !_showTeleprompter),
                    )
                  else
                    const SizedBox(width: 44),

                  GestureDetector(
                    onTap: _isInitialized ? _toggleRecording : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: _isRecording ? 30 : 64,
                          height: _isRecording ? 30 : 64,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(_isRecording ? 8 : 32),
                          ),
                        ),
                      ),
                    ),
                  ),

                  if (widget.script != null && !_isRecording && !_isLastStep)
                    _buildCircleButton(
                      icon: Icons.skip_next,
                      onTap: () => setState(() => _currentStepIndex++),
                    )
                  else
                    const SizedBox(width: 44),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(100),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: onTap != null ? Colors.white : Colors.white38,
          size: 24,
        ),
      ),
    );
  }

  void _showStopRecordingDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('正在錄影中'),
        content: const Text('要停止錄影並儲存嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('繼續錄影'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _toggleRecording();
              if (mounted) Navigator.pop(context);
            },
            child: const Text('停止並儲存', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

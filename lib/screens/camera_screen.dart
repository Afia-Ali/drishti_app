// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/app_settings.dart';
import '../services/bangla_tts.dart';
import '../services/inference_isolate.dart';
import '../services/journal_service.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  final InferenceService _inference = InferenceService();
  final JournalService _journal = JournalService();
  final AppSettings _settings = AppSettings();

  bool _isInitializing = true;
  bool _isDetecting = false;
  String _statusText = 'Initializing camera...';
  final String _backend = 'GPU';
  List<DetectionResult> _detections = [];
  int _lastInferenceMs = 0;

  Timer? _detectionTimer;
  static const Duration _cooldown = Duration(milliseconds: 1500);

  // ===== Dual TTS =====
  final FlutterTts _enTts = FlutterTts();
  final BanglaTTS _bnTts = BanglaTTS();
  Timer? _speakTimer;
  String _lastSpoken = '';
  String _lastSubtitle = '';
  static const Duration _speakInterval = Duration(seconds: 4);

  // Bangla class name mapping
  static const Map<String, String> _bnNames = {
    'bike': 'বাইক',
    'cng': 'সিএনজি',
    'leguna': 'লেগুনা',
    'rickshaw': 'রিকশা',
    'trucks': 'ট্রাক',
    'person': 'মানুষ',
    'car': 'গাড়ি',
    'bus': 'বাস',
    'chair': 'চেয়ার',
    'bed': 'বিছানা',
    'dining_table': 'টেবিল',
    'cup': 'কাপ',
    'bottle': 'বোতল',
    'laptop': 'ল্যাপটপ',
    'cell_phone': 'মোবাইল',
    'tv': 'টিভি',
    'book': 'বই',
    'backpack': 'ব্যাকপ্যাক',
    'handbag': 'ব্যাগ',
    'traffic_light': 'ট্রাফিক লাইট',
    'stop_sign': 'স্টপ সাইন',
  };

  late AnimationController _scanController;
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _settings.addListener(_onSettingsChanged);

    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _settings.removeListener(_onSettingsChanged);
    _detectionTimer?.cancel();
    _speakTimer?.cancel();
    _enTts.stop();
    _bnTts.dispose();
    _scanController.dispose();
    _fadeController.dispose();
    _cameraController?.dispose();
    _inference.dispose();
    _journal.endSession();
    super.dispose();
  }

  void _onSettingsChanged() {
    _enTts.setSpeechRate(_settings.voiceRate);
    _lastSpoken = '';
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _detectionTimer?.cancel();
      _speakTimer?.cancel();
      _enTts.stop();
      _bnTts.stop();
      _journal.endSession();
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _bootstrap();
    }
  }

  Future<void> _initEnTts() async {
    try {
      await _enTts.setLanguage('en-US');
      await _enTts.setSpeechRate(_settings.voiceRate);
      await _enTts.setVolume(1.0);
      await _enTts.setPitch(1.0);
      print('English TTS initialized at rate ${_settings.voiceRate}');
    } catch (e) {
      print('English TTS init error: $e');
    }
  }

  void _toggleLanguage() {
    final newLang = _settings.language == 'en' ? 'bn' : 'en';
    _settings.setLanguage(newLang);
    _enTts.stop();
    _bnTts.stop();
  }

  void _toggleMute() {
    _settings.setTtsEnabled(!_settings.ttsEnabled);
    if (!_settings.ttsEnabled) {
      _enTts.stop();
      _bnTts.stop();
    }
  }

  void _startSpeakLoop() {
    _speakTimer?.cancel();
    _speakTimer = Timer.periodic(_speakInterval, (_) => _speakCurrent());
  }

  Future<void> _speakCurrent() async {
    if (!_settings.ttsEnabled || !mounted) return;

    final text = _buildSpeechText(_detections);
    if (text == _lastSpoken) return;
    _lastSpoken = text;

    setState(() => _lastSubtitle = text);

    try {
      if (_settings.language == 'bn') {
        await _enTts.stop();
        await _bnTts.speak(text);
      } else {
        await _bnTts.stop();
        await _enTts.stop();
        await _enTts.setSpeechRate(_settings.voiceRate);
        await _enTts.speak(text);
      }
    } catch (e) {
      print('TTS speak error: $e');
    }
  }

  String _buildSpeechText(List<DetectionResult> detections) {
    if (detections.isEmpty) {
      return _settings.language == 'bn'
          ? 'কিছুই দেখা যাচ্ছে না'
          : 'Nothing detected';
    }

    final counts = <String, int>{};
    for (final d in detections) {
      counts[d.className] = (counts[d.className] ?? 0) + 1;
    }

    return _settings.language == 'bn'
        ? _buildBanglaSentence(counts)
        : _buildEnglishSentence(counts);
  }

  String _buildEnglishSentence(Map<String, int> counts) {
    final parts = <String>[];
    counts.forEach((name, count) {
      final label = name.replaceAll('_', ' ');
      if (count == 1) {
        final firstChar = label.isNotEmpty ? label[0].toLowerCase() : 'a';
        final isVowel = 'aeiou'.contains(firstChar);
        parts.add('${isVowel ? 'an' : 'a'} $label');
      } else {
        parts.add('${_numberWord(count)} ${label}s');
      }
    });

    if (parts.length == 1) return 'I see ${parts[0]}';
    if (parts.length == 2) return 'I see ${parts[0]} and ${parts[1]}';
    final last = parts.removeLast();
    return 'I see ${parts.join(', ')}, and $last';
  }

  String _buildBanglaSentence(Map<String, int> counts) {
    final parts = <String>[];
    counts.forEach((name, count) {
      final bnName = _bnNames[name] ?? name;
      if (count == 1) {
        parts.add('একটি $bnName');
      } else {
        parts.add('${_banglaNumber(count)} $bnName');
      }
    });

    if (parts.length == 1) return 'আমি ${parts[0]} দেখছি';
    if (parts.length == 2) return 'আমি ${parts[0]} এবং ${parts[1]} দেখছি';
    final last = parts.removeLast();
    return 'আমি ${parts.join(', ')} এবং $last দেখছি';
  }

  String _numberWord(int n) {
    const words = [
      'zero',
      'one',
      'two',
      'three',
      'four',
      'five',
      'six',
      'seven',
      'eight',
      'nine',
      'ten'
    ];
    return n < words.length ? words[n] : '$n';
  }

  String _banglaNumber(int n) {
    const words = [
      'শূন্য',
      'একটি',
      'দুটি',
      'তিনটি',
      'চারটি',
      'পাঁচটি',
      'ছয়টি',
      'সাতটি',
      'আটটি',
      'নয়টি',
      'দশটি'
    ];
    return n < words.length ? words[n] : '$n';
  }

  Future<void> _bootstrap() async {
    setState(() {
      _isInitializing = true;
      _statusText = 'Requesting permissions...';
    });

    final status = await Permission.camera.request();
    if (!status.isGranted) {
      setState(() {
        _isInitializing = false;
        _statusText = 'Camera permission denied';
      });
      return;
    }

    setState(() => _statusText = 'Loading AI model...');
    try {
      await _inference.initialize();
      print('Inference ready: ${_inference.labels.length} classes');
    } catch (e) {
      setState(() {
        _isInitializing = false;
        _statusText = 'Model load failed: $e';
      });
      return;
    }

    setState(() => _statusText = 'Loading voice...');
    await _initEnTts();

    setState(() => _statusText = 'Starting camera...');
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        setState(() {
          _isInitializing = false;
          _statusText = 'No camera found';
        });
        return;
      }

      final back = _cameras!.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras!.first,
      );

      _cameraController = CameraController(
        back,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();

      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _statusText = 'Detecting...';
      });

      _journal.startSession();
      _startDetectionLoop();
      _startSpeakLoop();
    } catch (e) {
      setState(() {
        _isInitializing = false;
        _statusText = 'Camera init failed: $e';
      });
    }
  }

  void _startDetectionLoop() {
    _detectionTimer?.cancel();
    _detectionTimer = Timer.periodic(_cooldown, (_) {
      if (!_isDetecting) _captureAndDetect();
    });
  }

  Future<void> _captureAndDetect() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    if (_isDetecting) return;

    _isDetecting = true;

    try {
      final picture = await controller.takePicture();
      final Uint8List bytes = await picture.readAsBytes();

      final response = await _inference.runInference(bytes);

      if (!mounted) return;
      setState(() {
        _detections = response.detections;
        _lastInferenceMs = response.inferenceTimeMs;
      });

      _fadeController.forward(from: 0);

      // Save detections to Firestore (with smart dedup, fire and forget)
      for (final d in response.detections) {
        _journal.saveDetection(
          className: d.className,
          confidence: d.confidence,
        );
      }
    } catch (e) {
      print('Detection error: $e');
    } finally {
      _isDetecting = false;
    }
  }

  Color _colorForClass(int classId) {
    final hue = (classId * 137.5) % 360;
    return HSVColor.fromAHSV(1.0, hue, 0.65, 0.95).toColor();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text(
          'Vision Assistant',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: TextButton(
              onPressed: _toggleLanguage,
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: Text(
                _settings.language == 'en' ? 'EN' : 'বাং',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: _toggleMute,
            icon: Icon(
              _settings.ttsEnabled ? Icons.volume_up : Icons.volume_off,
              color: _settings.ttsEnabled ? Colors.white : Colors.white54,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isInitializing ? _buildLoadingView() : _buildMainView(),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.white),
          const SizedBox(height: 24),
          Text(
            _statusText,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMainView() {
    return Column(
      children: [
        Expanded(
          flex: 5,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildCameraPreview(),
              AnimatedBuilder(
                animation: _scanController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _ScanLinePainter(progress: _scanController.value),
                  );
                },
              ),
              CustomPaint(
                painter: _BoxPainter(
                  detections: _detections,
                  colorForClass: _colorForClass,
                ),
              ),
              _buildBackendBadge(),
              if (_settings.ttsEnabled && _lastSubtitle.isNotEmpty)
                _buildSubtitleBar(),
            ],
          ),
        ),
        Expanded(
          flex: 4,
          child: _buildBottomPanel(),
        ),
      ],
    );
  }

  Widget _buildCameraPreview() {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return Center(
        child: Text(
          _statusText,
          style: const TextStyle(color: Colors.white),
        ),
      );
    }
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: controller.value.previewSize?.height ?? 1,
          height: controller.value.previewSize?.width ?? 1,
          child: CameraPreview(controller),
        ),
      ),
    );
  }

  Widget _buildBackendBadge() {
    return Positioned(
      top: 16,
      right: 16,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.45),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.15),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4ADE80),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _backend,
                      style: const TextStyle(
                        color: Color(0xFF4ADE80),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _lastInferenceMs > 0 ? '${_lastInferenceMs}ms' : '...',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubtitleBar() {
    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.55),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withOpacity(0.15),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.record_voice_over,
                  color: Color(0xFF60A5FA),
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _lastSubtitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomPanel() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1E40AF).withOpacity(0.85),
                const Color(0xFF2563EB).withOpacity(0.75),
              ],
            ),
            border: Border(
              top: BorderSide(
                color: Colors.white.withOpacity(0.18),
                width: 1,
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.visibility, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  const Text(
                    'Detected Objects',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.22),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.35),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      '${_detections.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Expanded(
                child: _detections.isEmpty
                    ? Center(
                        child: Text(
                          _statusText == 'Detecting...'
                              ? 'Looking around...'
                              : _statusText,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 15,
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        child: AnimatedBuilder(
                          animation: _fadeController,
                          builder: (context, _) {
                            return Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: _detections
                                  .asMap()
                                  .entries
                                  .map((entry) => _buildAnimatedPill(
                                        entry.value,
                                        entry.key,
                                      ))
                                  .toList(),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedPill(DetectionResult d, int index) {
    final start = (index * 0.08).clamp(0.0, 0.6);
    final end = (start + 0.4).clamp(0.0, 1.0);
    final t = CurvedAnimation(
      parent: _fadeController,
      curve: Interval(start, end, curve: Curves.easeOutBack),
    );

    return AnimatedBuilder(
      animation: t,
      builder: (context, _) {
        return Opacity(
          opacity: t.value.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: 0.7 + (t.value * 0.3),
            child: _buildPill(d),
          ),
        );
      },
    );
  }

  Widget _buildPill(DetectionResult d) {
    final color = _colorForClass(d.classId);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.35),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        '${d.className} ${(d.confidence * 100).toInt()}%',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ScanLinePainter extends CustomPainter {
  final double progress;

  _ScanLinePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress < 0.5 ? progress * 2 : (1 - progress) * 2;
    final y = t * size.height;

    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.transparent,
        const Color(0xFF60A5FA).withOpacity(0.0),
        const Color(0xFF60A5FA).withOpacity(0.65),
        Colors.white.withOpacity(0.85),
        const Color(0xFF60A5FA).withOpacity(0.65),
        const Color(0xFF60A5FA).withOpacity(0.0),
        Colors.transparent,
      ],
      stops: const [0.0, 0.35, 0.45, 0.5, 0.55, 0.65, 1.0],
    );

    final lineRect = Rect.fromLTWH(0, y - 40, size.width, 80);
    final paint = Paint()..shader = gradient.createShader(lineRect);
    canvas.drawRect(lineRect, paint);

    final sharp = Paint()
      ..color = Colors.white.withOpacity(0.55)
      ..strokeWidth = 1.2;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), sharp);
  }

  @override
  bool shouldRepaint(_ScanLinePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _BoxPainter extends CustomPainter {
  final List<DetectionResult> detections;
  final Color Function(int) colorForClass;

  _BoxPainter({
    required this.detections,
    required this.colorForClass,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final d in detections) {
      final color = colorForClass(d.classId);
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;

      final left = (d.x - d.w / 2) * size.width;
      final top = (d.y - d.h / 2) * size.height;
      final width = d.w * size.width;
      final height = d.h * size.height;

      final rect = Rect.fromLTWH(left, top, width, height);
      canvas.drawRect(rect, paint);

      final textPainter = TextPainter(
        text: TextSpan(
          text: '${d.className} ${(d.confidence * 100).toInt()}%',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      final labelBg = Rect.fromLTWH(
        left,
        top - textPainter.height - 4,
        textPainter.width + 8,
        textPainter.height + 4,
      );

      canvas.drawRect(labelBg, Paint()..color = color);
      textPainter.paint(canvas, Offset(left + 4, top - textPainter.height - 2));
    }
  }

  @override
  bool shouldRepaint(_BoxPainter oldDelegate) =>
      oldDelegate.detections != detections;
}

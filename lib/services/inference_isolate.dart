// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

// ============ Constants ============
const int kInputSize = 640;
const int kNumClasses = 21;
const double kConfThreshold = 0.25;
const double kIouThreshold = 0.45;
const String kModelPath = 'assets/models/drishti_unified.tflite';
const String kLabelsPath = 'assets/models/drishti_labels.txt';

// ============ Data Classes ============

class DetectionResult {
  final double x;
  final double y;
  final double w;
  final double h;
  final double confidence;
  final int classId;
  final String className;

  DetectionResult({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.confidence,
    required this.classId,
    required this.className,
  });

  Map<String, dynamic> toMap() => {
    'x': x,
    'y': y,
    'w': w,
    'h': h,
    'confidence': confidence,
    'classId': classId,
    'className': className,
  };

  factory DetectionResult.fromMap(Map m) => DetectionResult(
    x: (m['x'] as num).toDouble(),
    y: (m['y'] as num).toDouble(),
    w: (m['w'] as num).toDouble(),
    h: (m['h'] as num).toDouble(),
    confidence: (m['confidence'] as num).toDouble(),
    classId: m['classId'] as int,
    className: m['className'] as String,
  );
}

class InferenceResponse {
  final int requestId;
  final List<DetectionResult> detections;
  final int inferenceTimeMs;

  InferenceResponse({
    required this.requestId,
    required this.detections,
    required this.inferenceTimeMs,
  });
}

class _IsolateInitMessage {
  final SendPort mainSendPort;
  final Uint8List modelBytes;
  final List<String> labels;

  _IsolateInitMessage({
    required this.mainSendPort,
    required this.modelBytes,
    required this.labels,
  });
}

// ============ Service ============

class InferenceService {
  Isolate? _isolate;
  SendPort? _isolateSendPort;
  ReceivePort? _mainReceivePort;
  List<String> _labels = [];
  bool _initialized = false;
  int _requestCounter = 0;
  final Map<int, Completer<InferenceResponse>> _pendingRequests = {};

  bool get isInitialized => _initialized;
  List<String> get labels => List.unmodifiable(_labels);

  Future<void> initialize() async {
    if (_initialized) return;

    // Load labels in main thread
    final labelsRaw = await rootBundle.loadString(kLabelsPath);
    _labels = labelsRaw
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    print('Loaded ${_labels.length} labels');

    // Load model bytes in main thread
    final modelData = await rootBundle.load(kModelPath);
    final modelBytes = modelData.buffer.asUint8List();
    print('Loaded model: ${modelBytes.length} bytes');

    // Setup main receive port
    _mainReceivePort = ReceivePort();
    final readyCompleter = Completer<SendPort>();

    _mainReceivePort!.listen((message) {
      if (message is SendPort) {
        if (!readyCompleter.isCompleted) readyCompleter.complete(message);
      } else if (message is Map) {
        _handleResponse(Map<String, dynamic>.from(message));
      }
    });

    // Spawn isolate
    final initMsg = _IsolateInitMessage(
      mainSendPort: _mainReceivePort!.sendPort,
      modelBytes: modelBytes,
      labels: _labels,
    );
    _isolate = await Isolate.spawn(_isolateEntry, initMsg);

    // Wait for isolate ready
    _isolateSendPort = await readyCompleter.future;

    _initialized = true;
    print('Inference service initialized');
  }

  Future<InferenceResponse> runInference(Uint8List imageBytes) async {
    if (!_initialized || _isolateSendPort == null) {
      throw StateError('InferenceService not initialized');
    }
    final requestId = ++_requestCounter;
    final completer = Completer<InferenceResponse>();
    _pendingRequests[requestId] = completer;

    _isolateSendPort!.send({'imageBytes': imageBytes, 'requestId': requestId});

    return completer.future;
  }

  void _handleResponse(Map<String, dynamic> message) {
    final requestId = message['requestId'] as int;
    final completer = _pendingRequests.remove(requestId);
    if (completer == null) return;

    final detsRaw = message['detections'] as List;
    final detections = detsRaw
        .map((m) => DetectionResult.fromMap(m as Map))
        .toList();
    final inferenceTimeMs = message['inferenceTimeMs'] as int;

    completer.complete(
      InferenceResponse(
        requestId: requestId,
        detections: detections,
        inferenceTimeMs: inferenceTimeMs,
      ),
    );
  }

  Future<void> dispose() async {
    _isolate?.kill(priority: Isolate.immediate);
    _mainReceivePort?.close();
    _isolate = null;
    _mainReceivePort = null;
    _isolateSendPort = null;
    _initialized = false;
    _pendingRequests.clear();
  }

  // ============ Isolate Entry ============

  static void _isolateEntry(_IsolateInitMessage init) {
    final isolatePort = ReceivePort();
    init.mainSendPort.send(isolatePort.sendPort);

    Interpreter interpreter;
    try {
      interpreter = _createInterpreter(init.modelBytes);
    } catch (e) {
      print('Isolate failed to create interpreter: $e');
      return;
    }

    isolatePort.listen((message) {
      if (message is Map) {
        final m = Map<String, dynamic>.from(message);
        _processFrame(
          interpreter: interpreter,
          labels: init.labels,
          imageBytes: m['imageBytes'] as Uint8List,
          requestId: m['requestId'] as int,
          replyPort: init.mainSendPort,
        );
      }
    });
  }

  // ============ Interpreter Creation ============

  static Interpreter _createInterpreter(Uint8List modelBytes) {
    // Try GPU delegate first (Android Adreno/Mali, iOS Metal)
    try {
      final gpuDelegate = GpuDelegateV2(
        options: GpuDelegateOptionsV2(isPrecisionLossAllowed: true),
      );
      final options = InterpreterOptions()..addDelegate(gpuDelegate);
      final interpreter = Interpreter.fromBuffer(modelBytes, options: options);
      print('GPU delegate active');
      return interpreter;
    } catch (e) {
      print('GPU delegate failed: $e');
    }

    // Fallback: CPU 4 threads
    try {
      final options = InterpreterOptions()..threads = 4;
      final interpreter = Interpreter.fromBuffer(modelBytes, options: options);
      print('CPU 4-thread active');
      return interpreter;
    } catch (e) {
      print('CPU 4-thread failed: $e');
    }

    // Final fallback: default CPU
    final interpreter = Interpreter.fromBuffer(modelBytes);
    print('CPU default active');
    return interpreter;
  }

  // ============ Frame Processing ============

  static void _processFrame({
    required Interpreter interpreter,
    required List<String> labels,
    required Uint8List imageBytes,
    required int requestId,
    required SendPort replyPort,
  }) {
    final stopwatch = Stopwatch()..start();

    try {
      // Decode image (JPG/PNG)
      final decoded = img.decodeImage(imageBytes);
      if (decoded == null) {
        replyPort.send({
          'requestId': requestId,
          'detections': <Map<String, dynamic>>[],
          'inferenceTimeMs': stopwatch.elapsedMilliseconds,
        });
        return;
      }

      // Resize to 640x640
      final resized = img.copyResize(
        decoded,
        width: kInputSize,
        height: kInputSize,
      );

      // Build input tensor [1, 640, 640, 3]
      final input = _imageToFloat32(resized);

      // Build output tensor [1, 25, 8400]
      final outputShape = interpreter.getOutputTensor(0).shape;
      final output = List.generate(
        outputShape[0],
        (_) => List.generate(
          outputShape[1],
          (_) => List.filled(outputShape[2], 0.0),
        ),
      );

      // Run inference
      interpreter.run(input, output);

      // Parse + NMS
      final raw = _parseYoloOutput(output, labels);
      final filtered = _applyNMS(raw, kIouThreshold);

      stopwatch.stop();
      replyPort.send({
        'requestId': requestId,
        'detections': filtered.map((d) => d.toMap()).toList(),
        'inferenceTimeMs': stopwatch.elapsedMilliseconds,
      });
    } catch (e) {
      stopwatch.stop();
      print('Frame processing error: $e');
      replyPort.send({
        'requestId': requestId,
        'detections': <Map<String, dynamic>>[],
        'inferenceTimeMs': stopwatch.elapsedMilliseconds,
      });
    }
  }

  // ============ Image to Float32 Tensor ============

  static List _imageToFloat32(img.Image image) {
    return List.generate(
      1,
      (_) => List.generate(
        kInputSize,
        (y) => List.generate(kInputSize, (x) {
          final px = image.getPixel(x, y);
          return [px.r / 255.0, px.g / 255.0, px.b / 255.0];
        }),
      ),
    );
  }

  // ============ YOLO Output Parsing ============

  static List<DetectionResult> _parseYoloOutput(
    List output,
    List<String> labels,
  ) {
    final detections = <DetectionResult>[];
    final batch = output[0] as List;
    final numAnchors = (batch[0] as List).length;

    for (int i = 0; i < numAnchors; i++) {
      double maxScore = 0;
      int maxClassId = 0;

      for (int c = 0; c < kNumClasses; c++) {
        final score = ((batch[4 + c] as List)[i] as num).toDouble();
        if (score > maxScore) {
          maxScore = score;
          maxClassId = c;
        }
      }
      if (maxScore > 0.15) {
        print(
          'TOP-PRED: ${labels[maxClassId]} = ${(maxScore * 100).toStringAsFixed(1)}% (id=$maxClassId)',
        );
      }
      if (maxScore < kConfThreshold) continue;

      final cx = ((batch[0] as List)[i] as num).toDouble();
      final cy = ((batch[1] as List)[i] as num).toDouble();
      final w = ((batch[2] as List)[i] as num).toDouble();
      final h = ((batch[3] as List)[i] as num).toDouble();

      detections.add(
        DetectionResult(
          x: cx / kInputSize,
          y: cy / kInputSize,
          w: w / kInputSize,
          h: h / kInputSize,
          confidence: maxScore,
          classId: maxClassId,
          className: maxClassId < labels.length
              ? labels[maxClassId]
              : 'unknown',
        ),
      );
    }

    return detections;
  }

  // ============ Non-Max Suppression ============

  static List<DetectionResult> _applyNMS(
    List<DetectionResult> detections,
    double iouThreshold,
  ) {
    detections.sort((a, b) => b.confidence.compareTo(a.confidence));

    final keep = <DetectionResult>[];
    final suppressed = List<bool>.filled(detections.length, false);

    for (int i = 0; i < detections.length; i++) {
      if (suppressed[i]) continue;
      keep.add(detections[i]);

      for (int j = i + 1; j < detections.length; j++) {
        if (suppressed[j]) continue;
        if (detections[i].classId != detections[j].classId) continue;

        final iou = _calculateIoU(detections[i], detections[j]);
        if (iou > iouThreshold) suppressed[j] = true;
      }
    }

    return keep;
  }

  static double _calculateIoU(DetectionResult a, DetectionResult b) {
    final aLeft = a.x - a.w / 2;
    final aTop = a.y - a.h / 2;
    final aRight = a.x + a.w / 2;
    final aBottom = a.y + a.h / 2;

    final bLeft = b.x - b.w / 2;
    final bTop = b.y - b.h / 2;
    final bRight = b.x + b.w / 2;
    final bBottom = b.y + b.h / 2;

    final iLeft = math.max(aLeft, bLeft);
    final iTop = math.max(aTop, bTop);
    final iRight = math.min(aRight, bRight);
    final iBottom = math.min(aBottom, bBottom);

    if (iRight < iLeft || iBottom < iTop) return 0;

    final intersection = (iRight - iLeft) * (iBottom - iTop);
    final aArea = a.w * a.h;
    final bArea = b.w * b.h;
    final union = aArea + bArea - intersection;

    if (union <= 0) return 0;
    return intersection / union;
  }
}

import 'dart:math' as math;
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:path_provider/path_provider.dart';

/// Provides face detection using the Qualcomm Lightweight Face Detection ONNX model.
class FaceDetector {
  // Primary (package-qualified) asset path. Fallback will try the unqualified path.
  static const String _modelAssetPathPkg =
      'packages/local_face_detection/assets/face_model/face_model.onnx';
  static const String _modelAssetPathPlain =
      'assets/face_model/face_model.onnx';
  static const int _inputWidth = 640;
  static const int _inputHeight = 480;
  static const double _stride = 8.0;

  static final OnnxRuntime _runtime = OnnxRuntime();
  static OrtSession? _session;
  static String? _inputName;
  static List<String> _outputNames = [];

  static bool get isInitialized => _session != null;

  /// Loads the ONNX model into an [OrtSession]. Safe to call multiple times.
  static Future<void> initialize() async {
    if (_session != null) {
      return;
    }

    try {
      // Ensure assets exist and copy both model.onnx and model.data to a readable path.
      final modelPath = await _materializeModelFiles();

      final sessionOptions = OrtSessionOptions();
      _session = await _runtime.createSession(
        modelPath,
        options: sessionOptions,
      );

      if (_session == null) {
        throw StateError('Failed to create ONNX session for FaceValidator');
      }

      final inputNames = _session!.inputNames;
      if (inputNames.isEmpty) {
        throw StateError('Face detection model has no inputs');
      }
      _inputName = inputNames.first;
      _outputNames = _session!.outputNames;

      if (_outputNames.length < 3) {
        throw StateError(
          'Face detection model is expected to expose 3 outputs',
        );
      }

      print(
        'FaceValidator initialized. Input=$_inputName, Outputs=${_outputNames.join(', ')}',
      );
    } catch (e) {
      print('FaceValidator initialization failed: $e');
      rethrow;
    }
  }

  /// Copies ONNX and its external data file (if present) to an app-writable directory and
  /// returns the absolute path to the ONNX file.
  static Future<String> _materializeModelFiles() async {
    // Obtain the model bytes, attempting both qualified and plain paths.
    final onnxData = await _loadModelBytes();

    // Attempt to read external data (optional)
    // Try external data for both path variants.
    final String dataAssetPathPkg = _modelAssetPathPkg.replaceAll(
      '.onnx',
      '.data',
    );
    final String dataAssetPathPlain = _modelAssetPathPlain.replaceAll(
      '.onnx',
      '.data',
    );
    ByteData? externalData;
    try {
      externalData = await rootBundle.load(dataAssetPathPkg);
    } catch (_) {
      try {
        externalData = await rootBundle.load(dataAssetPathPlain);
      } catch (_) {
        externalData = null; // Not all models use external data
      }
    }

    final supportDir = await getApplicationSupportDirectory();
    final faceDir = Directory('${supportDir.path}/onnx/face');
    if (!await faceDir.exists()) {
      await faceDir.create(recursive: true);
    }

    final onnxFile = File('${faceDir.path}/face_model.onnx');
    await onnxFile.writeAsBytes(onnxData.buffer.asUint8List());

    if (externalData != null) {
      // ONNX runtime expects the external data file name to match what's referenced in the model.
      // The model references "model.data", so we must name the file accordingly.
      final dataFile = File('${faceDir.path}/model.data');
      await dataFile.writeAsBytes(externalData.buffer.asUint8List());
    }

    return onnxFile.path;
  }

  /// Attempt to load the model with diagnostics.
  static Future<ByteData> _loadModelBytes() async {
    try {
      return await rootBundle.load(_modelAssetPathPkg);
    } catch (ePkg) {
      // Fallback to plain path
      try {
        return await rootBundle.load(_modelAssetPathPlain);
      } catch (ePlain) {
        // Collect manifest keys for debugging.
        try {
          final manifestJson = await rootBundle.loadString(
            'AssetManifest.json',
          );
          // Keep log concise: show only face_model related entries.
          final relevant = manifestJson
              .split('"')
              .where((s) => s.contains('face_model'))
              .toSet()
              .join(', ');
          final msg =
              'FaceDetector: Unable to locate model. Tried:\n'
              '  $_modelAssetPathPkg\n'
              '  $_modelAssetPathPlain\n'
              'Underlying errors: package=$ePkg plain=$ePlain\n'
              'AssetManifest entries containing "face_model": $relevant';
          throw FlutterError(msg);
        } catch (manifestErr) {
          final msg =
              'FaceDetector: Model load failed (both paths). '
              'Package err=$ePkg plain err=$ePlain. Additionally failed to read '
              'AssetManifest: $manifestErr';
          throw FlutterError(msg);
        }
      }
    }
  }

  /// Disposes the underlying session. Call during app shutdown if desired.
  static Future<void> dispose() async {
    if (_session != null) {
      await _session!.close();
      _session = null;
      _inputName = null;
      _outputNames = [];
    }
  }

  /// Runs face detection on the provided [imageBytes].
  static Future<FaceDetectionResult> detectFaces(
    Uint8List imageBytes, {
    double scoreThreshold = 0.55,
    double nmsThreshold = -1,
  }) async {
    if (_session == null || _inputName == null) {
      throw StateError(
        'FaceValidator.initialize() must be called before detection',
      );
    }

    if (imageBytes.isEmpty) {
      return FaceDetectionResult.empty();
    }

    PreprocessedImage? preprocessed;
    OrtValue? inputTensor;
    Map<String, OrtValue> outputs = {};

    try {
      preprocessed = await _preprocess(imageBytes);

      inputTensor = await OrtValue.fromList(preprocessed.tensor, const [
        1,
        1,
        _inputHeight,
        _inputWidth,
      ]);

      outputs = await _session!.run({_inputName!: inputTensor});

      final heatmapValue = outputs[_outputNames[0]];
      final boxValue = outputs[_outputNames[1]];
      final landmarkValue = outputs[_outputNames[2]];

      if (heatmapValue == null || boxValue == null || landmarkValue == null) {
        throw StateError('Model output tensors are missing');
      }

      final heatmapData = Float32List.fromList(
        (await heatmapValue.asFlattenedList()).cast<double>(),
      );
      final boxData = Float32List.fromList(
        (await boxValue.asFlattenedList()).cast<double>(),
      );
      final landmarkData = Float32List.fromList(
        (await landmarkValue.asFlattenedList()).cast<double>(),
      );

      final heatmapShape = heatmapValue.shape;
      final hmHeight = heatmapShape[2];
      final hmWidth = heatmapShape[3];

      final candidates = _decodeDetections(
        heatmapData: heatmapData,
        boxData: boxData,
        landmarkData: landmarkData,
        hmHeight: hmHeight,
        hmWidth: hmWidth,
        scoreThreshold: scoreThreshold,
      );

      final filtered = _applyNmsIfNeeded(candidates, nmsThreshold);

      final faces = filtered
          .map((candidate) => candidate.toFaceDetection(preprocessed!))
          .whereType<FaceDetection>()
          .toList(growable: false);

      return FaceDetectionResult(
        detections: faces,
        originalWidth: preprocessed.originalWidth,
        originalHeight: preprocessed.originalHeight,
      );
    } catch (e) {
      print('Face detection failed: $e');
      return FaceDetectionResult.error();
    } finally {
      if (inputTensor != null) {
        await inputTensor.dispose();
      }
      await Future.wait(
        outputs.values.map((value) => value.dispose()),
        eagerError: false,
      );
    }
  }

  static Future<PreprocessedImage> _preprocess(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final original = frame.image;

    final originalWidth = original.width;
    final originalHeight = original.height;

    final scale = math.min(
      _inputWidth / originalWidth,
      _inputHeight / originalHeight,
    );

    final scaledWidth = (originalWidth * scale).round().clamp(1, _inputWidth);
    final scaledHeight = (originalHeight * scale).round().clamp(
      1,
      _inputHeight,
    );
    final padX = (_inputWidth - scaledWidth) / 2.0;
    final padY = (_inputHeight - scaledHeight) / 2.0;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, _inputWidth.toDouble(), _inputHeight.toDouble()),
      ui.Paint()..color = const ui.Color(0xFF000000),
    );

    final srcRect = ui.Rect.fromLTWH(
      0,
      0,
      originalWidth.toDouble(),
      originalHeight.toDouble(),
    );
    final dstRect = ui.Rect.fromLTWH(
      padX,
      padY,
      scaledWidth.toDouble(),
      scaledHeight.toDouble(),
    );
    canvas.drawImageRect(original, srcRect, dstRect, ui.Paint());

    final picture = recorder.endRecording();
    final resized = await picture.toImage(_inputWidth, _inputHeight);
    final byteData = await resized.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );

    final rgba = byteData!.buffer.asUint8List();
    final Float32List tensor = Float32List(_inputWidth * _inputHeight);
    for (int i = 0, j = 0; i < tensor.length; i++, j += 4) {
      final r = rgba[j];
      final g = rgba[j + 1];
      final b = rgba[j + 2];
      final gray = 0.299 * r + 0.587 * g + 0.114 * b;
      tensor[i] = gray / 255.0;
    }

    codec.dispose();
    frame.image.dispose();
    resized.dispose();
    picture.dispose();

    return PreprocessedImage(
      tensor: tensor,
      originalWidth: originalWidth,
      originalHeight: originalHeight,
      scale: scale,
      padX: padX,
      padY: padY,
    );
  }

  static List<_FaceCandidate> _decodeDetections({
    required Float32List heatmapData,
    required Float32List boxData,
    required Float32List landmarkData,
    required int hmHeight,
    required int hmWidth,
    required double scoreThreshold,
  }) {
    final List<_FaceCandidate> candidates = [];

    final spatialSize = hmHeight * hmWidth;
    for (int y = 0; y < hmHeight; y++) {
      for (int x = 0; x < hmWidth; x++) {
        final index = y * hmWidth + x;
        final score = heatmapData[index];

        if (score < scoreThreshold) {
          continue;
        }

        final leftOffset = boxData[index];
        final topOffset = boxData[spatialSize + index];
        final rightOffset = boxData[2 * spatialSize + index];
        final bottomOffset = boxData[3 * spatialSize + index];

        var left = (x - leftOffset) * _stride;
        var top = (y - topOffset) * _stride;
        var right = (x + rightOffset) * _stride;
        var bottom = (y + bottomOffset) * _stride;

        left = left.clamp(0.0, _inputWidth - 1.0);
        top = top.clamp(0.0, _inputHeight - 1.0);
        right = right.clamp(0.0, _inputWidth - 1.0);
        bottom = bottom.clamp(0.0, _inputHeight - 1.0);

        final width = math.max(1.0, right - left);
        final height = math.max(1.0, bottom - top);

        final growX = width * 0.05;
        final growY = height * 0.05;
        left = (left - growX).clamp(0.0, _inputWidth - 1.0);
        top = (top - growY).clamp(0.0, _inputHeight - 1.0);
        right = (right + growX).clamp(0.0, _inputWidth - 1.0);
        bottom = (bottom + growY).clamp(0.0, _inputHeight - 1.0);

        final landmarks = <ui.Offset>[];
        for (int k = 0; k < 5; k++) {
          final landmarkX =
              (landmarkData[k * spatialSize + index] + x) * _stride;
          final landmarkY =
              (landmarkData[(k + 5) * spatialSize + index] + y) * _stride;
          landmarks.add(ui.Offset(landmarkX, landmarkY));
        }

        candidates.add(
          _FaceCandidate(
            score: score,
            rect: ui.Rect.fromLTRB(left, top, right, bottom),
            landmarks: landmarks,
          ),
        );
      }
    }

    candidates.sort((a, b) => b.score.compareTo(a.score));
    return candidates;
  }

  static List<_FaceCandidate> _applyNmsIfNeeded(
    List<_FaceCandidate> candidates,
    double nmsThreshold,
  ) {
    if (nmsThreshold <= 0) {
      return candidates;
    }

    final List<_FaceCandidate> kept = [];
    final List<bool> suppressed = List<bool>.filled(candidates.length, false);

    for (int i = 0; i < candidates.length; i++) {
      if (suppressed[i]) {
        continue;
      }
      final current = candidates[i];
      kept.add(current);

      for (int j = i + 1; j < candidates.length; j++) {
        if (suppressed[j]) {
          continue;
        }

        final iou = _computeIoU(current.rect, candidates[j].rect);
        if (iou > nmsThreshold) {
          suppressed[j] = true;
        }
      }
    }

    return kept;
  }

  static double _computeIoU(ui.Rect a, ui.Rect b) {
    final intersect = a.intersect(b);
    if (intersect.isEmpty) {
      return 0;
    }

    final intersectArea = intersect.width * intersect.height;
    final areaA = a.width * a.height;
    final areaB = b.width * b.height;
    final union = areaA + areaB - intersectArea;
    if (union <= 0) {
      return 0;
    }
    return intersectArea / union;
  }
}

class PreprocessedImage {
  PreprocessedImage({
    required this.tensor,
    required this.originalWidth,
    required this.originalHeight,
    required this.scale,
    required this.padX,
    required this.padY,
  });

  final Float32List tensor;
  final int originalWidth;
  final int originalHeight;
  final double scale;
  final double padX;
  final double padY;
}

class _FaceCandidate {
  _FaceCandidate({
    required this.score,
    required this.rect,
    required this.landmarks,
  });

  final double score;
  final ui.Rect rect;
  final List<ui.Offset> landmarks;

  FaceDetection toFaceDetection(PreprocessedImage preprocessed) {
    final mappedRect = _mapRect(rect, preprocessed);
    if (mappedRect == null) {
      return FaceDetection.empty();
    }

    final mappedLandmarks = landmarks
        .map((point) => _mapPoint(point, preprocessed))
        .whereType<ui.Offset>()
        .toList(growable: false);

    return FaceDetection(
      boundingBox: mappedRect,
      score: score,
      landmarks: mappedLandmarks,
    );
  }

  ui.Rect? _mapRect(ui.Rect rect, PreprocessedImage preprocessed) {
    final left = _mapCoordinate(
      rect.left,
      preprocessed.padX,
      preprocessed.scale,
      preprocessed.originalWidth,
    );
    final top = _mapCoordinate(
      rect.top,
      preprocessed.padY,
      preprocessed.scale,
      preprocessed.originalHeight,
    );
    final right = _mapCoordinate(
      rect.right,
      preprocessed.padX,
      preprocessed.scale,
      preprocessed.originalWidth,
    );
    final bottom = _mapCoordinate(
      rect.bottom,
      preprocessed.padY,
      preprocessed.scale,
      preprocessed.originalHeight,
    );

    if (left >= right || top >= bottom) {
      return null;
    }

    return ui.Rect.fromLTRB(left, top, right, bottom);
  }

  ui.Offset? _mapPoint(ui.Offset point, PreprocessedImage preprocessed) {
    final mappedX = _mapCoordinate(
      point.dx,
      preprocessed.padX,
      preprocessed.scale,
      preprocessed.originalWidth,
    );
    final mappedY = _mapCoordinate(
      point.dy,
      preprocessed.padY,
      preprocessed.scale,
      preprocessed.originalHeight,
    );

    if (mappedX.isNaN || mappedY.isNaN) {
      return null;
    }

    return ui.Offset(mappedX, mappedY);
  }

  double _mapCoordinate(double value, double pad, double scale, int limit) {
    final mapped = (value - pad) / scale;
    return mapped.clamp(0.0, limit.toDouble());
  }
}

class FaceDetection {
  FaceDetection({
    required this.boundingBox,
    required this.score,
    this.landmarks = const [],
  }) : hasError = false;

  FaceDetection.empty()
    : boundingBox = ui.Rect.zero,
      score = 0,
      landmarks = const [],
      hasError = true;

  final ui.Rect boundingBox;
  final double score;
  final List<ui.Offset> landmarks;
  final bool hasError;

  bool get isValid => !hasError && boundingBox != ui.Rect.zero;
}

class FaceDetectionResult {
  FaceDetectionResult({
    required this.detections,
    required this.originalWidth,
    required this.originalHeight,
    this.hasError = false,
  });

  FaceDetectionResult.error()
    : detections = const [],
      originalWidth = 0,
      originalHeight = 0,
      hasError = true;

  FaceDetectionResult.empty()
    : detections = const [],
      originalWidth = 0,
      originalHeight = 0,
      hasError = false;

  final List<FaceDetection> detections;
  final int originalWidth;
  final int originalHeight;
  final bool hasError;

  bool get hasFaces => detections.isNotEmpty;
}

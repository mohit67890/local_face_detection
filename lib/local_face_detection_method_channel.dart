import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'services/FaceValidator.dart';
import 'local_face_detection_platform_interface.dart';

/// An implementation of [LocalFaceDetectionPlatform] that uses method channels.
class MethodChannelLocalFaceDetection extends LocalFaceDetectionPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('local_face_detection');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }

  @override
  Future<void> initializeFaceDetection() async {
    await FaceDetector.initialize();
  }

  @override
  Future<FaceDetectionResult> detectFaces(
    Uint8List imageBytes, {
    double scoreThreshold = 0.55,
    double nmsThreshold = -1,
  }) async {
    return FaceDetector.detectFaces(
      imageBytes,
      scoreThreshold: scoreThreshold,
      nmsThreshold: nmsThreshold,
    );
  }

  @override
  Future<void> disposeFaceDetection() async {
    await FaceDetector.dispose();
  }
}

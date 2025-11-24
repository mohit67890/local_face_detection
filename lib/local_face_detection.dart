import 'dart:typed_data';

import 'local_face_detection_platform_interface.dart';

// Re-export detection result/data classes for convenient public API consumption.
export 'local_face_detection_platform_interface.dart'
    show FaceDetection, FaceDetectionResult;

class LocalFaceDetection {
  Future<String?> getPlatformVersion() {
    return LocalFaceDetectionPlatform.instance.getPlatformVersion();
  }

  Future<void> initialize() {
    return LocalFaceDetectionPlatform.instance.initializeFaceDetection();
  }

  Future<FaceDetectionResult> detectFaces(
    Uint8List imageBytes, {
    double scoreThreshold = 0.55,
    double nmsThreshold = -1,
  }) {
    return LocalFaceDetectionPlatform.instance.detectFaces(
      imageBytes,
      scoreThreshold: scoreThreshold,
      nmsThreshold: nmsThreshold,
    );
  }

  Future<void> dispose() {
    return LocalFaceDetectionPlatform.instance.disposeFaceDetection();
  }
}

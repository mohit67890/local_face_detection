import 'dart:typed_data';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'services/FaceValidator.dart';
import 'local_face_detection_method_channel.dart';

// Re-export result/data classes for package consumers.
export 'services/FaceValidator.dart' show FaceDetection, FaceDetectionResult;

abstract class LocalFaceDetectionPlatform extends PlatformInterface {
  /// Constructs a LocalFaceDetectionPlatform.
  LocalFaceDetectionPlatform() : super(token: _token);

  static final Object _token = Object();

  static LocalFaceDetectionPlatform _instance =
      MethodChannelLocalFaceDetection();

  /// The default instance of [LocalFaceDetectionPlatform] to use.
  ///
  /// Defaults to [MethodChannelLocalFaceDetection].
  static LocalFaceDetectionPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [LocalFaceDetectionPlatform] when
  /// they register themselves.
  static set instance(LocalFaceDetectionPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  /// Initialize the underlying face detection model/session.
  Future<void> initializeFaceDetection() {
    throw UnimplementedError(
      'initializeFaceDetection() has not been implemented.',
    );
  }

  /// Run face detection against raw image bytes (e.g. PNG/JPEG encoded).
  /// Returns a [FaceDetectionResult] describing any faces found.
  Future<FaceDetectionResult> detectFaces(
    Uint8List imageBytes, {
    double scoreThreshold = 0.55,
    double nmsThreshold = -1,
  }) {
    throw UnimplementedError('detectFaces() has not been implemented.');
  }

  /// Dispose any resources associated with face detection.
  Future<void> disposeFaceDetection() {
    throw UnimplementedError(
      'disposeFaceDetection() has not been implemented.',
    );
  }
}

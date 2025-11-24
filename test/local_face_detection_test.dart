import 'package:flutter_test/flutter_test.dart';
import 'package:local_face_detection/local_face_detection.dart';
import 'package:local_face_detection/local_face_detection_platform_interface.dart';
import 'package:local_face_detection/local_face_detection_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockLocalFaceDetectionPlatform
    with MockPlatformInterfaceMixin
    implements LocalFaceDetectionPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final LocalFaceDetectionPlatform initialPlatform = LocalFaceDetectionPlatform.instance;

  test('$MethodChannelLocalFaceDetection is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelLocalFaceDetection>());
  });

  test('getPlatformVersion', () async {
    LocalFaceDetection localFaceDetectionPlugin = LocalFaceDetection();
    MockLocalFaceDetectionPlatform fakePlatform = MockLocalFaceDetectionPlatform();
    LocalFaceDetectionPlatform.instance = fakePlatform;

    expect(await localFaceDetectionPlugin.getPlatformVersion(), '42');
  });
}

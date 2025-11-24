import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:local_face_detection/local_face_detection.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _plugin = LocalFaceDetection();
  String _platformVersion = 'Unknown';
  bool _initializing = false;
  bool _detecting = false;
  Uint8List? _imageBytes;
  FaceDetectionResult? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    setState(() => _initializing = true);
    try {
      final version =
          await _plugin.getPlatformVersion() ?? 'Unknown platform version';
      await _plugin.initialize();
      if (!mounted) return;
      setState(() {
        _platformVersion = version;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Init failed: $e');
    } finally {
      if (mounted) setState(() => _initializing = false);
    }
  }

  Future<void> _pickImage() async {
    setState(() => _error = null);
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _result = null;
      });
      await _runDetection(bytes);
    } catch (e) {
      setState(() => _error = 'Image pick failed: $e');
    }
  }

  Future<void> _runDetection(Uint8List bytes) async {
    setState(() => _detecting = true);
    try {
      final res = await _plugin.detectFaces(
        bytes,
        scoreThreshold: 0.55,
        nmsThreshold: 0.4,
      );
      if (!mounted) return;
      setState(() => _result = res);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Detection failed: $e');
    } finally {
      if (mounted) setState(() => _detecting = false);
    }
  }

  @override
  void dispose() {
    _plugin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imageBytes = _imageBytes;
    final result = _result;
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Local Face Detection Demo')),
        body: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Platform: $_platformVersion'),
              if (_initializing) const LinearProgressIndicator(),
              const SizedBox(height: 8),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _initializing ? null : initPlatformState,
                    icon: const Icon(Icons.play_circle_fill),
                    label: const Text('Initialize'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed:
                        (_initializing || _detecting) ? null : _pickImage,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Pick Image'),
                  ),
                ],
              ),
              if (_detecting)
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: LinearProgressIndicator(),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              const SizedBox(height: 12),
              Expanded(
                child: Center(
                  child:
                      imageBytes == null
                          ? const Text('Select an image to run detection.')
                          : AspectRatio(
                            aspectRatio: _computeAspectRatio(result) ?? 1,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.memory(imageBytes, fit: BoxFit.contain),
                                if (result != null && result.hasFaces)
                                  CustomPaint(
                                    painter: _FaceOverlayPainter(result),
                                  ),
                              ],
                            ),
                          ),
                ),
              ),
              if (result != null) Text('Faces: ${result.detections.length}'),
            ],
          ),
        ),
      ),
    );
  }

  double? _computeAspectRatio(FaceDetectionResult? res) {
    if (res == null || res.originalWidth == 0 || res.originalHeight == 0)
      return null;
    return res.originalWidth / res.originalHeight;
  }
}

class _FaceOverlayPainter extends CustomPainter {
  _FaceOverlayPainter(this.result);
  final FaceDetectionResult result;

  @override
  void paint(Canvas canvas, Size size) {
    if (!result.hasFaces) return;
    final scaleX = size.width / result.originalWidth;
    final scaleY = size.height / result.originalHeight;

    final boxPaint =
        Paint()
          ..color = Colors.greenAccent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
    final landmarkPaint =
        Paint()
          ..color = Colors.yellowAccent
          ..style = PaintingStyle.fill;

    for (final face in result.detections) {
      final rect = Rect.fromLTRB(
        face.boundingBox.left * scaleX,
        face.boundingBox.top * scaleY,
        face.boundingBox.right * scaleX,
        face.boundingBox.bottom * scaleY,
      );
      canvas.drawRect(rect, boxPaint);
      for (final lm in face.landmarks) {
        canvas.drawCircle(
          Offset(lm.dx * scaleX, lm.dy * scaleY),
          3,
          landmarkPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FaceOverlayPainter oldDelegate) =>
      oldDelegate.result != result;
}

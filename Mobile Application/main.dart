import 'dart:async';
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart'; // For compute
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:just_audio/just_audio.dart';
import 'package:image/image.dart' as img; // For image processing
import 'package:flutter/services.dart'; //
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'dart:math' as math;



late List<CameraDescription> cameras;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final data = await rootBundle.load('assets/finalModel_dyn2.tflite');
    print("✅ Model file loaded: ${data.lengthInBytes} bytes");
  } catch (e) {
    print("❌ Asset loading failed: $e");
  }
  cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Drowsiness Detection',
      theme: ThemeData(primarySwatch: Colors.green),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Clean white background
      appBar: AppBar(
        title: const Text('Drowsiness Detection',style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            SizedBox(
              height: 320,
              child: Image.asset('assets/logo.png'), // Make sure you have a logo image
            ),
            const SizedBox(height: 32),

            // Title Text
            const Text(
              'Drive Safe',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,

              ),
            ),
            const SizedBox(height: 10),

            // Subtitle Text
            const Text(
              'Your safety is our priority.\nStay awake, stay alive.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 40),

            // Start Button
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DetectionScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.videocam,color: Colors.white,),
                label: const Text(
                  'Start Detection',
                  style: TextStyle(fontSize: 20,color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0, // Set to 0 for Home, or 1 for Profile
        onTap: (index) {
          // Placeholder for navigation logic
          print('Tapped item $index');
        },
        backgroundColor: Colors.white,
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),

    );
  }
}


class DetectionScreen extends StatefulWidget {
  const DetectionScreen({super.key});

  @override
  State<DetectionScreen> createState() => _DetectionScreenState();
}

class _DetectionScreenState extends State<DetectionScreen> {
  CameraController? _cameraController;
  FaceDetector? _faceDetector;
  Interpreter? _interpreter;
  AudioPlayer? _audioPlayer;
  bool _isDetecting = false;
  int _frameCount = 0; // <-- frame counter
  String _eyeStatus = 'Unknown';
  final List<int> _eyeStatusHistory = [];
  int _score = 0;
  final int _scoreThreshold = 5;
  final int _historyLength = 3;


  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      print("🔄 Initializing camera...");
      final frontCamera = cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.front,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      print("✅ Camera initialized");

      // Initialize face detector
      final options = FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        enableLandmarks: true,
        enableContours: true,
        enableClassification: true,
      );

      _faceDetector = FaceDetector(options: options);
      print("✅ Face detector initialized");

      // Load TFLite model
      _interpreter = await Interpreter.fromAsset('assets/finalModel_dyn2.tflite');
      print("✅ TFLite model loaded");

      // Load audio
      _audioPlayer = AudioPlayer();
      await _audioPlayer!.setAsset('assets/alarm.wav');
      _audioPlayer!.setLoopMode(LoopMode.one);
      print("✅ Audio player ready");

      // Start camera stream
      await _cameraController!.startImageStream(_processCameraImage);
      print("✅ Camera stream started");

      setState(() {}); // 🔄 Make sure UI updates

    } catch (e) {
      print("❌ Initialization error: $e");
    }
  }

//correct

//   Future<void> _processCameraImage(CameraImage image) async {
//     if (_isDetecting) return;
//     _isDetecting = true;
//
//     try {
//       // 1) Build an InputImage for ML Kit (ML Kit will rotate internally)
//       final allBytes = WriteBuffer();
//       for (final plane in image.planes) {
//         allBytes.putUint8List(plane.bytes);
//       }
//       final bytes = allBytes.done().buffer.asUint8List();
//
//       final inputImage = InputImage.fromBytes(
//         bytes: bytes,
//         metadata: InputImageMetadata(
//           size: Size(image.width.toDouble(), image.height.toDouble()),
//           rotation: InputImageRotationValue.fromRawValue(
//             _cameraController!.description.sensorOrientation,
//           ) ??
//               InputImageRotation.rotation0deg,
//           format: InputImageFormat.nv21,
//           bytesPerRow: image.planes[0].bytesPerRow,
//         ),
//       );
//
//       // 2) Detect faces
//       final faces = await _faceDetector!.processImage(inputImage);
//       if (faces.isEmpty) {
//         _isDetecting = false;
//         return;
//       }
//       final face = faces.first;
//       final leftLM  = face.landmarks[FaceLandmarkType.leftEye];
//       final rightLM = face.landmarks[FaceLandmarkType.rightEye];
//       if (leftLM == null || rightLM == null) {
//         _isDetecting = false;
//         return;
//       }
//
//       // 3) Only run every 5 frames
//       _frameCount++;
//       bool playedThisFrame = false;
//       if (_frameCount % 2 == 0) {
//         // Pass BOTH eyes to the cropper so it can compute eyeWidth
//         final leftClosed = await _predictEyeClosed(
//           image,
//           Point(leftLM.position.x.toInt(), leftLM.position.y.toInt()),
//           Point(rightLM.position.x.toInt(), rightLM.position.y.toInt()),
//         );
//         final rightClosed = await _predictEyeClosed(
//           image,
//           Point(rightLM.position.x.toInt(), rightLM.position.y.toInt()),
//           Point(leftLM.position.x.toInt(), leftLM.position.y.toInt()),
//         );
//         final bothClosed = leftClosed && rightClosed;
//
//         if (bothClosed) {
//           _closedEyesCounter++;
//         } else {
//           _closedEyesCounter = 0;
//         }
//         if (_closedEyesCounter >= _threshold) {
//           if (!_audioPlayer!.playing) {
//             print('🔔 Threshold reached, playing alarm');
//             _audioPlayer!.play();
//           }
//           playedThisFrame = true;
//         }
//
//       }
//       // regardless of whether it was a “5th frame” or not,
// // if for any reason the alarm is still playing but our counter has fallen below threshold, stop it
//       if (_audioPlayer!.playing && _closedEyesCounter < _threshold) {
//         print('🔇 Eyes opened or counter below threshold, stopping alarm');
//         _audioPlayer!.stop();
//       }
//     } catch (e) {
//       debugPrint('❌ Error in _processCameraImage: $e');
//     } finally {
//       _isDetecting = false;
//     }
//   }



//   Future<bool> _predictEyeClosed(CameraImage image, Point<int> eyePos, Point<int> otherEyePos,) async {
//     // 1) Turn YUV → RGB
//     img.Image frame = _convertYUV420toImageColor(image);
//
//     // 2) Rotate by sensorOrientation (ML Kit did the same internally)
//     final ori = _cameraController!.description.sensorOrientation;
//     if (ori != 0) {
//       frame = img.copyRotate(frame, angle: ori);
//     }
//
//     // 3) Mirror if front‐camera
//     if (_cameraController!.description.lensDirection ==
//         CameraLensDirection.front) {
//       frame = img.flipHorizontal(frame);
//     }
//
//     // 4) Compute horizontal eyeWidth (just as in Python)
//     final eyeWidth = (eyePos.x - otherEyePos.x).abs();
//     final half     = eyeWidth ~/ 2;
//
//     // 5) Center a square of side=eyeWidth on (eyePos.x, eyePos.y)
//     int x1 = eyePos.x - half;
//     int y1 = eyePos.y - half;
//     // clamp to [0..width-eyeWidth] / [0..height-eyeWidth]
//     x1 = x1.clamp(0, frame.width  - eyeWidth);
//     y1 = y1.clamp(0, frame.height - eyeWidth);
//
//     // 6) Crop & resize exactly as your Python code did
//     img.Image crop = img.copyCrop(
//       frame,
//       x:      x1,
//       y:      y1,
//       width:  eyeWidth,
//       height: eyeWidth,
//     );
//     const int S = 64;
//     img.Image resized = img.copyResize(crop, width: S, height: S);
//     // 1) Encode PNG
//     final pngBytes = img.encodePng(resized);
//
// // 2) Get a writable directory
//
//     final dir = await getExternalStorageDirectory();
//     if (dir == null) {
//       print("❌ Failed to get external storage directory");
//       return false;
//     }
//
// // 3) Choose a filename
//     final file = File('${dir.path}/Eye_crop_${DateTime.now().millisecondsSinceEpoch}.png');
//
// // 4) Write the bytes
//     await file.writeAsBytes(pngBytes);
//
// // 5) Log or notify
//     print('✅ Eye crop saved to ${file.path}');
//
//
//     // 7) Normalize into the input buffer
//     final input = Float32List(S * S * 3);
//     int idx = 0;
//     for (int yy = 0; yy < S; yy++) {
//       for (int xx = 0; xx < S; xx++) {
//         final p = resized.getPixel(xx, yy);
//         input[idx++] = p.r / 255.0;
//         input[idx++] = p.g / 255.0;
//         input[idx++] = p.b / 255.0;
//       }
//     }
//
//     // 8) Run inference
//     final output = List.generate(1, (_) => List.filled(2, 0.0));
//     _interpreter!.run(input.reshape([1, S, S, 3]), output);
//
//     final openProb   = output[0][1];
//     final closedProb = output[0][0];
//     print("👁️ Crop@($x1,$y1,$eyeWidth): Open=$openProb Closed=$closedProb");
//
//     return closedProb > openProb;
//   }
//   Point<double> _rotatePoint(
//       Point<double> p,
//       Point<double> center,
//       double angleDegrees,
//       ) {
//     final rad = angleDegrees * math.pi / 180;
//     final dx = p.x - center.x;
//     final dy = p.y - center.y;
//     final xNew = dx * math.cos(rad) - dy * math.sin(rad) + center.x;
//     final yNew = dx * math.sin(rad) + dy * math.cos(rad) + center.y;
//     return Point(xNew, yNew);
//   }
//
//   Future<bool> _predictEyeClosed(
//       CameraImage image,
//       Point<int> eyePos,
//       Point<int> otherEyePos,
//       ) async {
//     // 1) YUV → RGB
//     img.Image frame = _convertYUV420toImageColor(image);
//
//     // 2) Rotate by sensorOrientation (ML Kit uses the same internally)
//     final ori = _cameraController!.description.sensorOrientation;
//     if (ori != 0) {
//       frame = img.copyRotate(frame, angle: ori);
//     }
//
//     // 3) Mirror for front camera
//     final isFront = _cameraController!.description.lensDirection ==
//         CameraLensDirection.front;
//     if (isFront) {
//       frame = img.flipHorizontal(frame);
//     }
//
//     // 4) Transform landmarks through those same ops:
//     Point<double> p1 = Point(eyePos.x.toDouble(), eyePos.y.toDouble());
//     Point<double> p2 =
//     Point(otherEyePos.x.toDouble(), otherEyePos.y.toDouble());
//     // mirror
//     if (isFront) {
//       p1 = Point(frame.width - p1.x, p1.y);
//       p2 = Point(frame.width - p2.x, p2.y);
//     }
//     // (No need to rotate p1/p2 for ori: ML Kit already gave you coords in the rotated frame)
//
//     // 5) Compute true 2D distance & angle between eyes
//     final dx = p2.x - p1.x;
//     final dy = p2.y - p1.y;
//     final eyeDist  = math.sqrt(dx * dx + dy * dy);
//     final eyeWidth = eyeDist.toInt();
//     final half     = eyeWidth / 2;
//     var angleDeg = math.atan2(dy, dx) * 180 / math.pi;
//
//     if (angleDeg >  90) angleDeg -= 180;
//     if (angleDeg < -90) angleDeg += 180;
//
//     // 6) Rotate frame by –angleDeg to make the eye-line horizontal
//     frame = img.copyRotate(frame, angle: -angleDeg);
//
//     // 7) Rotate the landmark p1 around the image center by –angleDeg
//     final center = Point(frame.width / 2.0, frame.height / 2.0);
//     p1 = _rotatePoint(p1, center, -angleDeg);
//
//     // 8) Crop a square of side eyeWidth around p1
//     int x1 = (p1.x - half).round();
//     int y1 = (p1.y - half).round();
//     x1 = x1.clamp(0, frame.width  - eyeWidth);
//     y1 = y1.clamp(0, frame.height - eyeWidth);
//
//     final crop = img.copyCrop(
//       frame,
//       x:      x1,
//       y:      y1,
//       width:  eyeWidth,
//       height: eyeWidth,
//     );
//
//     // 9) Resize to 64×64
//     const int S = 64;
//     final resized = img.copyResize(crop, width: S, height: S);
//     final pngBytes = img.encodePng(resized);
//
// // 2) Get a writable directory
//
//     final dir = await getExternalStorageDirectory();
//     if (dir == null) {
//       print("❌ Failed to get external storage directory");
//       return false;
//     }
//
// // 3) Choose a filename
//     final file = File('${dir.path}/Eye_crop_${DateTime.now().millisecondsSinceEpoch}.png');
//
// // 4) Write the bytes
//     await file.writeAsBytes(pngBytes);
//
// // 5) Log or notify
//     print('✅ Eye crop saved to ${file.path}');
//
//     // 10) Normalize into Float32List
//     final input = Float32List(S * S * 3);
//     int idx = 0;
//     for (int yy = 0; yy < S; yy++) {
//       for (int xx = 0; xx < S; xx++) {
//         final p = resized.getPixel(xx, yy);
//         input[idx++] = p.r / 255.0;
//         input[idx++] = p.g / 255.0;
//         input[idx++] = p.b / 255.0;
//       }
//     }
//
//     // 11) Inference
//     final output = List.generate(1, (_) => List.filled(2, 0.0));
//     _interpreter!.run(input.reshape([1, S, S, 3]), output);
//
//     final openProb   = output[0][1];
//     final closedProb = output[0][0];
//     print('👁 Crop@($x1,$y1,$eyeWidth) θ=$angleDeg° → open=$openProb closed=$closedProb');
//
//     return closedProb > openProb;
//   }

// correct
//   Future<bool> _predictEyeClosed(
//       CameraImage image,
//       Point<int> eyePos,
//       Point<int> otherEyePos,
//       ) async {
//     // 1. Convert camera image to RGB
//     img.Image frame = _convertYUV420toImageColor(image);
//
//     // 2. Rotate by sensor orientation
//     final ori = _cameraController!.description.sensorOrientation;
//     if (ori != 0) {
//       frame = img.copyRotate(frame, angle: ori);
//     }
//
//     // 3. Mirror for front camera
//     final isFront = _cameraController!.description.lensDirection == CameraLensDirection.front;
//     if (isFront) {
//       frame = img.flipHorizontal(frame);
//     }
//
//     // 4. Convert eye landmark positions to doubles
//     Point<double> p1 = Point(eyePos.x.toDouble(), eyePos.y.toDouble());
//     Point<double> p2 = Point(otherEyePos.x.toDouble(), otherEyePos.y.toDouble());
//
//     if (isFront) {
//       p1 = Point(frame.width - p1.x, p1.y);
//       p2 = Point(frame.width - p2.x, p2.y);
//     }
//
//     // 5. Calculate eye-line angle
//     final dx = p2.x - p1.x;
//     final dy = p2.y - p1.y;
//     final angleDeg = math.atan2(dy, dx) * 180 / math.pi;
//
//     // 6. Rotate entire frame to make eye-line horizontal
//     frame = img.copyRotate(frame, angle: -angleDeg);
//
//     // 7. Crop fixed-size square around eye (use p1 as center)
//     const boxSize = 96;
//     int x1 = (p1.x - boxSize / 2).round();
//     int y1 = (p1.y - boxSize / 2).round();
//
//     // Clamp within image bounds
//     x1 = x1.clamp(0, frame.width - boxSize);
//     y1 = y1.clamp(0, frame.height - boxSize);
//
//     final cropped = img.copyCrop(frame, x: x1, y: y1, width: boxSize, height: boxSize);
//     final resized = img.copyResize(cropped, width: 64, height: 64);
//
//     // 8. Save cropped image for debugging
//     final dir = await getExternalStorageDirectory();
//     final file = File('${dir!.path}/Eye_crop_${DateTime.now().millisecondsSinceEpoch}.png');
//     await file.writeAsBytes(img.encodePng(resized));
//     print('✅ Eye crop saved to ${file.path}');
//
//     // 9. Normalize input to [0, 1]
//     final input = Float32List(64 * 64 * 3);
//     int idx = 0;
//     for (int y = 0; y < 64; y++) {
//       for (int x = 0; x < 64; x++) {
//         final px = resized.getPixel(x, y);
//         input[idx++] = px.r / 255.0;
//         input[idx++] = px.g / 255.0;
//         input[idx++] = px.b / 255.0;
//       }
//     }
//
//     // 10. Run model inference
//     final output = List.generate(1, (_) => List.filled(2, 0.0));
//     _interpreter!.run(input.reshape([1, 64, 64, 3]), output);
//
//     final openProb = output[0][1];
//     final closedProb = output[0][0];
//     print('👁 Crop@($x1,$y1,$boxSize) → open=$openProb closed=$closedProb');
//
//     return closedProb > openProb;
//   }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isDetecting) return;
    _isDetecting = true;

    try {
      // Build InputImage for ML Kit
      final allBytes = WriteBuffer();
      for (final plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();
      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: InputImageRotationValue.fromRawValue(
            _cameraController!.description.sensorOrientation,
          ) ??
              InputImageRotation.rotation0deg,
          format: InputImageFormat.nv21,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );

      // Detect faces
      final faces = await _faceDetector!.processImage(inputImage);
      if (faces.isEmpty) {
        _isDetecting = false;
        return;
      }
      final face = faces.first;
      final leftLM = face.landmarks[FaceLandmarkType.leftEye];
      final rightLM = face.landmarks[FaceLandmarkType.rightEye];
      if (leftLM == null || rightLM == null) {
        _isDetecting = false;
        return;
      }

      _frameCount++;
      if (_frameCount % 1 == 0) {
        final leftEye = Point(leftLM.position.x.toInt(), leftLM.position.y.toInt());
        final rightEye = Point(rightLM.position.x.toInt(), rightLM.position.y.toInt());

        final angleDeg = _computeEyeAngle(leftEye, rightEye);

        final leftClosed = await _predictEyeClosed(image, leftEye, angleDeg);
        final rightClosed = await _predictEyeClosed(image, rightEye, angleDeg);

        final bothClosed = leftClosed && rightClosed;
        _eyeStatus = bothClosed ? 'Closed' : 'Open';

        _eyeStatusHistory.add(bothClosed ? 1 : 0);
        if (_eyeStatusHistory.length > _historyLength) {
          _eyeStatusHistory.removeAt(0);
        }
        if (_eyeStatusHistory.where((e) => e == 1).length >= 2) {
          _score++;
        } else {
          _score--;
        }
        _score = _score < 0 ? 0 : _score;


        if (_score > _scoreThreshold && !_audioPlayer!.playing) {
          _audioPlayer!.play();
          print("🔔 Drowsiness detected, alarm playing.");
        } else if (_audioPlayer!.playing && _score <= _scoreThreshold) {
          _audioPlayer!.stop();
          print("🛑 Alarm stopped.");
        }
      }
    } catch (e) {
      debugPrint('❌ Error in _processCameraImage: $e');
    } finally {
      _isDetecting = false;
    }
  }

// ➕ Helper method
  double _computeEyeAngle(Point<int> left, Point<int> right) {
    final dx = right.x - left.x;
    final dy = right.y - left.y;
    return math.atan2(dy, dx) * 180 / math.pi;
  }

  Future<bool> _predictEyeClosed(CameraImage image, Point<int> eyePos, double angleDeg) async {
    img.Image frame = _convertYUV420toImageColor(image);

    final ori = _cameraController!.description.sensorOrientation;
    final isFront = _cameraController!.description.lensDirection == CameraLensDirection.front;

    // Apply rotation first
    if (ori != 0) {
      frame = img.copyRotate(frame, angle: ori);
    }

    // Flip horizontally for front camera
    if (isFront) {
      frame = img.flipHorizontal(frame);
      eyePos = Point(frame.width - eyePos.x, eyePos.y);  // Flip eye coordinates too
    }

    // Rotate to align eyes horizontally
    frame = img.copyRotate(frame, angle: -angleDeg);

    // Update coordinates again after rotation

    const boxSize = 96;
    int x1 = (eyePos.x - boxSize / 2).round();
    int y1 = (eyePos.y - boxSize / 2).round();
    x1 = x1.clamp(0, frame.width - boxSize);
    y1 = y1.clamp(0, frame.height - boxSize);

    final cropped = img.copyCrop(frame, x: x1, y: y1, width: boxSize, height: boxSize);
    final resized = img.copyResize(cropped, width: 64, height: 64);

    // Save for debugging
    final dir = await getExternalStorageDirectory();
    final file = File('${dir!.path}/Eye_crop_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(img.encodePng(resized));
    print('✅ Eye crop saved to ${file.path}');

    // Normalize input
    final input = Float32List(64 * 64 * 3);
    int idx = 0;
    for (int y = 0; y < 64; y++) {
      for (int x = 0; x < 64; x++) {
        final px = resized.getPixel(x, y);
        input[idx++] = px.r / 255.0;
        input[idx++] = px.g / 255.0;
        input[idx++] = px.b / 255.0;
      }
    }

    // Run inference
    final output = List.generate(1, (_) => List.filled(2, 0.0));
    _interpreter!.run(input.reshape([1, 64, 64, 3]), output);

    final openProb = output[0][1];
    final closedProb = output[0][0];
    print('👁 Crop@($x1,$y1,$boxSize) → open=$openProb closed=$closedProb');

    return closedProb > openProb;
  }


  img.Image _convertYUV420toImageColor(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final int uvRowStride = image.planes[1].bytesPerRow;
    final int uvPixelStride = image.planes[1].bytesPerPixel!;

    final img.Image imgBuffer = img.Image(width: width, height: height);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int uvIndex = uvPixelStride * (x ~/ 2) + uvRowStride * (y ~/ 2);
        final int index = y * width + x;

        final int yp = image.planes[0].bytes[index];
        final int up = image.planes[1].bytes[uvIndex];
        final int vp = image.planes[2].bytes[uvIndex];

        int r = (yp + (1.370705 * (vp - 128))).round();
        int g = (yp - (0.337633 * (up - 128)) - (0.698001 * (vp - 128)))
            .round();
        int b = (yp + (1.732446 * (up - 128))).round();

        imgBuffer.setPixelRgba(
            x, y, r.clamp(0, 255), g.clamp(0, 255), b.clamp(0, 255), 255);
      }
    }

    return imgBuffer;
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceDetector?.close();
    _interpreter?.close();
    _audioPlayer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print("📲 Building enhanced detection screen UI");

    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          CameraPreview(_cameraController!), // Fullscreen camera

          // App Bar (overlayed)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AppBar(
              backgroundColor: Colors.black.withOpacity(0.5),
              title: const Text('Live Detection'),
              foregroundColor: Colors.white,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

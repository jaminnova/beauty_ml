import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

class FaceMeasurementPage extends StatefulWidget {
  @override
  _FaceMeasurementPageState createState() => _FaceMeasurementPageState();
}

class _FaceMeasurementPageState extends State<FaceMeasurementPage>
    with TickerProviderStateMixin {
  File? _imageFile;
  Size? _imageSize;
  List<FaceMesh> _faceMeshes = [];
  late AnimationController _overlayController;
  late Animation<double> _overlayAnimation;

  int _currentPartIndex = 0;
  Timer? _sequencer;
  bool _isSequencing = true;
  final Duration _sequenceDuration = const Duration(seconds: 3);

  // Define facial parts with MediaPipe indices (enhanced chin with standard jawline points for accuracy)
  final List<FacialPart> _parts = [
    FacialPart(
      name: 'Left Eye',
      points: [463, 398, 384, 385, 386, 387, 388, 466, 263, 249, 390, 373, 374, 380, 381, 382, 362],
      lines: [[362, 33], [159, 145]],  // Dimensions: width, height
      contours: [  // Connections for eye shape outline
        [463, 398], [398, 384], [384, 385], [385, 386], [386, 387], [387, 388], [388, 466],
        [466, 263], [263, 249], [249, 390], [390, 373], [373, 374], [374, 380], [380, 381],
        [381, 382], [382, 362], [362, 463],  // Close contour
      ],
    ),
    FacialPart(
      name: 'Right Eye',
      points: [33, 246, 161, 160, 159, 158, 157, 173, 133, 155, 154, 153, 145, 144, 163, 7],
      lines: [[263, 133], [386, 374]],
      contours: [
        [33, 246], [246, 161], [161, 160], [160, 159], [159, 158], [158, 157], [157, 173],
        [173, 133], [133, 155], [155, 154], [154, 153], [153, 145], [145, 144], [144, 163],
        [163, 7], [7, 33],  // Close
      ],
    ),
    FacialPart(
      name: 'Nose',
      points: [1, 2, 6, 98, 327, 356, 454, 323, 361, 240, 468, 27, 31, 29, 30, 64, 63],
      lines: [[6, 1]],
      contours: [
        [1, 2], [2, 6], [6, 98], [98, 327], [327, 356], [356, 454], [454, 323], [323, 361],
        [361, 240], [240, 468], [468, 27], [27, 31], [31, 29], [29, 30], [30, 64], [64, 63],
        [63, 1],  // Close
      ],
    ),
    FacialPart(
      name: 'Mouth',
      points: [0, 267, 269, 270, 409, 1, 291, 375, 321, 405, 314, 17, 84, 181, 78, 146, 91, 61, 185, 40, 39, 37],
      lines: [[61, 291]],
      contours: [
        [0, 267], [267, 269], [269, 270], [270, 409], [409, 1], [1, 291], [291, 375], [375, 321],
        [321, 405], [405, 314], [314, 17], [17, 84], [84, 181], [181, 78], [78, 146], [146, 91],
        [91, 61], [61, 185], [185, 40], [40, 39], [39, 37], [37, 0],  // Close
      ],
    ),
    FacialPart(
      name: 'Cheeks',
      points: [123, 117, 234, 132, 58, 172, 454, 425, 205, 343, 352],  // Enhanced: key cheekbone and jaw points for better coverage
      lines: [[234, 454]],  // Cheek width
      contours: [
        [123, 117], [117, 234], [234, 132], [132, 58], [58, 172], [172, 454], [454, 425], [425, 205],
        [205, 343], [343, 352], [352, 123],  // Closed loop around cheeks/jaw
      ],
    ),
    FacialPart(
      name: 'Chin',
      points: [0, 4, 8, 12, 16, 152],  // Enhanced: Standard jawline points (0-16 subset) + inner chin (152) for accurate contour
      lines: [[8, 152]],  // Outer to inner chin height
      contours: [
        [0, 4], [4, 8], [8, 12], [12, 16], [16, 0],  // Jawline U-shape, with 152 as central point
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _overlayController = AnimationController(duration: const Duration(milliseconds: 1000), vsync: this);
    _overlayAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _overlayController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _sequencer?.cancel();
    _overlayController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        _currentPartIndex = 0;
      });
      await _processImage();
    }
  }

  Future<void> _processImage() async {
    if (_imageFile == null) return;

    // Decode image size
    final bytes = await _imageFile!.readAsBytes();
    final codec = await ui.instantiateImageCodec(Uint8List.fromList(bytes));
    final frameInfo = await codec.getNextFrame();
    _imageSize = Size(frameInfo.image.width.toDouble(), frameInfo.image.height.toDouble());
    frameInfo.image.dispose();
    codec.dispose();

    final inputImage = InputImage.fromFile(_imageFile!);
    final faceMeshDetector = FaceMeshDetector(option: FaceMeshDetectorOptions.faceMesh);

    _faceMeshes = await faceMeshDetector.processImage(inputImage);
    faceMeshDetector.close();

    if (mounted && _faceMeshes.isNotEmpty) {
      setState(() {});
      _startSequencer();
      await _showPartDialog();  // Start with first part
    }
  }

  void _startSequencer() {
    _sequencer?.cancel();
    _sequencer = Timer.periodic(_sequenceDuration, (timer) {
      if (_isSequencing) {
        setState(() {
          _currentPartIndex = (_currentPartIndex + 1) % _parts.length;
        });
        _showPartDialog();
      }
    });
  }

  void _nextPart() {
    setState(() {
      _currentPartIndex = (_currentPartIndex + 1) % _parts.length;
    });
    _showPartDialog();
  }

  void _toggleSequencing() {
    setState(() {
      _isSequencing = !_isSequencing;
    });
    if (_isSequencing) _startSequencer();
  }

  Future<void> _showPartDialog() async {
    if (_faceMeshes.isEmpty) return;

    final currentPart = _parts[_currentPartIndex];
    final faceMesh = _faceMeshes.first;
    final points = faceMesh.points;
    if (points.length < 468) return;

    // Compute bounding box with padding (tighter for cheeks/chin)
    final partPoints = currentPart.points.where((idx) => idx < points.length).map((idx) => Offset(points[idx].x, points[idx].y)).toList();
    if (partPoints.isEmpty) return;
    final minX = partPoints.map((p) => p.dx).reduce(math.min);
    final maxX = partPoints.map((p) => p.dx).reduce(math.max);
    final minY = partPoints.map((p) => p.dy).reduce(math.min);
    final maxY = partPoints.map((p) => p.dy).reduce(math.max);
    final padding = _currentPartIndex >= 4 ? 0.05 : 0.1;  // Smaller padding for cheeks/chin
    final cropRect = Rect.fromLTWH(
      (minX - (maxX - minX) * padding).clamp(0.0, _imageSize!.width),
      (minY - (maxY - minY) * padding).clamp(0.0, _imageSize!.height),
      ((maxX - minX) * (1 + 2 * padding)).clamp(0.0, _imageSize!.width),
      ((maxY - minY) * (1 + 2 * padding)).clamp(0.0, _imageSize!.height),
    );

    // Load full image
    final bytes = await _imageFile!.readAsBytes();
    final codec = await ui.instantiateImageCodec(Uint8List.fromList(bytes));
    final frameInfo = await codec.getNextFrame();
    final fullImage = frameInfo.image;
    codec.dispose();

    // Crop the image
    final recorder = ui.PictureRecorder();
    final croppedCanvas = Canvas(recorder);
    croppedCanvas.clipRect(Rect.fromLTWH(0, 0, cropRect.width, cropRect.height));
    croppedCanvas.drawImageRect(
      fullImage,
      cropRect,
      Rect.fromLTWH(0, 0, cropRect.width, cropRect.height),
      Paint(),
    );
    final croppedPicture = recorder.endRecording();
    final croppedImage = await croppedPicture.toImage(cropRect.width.toInt(), cropRect.height.toInt());
    croppedPicture.dispose();
    fullImage.dispose();

    // Convert to bytes (FIX: Async outside build)
    final byteData = await croppedImage.toByteData(format: ui.ImageByteFormat.png);
    final croppedBytes = byteData!.buffer.asUint8List();
    croppedImage.dispose();

    // Adjust landmarks to crop coords
    final adjustedPoints = <Offset>[];
    for (final idx in currentPart.points.where((i) => i < points.length)) {
      final origP = Offset(points[idx].x, points[idx].y);
      final adjustedX = origP.dx - cropRect.left;
      final adjustedY = origP.dy - cropRect.top;
      adjustedPoints.add(Offset(adjustedX, adjustedY));
    }

    // Show dialog (now sync, bytes pre-computed)
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        _overlayController.reset();
        _overlayController.forward();  // Start animation
        return Dialog.fullscreen(
          child: Scaffold(
            appBar: AppBar(
              title: Text('${currentPart.name} Analysis'),
              actions: [
                IconButton(
                  onPressed: _toggleSequencing,
                  icon: Icon(_isSequencing ? Icons.pause : Icons.play_arrow),
                ),
                IconButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _nextPart();
                  },
                  icon: const Icon(Icons.arrow_forward),
                  tooltip: 'Next Part',
                ),
              ],
            ),
            body: Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: cropRect.width,
                      height: cropRect.height,
                      child: Image.memory(croppedBytes),  // FIXED: Pre-computed Uint8List
                    ),
                  ),
                ),
                AnimatedBuilder(
                  animation: _overlayAnimation,
                  builder: (context, child) {
                    return CustomPaint(
                      size: Size.infinite,
                      painter: PartOverlayPainter(
                        cropSize: Size(cropRect.width, cropRect.height),
                        adjustedPoints: adjustedPoints,
                        currentPart: currentPart,
                        animationValue: _overlayAnimation.value,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sequential Face Measurement')),
      body: Column(
        children: [
          if (_imageFile == null)
            const Expanded(child: Center(child: Text('Upload or take a selfie to start.')))
          else if (_faceMeshes.isEmpty)
            const Expanded(child: Center(child: Text('No face detected. Try a clearer selfie.')))
          else
            Expanded(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: Image.file(_imageFile!),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Upload Selfie'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Take Selfie'),
                ),
                ElevatedButton.icon(
                  onPressed: _toggleSequencing,
                  icon: Icon(_isSequencing ? Icons.pause : Icons.play_arrow),
                  label: Text(_isSequencing ? 'Pause' : 'Resume'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FacialPart {
  final String name;
  final List<int> points;
  final List<List<int>> lines;  // Dimension lines
  final List<List<int>> contours;  // Contour connections

  FacialPart({required this.name, required this.points, required this.lines, required this.contours});
}

// Painter for cropped part overlays (FIXED: Use global indices directly with map lookup)
class PartOverlayPainter extends CustomPainter {
  final Size cropSize;
  final List<Offset> adjustedPoints;
  final FacialPart currentPart;
  final double animationValue;

  PartOverlayPainter({
    required this.cropSize,
    required this.adjustedPoints,
    required this.currentPart,
    required this.animationValue,
  });

  static const double pixelToCm = 0.03;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..strokeWidth = 2.0..style = PaintingStyle.stroke;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    final opacity = animationValue;
    final scale = 0.5 + 0.5 * animationValue;
    paint.color = Colors.red.withOpacity(opacity);

    if (adjustedPoints.isEmpty) return;

    // Map global index to adjusted Offset (for quick lookup)
    final pointMap = <int, Offset>{};
    for (int i = 0; i < currentPart.points.length; i++) {
      pointMap[currentPart.points[i]] = adjustedPoints[i];
    }

    // Draw contours (connect dots for shape) - using global indices
    for (final conn in currentPart.contours) {
      if (conn.length < 2) continue;
      final globalIdx1 = conn[0];
      final globalIdx2 = conn[1];
      if (!pointMap.containsKey(globalIdx1) || !pointMap.containsKey(globalIdx2)) continue;
      final p1 = pointMap[globalIdx1]!;
      final p2 = pointMap[globalIdx2]!;
      canvas.drawLine(p1, p2, paint);
    }

    // Draw dimension lines
    for (final line in currentPart.lines) {
      if (line.length < 2) continue;
      final globalIdx1 = line[0];
      final globalIdx2 = line[1];
      if (!pointMap.containsKey(globalIdx1) || !pointMap.containsKey(globalIdx2)) continue;
      final p1 = pointMap[globalIdx1]!;
      final p2 = pointMap[globalIdx2]!;
      canvas.drawLine(p1, p2, paint);

      // Measurement
      final distPixels = math.sqrt(math.pow(p2.dx - p1.dx, 2) + math.pow(p2.dy - p1.dy, 2));
      final distCm = (distPixels * pixelToCm).toStringAsFixed(1);
      textPainter.text = TextSpan(text: 'Dim: ${distCm}cm', style: const TextStyle(color: Colors.red, fontSize: 12));
      textPainter.layout();
      final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
      textPainter.paint(canvas, mid - Offset(textPainter.width / 2, 15));
    }

    // Draw points with indices
    final pointPaint = Paint()..color = Colors.blue.withOpacity(opacity);
    for (int i = 0; i < currentPart.points.length; i++) {
      final p = adjustedPoints[i];
      canvas.drawCircle(p, 3 * scale, pointPaint);

      // Index label (global)
      textPainter.text = TextSpan(text: '${currentPart.points[i]}', style: const TextStyle(color: Colors.blue, fontSize: 10));
      textPainter.layout();
      textPainter.paint(canvas, p + const Offset(5, -5));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
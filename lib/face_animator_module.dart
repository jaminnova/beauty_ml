// Face Animator Module (Flutter-only API using google_mlkit_face_mesh_detection)
//
// Enhancements:
// • Professional UI: empty-state card with instructions, progress chips, cleaner layout.
// • Shows the title of the current facial part in the main overlay and in the zoom dialog header.
// • Same part-by-part flow and animated measurement guides.
//
// Requires:
//   image_picker: ^1.0.8
//   google_mlkit_face_mesh_detection: ^0.4.1  (Android-only Beta)

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';

class FaceAnimatorModule extends StatefulWidget {
  const FaceAnimatorModule({super.key});
  @override
  State<FaceAnimatorModule> createState() => _FaceAnimatorModuleState();
}

class _FaceAnimatorModuleState extends State<FaceAnimatorModule>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();

  XFile? _lastPicked;
  ui.Image? _image;
  FaceLandmarks? _landmarks;

  FacialPart? _currentPart;
  int _partIndex = 0;

  late final AnimationController _animCtrl =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  late final FaceMeshDetector _meshDetector;

  static const _partsOrder = FacialPart.values;

  @override
  void initState() {
    super.initState();
    _meshDetector = FaceMeshDetector(option: FaceMeshDetectorOptions.faceMesh);
  }

  @override
  void dispose() {
    _meshDetector.close();
    _animCtrl.dispose();
    super.dispose();
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final hasImage = _image != null;
    final hasLm = _landmarks != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top controls row
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: _pickSelfie,
              icon: const Icon(Icons.file_upload),
              label: const Text('Upload Selfie'),
            ),
            const SizedBox(width: 12),
            if (hasLm)
              FilledButton.icon(
                onPressed: _restartSequence,
                icon: const Icon(Icons.replay),
                label: const Text('Replay'),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // Progress chips
        if (hasLm) _ProgressChips(currentIndex: _currentPart == null ? -1 : _partIndex),

        const SizedBox(height: 12),

        Expanded(
          child: hasImage
              ? ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(painter: _ImagePainter(_image!)),
                if (hasLm)
                  AnimatedBuilder(
                    animation: _animCtrl,
                    builder: (_, __) => CustomPaint(
                      painter: _FaceOverlayPainter(
                        _landmarks!,
                        highlight: _currentPart == null
                            ? null
                            : _indicesFor(_currentPart!),
                        progress: _animCtrl.value,
                      ),
                    ),
                  ),
                // Part title overlay (top-left)
                if (_currentPart != null)
                  Positioned(
                    left: 12,
                    top: 12,
                    child: _Tag(label: _labelOf(_currentPart!)),
                  ),
              ],
            ),
          )
              : _EmptyStateCard(onPick: _pickSelfie),
        ),
      ],
    );
  }

  // ---------- Flow ----------
  Future<void> _pickSelfie() async {
    final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 100);
    if (x == null) return;

    _lastPicked = x;

    final bytes = await x.readAsBytes();
    final img = await decodeImageFromList(bytes);

    setState(() {
      _image = img;
      _landmarks = null;
      _partIndex = 0;
      _currentPart = null;
    });

    await _runDetectionWithPath(
      x.path,
      Size(img.width.toDouble(), img.height.toDouble()),
    );
  }

  Future<void> _runDetectionWithPath(String path, Size imageSize) async {
    try {
      final inputImage = InputImage.fromFilePath(path);
      final meshes = await _meshDetector.processImage(inputImage);

      if (meshes.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('No face found in the image')));
        return;
      }

      final mesh = meshes.first;

      // Use mesh.points for vertices.
      // If your build returns normalized points, multiply by imageSize.
      final pts = <Offset>[];
      for (final p in mesh.points) {
        pts.add(Offset(p.x.toDouble(), p.y.toDouble()));
        // If points look normalized (0..1), use:
        // pts.add(Offset(p.x * imageSize.width, p.y * imageSize.height));
      }

      setState(() => _landmarks = FaceLandmarks(pts, imageSize));
      _startSequence();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Detection error: $e')));
    }
  }

  void _startSequence() {
    if (_landmarks == null) return;
    _partIndex = 0;
    _showPart(_partsOrder[_partIndex]);
  }

  void _restartSequence() {
    if (_landmarks == null) return;
    _startSequence();
  }

  void _showPart(FacialPart part) {
    setState(() => _currentPart = part);
    _animCtrl.forward(from: 0);
    WidgetsBinding.instance.addPostFrameCallback((_) => _openZoomDialogFor(part));
  }

  // ---------- Helpers ----------
  Set<int> _indicesFor(FacialPart p) {
    switch (p) {
      case FacialPart.leftEye:
        return FaceMeshIdx.leftEye;
      case FacialPart.rightEye:
        return FaceMeshIdx.rightEye;
      case FacialPart.nose:
        return FaceMeshIdx.nose;
      case FacialPart.leftCheek:
        return FaceMeshIdx.leftCheek;
      case FacialPart.rightCheek:
        return FaceMeshIdx.rightCheek;
      case FacialPart.mouth:
        return FaceMeshIdx.mouth;
      case FacialPart.chin:
        return FaceMeshIdx.chin;
      case FacialPart.forehead:
        return FaceMeshIdx.forehead;
    }
  }

  String _labelOf(FacialPart p) {
    switch (p) {
      case FacialPart.leftEye:
        return 'Left Eye';
      case FacialPart.rightEye:
        return 'Right Eye';
      case FacialPart.nose:
        return 'Nose';
      case FacialPart.leftCheek:
        return 'Left Cheek';
      case FacialPart.rightCheek:
        return 'Right Cheek';
      case FacialPart.mouth:
        return 'Mouth';
      case FacialPart.chin:
        return 'Chin';
      case FacialPart.forehead:
        return 'Forehead';
    }
  }

  Rect _tightPartRect(FaceLandmarks lm, Set<int> idxs, {double padRatio = 0.35}) {
    final pts = [for (final i in idxs) lm.points[i]];
    double minX = pts.first.dx, maxX = pts.first.dx, minY = pts.first.dy, maxY = pts.first.dy;
    for (final p in pts) {
      minX = math.min(minX, p.dx);
      maxX = math.max(maxX, p.dx);
      minY = math.min(minY, p.dy);
      maxY = math.max(maxY, p.dy);
    }
    final w = (maxX - minX);
    final h = (maxY - minY);
    final pad = math.max(w, h) * padRatio;
    final r = Rect.fromLTWH(minX - pad, minY - pad, w + pad * 2, h + pad * 2);

    // Clamp to image bounds
    final left = r.left.clamp(0.0, lm.imageSize.width);
    final top = r.top.clamp(0.0, lm.imageSize.height);
    final right = r.right.clamp(0.0, lm.imageSize.width);
    final bottom = r.bottom.clamp(0.0, lm.imageSize.height);
    return Rect.fromLTRB(left, top, right, bottom);
  }

  Future<void> _openZoomDialogFor(FacialPart part) async {
    if (_image == null || _landmarks == null) return;
    final lm = _landmarks!;
    final rect = _tightPartRect(lm, _indicesFor(part));

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with part title
              Row(
                children: [
                  Icon(_iconFor(part), color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    _labelOf(part),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Done',
                    icon: const Icon(Icons.check_circle),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // IMPORTANT: Use FittedBox to keep the crop ratio without stretch
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.contain, // preserves aspect ratio
                    child: SizedBox(
                      width: rect.width,         // intrinsic crop ratio
                      height: rect.height,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: _CroppedAnimatedView(
                          image: _image!,
                          landmarks: lm,
                          cropRect: rect,
                          part: part,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),
              Text(
                'Measuring width & height of the ${_labelOf(part).toLowerCase()}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );


    if (!mounted) return;
    _partIndex++;
    if (_partIndex < _partsOrder.length) {
      _showPart(_partsOrder[_partIndex]);
    } else {
      // Done
      Navigator.of(context).popUntil((route) => route.isFirst);
      setState(() => _currentPart = null);
    }
  }

  IconData _iconFor(FacialPart p) {
    switch (p) {
      case FacialPart.leftEye:
      case FacialPart.rightEye:
        return Icons.remove_red_eye;
      case FacialPart.nose:
        return Icons.trip_origin;
      case FacialPart.leftCheek:
      case FacialPart.rightCheek:
        return Icons.blur_on;
      case FacialPart.mouth:
        return Icons.tag_faces;
      case FacialPart.chin:
        return Icons.face_2;
      case FacialPart.forehead:
        return Icons.expand;
    }
  }
}

// ===== Data types & constants =====

class FaceLandmarks {
  final List<Offset> points; // e.g. 468 points
  final Size imageSize;
  FaceLandmarks(this.points, this.imageSize);
}

enum FacialPart { leftEye, rightEye, nose, leftCheek, rightCheek, mouth, chin, forehead }

class FaceMeshIdx {
  static const leftEye  = <int>{33, 133, 159, 145, 153, 154, 155, 157, 173};
  static const rightEye = <int>{263, 362, 386, 374, 380, 381, 382, 384, 398};
  static const nose     = <int>{1, 2, 98, 327, 168, 94, 331};
  static const mouth    = <int>{61, 291, 146, 91, 181, 84, 13, 14, 178, 402};
  static const chin     = <int>{152, 199, 200, 175};
  static const leftCheek  = <int>{50, 101, 205, 187};
  static const rightCheek = <int>{280, 330, 425, 411};
  static const forehead = <int>{10, 338, 297, 332, 67};
}

// ===== Painters & cropped overlay =====

class _ImagePainter extends CustomPainter {
  final ui.Image img;
  _ImagePainter(this.img);

  @override
  void paint(Canvas canvas, Size size) {
    final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
    final fitted = applyBoxFit(BoxFit.contain, src.size, size);
    final dst = Alignment.center.inscribe(fitted.destination, Offset.zero & size);
    final paint = Paint()..filterQuality = FilterQuality.high; // <-- sharper
    canvas.drawImageRect(img, src, dst, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


class _FaceOverlayPainter extends CustomPainter {
  final FaceLandmarks lm;
  final Set<int>? highlight;
  final double progress; // 0..1
  _FaceOverlayPainter(this.lm, {this.highlight, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final imgRect = Rect.fromLTWH(0, 0, lm.imageSize.width, lm.imageSize.height);
    final fitted = applyBoxFit(BoxFit.contain, imgRect.size, size);
    final out = Alignment.center.inscribe(fitted.destination, Offset.zero & size);

    final sx = out.width / lm.imageSize.width;
    final sy = out.height / lm.imageSize.height;

    final ptPaint = Paint()..strokeWidth = 1.5..style = PaintingStyle.stroke;
    final hlPaint = Paint()..strokeWidth = 2.0..style = PaintingStyle.stroke;

    for (int i = 0; i < lm.points.length; i++) {
      final p = lm.points[i];
      final mapped = Offset(out.left + p.dx * sx, out.top + p.dy * sy);
      final isHL = highlight?.contains(i) ?? false;
      canvas.drawCircle(mapped, isHL ? 2.2 : 1.2, isHL ? hlPaint : ptPaint);
    }

    if (highlight != null && highlight!.isNotEmpty) {
      final rect = _tightRectForIndices(lm, highlight!);
      final mappedRect = Rect.fromLTWH(
        out.left + rect.left * sx,
        out.top + rect.top * sy,
        rect.width * sx,
        rect.height * sy,
      );

      final growW = mappedRect.width * progress;
      final growH = mappedRect.height * progress;
      final linePaint = Paint()..strokeWidth = 3..style = PaintingStyle.stroke;

      // width (top) and height (left) guides
      canvas.drawLine(
        mappedRect.topLeft,
        Offset(mappedRect.left + growW, mappedRect.top),
        linePaint,
      );
      canvas.drawLine(
        mappedRect.topLeft,
        Offset(mappedRect.left, mappedRect.top + growH),
        linePaint,
      );

      final tpW = _tp('W: ${mappedRect.width.toStringAsFixed(0)}');
      final tpH = _tp('H: ${mappedRect.height.toStringAsFixed(0)}');
      tpW.paint(canvas, mappedRect.topCenter + const Offset(-24, -20));
      tpH.paint(canvas, mappedRect.centerLeft + const Offset(-40, -8));
    }
  }

  Rect _tightRectForIndices(FaceLandmarks lm, Set<int> idxs) {
    double minX = double.infinity, minY = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity;
    for (final i in idxs) {
      final p = lm.points[i];
      minX = math.min(minX, p.dx);
      maxX = math.max(maxX, p.dx);
      minY = math.min(minY, p.dy);
      maxY = math.max(maxY, p.dy);
    }
    final pad = math.max(8.0, 0.2 * math.max(maxX - minX, maxY - minY));
    return Rect.fromLTRB(
      (minX - pad).clamp(0.0, lm.imageSize.width),
      (minY - pad).clamp(0.0, lm.imageSize.height),
      (maxX + pad).clamp(0.0, lm.imageSize.width),
      (maxY + pad).clamp(0.0, lm.imageSize.height),
    );
  }

  TextPainter _tp(String t) => TextPainter(
    text: TextSpan(style: const TextStyle(color: Colors.white, fontSize: 12), text: t),
    textDirection: TextDirection.ltr,
  )..layout();

  @override
  bool shouldRepaint(covariant _FaceOverlayPainter old) =>
      old.lm != lm || old.highlight != highlight || old.progress != progress;
}

class _CroppedAnimatedView extends StatefulWidget {
  final ui.Image image;
  final FaceLandmarks landmarks;
  final Rect cropRect; // image coords
  final FacialPart part;
  const _CroppedAnimatedView({
    required this.image,
    required this.landmarks,
    required this.cropRect,
    required this.part,
  });

  @override
  State<_CroppedAnimatedView> createState() => _CroppedAnimatedViewState();
}

class _CroppedAnimatedViewState extends State<_CroppedAnimatedView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..forward();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final idxs = _indicesFor(widget.part);
    return Stack(
      children: [
        CustomPaint(
          painter: _CroppedImagePainter(widget.image, widget.cropRect),
          child: const SizedBox.expand(),
        ),
        AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => CustomPaint(
            painter: _CropOverlayPainter(
              widget.landmarks,
              widget.cropRect,
              idxs,
              progress: _ctrl.value,
            ),
            child: const SizedBox.expand(),
          ),
        ),
        // Floating label inside dialog (bottom-left)
        Positioned(
          left: 12,
          bottom: 12,
          child: _Tag(label: _labelOf(widget.part)),
        ),
      ],
    );
  }

  Set<int> _indicesFor(FacialPart p) {
    switch (p) {
      case FacialPart.leftEye:
        return FaceMeshIdx.leftEye;
      case FacialPart.rightEye:
        return FaceMeshIdx.rightEye;
      case FacialPart.nose:
        return FaceMeshIdx.nose;
      case FacialPart.leftCheek:
        return FaceMeshIdx.leftCheek;
      case FacialPart.rightCheek:
        return FaceMeshIdx.rightCheek;
      case FacialPart.mouth:
        return FaceMeshIdx.mouth;
      case FacialPart.chin:
        return FaceMeshIdx.chin;
      case FacialPart.forehead:
        return FaceMeshIdx.forehead;
    }
  }

  String _labelOf(FacialPart p) {
    switch (p) {
      case FacialPart.leftEye:
        return 'Left Eye';
      case FacialPart.rightEye:
        return 'Right Eye';
      case FacialPart.nose:
        return 'Nose';
      case FacialPart.leftCheek:
        return 'Left Cheek';
      case FacialPart.rightCheek:
        return 'Right Cheek';
      case FacialPart.mouth:
        return 'Mouth';
      case FacialPart.chin:
        return 'Chin';
      case FacialPart.forehead:
        return 'Forehead';
    }
  }
}

// --- Small UI bits ---

class _EmptyStateCard extends StatelessWidget {
  final VoidCallback onPick;
  const _EmptyStateCard({required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.image_outlined,
                  size: 48, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                'Upload a selfie to begin',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'We will detect facial parts (eyes, nose, mouth, cheeks, chin, forehead), '
                    'zoom into each, and draw animated measurements.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onPick,
                icon: const Icon(Icons.file_upload),
                label: const Text('Upload Selfie'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  const _Tag({required this.label});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.85),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ProgressChips extends StatelessWidget {
  final int currentIndex; // -1 when no active part
  const _ProgressChips({required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    const labels = [
      'Left Eye', 'Right Eye', 'Nose', 'Left Cheek',
      'Right Cheek', 'Mouth', 'Chin', 'Forehead'
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (int i = 0; i < labels.length; i++)
            Padding(
              padding: EdgeInsets.only(right: i == labels.length - 1 ? 0 : 8),
              child: Chip(
                label: Text(labels[i]),
                avatar: Icon(
                  i < currentIndex ? Icons.check_circle :
                  i == currentIndex ? Icons.play_circle : Icons.radio_button_unchecked,
                  size: 18,
                  color: i < currentIndex
                      ? Colors.green
                      : i == currentIndex
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).disabledColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ===== Cropped + overlay painters =====

class _CroppedImagePainter extends CustomPainter {
  final ui.Image img;
  final Rect crop; // image coords
  _CroppedImagePainter(this.img, this.crop);

  @override
  void paint(Canvas canvas, Size size) {
    final src = Rect.fromLTWH(crop.left, crop.top, crop.width, crop.height);
    final dst = Offset.zero & size;
    final paint = Paint()..filterQuality = FilterQuality.high; // <-- sharper
    canvas.drawImageRect(img, src, dst, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


class _CropOverlayPainter extends CustomPainter {
  final FaceLandmarks lm;
  final Rect crop; // image coords
  final Set<int> idxs;
  final double progress;
  _CropOverlayPainter(this.lm, this.crop, this.idxs, {required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / crop.width;
    final sy = size.height / crop.height;

    final hlPaint = Paint()..strokeWidth = 2.0..style = PaintingStyle.stroke;

    for (final i in idxs) {
      final p = lm.points[i];
      final mapped = Offset((p.dx - crop.left) * sx, (p.dy - crop.top) * sy);
      canvas.drawCircle(mapped, 2.2, hlPaint);
    }

    final rect = _tightRectForIndices(lm, idxs);
    final local = Rect.fromLTWH(
      (rect.left - crop.left) * sx,
      (rect.top - crop.top) * sy,
      rect.width * sx,
      rect.height * sy,
    );

    final growW = local.width * progress;
    final growH = local.height * progress;
    final linePaint = Paint()..strokeWidth = 3..style = PaintingStyle.stroke;

    canvas.drawRect(local, linePaint..color = Colors.white.withOpacity(0.15));
    canvas.drawLine(local.topLeft, Offset(local.left + growW, local.top), linePaint);
    canvas.drawLine(local.topLeft, Offset(local.left, local.top + growH), linePaint);
  }

  Rect _tightRectForIndices(FaceLandmarks lm, Set<int> idxs) {
    double minX = double.infinity, minY = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity;
    for (final i in idxs) {
      final p = lm.points[i];
      minX = math.min(minX, p.dx);
      maxX = math.max(maxX, p.dx);
      minY = math.min(minY, p.dy);
      maxY = math.max(maxY, p.dy);
    }
    final pad = math.max(8.0, 0.2 * math.max(maxX - minX, maxY - minY));
    return Rect.fromLTRB(minX - pad, minY - pad, maxX + pad, maxY + pad);
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter old) =>
      old.lm != lm || old.crop != crop || old.idxs != idxs || old.progress != progress;
}




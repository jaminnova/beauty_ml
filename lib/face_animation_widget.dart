import 'package:flutter/material.dart';
import 'dart:ui' as ui; // Import for ui.Image
import 'face_detector.dart';
import 'face_upload_section.dart';
import 'animation_controls.dart';
import 'loading_indicator.dart';
import 'error_dialog.dart';
import 'face_painter.dart';
import 'point3d.dart';

class FaceAnimationWidget extends StatefulWidget {
  final VoidCallback? onAnimationComplete;

  const FaceAnimationWidget({super.key, this.onAnimationComplete});

  @override
  State<FaceAnimationWidget> createState() => _FaceAnimationState();
}

class _FaceAnimationState extends State<FaceAnimationWidget>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  bool _hasError = false;
  String? _errorMessage;
  ui.Image? _image; // Explicitly use ui.Image (nullable)
  List<Point3D>? _landmarks;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _controller.reset();
        _controller.forward();
        widget.onAnimationComplete?.call();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onImageSelected(ui.Image image) { // Updated to ui.Image
    setState(() {
      _isLoading = true;
      _image = image; // Assign ui.Image
      _hasError = false;
    });
    _processImage();
  }

  void _processImage() async {
    if (_image == null) return;
    try {
      final landmarks = await FaceDetector.detect(_image!); // Ensure FaceDetector accepts ui.Image
      if (landmarks.isEmpty) throw Exception('No face detected');
      setState(() {
        _landmarks = landmarks;
        _isLoading = false;
      });
      _controller.forward();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  void _reset() {
    setState(() {
      _image = null;
      _landmarks = null;
      _controller.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_isLoading) LoadingIndicator(),
        if (_hasError) ErrorDialog(message: _errorMessage!, onRetry: _reset),
        if (!_isLoading && !_hasError && _image == null)
          FaceUploadSection(onImageSelected: _onImageSelected),
        if (_image != null && _landmarks != null)
          CustomPaint(
            painter: FacePainter(_image!, _landmarks!, _controller),
            child: SizedBox(
              width: 300,
              height: 300,
            ),
          ),
        if (_image != null && _landmarks != null)
          AnimationControls(controller: _controller, onReset: _reset),
      ],
    );
  }
}
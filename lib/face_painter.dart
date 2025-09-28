import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'face_animator.dart';
import 'point3d.dart';

class FacePainter extends CustomPainter {
  final ui.Image? image; // Nullable ui.Image
  final List<Point3D> landmarks;
  final AnimationController controller;

  FacePainter(this.image, this.landmarks, this.controller)
      : super(repaint: controller);

  @override
  void paint(Canvas canvas, Size size) {
    if (image == null) return;
    final animatedLandmarks = FaceAnimator.animateLandmarks(landmarks, controller);
    canvas.drawImage(image!, Offset.zero, Paint());
    final paint = Paint()..color = Colors.red;
    for (var point in animatedLandmarks) {
      canvas.drawCircle(Offset(point.x, point.y), 2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant FacePainter oldDelegate) => true;
}
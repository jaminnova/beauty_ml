import 'package:flutter/animation.dart';
import 'point3d.dart';

class FaceAnimator {
  static List<Point3D> animateLandmarks(List<Point3D> landmarks, AnimationController controller) {
    final progress = controller.value;
    return landmarks.map((point) {
      final dx = 20 * (progress - 0.5); // Range: -10 to 10
      return Point3D(point.x + dx, point.y, point.z);
    }).toList();
  }
}
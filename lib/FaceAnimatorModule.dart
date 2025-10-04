// Flutter Face Animator Module
// Works with a single selfie upload, detects facial landmarks with MediaPipe (via
// platform channels), and plays step-by-step part-focused animations directly in-app.
//
// HOW TO USE (high level):
// 1) Add this file to your Flutter project's lib/ folder.
// 2) Follow the Android/iOS native setup notes at the bottom of this file to link
// MediaPipe Tasks Face Landmarker.
// 3) In your app, use: FaceAnimatorModule()
//
// The widget will:
// - Let user pick a selfie (gallery or camera)
// - Run MediaPipe Face Landmarker natively and return 468 mesh landmarks
// - Detect specific parts (left eye → right eye → nose → left cheek → right cheek
// → mouth → chin → forehead)
// - For each part, crop/zoom tightly and show a dialog with animated guides
// (width/height lines). Then proceed to the next part.
// - Provide smooth on-canvas overlays with simple landmark smoothing.
//
// NOTE: This sample focuses on clarity and integration. You can customize the UI,
// animation timing, and styling freely.


import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';


/// Platform channel to call native MediaPipe Tasks FaceLandmarker
const _channel = MethodChannel('face_landmarker');


/// A single face's landmarks in image pixel-space.
class FaceLandmarks {
  /// List of 2D points (x, y) in image coordinates.
  final List<Offset> points; // length 468 for Face Mesh
  final Size imageSize; // original image dimensions in pixels
  FaceLandmarks(this.points, this.imageSize);
}


/// Facial parts we will animate, in order.
enum FacialPart { leftEye, rightEye, nose, leftCheek, rightCheek, mouth, chin, forehead }


/// Indices for key facial regions (MediaPipe Face Mesh landmark indices)
/// These sets are representative and sufficient for cropping/measurement overlays.
/// You can refine/extend them as needed.
class FaceMeshIdx {
// Left eye border (approx)
  static const leftEye = <int>{33, 133, 159, 145, 153, 154, 155, 157, 173};
// Right eye border (approx)
  static const rightEye = <int>{263, 362, 386, 374, 380, 381, 382, 384, 398};
// Nose bridge/tip
  static const nose = <int>{1, 2, 98, 327, 168, 94, 331};
// Mouth outer
  static const mouth = <int>{61, 291, 146, 91, 181, 84, 13, 14, 178, 402};
// Chin (menton region)
  static const chin = <int>{152, 199, 200, 175};
// Cheeks (approx centers). Use a few points around each cheek.
  static const leftCheek = <int>{50, 101, 205, 187};
  static const rightCheek = <int>{280, 330, 425, 411};
// Forehead / glabella region
  static const forehead = <int>{10, 338, 297, 332, 67};
}


class FaceAnimatorModule extends StatefulWidget {
  const FaceAnimatorModule({super.key});


  @override
  State<FaceAnimatorModule> createState() => _FaceAnimatorModuleState();
}


class _FaceAnimatorModuleState extends State<FaceAnimatorModule>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  ui.Image? _image;
  FaceLandmarks? _landmarks;
  FacialPart? _currentPart;
  int _partIndex = 0;

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    throw UnimplementedError();
  }


// Simple smoothing: keep last N landmark frames (we only run once, but this
// helps animate overlays stably when we re-render / scale)
}
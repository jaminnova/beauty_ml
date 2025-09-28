import 'package:flutter/material.dart';
import 'face_animation_widget.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Selfie Animation Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Scaffold(
        appBar: AppBar(title: const Text('Selfie Animation')),
        body: Center(
          child: FaceAnimationWidget(
            onAnimationComplete: () {
              print('Animation completed!');
            },
          ),
        ),
      ),
    );
  }
}
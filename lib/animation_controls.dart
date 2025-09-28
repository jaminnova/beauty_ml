import 'package:flutter/material.dart';

class AnimationControls extends StatelessWidget {
  final AnimationController controller;
  final VoidCallback onReset;

  const AnimationControls({super.key, required this.controller, required this.onReset});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.play_arrow),
          onPressed: () => controller.forward(),
        ),
        IconButton(
          icon: const Icon(Icons.pause),
          onPressed: () => controller.stop(),
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: onReset,
        ),
      ],
    );
  }
}
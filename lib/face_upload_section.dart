import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'image_processor.dart';
import 'dart:ui' as ui;

class FaceUploadSection extends StatelessWidget {
  final Function(ui.Image) onImageSelected;

  const FaceUploadSection({super.key, required this.onImageSelected});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton(
        onPressed: () async {
          final picker = ImagePicker();
          final pickedFile = await picker.pickImage(source: ImageSource.gallery);
          if (pickedFile != null) {
            final image = await ImageProcessor.process(pickedFile.path);
            onImageSelected(image);
          }
        },
        child: const Text('Upload Selfie'),
      ),
    );
  }
}
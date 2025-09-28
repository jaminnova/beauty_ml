import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data'; // Explicitly import dart:typed_data
import 'package:image/image.dart' as img;

class ImageProcessor {
  static Future<ui.Image> process(String path) async {
    final file = File(path);
    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw Exception('Failed to decode image');
    final resized = img.copyResize(decoded, width: 640, height: 480);
    final imgBytes = img.encodeJpg(resized); // List<int>
    final uint8Bytes = Uint8List.fromList(imgBytes); // Explicitly typed Uint8List
    final completer = ui.instantiateImageCodec(uint8Bytes);
    final frame = await (await completer).getNextFrame();
    return frame.image;
  }
}
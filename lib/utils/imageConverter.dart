// imgLib -> Image package from https://pub.dartlang.org/packages/image

import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:image/image.dart' as imglib;

// CameraImage BGRA8888 -> PNG
// Color
imglib.Image convertBGRA8888(Bgra8888Image image) {
  return imglib.Image.fromBytes(
    width: image.width,
    height: image.height,
    bytes: image.planes[0].bytes.buffer,
  );
}

imglib.Image convertJPEG(JpegImage image) {
  var byte = imglib.JpegDecoder().decode(image.bytes);
  if (byte != null) {
    return byte;
  } else {
    throw Exception();
  }
}

// CameraImage YUV420_888 -> PNG -> Image (compresion:0, filter: none)
// Black
imglib.Image convertYUV420ToImage(Yuv420Image cameraImage) {
  final imageWidth = cameraImage.width;
  final imageHeight = cameraImage.height;

  final yBuffer = cameraImage.planes[0].bytes;
  final uBuffer = cameraImage.planes[1].bytes;
  final vBuffer = cameraImage.planes[2].bytes;

  final int yRowStride = cameraImage.planes[0].bytesPerRow;
  final int yPixelStride = cameraImage.planes[0].bytesPerPixel!;

  final int uvRowStride = cameraImage.planes[1].bytesPerRow;
  final int uvPixelStride = cameraImage.planes[1].bytesPerPixel!;

  final image =
      imglib.Image(width: cameraImage.height, height: cameraImage.width);

  for (int h = 0; h < imageHeight; h++) {
    int uvh = (h / 2).floor();

    for (int w = 0; w < imageWidth; w++) {
      int uvw = (w / 2).floor();

      final yIndex = (h * yRowStride) + (w * yPixelStride);

      // Y plane should have positive values belonging to [0...255]
      final int y = yBuffer[yIndex];

      // U/V Values are subsampled i.e. each pixel in U/V chanel in a
      // YUV_420 image act as chroma value for 4 neighbouring pixels
      final int uvIndex = (uvh * uvRowStride) + (uvw * uvPixelStride);

      // U/V values ideally fall under [-0.5, 0.5] range. To fit them into
      // [0, 255] range they are scaled up and centered to 128.
      // Operation below brings U/V values to [-128, 127].
      final int u = uBuffer[uvIndex];
      final int v = vBuffer[uvIndex];

      // Compute RGB values per formula above.
      int r = (y + v * 1436 / 1024 - 179).round();
      int g = (y - u * 46549 / 131072 + 44 - v * 93604 / 131072 + 91).round();
      int b = (y + u * 1814 / 1024 - 227).round();

      r = r.clamp(0, 255);
      g = g.clamp(0, 255);
      b = b.clamp(0, 255);

      // Use 255 for alpha value, no transparency. ARGB values are
      // positioned in each byte of a single 4 byte integer
      // [AAAAAAAARRRRRRRRGGGGGGGGBBBBBBBB]
      final int argbIndex = h * imageWidth + w;
      if (image.data != null) {
        image.data!.setPixelRgba(imageHeight - h - 1, w, r, g, b, 255);
      }
    }
  }

  return image;
}

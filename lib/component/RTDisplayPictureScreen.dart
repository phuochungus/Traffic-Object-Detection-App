// A widget that displays the picture taken by the user.
import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:do_an_1/utils/imageConverter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as imglib;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'DisplayPictureScreen.dart';

class RTDisplayPictureScreen extends StatefulWidget {
  RTDisplayPictureScreen({
    super.key,
  });
  @override
  State<RTDisplayPictureScreen> createState() => _RTDisplayPictureState();
}

class _RTDisplayPictureState extends State<RTDisplayPictureScreen> {
  Queue<Uint8List> buffer = Queue();
  StreamController<Uint8List> controller = StreamController<Uint8List>();
  final channel = WebSocketChannel.connect(
    Uri.parse('ws://phuochungus-rtmdet.hf.space/image?threshold=0.5'),
  );
  // receiving\listening
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    channel.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text("Realtime Camera"),
      ),
      body: CameraAwesomeBuilder.analysisOnly(
        sensor: Sensors.front,
        builder: (state, previewSize, previewRect) => StreamBuilder(
            stream: channel.stream,
            builder: (context, snapshot) {
              if (snapshot.hasData) debugPrint(snapshot.data);
              if (buffer.isNotEmpty) controller.add(buffer.removeFirst());
              return snapshot.hasData
                  ? StreamBuilder(
                      stream: controller.stream,
                      builder: (context, snapshot) => snapshot.hasData
                          ? Image.memory(
                              snapshot.data!,
                              gaplessPlayback: true,
                            )
                          : const SizedBox.shrink(),
                    )
                  : const CircularProgressIndicator();
            }),
        onImageForAnalysis: (AnalysisImage image) async {
          var img = image.when(
            yuv420: (Yuv420Image img) => handleYuv420(img),
            bgra8888: (Bgra8888Image img) => convertBGRA8888(img),
            jpeg: (image) => convertJPEG(image),
          );
          if (img != null) {
            await _detectObject(img);
          }
        },
        imageAnalysisConfig: AnalysisConfig(
            androidOptions: const AndroidAnalysisOptions.yuv420(width: 200),
            maxFramesPerSecond: 24),
      ),
      floatingActionButton: FloatingActionButton(
        // Provide an onPressed callback.
        onPressed: () async {
          // Take the Picture in a try / catch block. If anything goes wrong,
          // catch the error.
          try {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const TakePictureScreen(),
              ),
            );
          } catch (e) {
            // If an error occurs, log the error to the console.
            print(e);
          }
        },
        child: const Icon(Icons.camera_alt),
      ),
    );
  }

  Future<void> _detectObject(imglib.Image image) async {
    debugPrint("Inferencing");
    try {
      if (buffer.length > 50) {
        buffer.clear();
        debugPrint("Clear buffer");
      }

      buffer.addLast(await FlutterImageCompress.compressWithList(
          imglib.PngEncoder(filter: imglib.PngFilter.none, level: 0)
              .encode(image),
          quality: 10,
          format: CompressFormat.png,
          rotate: 180));
      channel.sink.add(buffer.last);
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  imglib.Image handleYuv420(Yuv420Image image) {
    return convertYUV420ToImage(image);
  }
}

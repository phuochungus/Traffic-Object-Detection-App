import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:camerawesome/camerawesome_plugin.dart' as Camera;
import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:photo_view/photo_view.dart';
import '../utils/utils.dart';

const model_width = 640;
const model_height = 640;

// A screen that allows users to take a picture using a given camera.
class TakePictureScreen extends StatefulWidget {
  const TakePictureScreen({
    super.key,
  });
  @override
  TakePictureScreenState createState() => TakePictureScreenState();
}

class TakePictureScreenState extends State<TakePictureScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    // Dispose of the controller when the widget is disposed.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        // You must wait until the controller is initialized before displaying the
        // camera preview. Use a FutureBuilder to display a loading spinner until the
        // controller has finished initializing.
        body: Camera.CameraAwesomeBuilder.awesome(
      saveConfig: Camera.SaveConfig.photoAndVideo(
        photoPathBuilder: () => path(Camera.CaptureMode.photo),
        videoPathBuilder: () => path(Camera.CaptureMode.video),
        initialCaptureMode: Camera.CaptureMode.photo,
      ),
      enablePhysicalButton: true,
      flashMode: Camera.FlashMode.auto,
      aspectRatio: Camera.CameraAspectRatios.ratio_16_9,
      previewFit: Camera.CameraPreviewFit.fitWidth,
      onMediaTap: (mediaCapture) async {
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(
              builder: (context) =>
                  DisplayPictureScreen(imagePath: mediaCapture.filePath)),
        );
      },
      bottomActionsBuilder: (state) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            AwesomeOrientedWidget(
              child: InkWell(
                child: Container(
                  height: 45,
                  width: 45,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Container(),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _getCaptureButton(state),
                ),
              ),
            ),
            Align(
                alignment: Alignment.bottomCenter,
                child: AwesomeCameraSwitchButton(
                  state: state,
                ))
          ],
        );
      },
    ));
  }

  Widget? _getCaptureButton(CameraState state) {
    return state.when(
      onPhotoMode: (state) => _getFloatingActionButton(
        state,
        CaptureMode.photo,
        false,
      ),
      onVideoMode: (state) => _getFloatingActionButton(
        state,
        CaptureMode.video,
        false,
      ),
      onVideoRecordingMode: (state) => _getFloatingActionButton(
        state,
        CaptureMode.video,
        true,
      ),
    ) as Widget?;
  }

  Widget _getFloatingActionButton(
    CameraState state,
    CaptureMode captureMode,
    bool isRecording,
  ) {
    return FloatingActionButton(
      heroTag: 'camera_click',
      shape: const CircleBorder(),
      onPressed: () => _handleOnPress(state, captureMode, isRecording),
      backgroundColor: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: captureMode == CaptureMode.video && !isRecording
                ? BoxFit.none
                : BoxFit.fill,
            child: captureMode == CaptureMode.photo
                ? const Icon(
                    Icons.lens,
                    color: Colors.white,
                  )
                : isRecording
                    ? Icon(Icons.stop, color: Colors.red[900])
                    : Icon(Icons.lens, color: Colors.red[900]),
          )
        ],
      ),
    );
  }

  _handleOnPress(Camera.CameraState state, Camera.CaptureMode captureMode,
      bool isRecording) async {
    if (captureMode == CaptureMode.photo) {
      // ignore: invalid_use_of_protected_member
      var imagePath =
          await PhotoCameraState.from(state.cameraContext).takePhoto();
      debugPrint(imagePath);

      await Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => DisplayPictureScreen(imagePath: imagePath),
      ));
    }
    if (captureMode == CaptureMode.video) {
      if (!isRecording) {
        VideoCameraState.from(state.cameraContext).startRecording();
      } else {
        var util = Utils(context);
        util.startLoading();
        var path = await VideoRecordingCameraState.from(state.cameraContext)
            .filePathBuilder();
        await VideoRecordingCameraState.from(state.cameraContext)
            .stopRecording();
        sendVideo(XFile(path));
        Utils(context).stopLoading();
        Navigator.of(context).pop();
      }
    }
  }
}

class DisplayPictureScreen extends StatefulWidget {
  final String imagePath;
  const DisplayPictureScreen({super.key, required this.imagePath});
  @override
  State<StatefulWidget> createState() => _DisplayPictureState();
}

class _DisplayPictureState extends State<DisplayPictureScreen> {
  Uint8List _image = Uint8List(0);
  int thresHold = 50;
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance
        .addPostFrameCallback((_) => _detectObject(widget.imagePath));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Display the Picture'),
          actions: <Widget>[
            IconButton(
                onPressed: () async {
                  final result = await ImageGallerySaver.saveImage(_image,
                      quality: 60, name: "detected");
                  if (result['isSuccess']) {
                    Fluttertoast.showToast(
                        msg: "Save successfully",
                        gravity: ToastGravity.BOTTOM,
                        backgroundColor: const Color(0xff5CE3AB),
                        textColor: Colors.white);
                  }
                },
                icon: const Icon(Icons.save_rounded))
          ],
        ),
        // The image is stored as a file on the device. Use the `Image.file`
        // constructor with the given path to display the image.
        body: Center(
          child: Stack(
            children: [
              buildImage(),
            ],
          ),
        ));
  }

  Future<void> _detectObject(String imagePath) async {
    var request = http.MultipartRequest(
        'POST', Uri.parse('https://phuochungus-rtmdet.hf.space/image'));
    try {
      debugPrint("Start compress");
      var tempPath = imagePath;
      tempPath = "${tempPath.substring(0, tempPath.length - 4)}1.jpg";
      debugPrint(tempPath);
      request.files.add(await http.MultipartFile.fromPath(
          "file",
          (await FlutterImageCompress.compressAndGetFile(
            imagePath,
            tempPath,
            quality: 50,
          ))!
              .path));
      debugPrint("Done compress");
      debugPrint("Start Inference");
      http.StreamedResponse response = await request.send();
      if (response.statusCode == 200) {
        var resBody = response.stream;
        debugPrint("Done");
        _image = await resBody.toBytes();
        debugPrint("Done dowloading");
        setState(() {});
      } else {
        throw Exception();
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Widget buildImage() {
    debugPrint(_image.length.toString());
    return _image.isEmpty
        ? const CircularProgressIndicator()
        : PhotoView(imageProvider: Image.memory(_image).image);
  }
}

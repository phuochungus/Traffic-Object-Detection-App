import 'dart:io';

import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:do_an_1/component/DisplayPictureScreen.dart';
import 'package:do_an_1/screens/VideoQueue.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:path_provider/path_provider.dart';

Future<String> path(CaptureMode captureMode) async {
  if (captureMode == CaptureMode.photo) {
    final Directory extDir = await getTemporaryDirectory();
    final testDir =
        await Directory('${extDir.path}/test').create(recursive: true);
    final String filePath = '${testDir.path}/temp.jpg';
    return filePath;
  } else {
    final Directory extDir = await getTemporaryDirectory();
    final testDir =
        await Directory('${extDir.path}/test').create(recursive: true);
    final String filePath = '${testDir.path}/temp.mp4';
    return filePath;
  }
}

Future<void> routing(BuildContext context, String route) async {
  switch (route) {
    case "TakePicture":
      Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => const TakePictureScreen(),
      ));
      break;
    case "DisplayPictureScreen":
      ImagePicker picker = ImagePicker();
      XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        try {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => DisplayPictureScreen(
                imagePath: image.path,
              ),
            ),
          );
        } catch (e) {
          // If an error occurs, log the error to the console.
          print(e);
        }
      }
    case "VideoDetection":
      if (FirebaseAuth.instance.currentUser == null) {
        Fluttertoast.showToast(
            msg: "Please log in to use this function",
            toastLength: Toast.LENGTH_SHORT);
        Scaffold.of(context).openDrawer();
      } else {
        ImagePicker picker = ImagePicker();
        XFile? file = await picker.pickVideo(source: ImageSource.gallery);
        await sendVideo(file);
      }
    case "VideoQueue":
      if (FirebaseAuth.instance.currentUser == null) {
        Fluttertoast.showToast(
            msg: "Please log in to use this function",
            toastLength: Toast.LENGTH_SHORT);
      } else {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => const VideoQueue(),
        ));
      }
    case "RealtimeDetection":
      const AndroidIntent intent = AndroidIntent(action: 'com.example.YOLO');
      await intent.launch();

    default:
  }
}

class Utils {
  late BuildContext context;

  Utils(this.context);

  // this is where you would do your fullscreen loading
  Future<void> startLoading() async {
    return await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const SimpleDialog(
          elevation: 0.0,
          backgroundColor:
              Colors.transparent, // can change this to your prefered color
          children: <Widget>[
            Center(
              child: CircularProgressIndicator(),
            )
          ],
        );
      },
    );
  }

  Future<void> stopLoading() async {
    Navigator.of(context).pop();
  }

  Future<void> startFilter() async {
    return await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const SimpleDialog(
          elevation: 0.0,
          backgroundColor:
              Colors.transparent, // can change this to your prefered color
          children: <Widget>[
            Center(
              child: SizedBox.shrink(),
            )
          ],
        );
      },
    );
  }

  Future<void> closeFilter() async {
    Navigator.pop(context);
  }

  Future<void> showError(Object? error) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        action: SnackBarAction(
          label: 'Dismiss',
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
        backgroundColor: Colors.red,
        content: Text(handleError(error)),
      ),
    );
  }

  String handleError(Object? error) {
    return "Error";
  }
}

Future<void> sendVideo(XFile? file) async {
  var request = http.MultipartRequest(
      'POST', Uri.parse('https://firebasetot.onrender.com/predict_video'));
  if (file != null) {
    try {
      request.files.add(await http.MultipartFile.fromPath('video', file.path));
      request.fields.addEntries(<String, String>{
        "userId": FirebaseAuth.instance.currentUser!.uid
      }.entries);
      http.StreamedResponse response = await request.send();
      if (response.statusCode == 200) {
        debugPrint("Done");
      } else {
        throw Exception();
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  } else {
    debugPrint("NULL VIDEO");
  }
}

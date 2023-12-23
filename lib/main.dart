import 'dart:async';

import 'package:do_an_1/firebase_options.dart';
import 'package:do_an_1/screens/IntroScreen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:permission_handler/permission_handler.dart';

@pragma('vm:entry-point')
Future<void> _handleBackgroundMessage(RemoteMessage msg) async {
  debugPrint(msg.toString());
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  //Ask permission for camera
  var status = await Permission.camera.status;
  //Initialize Firebase app
  await Firebase.initializeApp(options: DefaultFirebaseOptions.android);
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(
    alert: true,
    announcement: true,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );
  final fcmToken = await FirebaseMessaging.instance.getToken();
  //Add listener for the firebase app
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint(messaging.toString());
    Fluttertoast.showToast(
        msg: message.data.toString(), toastLength: Toast.LENGTH_LONG);
  });
  FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);
  if (status.isDenied) {
    // We didn't ask for permission yet or the permission has been denied before but not permanently.
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.storage,
    ].request();
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Object Detection and Tracking',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.white),
        useMaterial3: true,
      ),
      home: const IntroScreen(),
    );
  }
}

// ignore_for_file: use_build_context_synchronously

import 'package:card_swiper/card_swiper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:do_an_1/screens/HomeScreen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../constrains/InfoQueries.dart';

class InfoScreen extends StatefulWidget {
  const InfoScreen({super.key});

  @override
  State<InfoScreen> createState() => _InfoScreenState();
}

class _InfoScreenState extends State<InfoScreen> {
  SwiperController controller = SwiperController();
  var db = FirebaseFirestore.instance;
  bool isLoading = false;
  final user = <String, String>{};
  String? error = null;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: const Color(0xff5CE3AB),
        body: isLoading
            ? const Center(
                child: Card(
                  child: SizedBox(
                      width: 200,
                      height: 200,
                      child: Center(
                        child: SizedBox(
                          width: 50,
                          height: 50,
                          child: CircularProgressIndicator(),
                        ),
                      )),
                ),
              )
            : Swiper(
                controller: controller,
                itemBuilder: (context, index) => Center(
                      child: Card(
                        child: SizedBox(
                          width: 300,
                          height: 230,
                          child: Padding(
                            padding: const EdgeInsets.only(
                                top: 30.0,
                                bottom: 20.0,
                                left: 20.0,
                                right: 20.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Align(
                                  alignment: Alignment.topCenter,
                                  child: Text(
                                    InfoQueries[index]["Question"]!,
                                    style: const TextStyle(
                                        fontSize: 18.0,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.center,
                                  child: InfoQueries[index]["Information"] ==
                                          null
                                      ? const SizedBox.shrink()
                                      : TextField(
                                          decoration: InputDecoration(
                                              labelText: InfoQueries[index]
                                                  ["Information"],
                                              hintText: InfoQueries[index]
                                                          ["Example"] !=
                                                      null
                                                  ? "Example: ${InfoQueries[index]["Example"]!}"
                                                  : "",
                                              errorText: error),
                                          onChanged: (value) => user.addEntries(
                                              <String, String>{
                                            InfoQueries[index]["Information"]!:
                                                value
                                          }.entries),
                                        ),
                                ),
                                Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      ElevatedButton(
                                          onPressed: () =>
                                              controller.previous(),
                                          child: const Text(
                                            "back",
                                            style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w500),
                                          )),
                                      const SizedBox(
                                        width: 50,
                                      ),
                                      ElevatedButton(
                                          onPressed: () async {
                                            if (index ==
                                                InfoQueries.length - 1) {
                                              _sendDataToDatabase();
                                              isLoading = true;
                                              setState(() {});
                                            } else {
                                              if (user[InfoQueries[index]
                                                      ["Information"]!] ==
                                                  null) {
                                                error =
                                                    "Please fill in the form";
                                              } else {
                                                controller.next();
                                              }
                                            }
                                          },
                                          child: Text(
                                            InfoQueries[index]["ButtonText"]!,
                                            style: const TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w500),
                                          )),
                                    ],
                                  ),
                                )
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                itemCount: InfoQueries.length));
  }

  Future<void> _sendDataToDatabase() async {
    final fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken != null) {
      user.addEntries(<String, String>{"deviceId": fcmToken}.entries);
    }
    var uid = FirebaseAuth.instance.currentUser!.uid;
    await db
        .collection("user")
        .doc(uid)
        .set(user)
        .onError((error, stackTrace) => debugPrint(error.toString()));
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => HomeScreen(),
      ));
    }
  }
}

import 'package:card_swiper/card_swiper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:do_an_1/constrains/InfoQueries.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'InfoScreen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final selectionList = <bool>[true, false];
  String? error = null;
  String? email = null;
  String? password = null;
  bool confirmPassword = false;
  bool isLoading = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff5CE3AB),
      body: Center(
          child: Card(
              child: isLoading
                  ? const SizedBox(
                      width: 250,
                      height: 250,
                      child: Center(
                        child: SizedBox(
                            width: 50,
                            height: 50,
                            child: CircularProgressIndicator()),
                      ))
                  : AnimatedSize(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeIn,
                      child: SizedBox(
                        width: 300,
                        height:
                            selectionList[0] || password == null ? 300 : 370,
                        child: Padding(
                          padding: const EdgeInsets.only(
                              left: 20.0, right: 20.0, top: 10.0, bottom: 7.0),
                          child: Stack(
                            children: [
                              Align(
                                  alignment: Alignment.topCenter,
                                  child: ToggleButtons(
                                    onPressed: (int index) {
                                      setState(() {
                                        // The button that is tapped is set to true, and the others to false.
                                        for (int i = 0;
                                            i < selectionList.length;
                                            i++) {
                                          selectionList[i] = i == index;
                                        }
                                        email = null;
                                        password = null;
                                        confirmPassword = false;
                                        error = null;
                                      });
                                    },
                                    borderRadius: const BorderRadius.all(
                                        Radius.circular(8)),
                                    selectedBorderColor: Colors.red[700],
                                    selectedColor: Colors.white,
                                    fillColor: Colors.red[200],
                                    color: Colors.red[400],
                                    constraints: const BoxConstraints(
                                      minHeight: 40.0,
                                      minWidth: 80.0,
                                    ),
                                    isSelected: selectionList,
                                    children: const [
                                      Text("Login"),
                                      Text("Signup")
                                    ],
                                  )),
                              ...({
                                selectionList[0] ? LoginForm() : SignUpForm()
                              }.toList()),
                              Align(
                                alignment: Alignment.bottomCenter,
                                child: Text(
                                  error ?? "",
                                  style: const TextStyle(
                                      fontSize: 12.0, color: Colors.red),
                                ),
                              ),
                              (email != null &&
                                      password != null &&
                                      (confirmPassword || selectionList[0]))
                                  ? Align(
                                      alignment: Alignment.bottomCenter,
                                      child: ElevatedButton(
                                        onPressed: () async => _handleButton(),
                                        style: ButtonStyle(
                                          backgroundColor:
                                              MaterialStateColor.resolveWith(
                                                  (states) => Colors.green),
                                          foregroundColor:
                                              MaterialStateColor.resolveWith(
                                                  (states) => Colors.white),
                                        ),
                                        child: Text(
                                          selectionList[0]
                                              ? "Log in"
                                              : "Sign up",
                                          style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink()
                            ],
                          ),
                        ),
                      ),
                    ))),
    );
  }

  Widget LoginForm() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: "Email",
            hintText: "Enter your email",
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => _handleEmail(value),
        ),
        const Divider(
          height: 20,
        ),
        TextField(
          decoration: const InputDecoration(
              labelText: "Password", border: OutlineInputBorder()),
          onChanged: (value) {
            if (_validatePassword(value)) {
              password = value;
            } else {
              password = null;
            }
            setState(() {});
          },
          obscureText: true,
        ),
      ],
    );
  }

  Widget SignUpForm() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
              hintText: "Enter your email",
              labelText: "Email",
              border: OutlineInputBorder()),
          onChanged: (value) => _handleEmail(value),
        ),
        const Divider(
          height: 20,
        ),
        TextField(
          decoration: const InputDecoration(
              hintText: "Type in a strong password",
              labelText: "Password",
              border: OutlineInputBorder()),
          onChanged: (value) {
            if (_validatePassword(value)) {
              password = value;
            } else {
              password = null;
            }
            setState(() {});
          },
          obscureText: true,
        ),
        ...(password != null
            ? [
                const Divider(
                  height: 20,
                ),
                TextField(
                  decoration: const InputDecoration(
                      labelText: "Confirm password",
                      border: OutlineInputBorder()),
                  onChanged: _validateConfirmPassword,
                  obscureText: true,
                )
              ]
            : [const SizedBox.shrink()])
      ],
    );
  }

  void _validateConfirmPassword(String value) {
    if (value.compareTo(password!) != 0) {
      error = "Confirm password is not right";
      confirmPassword = false;
    } else {
      error = null;
      confirmPassword = true;
    }
    setState(() {});
  }

  bool _validatePassword(String value) {
    var text = '';
    if (value.length < 6) {
      text += "Your password must at least 6 characters long\n";
    }
    if (!value.contains(RegExp(r'[a-zA-Z]')) && value.length > 1) {
      text += "It must have at least 1 character like a-z or A-Z";
    }
    error = text;
    return text.isEmpty;
  }

  void _handleEmail(String value) {
    if (!value.contains('@')) {
      error = "Invalid email\n";
    } else {
      error = null;
      email = value;
    }
    setState(() {});
  }

  Future<void> _handleButton() async {
    if (selectionList[0])
      _Login();
    else
      _SignUp();
    isLoading = true;
    setState(() {});
  }

  Future<void> _SignUp() async {
    try {
      final credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email!,
        password: password!,
      );
      // ignore: use_build_context_synchronously
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const InfoScreen(),
          ));
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        error = 'The password provided is too weak.';
        password = null;
        confirmPassword = false;
      } else if (e.code == 'email-already-in-use') {
        error = 'The account already exists for that email.';
        email = null;
        password = null;
        confirmPassword = false;
      }
      isLoading = false;
      setState(() {});
    } catch (e) {
      print(e);
    }
  }

  Future<void> _Login() async {
    try {
      final credential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email!, password: password!);
      debugPrint(credential.toString());
      var db = FirebaseFirestore.instance;
      var userRef =
          db.collection("user").doc(FirebaseAuth.instance.currentUser!.uid);
      var userSnapshot = await userRef.get();
      if (userSnapshot.data() != null &&
          userSnapshot.data()!["deviceId"] !=
              FirebaseMessaging.instance.getToken()) {
        userRef
            .update({"deviceId": await FirebaseMessaging.instance.getToken()});
        Fluttertoast.showToast(
            msg:
                "Now this device is your main device. you will receive notification on this device",
            toastLength: Toast.LENGTH_LONG);
      }
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        error = 'No user found for that email.';
        email = null;
        password = null;
      } else if (e.code == 'wrong-password') {
        error = 'Wrong password provided for that user.';
        password = null;
      }
      isLoading = false;

      setState(() {});
    } catch (e) {
      print(e);
    }
  }
}

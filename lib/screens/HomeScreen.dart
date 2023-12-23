import 'package:bottom_drawer/bottom_drawer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:do_an_1/component/MarqueeText.dart';
import 'package:do_an_1/constrains/classList.dart';
import 'package:do_an_1/screens/LoginScreen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:marquee/marquee.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/utils.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  BottomDrawerController controller = BottomDrawerController();
  ScrollController scrollController = ScrollController();
  late AnimationController anicontrolller;
  BottomDrawer? bottomDrawer;
  double arrowOffset = 0.0;
  var db = FirebaseFirestore.instance;
  Map<String, dynamic>? user = null;
  @override
  void initState() {
    anicontrolller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..forward()
      ..addListener(() {
        if (anicontrolller.isCompleted) {
          anicontrolller.repeat();
        }
      });
    _initUser();
    bottomDrawer = _createBottomDrawer();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Hero(
              tag: 'title',
              child: Text(
                'Home',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.black,
                    fontSize: 25,
                    fontWeight: FontWeight.bold),
              )),
          leading: Builder(
            builder: (context) => IconButton(
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
              icon: Padding(
                padding: const EdgeInsets.only(left: 10.0),
                child: Hero(
                  tag: 'icon',
                  child: ClipRRect(
                    borderRadius: const BorderRadius.all(Radius.circular(0)),
                    child: SizedBox(
                      width: 100,
                      height: 120,
                      child: Image.asset(
                        'lib/images/icon.png',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          )),
      drawer: Drawer(
          // Add a ListView to the drawer. This ensures the user can scroll
          // through the options in the drawer if there isn't enough vertical
          // space to fit everything.
          child: Padding(
        padding: const EdgeInsets.only(bottom: 10.0),
        child: Stack(
          children: [
            ListView(
              // Important: Remove any padding from the ListView.
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
                    decoration: const BoxDecoration(
                      color: Color(0xff5CE3AB),
                    ),
                    child: FirebaseAuth.instance.currentUser == null
                        ? Align(
                            alignment: Alignment.center,
                            child: ElevatedButton(
                              onPressed: () async {
                                await Navigator.of(context)
                                    .push(MaterialPageRoute(
                                  builder: (context) => const LoginScreen(),
                                ))
                                    .then((value) {
                                  setState(
                                    () {},
                                  );
                                });
                              },
                              child: const Text("Log in",
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w500)),
                            ),
                          )
                        : user == null
                            ? const SizedBox.shrink()
                            // ignore: prefer_interpolation_to_compose_strings
                            : Text(
                                "Welcome back\n" + user!["name"],
                                style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                              )),
                ListTile(
                  title: const Text('UITogether'),
                  onTap: () {
                    // Update the state of the app.
                    // ...
                  },
                ),
                ListTile(
                  title: const Text('About us'),
                  onTap: () {
                    // Update the state of the app.
                    // ...
                  },
                ),
                ListTile(
                  leading: const ImageIcon(
                    AssetImage("lib/images/UIT_logo.png"),
                    color: Color(0xff4960b1),
                  ),
                  title: const Text(
                    'UIT',
                    style: TextStyle(color: Color(0xff4960b1)),
                  ),
                  onTap: () async {
                    if (await canLaunchUrl(
                        Uri.parse("https://daa.uit.edu.vn"))) {
                      launchUrl(Uri.parse("https://daa.uit.edu.vn"));
                    } else {
                      // can't launch url
                    }
                  },
                ),
              ],
            ),
            FirebaseAuth.instance.currentUser != null
                ? Align(
                    alignment: Alignment.bottomCenter,
                    child: ElevatedButton(
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                        setState(() {});
                      },
                      child: const Text("Log out",
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w500)),
                    ),
                  )
                : const SizedBox.shrink()
          ],
        ),
      )),
      body: Align(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 80.0),
              child: GestureDetector(
                onPanUpdate: (details) {
                  if (details.delta.direction < 1) {
                    setState(() {
                      arrowOffset = -10;
                    });
                  } else {
                    setState(() {
                      arrowOffset = 10;
                    });
                  }
                },
                onPanEnd: (details) {
                  int offset = details.velocity.pixelsPerSecond.direction < 1
                      ? -400
                      : 400;
                  scrollController.animateTo(scrollController.offset + offset,
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.linear);
                },
                child: CustomScrollView(
                  controller: scrollController,
                  physics: const NeverScrollableScrollPhysics(),
                  scrollDirection: Axis.horizontal,
                  slivers: [
                    const SliverAppBar(
                      pinned: false,
                      toolbarHeight: 30.0,
                      leading: SizedBox.shrink(),
                    ),
                    SliverFixedExtentList(
                      itemExtent: 400,
                      delegate: SliverChildBuilderDelegate(
                        (BuildContext context, int index) {
                          return Row(
                            children: [
                              _createFunctionCard(
                                  funcList[index % funcList.length]["name"]!
                                      .toString(),
                                  funcList[index % funcList.length]["image"]!
                                      .toString(),
                                  funcList[index % funcList.length]
                                          ["description"]!
                                      .toString(),
                                  funcList[index % funcList.length]["route"]!
                                      .toString(),
                                  Scaffold.of(context),
                                  funcList[index % funcList.length]
                                      ["requireAuthentication"]! as bool),
                              const SizedBox(
                                width: 50,
                              )
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            bottomDrawer == null
                ? const CircularProgressIndicator()
                : bottomDrawer!
          ],
        ),
      ),
    );
  }

  BottomDrawer _createBottomDrawer() {
    return BottomDrawer(
      /// your customized drawer header.
      header: AnimatedBuilder(
        animation: anicontrolller,
        builder: (context, child) => Transform.translate(
          offset: Offset(
              0,
              QuadraFunction(Curves.easeInOut.transform(anicontrolller.value)) *
                  7),
          child: const Icon(
            Icons.arrow_drop_up,
            size: 50,
            color: Colors.white,
          ),
        ),
      ),

      /// your customized drawer body.
      body: GridView.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 100.0,
          mainAxisSpacing: 10.0,
          crossAxisSpacing: 10.0,
          childAspectRatio: 1.0,
        ),
        itemBuilder: (context, index) => Column(
          children: [
            Card(
              child: InkWell(
                onTap: () => routing(context,
                    funcList[index % funcList.length]['route']!.toString()),
                child: Card(
                  color: Colors.white,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: const BoxDecoration(
                        borderRadius: BorderRadius.all(Radius.circular(10.0))),
                    child: Image.asset(
                      funcList[index % funcList.length]['icon']!.toString(),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 50,
              height: 16,
              child: Center(
                child: Text(
                  overflow: TextOverflow.ellipsis,
                  funcList[index % funcList.length]['name']!.toString(),
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                      color: Colors.white),
                ),
              ),
            )
          ],
        ),
        itemCount: funcList.length,
      ),

      /// your customized drawer header height.
      headerHeight: 80.0,

      /// your customized drawer body height.
      drawerHeight: 250.0,

      /// drawer background color.
      color: const Color(0xff5CE3AB),

      /// drawer controller.
      controller: controller,
    );
  }

  Widget _createFunctionCard(String name, String image, String description,
      String route, ScaffoldState scaffoldState, bool requireAuth) {
    return InkWell(
      onTap: () {
        if (requireAuth && FirebaseAuth.instance.currentUser == null) {
          _handleAutheticationRequest(scaffoldState);
        } else {
          routing(context, route);
        }
      },
      child: Card(
        child: SizedBox(
          width: MediaQuery.of(context).size.width - 70,
          height: MediaQuery.of(context).size.height - 300,
          child: Padding(
            padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 20.0),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 15.0),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: MaybeMarqueeText(
                      name,
                    ),
                  ),
                ),
                Center(
                    child: Image.asset(
                  image,
                )),
                Padding(
                  padding: const EdgeInsets.only(bottom: 30.0),
                  child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Marquee(
                        text: description,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 30),
                        scrollAxis: Axis.horizontal,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        blankSpace: 50.0,
                        velocity: 100.0,
                        pauseAfterRound: const Duration(seconds: 1),
                        startPadding: 10.0,
                        accelerationDuration: const Duration(seconds: 1),
                        accelerationCurve: Curves.linear,
                        decelerationDuration: Duration(milliseconds: 500),
                        decelerationCurve: Curves.easeOut,
                      )),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _initUser() async {
    var instance = FirebaseAuth.instance;
    if (instance.currentUser != null) {
      user = (await db.collection('user').doc(instance.currentUser!.uid).get())
          .data();
      setState(() {});
    }
  }

  void _handleAutheticationRequest(ScaffoldState state) {
    if (state.hasDrawer) {
      state.openDrawer();
    }
    Fluttertoast.showToast(
        msg: "You need to log in to use this fuction",
        toastLength: Toast.LENGTH_SHORT);
  }
}

double QuadraFunction(double value) {
  return (-4 * value * value + 4 * value);
}

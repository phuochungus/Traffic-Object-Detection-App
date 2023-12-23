import 'package:do_an_1/screens/homeScreen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<StatefulWidget> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..forward()
          ..addListener(() {
            if (_controller.isCompleted) {
              _controller.repeat();
            }
          });
    _detectObject();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: const Color(0xff5CE3AB),
        body: Stack(children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) => Transform.translate(
                      offset: Offset(
                          0,
                          Curves.linear.transform(
                                  (-4 * _controller.value * _controller.value +
                                      4 * _controller.value)) *
                              -50),
                      child: RotationTransition(
                        turns: _controller,
                        child: Hero(
                          tag: 'icon',
                          child: ClipRRect(
                            borderRadius:
                                const BorderRadius.all(Radius.circular(20)),
                            child: SizedBox(
                              width: 120,
                              height: 120,
                              child: Image.asset(
                                'lib/images/icon.png',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 50,
                  ),
                  const Text(
                    'OBJECT',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.bold),
                  ),
                  const Hero(
                    tag: 'title',
                    child: Text(
                      'DETECTION AND TRACKING',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 20.0),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) => Text(
                        'Loading${List.filled(Curves.linear.transform(_controller.value) ~/ 0.25, ".").join("")}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 25,
                            fontWeight: FontWeight.bold),
                      )),
            ),
          )
        ]));
  }

  Future<void> _detectObject() async {
    var request = http.MultipartRequest('GET',
        Uri.parse('https://rtmdet-s-server-e4b8cd044511.herokuapp.com/'));

    try {
      await request.send().whenComplete(() async {
        var request = http.MultipartRequest(
            'GET', Uri.parse('https://phuochungus-rtmdet.hf.space/'));

        try {
          await request.send().whenComplete(() => Navigator.of(context)
              .pushAndRemoveUntil(
                  _createRoute(), (route) => Navigator.canPop(context)));
        } catch (e) {
          debugPrint(e.toString());
        }
      });
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Route _createRoute() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          const HomeScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        const curve = Curves.ease;

        var tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    );
  }
}

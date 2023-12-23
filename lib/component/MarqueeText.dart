import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';

/// Marquee text along Axis.horizontal for the purpose of the demo.
class MaybeMarqueeText extends StatelessWidget {
  final String text;
  final double height;
  final double maxWidth;

  const MaybeMarqueeText(
    this.text, {
    Key? key,
    this.height = 50,
    this.maxWidth = 100,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const TextStyle textStyle = TextStyle(fontSize: 18, color: Colors.white);

    return Container(
      child: Builder(
        builder: (context) {
          if (_willTextOverflow(text: text, style: textStyle)) {
            return SizedBox(
              height: height,
              child: Center(
                child: Marquee(
                  text: text,
                  style: const TextStyle(
                      fontSize: 35, fontWeight: FontWeight.bold),
                  blankSpace: maxWidth / 3,
                  velocity: 30,
                  pauseAfterRound: const Duration(milliseconds: 1500),
                ),
              ),
            );
          } else {
            return SizedBox(
              height: height,
              child: Center(
                child: Text(text,
                    maxLines: 1,
                    style: const TextStyle(
                        fontSize: 35, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center),
              ),
            );
          }
        },
      ),
    );
  }

  // https://stackoverflow.com/questions/51114778/how-to-check-if-flutter-text-widget-was-overflowed
  bool _willTextOverflow({required String text, required TextStyle style}) {
    final TextPainter textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(minWidth: 0, maxWidth: maxWidth);

    return textPainter.didExceedMaxLines;
  }
}

import 'dart:ui';
import 'package:flutter/material.dart';

class BoundingTextSize {
  late Locale locale;

  late final TextStyle style;
  // TextStyle style = Theme.of(context).textTheme.titleMedium!;
  // fontFamily Segoe UI
  // fontSize 16
  // fontWeight w400
  // textBaseline alphabetic

  late double maxWidth;
  late double singleLineHeight;

  BoundingTextSize(BuildContext context, this.style) {
    this.locale = Localizations.localeOf(context);

    final TextPainter textPainter = TextPainter(
        textDirection: TextDirection.ltr,
        locale: locale,
        text: TextSpan(text: "中", style: style),
        maxLines: null)
      ..layout(maxWidth: 1000);

    this.singleLineHeight = textPainter.size.height;
    return;
  }

  updateWitdh(double width) {
    this.maxWidth = width;
    return;
  }

  Size getTextSize(String text) {
    final TextPainter textPainter = TextPainter(
        textDirection: TextDirection.ltr,
        locale: locale,
        text: TextSpan(text: text, style: style),
        maxLines: null)
      ..layout();

    return textPainter.size;
  }

  int getTextLineCount(String text) {
    if ("" == text) {
      return 1;
    }
    final TextPainter textPainter = TextPainter(
        textDirection: TextDirection.ltr,
        locale: locale,
        text: TextSpan(text: text, style: style),
        maxLines: null)
      ..layout(maxWidth: maxWidth);

    int lineCount =
        ((textPainter.size.height + singleLineHeight * 0.3) / singleLineHeight)
            .toInt();
    if (0 == lineCount) {
      assert(false);
      lineCount = 1;
    }
    return lineCount;
  }

// Size boundingTextSize(BuildContext context, String text, TextStyle style,
//     {int maxLines = 2 ^ 31, double maxWidth = double.infinity}) {
//   if (text.isEmpty) {
//     return Size.zero;
//   }
//   final TextPainter textPainter = TextPainter(
//       textDirection: TextDirection.ltr,
//       locale: Localizations.localeOf(context),
//       text: TextSpan(text: text, style: style),
//       maxLines: maxLines)
//     ..layout(maxWidth: maxWidth);
//   return textPainter.size;
// }
}

import 'package:flutter/material.dart';

class RichTextController extends TextEditingController {
  final RegExp mentionRegex = RegExp(r'(@\w+)');
  final RegExp hashtagRegex = RegExp(r'(#\w+)');

  final TextStyle mentionStyle = const TextStyle(
    color: Colors.blue,
    fontWeight: FontWeight.bold,
  );

  final TextStyle hashtagStyle = const TextStyle(
    color: Colors.blue,
    fontStyle: FontStyle.italic,
  );

  RichTextController({String? text}) : super(text: text);

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    List<TextSpan> children = [];
    final textStr = text;

    if (textStr.isEmpty) {
      return TextSpan(style: style, text: '');
    }

    // A combined pattern to match mentions and hashtags
    final pattern = RegExp(r'(@\w+)|(#\w+)');
    final matches = pattern.allMatches(textStr);

    int lastMatchEnd = 0;

    for (final match in matches) {
      // Add normal text before the match
      if (match.start > lastMatchEnd) {
        children.add(TextSpan(
          text: textStr.substring(lastMatchEnd, match.start),
          style: style,
        ));
      }

      // Add the matched text with appropriate styling
      final matchedText = match.group(0)!;
      if (matchedText.startsWith('@')) {
        children.add(TextSpan(
          text: matchedText,
          style: (style ?? const TextStyle()).merge(mentionStyle),
        ));
      } else if (matchedText.startsWith('#')) {
        children.add(TextSpan(
          text: matchedText,
          style: (style ?? const TextStyle()).merge(hashtagStyle),
        ));
      }

      lastMatchEnd = match.end;
    }

    // Add any remaining text
    if (lastMatchEnd < textStr.length) {
      children.add(TextSpan(
        text: textStr.substring(lastMatchEnd),
        style: style,
      ));
    }

    return TextSpan(style: style, children: children);
  }
}

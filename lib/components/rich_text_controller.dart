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

  final TextStyle linkStyle = const TextStyle(
    color: Color(0xFF1877F2),
    decoration: TextDecoration.underline,
    fontWeight: FontWeight.w500,
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

    final pattern = RegExp(
      r'(https?:\/\/[^\s]+|www\.[^\s]+)|(@\w+)|(#\w+)',
      caseSensitive: false,
    );
    final matches = pattern.allMatches(textStr);

    int lastMatchEnd = 0;
    final TextStyle defaultBaseStyle =
        style ?? DefaultTextStyle.of(context).style;

    for (final match in matches) {
      if (match.start > lastMatchEnd) {
        children.add(TextSpan(
          text: textStr.substring(lastMatchEnd, match.start),
          style: style,
        ));
      }

      final matchedText = match.group(0)!;
      final lowerMatched = matchedText.toLowerCase();

      if (lowerMatched.startsWith('http://') ||
          lowerMatched.startsWith('https://') ||
          lowerMatched.startsWith('www.')) {
        children.add(TextSpan(
          text: matchedText,
          style: defaultBaseStyle.merge(linkStyle),
        ));
      } else if (matchedText.startsWith('@')) {
        children.add(TextSpan(
          text: matchedText,
          style: defaultBaseStyle.merge(mentionStyle),
        ));
      } else if (matchedText.startsWith('#')) {
        children.add(TextSpan(
          text: matchedText,
          style: defaultBaseStyle.merge(hashtagStyle),
        ));
      }

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < textStr.length) {
      children.add(TextSpan(
        text: textStr.substring(lastMatchEnd),
        style: style,
      ));
    }

    return TextSpan(style: style, children: children);
  }
}

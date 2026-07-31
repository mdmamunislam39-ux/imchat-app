import 'package:flutter/material.dart';

class RichTextViewer extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  const RichTextViewer({
    super.key,
    required this.text,
    this.style,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) {
      return Text('', style: style);
    }

    List<TextSpan> children = [];
    final pattern = RegExp(r'(@\w+)|(#\w+)');
    final matches = pattern.allMatches(text);

    int lastMatchEnd = 0;
    
    final mentionStyle = const TextStyle(
      color: Colors.blue,
      fontWeight: FontWeight.bold,
    );
    final hashtagStyle = const TextStyle(
      color: Colors.blue,
      fontStyle: FontStyle.italic,
    );

    for (final match in matches) {
      if (match.start > lastMatchEnd) {
        children.add(TextSpan(
          text: text.substring(lastMatchEnd, match.start),
          style: style,
        ));
      }

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

    if (lastMatchEnd < text.length) {
      children.add(TextSpan(
        text: text.substring(lastMatchEnd),
        style: style,
      ));
    }

    return RichText(
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
      text: TextSpan(
        style: style ?? DefaultTextStyle.of(context).style,
        children: children,
      ),
    );
  }
}

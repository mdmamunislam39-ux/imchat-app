import 'package:flutter/material.dart';

import 'seen_by.dart';

class StoryText {
  final String text;
  final Color bgColor;
  List<SeenBy> seenBy;
  final DateTime createdAt;

  StoryText({
    required this.text,
    required this.bgColor,
    this.seenBy = const [],
    required this.createdAt,
  });

  factory StoryText.fromMap(Map<String, dynamic> data) {
    DateTime parsedCreatedAt;
    if (data['createdAt'] is int) {
      parsedCreatedAt =
          DateTime.fromMillisecondsSinceEpoch(data['createdAt'] as int);
    } else {
      parsedCreatedAt = DateTime.now();
    }

    Color parsedBgColor;
    if (data['bgColor'] is int) {
      parsedBgColor = Color(data['bgColor'] as int);
    } else {
      parsedBgColor = Colors.black;
    }

    return StoryText(
      text: data['text']?.toString() ?? '',
      bgColor: parsedBgColor,
      seenBy: SeenBy.seenByFrom(data['seenBy']),
      createdAt: parsedCreatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'bgColor': bgColor.toARGB32(),
      'seenBy': seenBy.map((e) => e.toMap()).toList(),
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  static List<StoryText> textsFrom(dynamic listOfMaps) {
    if (listOfMaps == null || listOfMaps is! List) return [];
    return listOfMaps
        .whereType<Map>()
        .map((item) => StoryText.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }
}
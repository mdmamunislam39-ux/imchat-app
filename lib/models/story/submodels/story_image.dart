import 'seen_by.dart';

class StoryImage {
  final String imageUrl;
  List<SeenBy> seenBy;
  final DateTime createdAt;

  StoryImage({
    required this.imageUrl,
    this.seenBy = const [],
    required this.createdAt,
  });

  factory StoryImage.fromMap(Map<String, dynamic> data) {
    DateTime parsedCreatedAt;
    if (data['createdAt'] is int) {
      parsedCreatedAt =
          DateTime.fromMillisecondsSinceEpoch(data['createdAt'] as int);
    } else {
      parsedCreatedAt = DateTime.now();
    }

    return StoryImage(
      imageUrl: data['imageUrl']?.toString() ?? '',
      seenBy: SeenBy.seenByFrom(data['seenBy']),
      createdAt: parsedCreatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'imageUrl': imageUrl,
      'seenBy': seenBy.map((e) => e.toMap()).toList(),
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  static List<StoryImage> imagesFrom(dynamic listOfMaps) {
    if (listOfMaps == null || listOfMaps is! List) return [];
    return listOfMaps
        .whereType<Map>()
        .map((item) => StoryImage.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }
}
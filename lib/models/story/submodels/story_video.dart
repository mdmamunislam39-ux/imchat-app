import 'seen_by.dart';

class StoryVideo {
  final String videoUrl;
  final String thumbnailUrl;
  List<SeenBy> seenBy;
  final DateTime createdAt;

  StoryVideo({
    required this.videoUrl,
    required this.thumbnailUrl,
    this.seenBy = const [],
    required this.createdAt,
  });

  factory StoryVideo.fromMap(Map<String, dynamic> data) {
    DateTime parsedCreatedAt;
    if (data['createdAt'] is int) {
      parsedCreatedAt =
          DateTime.fromMillisecondsSinceEpoch(data['createdAt'] as int);
    } else {
      parsedCreatedAt = DateTime.now();
    }

    return StoryVideo(
      videoUrl: data['videoUrl']?.toString() ?? '',
      thumbnailUrl: data['thumbnailUrl']?.toString() ?? '',
      seenBy: SeenBy.seenByFrom(data['seenBy']),
      createdAt: parsedCreatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'seenBy': seenBy.map((e) => e.toMap()).toList(),
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  static List<StoryVideo> videosFrom(dynamic listOfMaps) {
    if (listOfMaps == null || listOfMaps is! List) return [];
    return listOfMaps
        .whereType<Map>()
        .map((item) => StoryVideo.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }
}
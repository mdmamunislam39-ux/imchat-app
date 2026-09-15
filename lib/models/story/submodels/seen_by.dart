class SeenBy {
  final String userId;
  final String fullname;
  final String photoUrl;
  final DateTime time;
  final String emoji;
  final String comment;

  const SeenBy({
    required this.userId,
    required this.fullname,
    required this.photoUrl,
    required this.time,
    required this.emoji,
    required this.comment
  });

  factory SeenBy.fromMap(Map<String, dynamic> data) {
    DateTime parsedTime;
    if (data['time'] is int) {
      parsedTime = DateTime.fromMillisecondsSinceEpoch(data['time'] as int);
    } else if (data['time'] != null && data['time'].toString().isNotEmpty) {
      parsedTime = DateTime.tryParse(data['time'].toString()) ?? DateTime.now();
    } else {
      parsedTime = DateTime.now();
    }

    return SeenBy(
      userId: data['userId']?.toString() ?? '',
      fullname: data['fullname']?.toString() ?? '',
      photoUrl: data['photoUrl']?.toString() ?? '',
      time: parsedTime,
      emoji: (data['imoji'] ?? data['emoji'])?.toString() ?? '',
      comment: data['comment']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'fullname': fullname,
      'photoUrl': photoUrl,
      'time': time.millisecondsSinceEpoch,
      'imoji': emoji,
      'comment': comment,
    };
  }

  static List<SeenBy> seenByFrom(dynamic listOfMaps) {
    if (listOfMaps == null || listOfMaps is! List) return [];
    return listOfMaps
        .whereType<Map>()
        .map((e) => SeenBy.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }
}

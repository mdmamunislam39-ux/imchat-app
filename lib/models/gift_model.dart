class GiftModel {
  final String from;
  final String giftId;
  final DateTime timestamp;

  GiftModel({required this.from, required this.giftId, required this.timestamp});

  Map<String, dynamic> toMap() => {
    'from': from,
    'giftId': giftId,
    'timestamp': timestamp.toIso8601String(),
  };

  static GiftModel fromMap(Map<String, dynamic> map) {
    return GiftModel(
      from: map['from'],
      giftId: map['giftId'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }
}

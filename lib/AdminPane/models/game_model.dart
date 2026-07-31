import 'package:cloud_firestore/cloud_firestore.dart';

class GameModel {
  final String id;
  final String name;
  final String thumbnailUrl;
  final String gameUrl;
  final double winRatio;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  GameModel({
    required this.id,
    required this.name,
    required this.thumbnailUrl,
    required this.gameUrl,
    this.winRatio = 0.5,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory GameModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GameModel(
      id: doc.id,
      name: data['name'] ?? '',
      thumbnailUrl: data['thumbnailUrl'] ?? '',
      gameUrl: data['gameUrl'] ?? '',
      winRatio: (data['winRatio'] ?? 0.5).toDouble(),
      isActive: data['isActive'] ?? true,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'thumbnailUrl': thumbnailUrl,
      'gameUrl': gameUrl,
      'winRatio': winRatio,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  GameModel copyWith({
    String? id,
    String? name,
    String? thumbnailUrl,
    String? gameUrl,
    double? winRatio,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return GameModel(
      id: id ?? this.id,
      name: name ?? this.name,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      gameUrl: gameUrl ?? this.gameUrl,
      winRatio: winRatio ?? this.winRatio,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

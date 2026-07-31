import 'package:cloud_firestore/cloud_firestore.dart';

class GameModel {
  final String id;
  final String name;
  final String picture;
  final String apiLink;
  final double winningValue;
  final bool isEnabled;

  GameModel({
    required this.id,
    required this.name,
    required this.picture,
    required this.apiLink,
    required this.winningValue,
    required this.isEnabled,
  });

  factory GameModel.fromMap(Map<String, dynamic> map, String docId) {
    return GameModel(
      id: docId,
      name: map['name'] ?? '',
      picture: map['picture'] ?? '',
      apiLink: map['apiLink'] ?? '',
      winningValue: (map['winningValue'] ?? 1.0).toDouble(),
      isEnabled: map['isEnabled'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'picture': picture,
      'apiLink': apiLink,
      'winningValue': winningValue,
      'isEnabled': isEnabled,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

class OfficialChannel {
  final String id;
  final String name;
  final String logo;
  final String banner;
  final String description;
  final bool isVerified;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? lastMessage;
  
  OfficialChannel({
    required this.id,
    required this.name,
    this.logo = '',
    this.banner = '',
    this.description = '',
    this.isVerified = false,
    this.createdAt,
    this.updatedAt,
    this.lastMessage,
  });

  factory OfficialChannel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return OfficialChannel(
      id: doc.id,
      name: data['name'] ?? '',
      logo: data['logo'] ?? data['imageUrl'] ?? '',
      banner: data['banner'] ?? '',
      description: data['description'] ?? '',
      isVerified: data['isVerified'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      lastMessage: data['lastMessage'],
    );
  }
}

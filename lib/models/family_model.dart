import 'package:cloud_firestore/cloud_firestore.dart';

class FamilyModel {
  final String familyId;
  final String familyName;
  final String familyBio;
  final String coverImage;
  final String ownerId; // Storing as String for easy serialization
  final String level;
  final int flamePoints;
  final int memberCount;
  final DateTime createdAt;

  FamilyModel({
    required this.familyId,
    required this.familyName,
    required this.familyBio,
    required this.coverImage,
    required this.ownerId,
    required this.level,
    required this.flamePoints,
    required this.memberCount,
    required this.createdAt,
  });

  factory FamilyModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    
    // Handle DocumentReference or String for owner_id
    String parsedOwnerId = '';
    if (data['owner_id'] is DocumentReference) {
      parsedOwnerId = (data['owner_id'] as DocumentReference).id;
    } else {
      parsedOwnerId = data['owner_id']?.toString() ?? '';
    }

    return FamilyModel(
      familyId: doc.id,
      familyName: data['family_name'] ?? 'Unknown Family',
      familyBio: data['family_bio'] ?? '',
      coverImage: data['cover_image'] ?? '',
      ownerId: parsedOwnerId,
      level: data['level']?.toString() ?? 'steel',
      flamePoints: data['flame_points'] ?? 0,
      memberCount: data['member_count'] ?? 1,
      createdAt: data['created_at'] != null 
          ? (data['created_at'] as Timestamp).toDate() 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'family_id': familyId,
      'family_name': familyName,
      'family_bio': familyBio,
      'cover_image': coverImage,
      'owner_id': FirebaseFirestore.instance.collection('Users').doc(ownerId),
      'level': level,
      'flame_points': flamePoints,
      'member_count': memberCount,
      'created_at': Timestamp.fromDate(createdAt),
    };
  }
}

class FamilyMemberModel {
  final String memberId;
  final String familyId;
  final String userId;
  final String role; // owner, admin, member
  final int contributionFlame;
  final DateTime joinedAt;

  FamilyMemberModel({
    required this.memberId,
    required this.familyId,
    required this.userId,
    required this.role,
    required this.contributionFlame,
    required this.joinedAt,
  });

  factory FamilyMemberModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // Handle DocumentReferences
    String parsedFamilyId = '';
    if (data['family_id'] is DocumentReference) {
      parsedFamilyId = (data['family_id'] as DocumentReference).id;
    } else {
      parsedFamilyId = data['family_id']?.toString() ?? '';
    }

    String parsedUserId = '';
    if (data['user_id'] is DocumentReference) {
      parsedUserId = (data['user_id'] as DocumentReference).id;
    } else {
      parsedUserId = data['user_id']?.toString() ?? '';
    }

    return FamilyMemberModel(
      memberId: doc.id,
      familyId: parsedFamilyId,
      userId: parsedUserId,
      role: data['role'] ?? 'member',
      contributionFlame: data['contribution_flame'] ?? 0,
      joinedAt: data['joined_at'] != null 
          ? (data['joined_at'] as Timestamp).toDate() 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'member_id': memberId,
      'family_id': FirebaseFirestore.instance.collection('families').doc(familyId),
      'user_id': FirebaseFirestore.instance.collection('Users').doc(userId),
      'role': role,
      'contribution_flame': contributionFlame,
      'joined_at': Timestamp.fromDate(joinedAt),
    };
  }
}

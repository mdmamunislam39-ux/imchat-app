import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

enum LoginProvider { email, google, apple }

class User {
  String userId;
  String fullname;
 // String username;
  String number;
  String photoUrl;
  String email;
  String bio;
  String gender;
  String birthday;
  String country;
  String homePageBackground;
  List<String> homePageBackgrounds;
  bool isOnline;
  DateTime? lastActive;
  String deviceToken;
  String status;
  LoginProvider loginProvider;
  bool isTyping;
  String typingTo;
  bool isRecording;
  String recordingTo;
  List<String> mutedGroups;
  DateTime? createdAt;
  bool isVerified;
  String level;
  String searchId;
  int following;
  int followers;
  int visitorCount;
  
  // Wallet and economy fields
  int diamonds;
  int totalDiamonds;
  int beans;
  String userType; // regular, host, seller, admin
  List<String> roles; // Supports multiple roles simultaneously
  bool isAgency;
  String? agencyId;
  String? agencyName;
  String? familyId;
  String? familyName;
  
  // Referral system
  String? referralCode;
  String? referredBy;
  int referralCount;
  
  // Level system
  UserLevel? sendingLevel;
  UserLevel? receivingLevel;
  UserLevel? roomLevel;
  
  // Customization
  UserCustomization? customization;
  
  // Activity stats
  UserActivityStats? activityStats;
  
  // Punishments
  List<UserPunishment> punishments;

  // SVIP tracking
  int monthlyRechargeAmount;
  String lastRechargeMonth;
  int activeSvipLevel;
  String svipValidUntilMonth;

  // Real-time Ban Enforcement
  UserBanStatus? banStatus;

  User({
    this.userId = '',
    this.fullname = '',
   // this.username = '',
    this.number = '',
    this.photoUrl = '',
    this.email = '',
    this.bio = '',
    this.gender = '',
    this.birthday = '',
    this.country = '',
    this.homePageBackground = '',
    this.homePageBackgrounds = const [],
    this.isOnline = false,
    this.lastActive,
    this.deviceToken = '',
    this.status = 'active',
    this.loginProvider = LoginProvider.email,
    this.isTyping = false,
    this.typingTo = '',
    this.isRecording = false,
    this.recordingTo = '',
    this.mutedGroups = const [],
    this.createdAt,
    this.isVerified=false,
    this.level = '',
    this.searchId = '',
    this.following = 0,
    this.followers = 0,
    this.visitorCount = 0,
    // Wallet and economy defaults
    this.diamonds = 0,
    this.totalDiamonds = 0,
    this.beans = 0,
    this.userType = 'regular',
    this.roles = const [],
    this.isAgency = false,
    this.agencyId,
    this.agencyName,
    this.familyId,
    this.familyName,
    this.referralCode,
    this.referredBy,
    this.referralCount = 0,
    this.sendingLevel,
    this.receivingLevel,
    this.roomLevel,
    this.customization,
    this.activityStats,
    this.punishments = const [],
    this.monthlyRechargeAmount = 0,
    this.lastRechargeMonth = '',
    this.activeSvipLevel = 0,
    this.svipValidUntilMonth = '',
    this.banStatus,
  });

  // Get User first name
  String get firstName => fullname.split(' ').first;

  @override
  String toString() {
    return 'User(userId: $userId, fullname: $fullname,number:$number, photoUrl: $photoUrl, bio: $bio, isOnline: $isOnline, lastActive: $lastActive, deviceToken: $deviceToken, isTyping: $isTyping, typingTo: $typingTo, level: $level, searchId: $searchId, familyId: $familyId)';
  }

  factory User.fromMap(Map<String, dynamic> data) {
    return User(
      userId: data['userId'] ?? data['id'] ?? '',
      fullname: data['fullname'] ?? data['name'] ?? '',
    //  username: data['username'] ?? '',
      number: data['number']??'',
      photoUrl: data['photoUrl'] ?? data['imageUrl'] ?? data['profileImageUrl'] ?? '',
      email: data['email'] ?? '',
      bio: data['bio'] ?? '',
      gender: data['gender'] ?? '',
      birthday: data['birthday'] ?? '',
      country: data['country'] ?? '',
      homePageBackground: data['homePageBackground'] ?? '',
      homePageBackgrounds: data['homePageBackgrounds'] != null ? List<String>.from(data['homePageBackgrounds']) : [],
      isOnline: data['isOnline'] ?? false,
      lastActive: data['lastActive'] is int
          ? DateTime.fromMillisecondsSinceEpoch(data['lastActive'])
          : (data['lastActive'] is Timestamp
              ? (data['lastActive'] as Timestamp).toDate()
              : null),
      deviceToken: data['deviceToken'] ?? '',
      status: data['status'] ?? '',
      loginProvider: LoginProvider.values
              .firstWhereOrNull((el) => el.name == data['loginProvider']) ??
          LoginProvider.email,
      isTyping: data['isTyping'] ?? false,
      typingTo: data['typingTo'] ?? '',
      isRecording: data['isRecording'] ?? false,
      recordingTo: data['recordingTo'] ?? '',
      mutedGroups: List.from(data['mutedGroups'] ?? []),
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : (data['createdAt'] is int
              ? DateTime.fromMillisecondsSinceEpoch(data['createdAt'])
              : null),
      isVerified: data['isVerified']??false,
      level: data['level'] ?? '',
      searchId: data['searchId'] ?? '',
      following: data['following'] is int ? data['following'] : (data['following'] is num ? (data['following'] as num).toInt() : (data['following'] is String ? int.tryParse(data['following']) ?? 0 : 0)),
      followers: data['followers'] is int ? data['followers'] : (data['followers'] is num ? (data['followers'] as num).toInt() : (data['followers'] is String ? int.tryParse(data['followers']) ?? 0 : 0)),
      visitorCount: data['visitorCount'] is int ? data['visitorCount'] : (data['visitorCount'] is num ? (data['visitorCount'] as num).toInt() : (data['visitorCount'] is String ? int.tryParse(data['visitorCount']) ?? 0 : 0)),
      // Wallet and economy fields
      diamonds: (data['diamonds'] as num?)?.toInt() ?? 0,
      totalDiamonds: (data['totalDiamonds'] as num?)?.toInt() ?? 0,
      beans: (data['beans'] as num?)?.toInt() ?? 0,
      userType: data['isOfficialChannel'] == true ? 'channel' : (data['userType'] ?? 'regular'),
      roles: data['roles'] != null ? List<String>.from(data['roles']) : [data['isOfficialChannel'] == true ? 'channel' : (data['userType'] ?? 'regular')],
      isAgency: data['isAgency'] ?? 
                (data['roles'] != null 
                    ? List<String>.from(data['roles']).contains('agency') 
                    : (data['userType'] == 'agency' || data['userType'] == 'agency_owner')),
      agencyId: data['agencyId'],
      agencyName: data['agencyName'],
      familyId: data['familyId'],
      familyName: data['familyName'],
      referralCode: data['referralCode'],
      referredBy: data['referredBy'],
      referralCount: data['referralCount'] ?? 0,
      sendingLevel: data['sendingLevel'] != null ? UserLevel.fromMap(Map<String, dynamic>.from(data['sendingLevel'])) : null,
      receivingLevel: data['receivingLevel'] != null ? UserLevel.fromMap(Map<String, dynamic>.from(data['receivingLevel'])) : null,
      roomLevel: data['roomLevel'] != null ? UserLevel.fromMap(Map<String, dynamic>.from(data['roomLevel'])) : null,
      customization: data['customization'] != null ? UserCustomization.fromMap(Map<String, dynamic>.from(data['customization'])) : null,
      activityStats: data['activityStats'] != null ? UserActivityStats.fromMap(Map<String, dynamic>.from(data['activityStats'])) : null,
      punishments: data['punishments'] != null 
          ? (data['punishments'] as List).map((p) => UserPunishment.fromMap(Map<String, dynamic>.from(p))).toList()
          : [],
      monthlyRechargeAmount: data['monthlyRechargeAmount'] ?? 0,
      lastRechargeMonth: data['lastRechargeMonth'] ?? '',
      activeSvipLevel: data['activeSvipLevel'] ?? 0,
      svipValidUntilMonth: data['svipValidUntilMonth'] ?? '',
      banStatus: data['banStatus'] != null ? UserBanStatus.fromMap(Map<String, dynamic>.from(data['banStatus'])) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'fullname': fullname,
     // 'username': username,
      'number': number,
      'photoUrl': photoUrl,
      'email': email,
      'bio': bio,
      'gender': gender,
      'birthday': birthday,
      'country': country,
      'homePageBackground': homePageBackground,
      'homePageBackgrounds': homePageBackgrounds,
      'isOnline': isOnline,
      'lastActive': lastActive?.millisecondsSinceEpoch,
      'deviceToken': deviceToken,
      'status': status,
      'isTyping': isTyping,
      'typingTo': typingTo,
      'createdAt': FieldValue.serverTimestamp(),
      'isVerified': isVerified,
      'level': level,
      'searchId': searchId,
      'following': following,
      'followers': followers,
      'visitorCount': visitorCount,
      // Wallet and economy fields
      'diamonds': diamonds,
      'totalDiamonds': totalDiamonds,
      'beans': beans,
      'userType': userType,
      'roles': roles.isNotEmpty ? roles : [userType],
      'isAgency': isAgency,
      'agencyId': agencyId,
      'agencyName': agencyName,
      'familyId': familyId,
      'familyName': familyName,
      'referralCode': referralCode,
      'referredBy': referredBy,
      'referralCount': referralCount,
      'sendingLevel': sendingLevel?.toMap(),
      'receivingLevel': receivingLevel?.toMap(),
      'roomLevel': roomLevel?.toMap(),
      'customization': customization?.toMap(),
      'activityStats': activityStats?.toMap(),
      'punishments': punishments.map((p) => p.toMap()).toList(),
      'monthlyRechargeAmount': monthlyRechargeAmount,
      'lastRechargeMonth': lastRechargeMonth,
      'activeSvipLevel': activeSvipLevel,
      'svipValidUntilMonth': svipValidUntilMonth,
      'banStatus': banStatus?.toMap(),
    };
  }
}

class UserBanStatus {
  DateTime? loginBanEndTime;
  DateTime? micBanEndTime;
  DateTime? chatBanEndTime;
  bool isLoginBanPermanent;
  bool isMicBanPermanent;
  bool isChatBanPermanent;

  UserBanStatus({
    this.loginBanEndTime,
    this.micBanEndTime,
    this.chatBanEndTime,
    this.isLoginBanPermanent = false,
    this.isMicBanPermanent = false,
    this.isChatBanPermanent = false,
  });

  factory UserBanStatus.fromMap(Map<String, dynamic> data) {
    return UserBanStatus(
      loginBanEndTime: data['loginBanEndTime'] is Timestamp ? (data['loginBanEndTime'] as Timestamp).toDate() : null,
      micBanEndTime: data['micBanEndTime'] is Timestamp ? (data['micBanEndTime'] as Timestamp).toDate() : null,
      chatBanEndTime: data['chatBanEndTime'] is Timestamp ? (data['chatBanEndTime'] as Timestamp).toDate() : null,
      isLoginBanPermanent: data['isLoginBanPermanent'] ?? false,
      isMicBanPermanent: data['isMicBanPermanent'] ?? false,
      isChatBanPermanent: data['isChatBanPermanent'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'loginBanEndTime': loginBanEndTime != null ? Timestamp.fromDate(loginBanEndTime!) : null,
      'micBanEndTime': micBanEndTime != null ? Timestamp.fromDate(micBanEndTime!) : null,
      'chatBanEndTime': chatBanEndTime != null ? Timestamp.fromDate(chatBanEndTime!) : null,
      'isLoginBanPermanent': isLoginBanPermanent,
      'isMicBanPermanent': isMicBanPermanent,
      'isChatBanPermanent': isChatBanPermanent,
    };
  }
}

// Supporting classes for User model
class UserLevel {
  int level;
  int currentProgress;
  int requiredForNext;
  String levelName;
  DateTime lastUpdated;

  UserLevel({
    required this.level,
    required this.currentProgress,
    required this.requiredForNext,
    required this.levelName,
    required this.lastUpdated,
  });

  factory UserLevel.fromMap(Map<String, dynamic> data) {
    return UserLevel(
      level: data['level'] ?? 1,
      currentProgress: data['currentProgress'] ?? 0,
      requiredForNext: data['requiredForNext'] ?? 100,
      levelName: data['levelName'] ?? 'Beginner',
      lastUpdated: data['lastUpdated']?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'level': level,
      'currentProgress': currentProgress,
      'requiredForNext': requiredForNext,
      'levelName': levelName,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }
}

class UserCustomization {
  String? selectedBadgeId;
  String? selectedFrameId;
  String? selectedEntryEffectId;
  String? selectedBackgroundThemeId;
  String? selectedRoomThemeId;
  String? selectedNameplateId;
  String? selectedMicRefillId;
  String? selectedRoomProfileBackgroundId;
  List<String> ownedBadges;
  List<String> ownedFrames;
  List<String> ownedEntryEffects;
  List<String> ownedBackgroundThemes;
  List<String> ownedNameplates;
  List<String> ownedMicRefills;
  List<String> ownedRoomProfileBackgrounds;

  UserCustomization({
    this.selectedBadgeId,
    this.selectedFrameId,
    this.selectedEntryEffectId,
    this.selectedBackgroundThemeId,
    this.selectedRoomThemeId,
    this.selectedNameplateId,
    this.selectedMicRefillId,
    this.selectedRoomProfileBackgroundId,
    this.ownedBadges = const [],
    this.ownedFrames = const [],
    this.ownedEntryEffects = const [],
    this.ownedBackgroundThemes = const [],
    this.ownedNameplates = const [],
    this.ownedMicRefills = const [],
    this.ownedRoomProfileBackgrounds = const [],
  });

  factory UserCustomization.fromMap(Map<String, dynamic> data) {
    return UserCustomization(
      selectedBadgeId: data['selectedBadgeId'],
      selectedFrameId: data['selectedFrameId'],
      selectedEntryEffectId: data['selectedEntryEffectId'],
      selectedBackgroundThemeId: data['selectedBackgroundThemeId'],
      selectedRoomThemeId: data['selectedRoomThemeId'],
      selectedNameplateId: data['selectedNameplateId'],
      selectedMicRefillId: data['selectedMicRefillId'],
      selectedRoomProfileBackgroundId: data['selectedRoomProfileBackgroundId'],
      ownedBadges: List<String>.from(data['ownedBadges'] ?? []),
      ownedFrames: List<String>.from(data['ownedFrames'] ?? []),
      ownedEntryEffects: List<String>.from(data['ownedEntryEffects'] ?? []),
      ownedBackgroundThemes: List<String>.from(data['ownedBackgroundThemes'] ?? []),
      ownedNameplates: List<String>.from(data['ownedNameplates'] ?? []),
      ownedMicRefills: List<String>.from(data['ownedMicRefills'] ?? []),
      ownedRoomProfileBackgrounds: List<String>.from(data['ownedRoomProfileBackgrounds'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'selectedBadgeId': selectedBadgeId,
      'selectedFrameId': selectedFrameId,
      'selectedEntryEffectId': selectedEntryEffectId,
      'selectedBackgroundThemeId': selectedBackgroundThemeId,
      'selectedRoomThemeId': selectedRoomThemeId,
      'selectedNameplateId': selectedNameplateId,
      'selectedMicRefillId': selectedMicRefillId,
      'selectedRoomProfileBackgroundId': selectedRoomProfileBackgroundId,
      'ownedBadges': ownedBadges,
      'ownedFrames': ownedFrames,
      'ownedEntryEffects': ownedEntryEffects,
      'ownedBackgroundThemes': ownedBackgroundThemes,
      'ownedNameplates': ownedNameplates,
      'ownedMicRefills': ownedMicRefills,
      'ownedRoomProfileBackgrounds': ownedRoomProfileBackgrounds,
    };
  }
}

class UserActivityStats {
  int dailyDiamondsSent;
  int dailyDiamondsReceived;
  int weeklyDiamondsSent;
  int weeklyDiamondsReceived;
  int monthlyDiamondsSent;
  int monthlyDiamondsReceived;
  int dailyVoiceRoomMinutes;
  int weeklyVoiceRoomMinutes;
  int monthlyVoiceRoomMinutes;
  DateTime lastUpdated;

  UserActivityStats({
    this.dailyDiamondsSent = 0,
    this.dailyDiamondsReceived = 0,
    this.weeklyDiamondsSent = 0,
    this.weeklyDiamondsReceived = 0,
    this.monthlyDiamondsSent = 0,
    this.monthlyDiamondsReceived = 0,
    this.dailyVoiceRoomMinutes = 0,
    this.weeklyVoiceRoomMinutes = 0,
    this.monthlyVoiceRoomMinutes = 0,
    required this.lastUpdated,
  });

  factory UserActivityStats.fromMap(Map<String, dynamic> data) {
    return UserActivityStats(
      dailyDiamondsSent: data['dailyDiamondsSent'] ?? 0,
      dailyDiamondsReceived: data['dailyDiamondsReceived'] ?? 0,
      weeklyDiamondsSent: data['weeklyDiamondsSent'] ?? 0,
      weeklyDiamondsReceived: data['weeklyDiamondsReceived'] ?? 0,
      monthlyDiamondsSent: data['monthlyDiamondsSent'] ?? 0,
      monthlyDiamondsReceived: data['monthlyDiamondsReceived'] ?? 0,
      dailyVoiceRoomMinutes: data['dailyVoiceRoomMinutes'] ?? 0,
      weeklyVoiceRoomMinutes: data['weeklyVoiceRoomMinutes'] ?? 0,
      monthlyVoiceRoomMinutes: data['monthlyVoiceRoomMinutes'] ?? 0,
      lastUpdated: data['lastUpdated']?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'dailyDiamondsSent': dailyDiamondsSent,
      'dailyDiamondsReceived': dailyDiamondsReceived,
      'weeklyDiamondsSent': weeklyDiamondsSent,
      'weeklyDiamondsReceived': weeklyDiamondsReceived,
      'monthlyDiamondsSent': monthlyDiamondsSent,
      'monthlyDiamondsReceived': monthlyDiamondsReceived,
      'dailyVoiceRoomMinutes': dailyVoiceRoomMinutes,
      'weeklyVoiceRoomMinutes': weeklyVoiceRoomMinutes,
      'monthlyVoiceRoomMinutes': monthlyVoiceRoomMinutes,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }
}

class UserPunishment {
  String id;
  String reason;
  String type; // warning, temporaryBlock, permanentBlock, suspension
  DateTime issuedAt;
  DateTime? expiresAt;
  String issuedBy;
  bool isActive;

  UserPunishment({
    required this.id,
    required this.reason,
    required this.type,
    required this.issuedAt,
    this.expiresAt,
    required this.issuedBy,
    this.isActive = true,
  });

  factory UserPunishment.fromMap(Map<String, dynamic> data) {
    return UserPunishment(
      id: data['id'] ?? '',
      reason: data['reason'] ?? '',
      type: data['type'] ?? 'warning',
      issuedAt: data['issuedAt']?.toDate() ?? DateTime.now(),
      expiresAt: data['expiresAt']?.toDate(),
      issuedBy: data['issuedBy'] ?? '',
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reason': reason,
      'type': type,
      'issuedAt': Timestamp.fromDate(issuedAt),
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'issuedBy': issuedBy,
      'isActive': isActive,
    };
  }
}

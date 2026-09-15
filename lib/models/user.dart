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

  // SVIP tracking (Strictly Seller Page Recharge Only)
  int monthlyRechargeAmount;
  int eligibleSellerRechargeAmount;
  int totalEligibleSellerRechargeAmount;
  String lastRechargeMonth;
  int activeSvipLevel;
  String svipValidUntilMonth;

  // VIP tracking
  int activeVipLevel;
  String vipValidUntilMonth;
  DateTime? vipValidUntil;

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
    this.eligibleSellerRechargeAmount = 0,
    this.totalEligibleSellerRechargeAmount = 0,
    this.lastRechargeMonth = '',
    this.activeSvipLevel = 0,
    this.svipValidUntilMonth = '',
    this.activeVipLevel = 0,
    this.vipValidUntilMonth = '',
    this.vipValidUntil,
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
      monthlyRechargeAmount: (data['monthlyRechargeAmount'] as num?)?.toInt() ?? 0,
      eligibleSellerRechargeAmount: (data['eligibleSellerRechargeAmount'] as num?)?.toInt() ?? 0,
      totalEligibleSellerRechargeAmount: (data['totalEligibleSellerRechargeAmount'] as num?)?.toInt() ?? 0,
      lastRechargeMonth: data['lastRechargeMonth'] ?? '',
      activeSvipLevel: (data['activeSvipLevel'] as num?)?.toInt() ?? 0,
      svipValidUntilMonth: data['svipValidUntilMonth'] ?? '',
      activeVipLevel: data['activeVipLevel'] ?? 0,
      vipValidUntilMonth: data['vipValidUntilMonth'] ?? '',
      vipValidUntil: data['vipValidUntil'] != null 
          ? (data['vipValidUntil'] is Timestamp 
              ? (data['vipValidUntil'] as Timestamp).toDate() 
              : DateTime.tryParse(data['vipValidUntil'].toString())) 
          : null,
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
      'eligibleSellerRechargeAmount': eligibleSellerRechargeAmount,
      'totalEligibleSellerRechargeAmount': totalEligibleSellerRechargeAmount,
      'lastRechargeMonth': lastRechargeMonth,
      'activeSvipLevel': activeSvipLevel,
      'svipValidUntilMonth': svipValidUntilMonth,
      'activeVipLevel': activeVipLevel,
      'vipValidUntilMonth': vipValidUntilMonth,
      'vipValidUntil': vipValidUntil != null ? Timestamp.fromDate(vipValidUntil!) : null,
      'banStatus': banStatus?.toMap(),
    };
  }
}

class UserBanStatus {
  DateTime? loginBanEndTime;
  DateTime? micBanEndTime;
  DateTime? chatBanEndTime;
  DateTime? postBanEndTime;
  bool isLoginBanPermanent;
  bool isMicBanPermanent;
  bool isChatBanPermanent;
  bool isPostBanPermanent;

  UserBanStatus({
    this.loginBanEndTime,
    this.micBanEndTime,
    this.chatBanEndTime,
    this.postBanEndTime,
    this.isLoginBanPermanent = false,
    this.isMicBanPermanent = false,
    this.isChatBanPermanent = false,
    this.isPostBanPermanent = false,
  });

  factory UserBanStatus.fromMap(Map<String, dynamic> data) {
    return UserBanStatus(
      loginBanEndTime: data['loginBanEndTime'] is Timestamp ? (data['loginBanEndTime'] as Timestamp).toDate() : null,
      micBanEndTime: data['micBanEndTime'] is Timestamp ? (data['micBanEndTime'] as Timestamp).toDate() : null,
      chatBanEndTime: data['chatBanEndTime'] is Timestamp ? (data['chatBanEndTime'] as Timestamp).toDate() : null,
      postBanEndTime: data['postBanEndTime'] is Timestamp ? (data['postBanEndTime'] as Timestamp).toDate() : null,
      isLoginBanPermanent: data['isLoginBanPermanent'] ?? false,
      isMicBanPermanent: data['isMicBanPermanent'] ?? false,
      isChatBanPermanent: data['isChatBanPermanent'] ?? false,
      isPostBanPermanent: data['isPostBanPermanent'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'loginBanEndTime': loginBanEndTime != null ? Timestamp.fromDate(loginBanEndTime!) : null,
      'micBanEndTime': micBanEndTime != null ? Timestamp.fromDate(micBanEndTime!) : null,
      'chatBanEndTime': chatBanEndTime != null ? Timestamp.fromDate(chatBanEndTime!) : null,
      'postBanEndTime': postBanEndTime != null ? Timestamp.fromDate(postBanEndTime!) : null,
      'isLoginBanPermanent': isLoginBanPermanent,
      'isMicBanPermanent': isMicBanPermanent,
      'isChatBanPermanent': isChatBanPermanent,
      'isPostBanPermanent': isPostBanPermanent,
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
  List<String> selectedNameplateIds;
  String? selectedMicRefillId;
  String? selectedRoomProfileBackgroundId;
  String? selectedShortProfileThemeId;
  String? selectedRoomEntryId;
  List<String> ownedBadges;
  List<String> ownedFrames;
  List<String> ownedEntryEffects;
  List<String> ownedBackgroundThemes;
  List<String> ownedNameplates;
  List<String> ownedMicRefills;
  List<String> ownedRoomProfileBackgrounds;
  List<String> ownedShortProfileThemes;
  List<String> ownedRoomEntries;

  UserCustomization({
    this.selectedBadgeId,
    this.selectedFrameId,
    this.selectedEntryEffectId,
    this.selectedBackgroundThemeId,
    this.selectedRoomThemeId,
    this.selectedNameplateId,
    this.selectedNameplateIds = const [],
    this.selectedMicRefillId,
    this.selectedRoomProfileBackgroundId,
    this.selectedShortProfileThemeId,
    this.selectedRoomEntryId,
    this.ownedBadges = const [],
    this.ownedFrames = const [],
    this.ownedEntryEffects = const [],
    this.ownedBackgroundThemes = const [],
    this.ownedNameplates = const [],
    this.ownedMicRefills = const [],
    this.ownedRoomProfileBackgrounds = const [],
    this.ownedShortProfileThemes = const [],
    this.ownedRoomEntries = const [],
  }) {
    if (selectedNameplateIds.isEmpty && selectedNameplateId != null && selectedNameplateId!.isNotEmpty) {
      selectedNameplateIds = [selectedNameplateId!];
    }
  }

  factory UserCustomization.fromMap(Map<String, dynamic> data) {
    final nameplateId = data['selectedNameplateId'] as String?;
    List<String> nameplateIds = [];
    if (data['selectedNameplateIds'] != null) {
      nameplateIds = (data['selectedNameplateIds'] as List?)?.whereType<String>().toList() ?? [];
    } else if (nameplateId != null && nameplateId.isNotEmpty) {
      nameplateIds = [nameplateId];
    }

    return UserCustomization(
      selectedBadgeId: data['selectedBadgeId'] as String?,
      selectedFrameId: data['selectedFrameId'] as String?,
      selectedEntryEffectId: data['selectedEntryEffectId'] as String?,
      selectedBackgroundThemeId: data['selectedBackgroundThemeId'] as String?,
      selectedRoomThemeId: data['selectedRoomThemeId'] as String?,
      selectedNameplateId: nameplateId ?? (nameplateIds.isNotEmpty ? nameplateIds.first : null),
      selectedNameplateIds: nameplateIds,
      selectedMicRefillId: data['selectedMicRefillId'] as String?,
      selectedRoomProfileBackgroundId: data['selectedRoomProfileBackgroundId'] as String?,
      selectedShortProfileThemeId: data['selectedShortProfileThemeId'] as String?,
      selectedRoomEntryId: data['selectedRoomEntryId'] as String?,
      ownedBadges: (data['ownedBadges'] as List?)?.whereType<String>().toList() ?? [],
      ownedFrames: (data['ownedFrames'] as List?)?.whereType<String>().toList() ?? [],
      ownedEntryEffects: (data['ownedEntryEffects'] as List?)?.whereType<String>().toList() ?? [],
      ownedBackgroundThemes: (data['ownedBackgroundThemes'] as List?)?.whereType<String>().toList() ?? [],
      ownedNameplates: (data['ownedNameplates'] as List?)?.whereType<String>().toList() ?? [],
      ownedMicRefills: (data['ownedMicRefills'] as List?)?.whereType<String>().toList() ?? [],
      ownedRoomProfileBackgrounds: (data['ownedRoomProfileBackgrounds'] as List?)?.whereType<String>().toList() ?? [],
      ownedShortProfileThemes: (data['ownedShortProfileThemes'] as List?)?.whereType<String>().toList() ?? [],
      ownedRoomEntries: (data['ownedRoomEntries'] as List?)?.whereType<String>().toList() ?? [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'selectedBadgeId': selectedBadgeId,
      'selectedFrameId': selectedFrameId,
      'selectedEntryEffectId': selectedEntryEffectId,
      'selectedBackgroundThemeId': selectedBackgroundThemeId,
      'selectedRoomThemeId': selectedRoomThemeId,
      'selectedNameplateId': selectedNameplateId ?? (selectedNameplateIds.isNotEmpty ? selectedNameplateIds.first : null),
      'selectedNameplateIds': selectedNameplateIds,
      'selectedMicRefillId': selectedMicRefillId,
      'selectedRoomProfileBackgroundId': selectedRoomProfileBackgroundId,
      'selectedShortProfileThemeId': selectedShortProfileThemeId,
      'selectedRoomEntryId': selectedRoomEntryId,
      'ownedBadges': ownedBadges,
      'ownedFrames': ownedFrames,
      'ownedEntryEffects': ownedEntryEffects,
      'ownedBackgroundThemes': ownedBackgroundThemes,
      'ownedNameplates': ownedNameplates,
      'ownedMicRefills': ownedMicRefills,
      'ownedRoomProfileBackgrounds': ownedRoomProfileBackgrounds,
      'ownedShortProfileThemes': ownedShortProfileThemes,
      'ownedRoomEntries': ownedRoomEntries,
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

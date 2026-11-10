import 'package:cloud_firestore/cloud_firestore.dart';

class EventModel {
  final String id;
  final String eventId;
  final String eventName;
  final String banner;
  final String description;
  final String rules;
  final List<Map<String, dynamic>> rewards;
  final String rankingType;
  final DateTime startTime;
  final DateTime endTime;
  final String status; // 'active', 'inactive', 'expired'
  final String eventLink;
  final String deepLink;
  final DateTime createdAt;
  final bool hasRegistrationForm;
  final List<Map<String, dynamic>> bannerClickableAreas;
  final String eventType;
  final List<String> eligibleGiftIds; // specific gifts that count towards event
  final int minRequiredDiamonds; // minimum diamond threshold to qualify
  
  final String htmlContent;
  final String customSlug;
  final String customDomain;

  // Theme & Layout Builder
  final Map<String, dynamic> themeConfig;
  final List<Map<String, dynamic>> layoutBlocks;
  final double pointMultiplier;
  final String scoringMode;
  final List<Map<String, dynamic>> targetMilestones;
  final List<Map<String, dynamic>> rewardTiers;

  final int viewsCount;
  final int likesCount;

  String get fullEventUrl {
    final base = (customDomain.isNotEmpty ? customDomain : 'https://ev.imchatapp.com').replaceAll(RegExp(r'/+$'), '');
    final slug = customSlug.trim().isNotEmpty ? customSlug.trim() : eventId;
    return '$base/e/$slug';
  }

  EventModel({
    required this.id,
    required this.eventId,
    required this.eventName,
    required this.banner,
    required this.description,
    required this.rules,
    required this.rewards,
    required this.rankingType,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.eventLink,
    required this.deepLink,
    required this.createdAt,
    this.hasRegistrationForm = false,
    this.bannerClickableAreas = const [],
    this.eventType = 'weekly_star',
    this.eligibleGiftIds = const [],
    this.minRequiredDiamonds = 0,
    this.htmlContent = '',
    this.customSlug = '',
    this.customDomain = 'https://ev.imchatapp.com',
    this.themeConfig = const {},
    this.layoutBlocks = const [],
    this.pointMultiplier = 1.0,
    this.scoringMode = 'diamonds',
    this.targetMilestones = const [],
    this.rewardTiers = const [],
    this.viewsCount = 0,
    this.likesCount = 0,
  });

  static List<Map<String, dynamic>> _parseListMap(dynamic val) {
    if (val == null || val is! List) return <Map<String, dynamic>>[];
    final List<Map<String, dynamic>> result = [];
    for (var item in val) {
      if (item is Map) {
        result.add(Map<String, dynamic>.from(item));
      }
    }
    return result;
  }

  static Map<String, dynamic> _parseMap(dynamic val) {
    if (val == null || val is! Map) return <String, dynamic>{};
    return Map<String, dynamic>.from(val);
  }

  static List<String> _parseStringList(dynamic val) {
    if (val == null || val is! List) return <String>[];
    return val.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList();
  }

  factory EventModel.fromMap(Map<String, dynamic> data, String id) {
    final domain = (data['customDomain'] as String?)?.trim() ?? 'https://ev.imchatapp.com';
    final slug = (data['customSlug'] as String?)?.trim() ?? '';
    final eId = data['eventId']?.toString() ?? '';
    final defaultLink = '$domain/e/${slug.isNotEmpty ? slug : eId}';

    return EventModel(
      id: id,
      eventId: eId,
      eventName: data['eventName']?.toString() ?? '',
      banner: data['banner']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      rules: data['rules']?.toString() ?? '',
      rewards: _parseListMap(data['rewards']),
      rankingType: data['rankingType']?.toString() ?? 'Top Sender',
      startTime: (data['startTime'] is Timestamp) ? (data['startTime'] as Timestamp).toDate() : DateTime.now(),
      endTime: (data['endTime'] is Timestamp) ? (data['endTime'] as Timestamp).toDate() : DateTime.now(),
      status: data['status']?.toString() ?? 'inactive',
      eventLink: data['eventLink']?.toString() ?? defaultLink,
      deepLink: data['deepLink']?.toString() ?? 'imchat://event/${slug.isNotEmpty ? slug : eId}',
      createdAt: (data['createdAt'] is Timestamp) ? (data['createdAt'] as Timestamp).toDate() : DateTime.now(),
      hasRegistrationForm: data['hasRegistrationForm'] == true,
      bannerClickableAreas: _parseListMap(data['bannerClickableAreas']),
      eventType: data['eventType']?.toString() ?? 'weekly_star',
      eligibleGiftIds: _parseStringList(data['eligibleGiftIds']),
      minRequiredDiamonds: (data['minRequiredDiamonds'] as num?)?.toInt() ?? 0,
      htmlContent: data['htmlContent']?.toString() ?? '',
      customSlug: slug,
      customDomain: domain,
      themeConfig: _parseMap(data['themeConfig']),
      layoutBlocks: _parseListMap(data['layoutBlocks']),
      pointMultiplier: (data['pointMultiplier'] as num?)?.toDouble() ?? 1.0,
      scoringMode: data['scoringMode']?.toString() ?? 'diamonds',
      targetMilestones: _parseListMap(data['targetMilestones']),
      rewardTiers: _parseListMap(data['rewardTiers']),
      viewsCount: (data['viewsCount'] as num?)?.toInt() ?? 0,
      likesCount: (data['likesCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'eventName': eventName,
      'banner': banner,
      'description': description,
      'rules': rules,
      'rewards': rewards,
      'rankingType': rankingType,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'status': status,
      'eventLink': eventLink.isNotEmpty ? eventLink : fullEventUrl,
      'deepLink': deepLink.isNotEmpty ? deepLink : 'imchat://event/${customSlug.isNotEmpty ? customSlug : eventId}',
      'createdAt': Timestamp.fromDate(createdAt),
      'hasRegistrationForm': hasRegistrationForm,
      'bannerClickableAreas': bannerClickableAreas,
      'eventType': eventType,
      'eligibleGiftIds': eligibleGiftIds,
      'minRequiredDiamonds': minRequiredDiamonds,
      'htmlContent': htmlContent,
      'customSlug': customSlug,
      'customDomain': customDomain,
      'themeConfig': themeConfig,
      'layoutBlocks': layoutBlocks,
      'pointMultiplier': pointMultiplier,
      'scoringMode': scoringMode,
      'targetMilestones': targetMilestones,
      'rewardTiers': rewardTiers,
      'viewsCount': viewsCount,
      'likesCount': likesCount,
    };
  }
}

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
  
  // Theme & Layout Builder
  final Map<String, dynamic> themeConfig;
  final List<Map<String, dynamic>> layoutBlocks;

  final int viewsCount;
  final int likesCount;

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
    this.themeConfig = const {},
    this.layoutBlocks = const [],
    this.viewsCount = 0,
    this.likesCount = 0,
  });

  factory EventModel.fromMap(Map<String, dynamic> data, String id) {
    return EventModel(
      id: id,
      eventId: data['eventId'] ?? '',
      eventName: data['eventName'] ?? '',
      banner: data['banner'] ?? '',
      description: data['description'] ?? '',
      rules: data['rules'] ?? '',
      rewards: List<Map<String, dynamic>>.from(data['rewards'] ?? []),
      rankingType: data['rankingType'] ?? 'Top Sender',
      startTime: (data['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endTime: (data['endTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'inactive',
      eventLink: data['eventLink'] ?? '',
      deepLink: data['deepLink'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      hasRegistrationForm: data['hasRegistrationForm'] ?? false,
      bannerClickableAreas: List<Map<String, dynamic>>.from(data['bannerClickableAreas'] ?? []),
      eventType: data['eventType'] ?? 'weekly_star',
      eligibleGiftIds: List<String>.from(data['eligibleGiftIds'] ?? []),
      themeConfig: Map<String, dynamic>.from(data['themeConfig'] ?? {}),
      layoutBlocks: List<Map<String, dynamic>>.from(data['layoutBlocks'] ?? []),
      viewsCount: data['viewsCount'] ?? 0,
      likesCount: data['likesCount'] ?? 0,
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
      'eventLink': eventLink,
      'deepLink': deepLink,
      'createdAt': Timestamp.fromDate(createdAt),
      'hasRegistrationForm': hasRegistrationForm,
      'bannerClickableAreas': bannerClickableAreas,
      'eventType': eventType,
      'eligibleGiftIds': eligibleGiftIds,
      'themeConfig': themeConfig,
      'layoutBlocks': layoutBlocks,
      'viewsCount': viewsCount,
      'likesCount': likesCount,
    };
  }
}

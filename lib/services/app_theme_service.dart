import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AppThemeService extends GetxService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Rx Variables for Real-time Updates
  final RxString appLogoUrl = ''.obs;
  final RxString diamondIconUrl = ''.obs;
  final RxString beansIconUrl = ''.obs;
  final RxString defaultAvatarUrl = ''.obs;

  final RxString splashImageUrl = ''.obs;
  final Rx<Color?> splashColor = Rx<Color?>(null);
  final Rx<Color?> splashTextColor = Rx<Color?>(null);

  final RxMap<String, String> screenBgUrls = <String, String>{}.obs;
  final RxMap<String, Color> screenBgColors = <String, Color>{}.obs;
  final RxMap<String, Color> screenTextColors = <String, Color>{}.obs;
  final RxMap<String, Color> screenSecondaryTextColors = <String, Color>{}.obs;

  final RxMap<String, String> leaderboardFrames = <String, String>{}.obs;
  final RxString leaderboardBgUrl = ''.obs;
  final RxString top1FrameUrl = ''.obs;
  final RxString top2FrameUrl = ''.obs;
  final RxString top3FrameUrl = ''.obs;
  final RxString leaderboardPodiumUrl = ''.obs;
  final Rx<Color?> leaderboardBgColor = Rx<Color?>(null);
  final Rx<Color?> leaderboardTextColor = Rx<Color?>(null);
  final Rx<Color?> leaderboardSecondaryTextColor = Rx<Color?>(null);

  // Dynamic bottom bar and room settings icons
  final RxString giftBoxIconUrl = ''.obs;
  final RxString gameWallIconUrl = ''.obs;
  final RxMap<String, String> roomSettingsIcons = <String, String>{}.obs;

  // Dynamic TabBar & Header Action Icons
  final RxString tabChatIconUrl = ''.obs;
  final RxString tabHomeIconUrl = ''.obs;
  final RxString tabGlobeIconUrl = ''.obs;
  final RxString tabContactsIconUrl = ''.obs;
  final RxString searchIconUrl = ''.obs;
  final RxString trophyIconUrl = ''.obs;

  @override
  void onInit() {
    super.onInit();
    _listenToThemeChanges();
  }

  void _listenToThemeChanges() {
    _firestore
        .collection('global_settings')
        .doc('app_theme')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data()!;

        // General Assets
        appLogoUrl.value = data['appLogoUrl'] ?? '';
        diamondIconUrl.value = data['diamondIconUrl'] ?? '';
        beansIconUrl.value = data['beansIconUrl'] ?? '';
        defaultAvatarUrl.value = data['defaultAvatarUrl'] ?? '';

        // Tab Bar & Header Action Icons
        tabChatIconUrl.value = data['tabChatIconUrl'] ?? '';
        tabHomeIconUrl.value = data['tabHomeIconUrl'] ?? '';
        tabGlobeIconUrl.value = data['tabGlobeIconUrl'] ?? '';
        tabContactsIconUrl.value = data['tabContactsIconUrl'] ?? '';
        searchIconUrl.value = data['searchIconUrl'] ?? '';
        trophyIconUrl.value = data['trophyIconUrl'] ?? '';

        debugPrint('🎨 [AppThemeService] Tab & Header icons updated: chat=${tabChatIconUrl.value}, home=${tabHomeIconUrl.value}, globe=${tabGlobeIconUrl.value}, contacts=${tabContactsIconUrl.value}, search=${searchIconUrl.value}, trophy=${trophyIconUrl.value}');

        // Splash Screen
        splashImageUrl.value = data['splashImageUrl'] ?? '';
        splashColor.value = _hexToColor(data['splashColor']);
        splashTextColor.value = _hexToColor(data['splashTextColor']);

        // Screen Themes
        if (data['screenThemes'] is Map) {
          final Map<String, dynamic> themes = data['screenThemes'];

          final Map<String, String> urls = {};
          final Map<String, Color> colors = {};
          final Map<String, Color> textColors = {};
          final Map<String, Color> secondaryTextColors = {};

          themes.forEach((key, value) {
            if (key.endsWith('BgUrl') && value.toString().isNotEmpty) {
              final screenName = key.replaceAll('BgUrl', '');
              urls[screenName] = value.toString();
            } else if (key.endsWith('SecondaryTextColor') && value.toString().isNotEmpty) {
              final screenName = key.replaceAll('SecondaryTextColor', '');
              final parsedColor = _hexToColor(value.toString());
              if (parsedColor != null) {
                secondaryTextColors[screenName] = parsedColor;
              }
            } else if (key.endsWith('TextColor') && value.toString().isNotEmpty) {
              final screenName = key.replaceAll('TextColor', '');
              final parsedColor = _hexToColor(value.toString());
              if (parsedColor != null) {
                textColors[screenName] = parsedColor;
              }
            } else if (key.endsWith('Color') && value.toString().isNotEmpty) {
              final screenName = key.replaceAll('Color', '');
              final parsedColor = _hexToColor(value.toString());
              if (parsedColor != null) {
                colors[screenName] = parsedColor;
              }
            }
          });

          screenBgUrls.assignAll(urls);
          screenBgColors.assignAll(colors);
          screenTextColors.assignAll(textColors);
          screenSecondaryTextColors.assignAll(secondaryTextColors);
          debugPrint('🎨 [AppThemeService] Screen themes updated: colors=$screenBgColors, textColors=$screenTextColors, secondary=$screenSecondaryTextColors');
        }

        // Leaderboard Visuals & Frames
        String lbUrl = (data['leaderboardBgUrl'] ?? '').toString();
        if (lbUrl.isEmpty && data['screenThemes'] is Map) {
          lbUrl = (data['screenThemes']['leaderboardBgUrl'] ?? '').toString();
        }
        if (lbUrl.isEmpty && data['leaderboardFrames'] is Map) {
          lbUrl = (data['leaderboardFrames']['backgroundUrl'] ?? '').toString();
        }
        leaderboardBgUrl.value = lbUrl;
        top1FrameUrl.value = (data['top1FrameUrl'] ?? '').toString();
        top2FrameUrl.value = (data['top2FrameUrl'] ?? '').toString();
        top3FrameUrl.value = (data['top3FrameUrl'] ?? '').toString();
        leaderboardPodiumUrl.value = (data['leaderboardPodiumUrl'] ?? '').toString();

        if (data['leaderboardFrames'] is Map) {
          final Map<String, dynamic> lbData = data['leaderboardFrames'];
          final Map<String, String> frames = {};

          lbData.forEach((key, value) {
            if (key == 'backgroundColor') {
              leaderboardBgColor.value = _hexToColor(value.toString());
            } else if (key == 'textColor') {
              leaderboardTextColor.value = _hexToColor(value.toString());
            } else if (key == 'secondaryTextColor') {
              leaderboardSecondaryTextColor.value = _hexToColor(value.toString());
            } else if (key == 'backgroundUrl' && leaderboardBgUrl.value.isEmpty) {
              leaderboardBgUrl.value = value.toString();
            } else if (value.toString().isNotEmpty) {
              frames[key] = value.toString();
            }
          });

          // Sync top1, top2, top3 from map if not set at top level
          if (top1FrameUrl.value.isEmpty && frames['1'] != null) {
            top1FrameUrl.value = frames['1']!;
          }
          if (top2FrameUrl.value.isEmpty && frames['2'] != null) {
            top2FrameUrl.value = frames['2']!;
          }
          if (top3FrameUrl.value.isEmpty && frames['3'] != null) {
            top3FrameUrl.value = frames['3']!;
          }

          leaderboardFrames.assignAll(frames);
        }

        // Bottom Bar & Room Settings Icons
        giftBoxIconUrl.value = data['giftBoxIconUrl'] ?? '';
        gameWallIconUrl.value = data['gameWallIconUrl'] ?? '';

        final dynamic rawIcons =
            data['roomSettingsIcons'] ?? data['roomControlIcons'];
        if (rawIcons is Map) {
          final Map<dynamic, dynamic> iconsMap = rawIcons;
          final Map<String, String> parsedIcons = {};
          iconsMap.forEach((key, value) {
            if (value.toString().isNotEmpty) {
              parsedIcons[key.toString()] = value.toString();
            }
          });
          roomSettingsIcons.assignAll(parsedIcons);
          debugPrint(
              '🎨 [AppThemeService] Updated room control icons: $roomSettingsIcons');
        } else {
          roomSettingsIcons.clear();
          debugPrint(
              '🎨 [AppThemeService] No room control icons map found in config');
        }
      }
    }, onError: (e) {
      debugPrint('Error listening to app theme config: $e');
    });
  }

  // --- Helper Methods ---

  Color? _hexToColor(String? hexString) {
    if (hexString == null) return null;
    String cleanHex = hexString.trim().replaceAll('#', '');
    if (cleanHex.toLowerCase().startsWith('0x')) {
      cleanHex = cleanHex.substring(2);
    }
    if (cleanHex.isEmpty) return null;
    if (cleanHex.length == 3) {
      cleanHex = 'FF${cleanHex[0]}${cleanHex[0]}${cleanHex[1]}${cleanHex[1]}${cleanHex[2]}${cleanHex[2]}';
    } else if (cleanHex.length == 6) {
      cleanHex = 'FF$cleanHex';
    } else if (cleanHex.length == 8) {
      // already 8 hex digits ARGB
    } else {
      return null;
    }
    try {
      return Color(int.parse(cleanHex, radix: 16));
    } catch (e) {
      return null;
    }
  }

  /// Get the background color for a specific screen (e.g. 'home', 'profile', 'room')
  Color? getScreenColor(String screenName) => screenBgColors[screenName];

  /// Get the primary text color for a specific screen (e.g. 'home', 'profile', 'room')
  Color? getScreenTextColor(String screenName) => screenTextColors[screenName];

  /// Get the secondary text color for a specific screen
  Color? getScreenSecondaryTextColor(String screenName) =>
      screenSecondaryTextColors[screenName];

  /// Get the background image URL for a specific screen
  String? getScreenBgUrl(String screenName) => screenBgUrls[screenName];

  /// Get the frame URL for a specific leaderboard rank (e.g., rank 1, 2, 3)
  String? getLeaderboardFrameUrl(String category, int rank) {
    if (rank == 1 && top1FrameUrl.value.isNotEmpty) return top1FrameUrl.value;
    if (rank == 2 && top2FrameUrl.value.isNotEmpty) return top2FrameUrl.value;
    if (rank == 3 && top3FrameUrl.value.isNotEmpty) return top3FrameUrl.value;
    return leaderboardFrames['$rank'] ??
        leaderboardFrames['rank$rank'] ??
        leaderboardFrames['top${rank}FrameUrl'] ??
        leaderboardFrames['${category}_rank${rank}_url'];
  }
}

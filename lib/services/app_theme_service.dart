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
  
  final RxMap<String, String> screenBgUrls = <String, String>{}.obs;
  final RxMap<String, Color> screenBgColors = <String, Color>{}.obs;

  final RxMap<String, String> leaderboardFrames = <String, String>{}.obs;
  final Rx<Color?> leaderboardBgColor = Rx<Color?>(null);

  @override
  void onInit() {
    super.onInit();
    _listenToThemeChanges();
  }

  void _listenToThemeChanges() {
    _firestore.collection('global_settings').doc('app_theme').snapshots().listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data()!;
        
        // General Assets
        appLogoUrl.value = data['appLogoUrl'] ?? '';
        diamondIconUrl.value = data['diamondIconUrl'] ?? '';
        beansIconUrl.value = data['beansIconUrl'] ?? '';
        defaultAvatarUrl.value = data['defaultAvatarUrl'] ?? '';
        
        // Splash Screen
        splashImageUrl.value = data['splashImageUrl'] ?? '';
        splashColor.value = _hexToColor(data['splashColor']);
        
        // Screen Themes
        if (data['screenThemes'] is Map) {
          final Map<String, dynamic> themes = data['screenThemes'];
          
          final Map<String, String> urls = {};
          final Map<String, Color> colors = {};
          
          themes.forEach((key, value) {
            if (key.endsWith('BgUrl') && value.toString().isNotEmpty) {
              final screenName = key.replaceAll('BgUrl', '');
              urls[screenName] = value.toString();
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
        }
        
        // Leaderboard Frames
        if (data['leaderboardFrames'] is Map) {
          final Map<String, dynamic> lbData = data['leaderboardFrames'];
          final Map<String, String> frames = {};
          
          lbData.forEach((key, value) {
            if (key == 'backgroundColor') {
              leaderboardBgColor.value = _hexToColor(value.toString());
            } else if (value.toString().isNotEmpty) {
              frames[key] = value.toString();
            }
          });
          
          leaderboardFrames.assignAll(frames);
        }
      }
    }, onError: (e) {
      debugPrint('Error listening to app theme config: $e');
    });
  }

  // --- Helper Methods ---

  Color? _hexToColor(String? hexString) {
    if (hexString == null || hexString.isEmpty) return null;
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    try {
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (e) {
      return null;
    }
  }

  /// Get the background color for a specific screen (e.g. 'home', 'profile', 'room')
  Color? getScreenColor(String screenName) => screenBgColors[screenName];
  
  /// Get the background image URL for a specific screen
  String? getScreenBgUrl(String screenName) => screenBgUrls[screenName];

  /// Get the frame URL for a specific leaderboard rank (e.g., 'sender_rank1_url')
  String? getLeaderboardFrameUrl(String category, int rank) {
    return leaderboardFrames['${category}_rank${rank}_url'];
  }
}

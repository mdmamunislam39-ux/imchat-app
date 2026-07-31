import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:app_links/app_links.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/audio_rooms_v2_integration.dart';
import 'package:chat_messenger/screens/news_feed/single_post_screen.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/routes/app_routes.dart';

class DeepLinkService extends GetxService {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  Future<DeepLinkService> init() async {
    _appLinks = AppLinks();

    // 1. Check Initial App Links
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      debugPrint('Error handling initial app link: $e');
    }

    // 2. Listen to App Links in foreground
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    }, onError: (err) {
      debugPrint('Error handling deep link stream: $err');
    });

    return this;
  }

  Future<void> _handleDeepLink(Uri uri) async {
    debugPrint('Received Deep Link: $uri');

    final pathSegments = uri.pathSegments;
    if (pathSegments.isEmpty) return;

    if (pathSegments[0] == 'room' && pathSegments.length > 1) {
      final roomId = pathSegments[1];
      await _processRoomJoin(roomId);
    } else if (pathSegments[0] == 'audioroom' && uri.queryParameters.containsKey('id')) {
      final roomId = uri.queryParameters['id']!;
      await _processRoomJoin(roomId);
    } else if (pathSegments[0] == 'post' && pathSegments.length > 1) {
      final postId = pathSegments[1];
      Get.to(() => SinglePostScreen(postId: postId));
    }
  }

  Future<void> _processRoomJoin(String roomId) async {
    final authController = Get.isRegistered<AuthController>() ? Get.find<AuthController>() : null;
    
    // Check if user is logged in
    if (authController != null && authController.firebaseUser != null) {
      // User logged in -> join immediately
      AudioRoomsV2Integration.joinRoomById(roomId);
    } else {
      // User not logged in -> save pending ID and redirect
      debugPrint('User not logged in. Saving pending room ID: $roomId');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_room_id', roomId);
      Get.offAllNamed(AppRoutes.phoneSignIn);
    }
  }

  static Future<void> checkPendingRoom() async {
    final prefs = await SharedPreferences.getInstance();
    final roomId = prefs.getString('pending_room_id');
    if (roomId != null && roomId.isNotEmpty) {
      // Clear the pending ID and join the room
      await prefs.remove('pending_room_id');
      Future.delayed(const Duration(milliseconds: 500), () {
        AudioRoomsV2Integration.joinRoomById(roomId);
      });
    }
  }

  // Generate standard app link
  static String generateRoomLink(String roomId) {
    return 'https://imchatapp.com/room/$roomId';
  }

  static String generatePostLink(String postId) {
    return 'https://imchatapp.com/post/$postId';
  }

  @override
  void onClose() {
    _linkSubscription?.cancel();
    super.onClose();
  }
}

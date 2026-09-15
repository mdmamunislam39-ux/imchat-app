import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:app_links/app_links.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/audio_rooms_v2_integration.dart';
import 'package:chat_messenger/screens/news_feed/single_post_screen.dart';
import 'package:chat_messenger/screens/events/event_details_screen.dart';
import 'package:chat_messenger/services/event_service.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/routes/app_routes.dart';

class DeepLinkService extends GetxService {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  Future<DeepLinkService> init() async {
    _appLinks = AppLinks();

    // 1. Check Initial App Link (Cold Start)
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        debugPrint('🔗 Initial Deep Link found on cold start: $initialUri');
        await _storePendingLinkFromUri(initialUri);
      }
    } catch (e) {
      debugPrint('Error handling initial app link: $e');
    }

    // 2. Listen to App Links stream in foreground & background
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      debugPrint('🔗 Received Deep Link Stream: $uri');
      _handleDeepLink(uri);
    }, onError: (err) {
      debugPrint('Error handling deep link stream: $err');
    });

    return this;
  }

  // Universal parser for all deep link URIs (e.g. https://imchatapp.com/room/123, imchat://post/456, imchat://event/EVT1001)
  static Map<String, String>? parseDeepLink(Uri uri) {
    final host = uri.host.toLowerCase().trim();
    final pathSegments = uri.pathSegments.where((s) => s.isNotEmpty).toList();

    // Extract potential query IDs (?id=..., ?roomId=..., ?postId=..., ?eventId=...)
    final String? queryId = uri.queryParameters['id'] ??
        uri.queryParameters['roomId'] ??
        uri.queryParameters['postId'] ??
        uri.queryParameters['eventId'];

    // Case 1: Custom Scheme format (e.g. imchat://room/123 or imchat://post/456 or imchat://event/EVT1001)
    // In Uri: host = 'room'|'post'|'event', pathSegments = ['123']
    if (host == 'room' || host == 'audioroom') {
      final roomId =
          (pathSegments.isNotEmpty ? pathSegments[0] : null) ?? queryId;
      if (roomId != null && roomId.isNotEmpty) {
        return {'type': 'room', 'id': roomId.trim()};
      }
    } else if (host == 'post') {
      final postId =
          (pathSegments.isNotEmpty ? pathSegments[0] : null) ?? queryId;
      if (postId != null && postId.isNotEmpty) {
        return {'type': 'post', 'id': postId.trim()};
      }
    } else if (host == 'event') {
      final eventId =
          (pathSegments.isNotEmpty ? pathSegments[0] : null) ?? queryId;
      if (eventId != null && eventId.isNotEmpty) {
        return {'type': 'event', 'id': eventId.trim()};
      }
    }

    // Case 2: Standard HTTPS domain format (e.g. https://imchatapp.com/room/123 or https://imchatapp.com/post/456)
    if (pathSegments.isNotEmpty) {
      final firstSegment = pathSegments[0].toLowerCase().trim();
      final secondSegment =
          pathSegments.length > 1 ? pathSegments[1].trim() : queryId?.trim();

      if ((firstSegment == 'room' || firstSegment == 'audioroom') &&
          secondSegment != null &&
          secondSegment.isNotEmpty) {
        return {'type': 'room', 'id': secondSegment};
      }
      if (firstSegment == 'post' &&
          secondSegment != null &&
          secondSegment.isNotEmpty) {
        return {'type': 'post', 'id': secondSegment};
      }
      if (firstSegment == 'event' &&
          secondSegment != null &&
          secondSegment.isNotEmpty) {
        return {'type': 'event', 'id': secondSegment};
      }
    }

    // Case 3: Fallback check for query parameter on any URL path
    if (queryId != null && queryId.trim().isNotEmpty) {
      final cleanQueryId = queryId.trim();
      if (uri.path.contains('room')) {
        return {'type': 'room', 'id': cleanQueryId};
      }
      if (uri.path.contains('post')) {
        return {'type': 'post', 'id': cleanQueryId};
      }
      if (uri.path.contains('event')) {
        return {'type': 'event', 'id': cleanQueryId};
      }
    }

    return null;
  }

  Future<void> _handleDeepLink(Uri uri) async {
    final parsed = parseDeepLink(uri);
    if (parsed == null) {
      debugPrint('⚠️ Could not parse deep link: $uri');
      return;
    }

    final type = parsed['type']!;
    final id = parsed['id']!;

    final authController =
        Get.isRegistered<AuthController>() ? Get.find<AuthController>() : null;
    final bool isLoggedIn =
        (authController != null && authController.firebaseUser != null) ||
            AuthController.instance.currentUser.userId.isNotEmpty;

    if (!isLoggedIn) {
      debugPrint('User not logged in. Saving pending $type ID: $id');
      await _storePendingLink(type, id);
      Get.offAllNamed(AppRoutes.phoneSignIn);
      return;
    }

    await executeDeepLinkAction(type, id);
  }

  static Future<void> executeDeepLinkAction(String type, String id) async {
    debugPrint('🚀 Executing Deep Link Action: type=$type, id=$id');
    try {
      if (type == 'room') {
        await AudioRoomsV2Integration.joinRoomById(id);
      } else if (type == 'post') {
        Get.to(() => SinglePostScreen(postId: id));
      } else if (type == 'event') {
        final event = await EventService.getEventByEventId(id);
        if (event != null) {
          Get.to(() => EventDetailsScreen(event: event));
        } else {
          Get.snackbar('Notice', 'Event not found',
              snackPosition: SnackPosition.BOTTOM);
        }
      }
    } catch (e) {
      debugPrint('❌ Error executing deep link action: $e');
    }
  }

  static Future<void> _storePendingLink(String type, String id) async {
    final prefs = await SharedPreferences.getInstance();
    if (type == 'room') {
      await prefs.setString('pending_room_id', id);
    } else if (type == 'post') {
      await prefs.setString('pending_post_id', id);
    } else if (type == 'event') {
      await prefs.setString('pending_event_id', id);
    }
  }

  Future<void> _storePendingLinkFromUri(Uri uri) async {
    final parsed = parseDeepLink(uri);
    if (parsed != null) {
      await _storePendingLink(parsed['type']!, parsed['id']!);
    }
  }

  static Future<void> checkPendingRoom() => checkPendingDeepLinks();

  static Future<void> checkPendingDeepLinks() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Pending Room
    final roomId = prefs.getString('pending_room_id');
    if (roomId != null && roomId.isNotEmpty) {
      await prefs.remove('pending_room_id');
      Future.delayed(const Duration(milliseconds: 600), () {
        executeDeepLinkAction('room', roomId);
      });
      return;
    }

    // 2. Pending Post
    final postId = prefs.getString('pending_post_id');
    if (postId != null && postId.isNotEmpty) {
      await prefs.remove('pending_post_id');
      Future.delayed(const Duration(milliseconds: 600), () {
        executeDeepLinkAction('post', postId);
      });
      return;
    }

    // 3. Pending Event
    final eventId = prefs.getString('pending_event_id');
    if (eventId != null && eventId.isNotEmpty) {
      await prefs.remove('pending_event_id');
      Future.delayed(const Duration(milliseconds: 600), () {
        executeDeepLinkAction('event', eventId);
      });
      return;
    }
  }

  // Generate standard app links
  static String generateRoomLink(String roomId) {
    return 'https://invite.imchatapp.com/room/$roomId';
  }

  static String generatePostLink(String postId) {
    return 'https://invite.imchatapp.com/post/$postId';
  }

  static String generateEventLink(String eventId) {
    return 'https://invite.imchatapp.com/event/$eventId';
  }

  @override
  void onClose() {
    _linkSubscription?.cancel();
    super.onClose();
  }
}

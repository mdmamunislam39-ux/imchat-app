import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'global_settings_service.dart';

/// Lightweight REST API client for self-hosted VPS PostgreSQL Backend
class VpsApiService extends GetxService {
  final GlobalSettingsService _settings = Get.find<GlobalSettingsService>();

  String get baseUrl => _settings.vpsBaseUrl.value.trim().replaceAll(RegExp(r'/+$'), '');

  Future<Map<String, String>> _getHeaders({bool requireAuth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (requireAuth) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          final token = await user.getIdToken();
          if (token != null && token.isNotEmpty) {
            headers['Authorization'] = 'Bearer $token';
          }
        } catch (e) {
          debugPrint('[VpsApiService] Failed to obtain Firebase ID token: $e');
        }
        headers['x-user-id'] = user.uid;
      }
    }
    return headers;
  }

  /// Health Check for Admin Panel and Connection diagnostics
  Future<Map<String, dynamic>> checkHealth([String? customUrl]) async {
    final targetUrl = (customUrl != null && customUrl.trim().isNotEmpty)
        ? customUrl.trim().replaceAll(RegExp(r'/+$'), '')
        : baseUrl;

    if (targetUrl.isEmpty) {
      return {'status': 'error', 'message': 'VPS Server Base URL is empty'};
    }

    try {
      final uri = Uri.parse('$targetUrl/health');
      final res = await http.get(uri).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } else {
        return {'status': 'error', 'code': res.statusCode, 'body': res.body};
      }
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  /// HTTP GET Request
  Future<dynamic> get(String path, {Map<String, String>? queryParams, bool requireAuth = true}) async {
    if (baseUrl.isEmpty) throw Exception('VPS Base URL not configured');

    var uri = Uri.parse('$baseUrl$path');
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }

    final headers = await _getHeaders(requireAuth: requireAuth);
    final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 15));
    return _handleResponse(response);
  }

  /// HTTP POST Request
  Future<dynamic> post(String path, {Map<String, dynamic>? body, bool requireAuth = true}) async {
    if (baseUrl.isEmpty) throw Exception('VPS Base URL not configured');

    final uri = Uri.parse('$baseUrl$path');
    final headers = await _getHeaders(requireAuth: requireAuth);
    final response = await http.post(
      uri,
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    ).timeout(const Duration(seconds: 15));
    return _handleResponse(response);
  }

  /// Sync user profile with VPS PostgreSQL
  Future<void> syncUserProfile({
    required String fullname,
    String? email,
    String? photoUrl,
    String? phoneNumber,
    String? gender,
    String? country,
    String? fcmToken,
  }) async {
    if (baseUrl.isEmpty) return;
    try {
      await post('/api/user/sync', body: {
        'fullname': fullname,
        'email': email,
        'photoUrl': photoUrl,
        'phoneNumber': phoneNumber,
        'gender': gender,
        'country': country,
        'fcmToken': fcmToken,
      });
    } catch (e) {
      debugPrint('[VpsApiService] User sync error: $e');
    }
  }

  /// Fetch store assets (Frames, Badges, Emojis, Themes, Gifts)
  Future<List<dynamic>> getStoreAssets({String? category}) async {
    final query = category != null ? {'category': category} : null;
    final res = await get('/api/store/assets', queryParams: query, requireAuth: false);
    if (res is Map && res['assets'] is List) {
      return res['assets'] as List<dynamic>;
    }
    return [];
  }

  /// Equip asset (Frame, Badge, Entrance, Theme)
  Future<dynamic> equipAsset({required String assetId, required String category}) async {
    return await post('/api/store/equip', body: {
      'assetId': assetId,
      'category': category,
    });
  }

  /// Fetch single user profile by ID
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final res = await get('/api/user/$userId', requireAuth: false);
      if (res is Map && res['user'] is Map) {
        return Map<String, dynamic>.from(res['user']);
      }
    } catch (e) {
      debugPrint('[VpsApiService] getUserProfile error: $e');
    }
    return null;
  }

  /// Update user profile
  Future<Map<String, dynamic>?> updateUserProfile({
    String? fullname,
    String? bio,
    String? photoUrl,
    String? gender,
    String? country,
    String? birthdate,
  }) async {
    try {
      final res = await post('/api/user/update', body: {
        'fullname': fullname,
        'bio': bio,
        'photoUrl': photoUrl,
        'gender': gender,
        'country': country,
        'birthdate': birthdate,
      });
      if (res is Map && res['user'] is Map) {
        return Map<String, dynamic>.from(res['user']);
      }
    } catch (e) {
      debugPrint('[VpsApiService] updateUserProfile error: $e');
    }
    return null;
  }

  /// Search users
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      final res = await get('/api/users/search', queryParams: {'q': query}, requireAuth: false);
      if (res is Map && res['users'] is List) {
        return (res['users'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (e) {
      debugPrint('[VpsApiService] searchUsers error: $e');
    }
    return [];
  }

  /// 1v1 Chats list
  Future<List<Map<String, dynamic>>> getDirectChats() async {
    try {
      final res = await get('/api/chats', requireAuth: true);
      if (res is Map && res['chats'] is List) {
        return (res['chats'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (e) {
      debugPrint('[VpsApiService] getDirectChats error: $e');
    }
    return [];
  }

  /// 1v1 Messages history
  Future<List<Map<String, dynamic>>> getDirectMessages(String otherUserId, {int limit = 60, DateTime? before}) async {
    try {
      final Map<String, String> queryParams = {'limit': limit.toString()};
      if (before != null) {
        queryParams['before'] = before.toUtc().toIso8601String();
      }
      final res = await get('/api/chats/$otherUserId/messages', queryParams: queryParams, requireAuth: true);
      if (res is Map && res['messages'] is List) {
        return (res['messages'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (e) {
      debugPrint('[VpsApiService] getDirectMessages error: $e');
    }
    return [];
  }

  /// Send 1v1 Message
  Future<Map<String, dynamic>?> sendDirectMessage({
    required String receiverId,
    String messageType = 'text',
    String content = '',
    String mediaUrl = '',
    int mediaDuration = 0,
    String? giftId,
    int giftCount = 1,
  }) async {
    try {
      final res = await post('/api/messages/send', body: {
        'receiverId': receiverId,
        'messageType': messageType,
        'content': content,
        'mediaUrl': mediaUrl,
        'mediaDuration': mediaDuration,
        'giftId': giftId,
        'giftCount': giftCount,
      }, requireAuth: true);
      if (res is Map && res['message'] is Map) {
        return Map<String, dynamic>.from(res['message']);
      }
    } catch (e) {
      debugPrint('[VpsApiService] sendDirectMessage error: $e');
    }
    return null;
  }

  /// Groups List
  Future<List<Map<String, dynamic>>> getGroups() async {
    try {
      final res = await get('/api/groups', requireAuth: true);
      if (res is Map && res['groups'] is List) {
        return (res['groups'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (e) {
      debugPrint('[VpsApiService] getGroups error: $e');
    }
    return [];
  }

  /// Create Group
  Future<Map<String, dynamic>?> createGroup({
    required String name,
    String description = '',
    String coverUrl = '',
    List<String> memberIds = const [],
  }) async {
    try {
      final res = await post('/api/groups/create', body: {
        'name': name,
        'description': description,
        'coverUrl': coverUrl,
        'memberIds': memberIds,
      }, requireAuth: true);
      if (res is Map && res['group'] is Map) {
        return Map<String, dynamic>.from(res['group']);
      }
    } catch (e) {
      debugPrint('[VpsApiService] createGroup error: $e');
    }
    return null;
  }

  /// Group Messages History
  Future<List<Map<String, dynamic>>> getGroupMessages(String groupId, {int limit = 60, DateTime? before}) async {
    try {
      final Map<String, String> queryParams = {'limit': limit.toString()};
      if (before != null) {
        queryParams['before'] = before.toUtc().toIso8601String();
      }
      final res = await get('/api/groups/$groupId/messages', queryParams: queryParams, requireAuth: true);
      if (res is Map && res['messages'] is List) {
        return (res['messages'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (e) {
      debugPrint('[VpsApiService] getGroupMessages error: $e');
    }
    return [];
  }

  /// Send Group Message
  Future<Map<String, dynamic>?> sendGroupMessage({
    required String groupId,
    String messageType = 'text',
    String content = '',
    String mediaUrl = '',
    int mediaDuration = 0,
  }) async {
    try {
      final res = await post('/api/groups/$groupId/send', body: {
        'messageType': messageType,
        'content': content,
        'mediaUrl': mediaUrl,
        'mediaDuration': mediaDuration,
      }, requireAuth: true);
      if (res is Map && res['message'] is Map) {
        return Map<String, dynamic>.from(res['message']);
      }
    } catch (e) {
      debugPrint('[VpsApiService] sendGroupMessage error: $e');
    }
    return null;
  }

  /// Wallet Balance
  Future<Map<String, dynamic>> getWalletBalance() async {
    try {
      final res = await get('/api/wallet/balance', requireAuth: true);
      if (res is Map) {
        return {'coins': res['coins'] ?? 0, 'diamonds': res['diamonds'] ?? 0};
      }
    } catch (e) {
      debugPrint('[VpsApiService] getWalletBalance error: $e');
    }
    return {'coins': 0, 'diamonds': 0};
  }

  /// Rankings
  Future<List<Map<String, dynamic>>> getRankings(String type) async {
    try {
      final res = await get('/api/rankings/$type', requireAuth: false);
      if (res is Map && res['rankings'] is List) {
        return (res['rankings'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (e) {
      debugPrint('[VpsApiService] getRankings error: $e');
    }
    return [];
  }

  /// Seller Request Diamonds
  Future<bool> requestSellerDiamonds({
    required String sellerName,
    required String sellerPhone,
    required int requestedDiamonds,
    required double amountPaid,
    required String paymentMethod,
    required String transactionId,
    String proofImageUrl = '',
    String note = '',
  }) async {
    try {
      final res = await post('/api/seller/request-diamonds', body: {
        'sellerName': sellerName,
        'sellerPhone': sellerPhone,
        'requestedDiamonds': requestedDiamonds,
        'amountPaid': amountPaid,
        'paymentMethod': paymentMethod,
        'transactionId': transactionId,
        'proofImageUrl': proofImageUrl,
        'note': note,
      }, requireAuth: true);
      return res is Map && res['success'] == true;
    } catch (e) {
      debugPrint('[VpsApiService] requestSellerDiamonds error: $e');
      return false;
    }
  }

  /// Get Seller Requests History
  Future<List<Map<String, dynamic>>> getSellerRequests({String? status, bool all = false}) async {
    try {
      final query = <String, String>{};
      if (status != null) query['status'] = status;
      if (all) query['all'] = 'true';
      final res = await get('/api/seller/requests', queryParams: query, requireAuth: true);
      if (res is Map && res['requests'] is List) {
        return (res['requests'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (e) {
      debugPrint('[VpsApiService] getSellerRequests error: $e');
    }
    return [];
  }

  /// Events / Banners
  Future<List<Map<String, dynamic>>> getAppEvents() async {
    try {
      final res = await get('/api/events', requireAuth: false);
      if (res is Map && res['events'] is List) {
        return (res['events'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (e) {
      debugPrint('[VpsApiService] getAppEvents error: $e');
    }
    return [];
  }

  // --------------------------------------------------------------------------
  // Moments / News Feed REST APIs
  // --------------------------------------------------------------------------

  /// Fetch moments posts
  Future<List<Map<String, dynamic>>> getMomentPosts({int limit = 20, int offset = 0, String type = 'latest'}) async {
    try {
      final res = await get('/api/moments/posts', queryParams: {
        'limit': limit.toString(),
        'offset': offset.toString(),
        'type': type,
      }, requireAuth: false);
      if (res is Map && res['posts'] is List) {
        return (res['posts'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (e) {
      debugPrint('[VpsApiService] getMomentPosts error: $e');
    }
    return [];
  }

  /// Get single post
  Future<Map<String, dynamic>?> getSingleMomentPost(String postId) async {
    try {
      final res = await get('/api/moments/posts/$postId', requireAuth: false);
      if (res is Map && res['post'] is Map) {
        return Map<String, dynamic>.from(res['post']);
      }
    } catch (e) {
      debugPrint('[VpsApiService] getSingleMomentPost error: $e');
    }
    return null;
  }

  /// Create new moment post
  Future<Map<String, dynamic>?> createMomentPost(Map<String, dynamic> postData) async {
    try {
      final res = await post('/api/moments/posts/create', body: postData, requireAuth: true);
      if (res is Map && res['post'] is Map) {
        return Map<String, dynamic>.from(res['post']);
      }
    } catch (e) {
      debugPrint('[VpsApiService] createMomentPost error: $e');
    }
    return null;
  }

  /// Like or reaction to a post
  Future<Map<String, dynamic>?> likeMomentPost(String postId, {String reactionType = 'like'}) async {
    try {
      final res = await post('/api/moments/posts/$postId/like', body: {'reactionType': reactionType}, requireAuth: true);
      if (res is Map) {
        return Map<String, dynamic>.from(res);
      }
    } catch (e) {
      debugPrint('[VpsApiService] likeMomentPost error: $e');
    }
    return null;
  }

  /// Add comment to post
  Future<Map<String, dynamic>?> createMomentComment({
    required String postId,
    String? commentId,
    required String text,
    required String userName,
    String? userAvatar,
    String? userFrameId,
    String? imageUrl,
    String? replyToId,
    String? replyToUserName,
  }) async {
    try {
      final res = await post('/api/moments/posts/$postId/comments', body: {
        'id': commentId,
        'text': text,
        'userName': userName,
        'userAvatar': userAvatar,
        'userFrameId': userFrameId,
        'imageUrl': imageUrl,
        'replyToId': replyToId,
        'replyToUserName': replyToUserName,
      }, requireAuth: true);
      if (res is Map && res['comment'] is Map) {
        return Map<String, dynamic>.from(res['comment']);
      }
    } catch (e) {
      debugPrint('[VpsApiService] createMomentComment error: $e');
    }
    return null;
  }

  /// Get comments for a post
  Future<List<Map<String, dynamic>>> getMomentComments(String postId) async {
    try {
      final res = await get('/api/moments/posts/$postId/comments', requireAuth: false);
      if (res is Map && res['comments'] is List) {
        return (res['comments'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (e) {
      debugPrint('[VpsApiService] getMomentComments error: $e');
    }
    return [];
  }

  /// Share post
  Future<bool> shareMomentPost(String postId) async {
    try {
      final res = await post('/api/moments/posts/$postId/share', body: {}, requireAuth: false);
      return res is Map && res['success'] == true;
    } catch (e) {
      debugPrint('[VpsApiService] shareMomentPost error: $e');
      return false;
    }
  }

  /// Delete post
  Future<bool> deleteMomentPost(String postId) async {
    try {
      final headers = await _getHeaders(requireAuth: true);
      final uri = Uri.parse('$baseUrl/api/moments/posts/$postId');
      final res = await http.delete(uri, headers: headers).timeout(const Duration(seconds: 15));
      final data = _handleResponse(res);
      return data is Map && data['success'] == true;
    } catch (e) {
      debugPrint('[VpsApiService] deleteMomentPost error: $e');
      return false;
    }
  }

  dynamic _handleResponse(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return {};
      try {
        return jsonDecode(res.body);
      } catch (_) {
        return res.body;
      }
    } else if (res.statusCode == 404) {
      return null;
    } else {
      throw Exception('Server error [${res.statusCode}]: ${res.body}');
    }
  }
}

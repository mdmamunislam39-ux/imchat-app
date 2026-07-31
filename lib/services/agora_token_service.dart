import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:get/get.dart';
import 'local_agora_token.dart';
import '../models/agora_models.dart';
import 'global_settings_service.dart';

/// Service for managing Agora tokens dynamically and securely
class AgoraTokenService {
  static AgoraTokenService? _instance;
  static AgoraTokenService get instance => _instance ??= AgoraTokenService._();
  AgoraTokenService._();

  // Cache for tokens to avoid unnecessary requests
  final Map<String, TokenResponse> _tokenCache = {};

  static const String railwayFunctionUrl = 'https://steadfast-vibrancy-production.up.railway.app/token';

  /// Get the current App ID and Certificate from GlobalSettingsService dynamically
  String get dynamicAppId {
    try {
      final settingsService = Get.find<GlobalSettingsService>();
      final val = settingsService.agoraAppId.value;
      return val.isNotEmpty ? val : 'c74eafbb98784225bae6be9b7e7f6225';
    } catch (e) {
      debugPrint('🎫 [TokenService] GlobalSettingsService not found, using default AppID');
      return 'c74eafbb98784225bae6be9b7e7f6225'; // fallback
    }
  }

  String get dynamicAppCertificate {
    try {
      final settingsService = Get.find<GlobalSettingsService>();
      final val = settingsService.agoraCertificate.value;
      return val.isNotEmpty ? val : 'eb4c5875fba74804b9d348882d7365f0';
    } catch (e) {
      debugPrint('🎫 [TokenService] GlobalSettingsService not found, using default AppCertificate');
      return 'eb4c5875fba74804b9d348882d7365f0'; // fallback
    }
  }

  /// Generate Agora token for a channel
  Future<TokenResponse?> generateToken({
    required String channelName,
    required int uid,
    String role = 'publisher',
    int expirationTimeInSeconds = 3600,
  }) async {
    try {
      debugPrint('🎫 [TokenService] Generating token for channel: $channelName, uid: $uid, role: $role');
      
      final cacheKey = '${channelName}_${uid}_$role';
      
      // Check cache first
      if (_tokenCache.containsKey(cacheKey)) {
        final cachedToken = _tokenCache[cacheKey]!;
        if (!cachedToken.willExpireSoon) {
          debugPrint('🎫 [TokenService] Using cached token');
          return cachedToken;
        } else {
          debugPrint('🎫 [TokenService] Cached token will expire soon, generating new one');
          _tokenCache.remove(cacheKey);
        }
      }

      String? token;

      // 1. Try Firebase Cloud Function first (most secure, generates official v006 token)
      try {
        debugPrint('🎫 [TokenService] Attempting Firebase Cloud Function token generation...');
        final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('generateAgoraToken');
        final response = await callable.call({
          'channelName': channelName,
          'uid': uid,
          'role': role,
          'expirationTimeInSeconds': expirationTimeInSeconds,
        }).timeout(const Duration(seconds: 3));

        if (response.data != null && response.data['success'] == true) {
          token = response.data['token'];
          debugPrint('🎫 [TokenService] Token generated via Firebase Function successfully');
        } else {
          debugPrint('🎫 [TokenService] Firebase Function returned success: false or null data');
        }
      } catch (e) {
        debugPrint('🎫 [TokenService] Firebase Function failed/timed out: $e');
      }

      // 2. Try Railway API endpoint as fallback
      if (token == null || token.isEmpty) {
        try {
          debugPrint('🎫 [TokenService] Attempting Railway URL fallback...');
          final requestBody = {
            'channelName': channelName,
            'uid': uid,
            'role': role,
            'expireTime': expirationTimeInSeconds,
          };
          final response = await http.post(
            Uri.parse(railwayFunctionUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          ).timeout(const Duration(seconds: 3));
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body) as Map<String, dynamic>;
            token = data['token'] as String?;
            debugPrint('🎫 [TokenService] Token generated via Railway API successfully');
          } else {
            debugPrint('🎫 [TokenService] HTTP Error ${response.statusCode} from Railway API');
          }
        } catch (e) {
          debugPrint('🎫 [TokenService] Railway API request failed/timed out: $e');
        }
      }

      // 3. Client-side local generation using dynamic settings as final safety net fallback
      if (token == null || token.isEmpty) {
        try {
          debugPrint('🎫 [TokenService] Attempting client-side local token generation fallback...');
          final appId = dynamicAppId;
          final appCert = dynamicAppCertificate;
          
          if (appId.isNotEmpty && appCert.isNotEmpty) {
            token = RtcTokenBuilder.buildTokenWithUid(
              appId: appId,
              appCertificate: appCert,
              channelName: channelName,
              uid: uid,
              tokenExpireSeconds: expirationTimeInSeconds,
            );
            debugPrint('🎫 [TokenService] Token generated locally via RtcTokenBuilder successfully');
          } else {
            debugPrint('🎫 [TokenService] Local generation skipped due to empty appId/appCertificate');
          }
        } catch (e) {
          debugPrint('🎫 [TokenService] Local token generation failed: $e');
        }
      }

      // Process and cache the token if successfully obtained
      if (token != null && token.isNotEmpty) {
        final expiresAt = DateTime.now().add(Duration(seconds: expirationTimeInSeconds));
        final tokenResponse = TokenResponse(
          token: token,
          uid: uid,
          channelName: channelName,
          expiresAt: expiresAt,
        );
        
        // Cache the token
        _tokenCache[cacheKey] = tokenResponse;
        
        debugPrint('🎫 [TokenService] Token generated successfully ✅ (length: ${token.length})');
        return tokenResponse;
      } else {
        debugPrint('🎫 [TokenService] All token generation methods failed! ❌');
        return null;
      }
    } catch (e) {
      debugPrint('🎫 [TokenService] Exception in generateToken: $e');
      return null;
    }
  }

  /// Generate tokens for multiple users (batch operation)
  Future<List<TokenResponse>?> generateBatchTokens({
    required String channelName,
    required List<TokenRequest> users,
    int expirationTimeInSeconds = 3600,
  }) async {
    try {
      debugPrint('🎫 [TokenService] Generating batch tokens for ${users.length} users');
      final tokens = <TokenResponse>[];
      
      for (final user in users) {
        final token = await generateToken(
          channelName: channelName,
          uid: user.uid,
          role: user.role,
          expirationTimeInSeconds: expirationTimeInSeconds,
        );
        
        if (token != null) {
          tokens.add(token);
        } else {
          debugPrint('🎫 [TokenService] Failed to generate token for uid: ${user.uid}');
        }
      }
      
      debugPrint('🎫 [TokenService] Batch tokens generated: ${tokens.length}/${users.length}');
      return tokens.isNotEmpty ? tokens : null;
    } catch (e) {
      debugPrint('🎫 [TokenService] Error generating batch tokens: $e');
      return null;
    }
  }

  /// Refresh an existing token
  Future<TokenResponse?> refreshToken({
    required String channelName,
    required int uid,
    required String currentToken,
    String role = 'publisher',
    int expirationTimeInSeconds = 3600,
  }) async {
    try {
      debugPrint('🎫 [TokenService] Refreshing token for channel: $channelName, uid: $uid');
      
      // Clear the cached token first
      final cacheKey = '${channelName}_${uid}_$role';
      _tokenCache.remove(cacheKey);
      
      // Generate a new token
      return await generateToken(
        channelName: channelName,
        uid: uid,
        role: role,
        expirationTimeInSeconds: expirationTimeInSeconds,
      );
    } catch (e) {
      debugPrint('🎫 [TokenService] Error refreshing token: $e');
      return null;
    }
  }

  /// Get token info (for debugging)
  Future<Map<String, dynamic>?> getTokenInfo() async {
    try {
      return {
        'success': true,
        'service': 'Dynamic Agora Token Service',
        'endpoint': railwayFunctionUrl,
        'currentTimestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'serverTime': DateTime.now().toIso8601String(),
        'cacheSize': _tokenCache.length,
        'appId': '${dynamicAppId.substring(0, 5)}...',
      };
    } catch (e) {
      debugPrint('🎫 [TokenService] Error getting token info: $e');
      return null;
    }
  }

  /// Check if token needs renewal
  bool shouldRenewToken(TokenResponse token) {
    return token.willExpireSoon || token.isExpired;
  }

  /// Get cached token if available and valid
  TokenResponse? getCachedToken(String channelName, int uid, String role) {
    final cacheKey = '${channelName}_${uid}_$role';
    final cachedToken = _tokenCache[cacheKey];
    
    if (cachedToken != null && !cachedToken.willExpireSoon) {
      return cachedToken;
    }
    
    // Remove expired/expiring token from cache
    if (cachedToken != null) {
      _tokenCache.remove(cacheKey);
    }
    
    return null;
  }

  /// Clear token cache
  void clearCache() {
    _tokenCache.clear();
    debugPrint('🎫 [TokenService] Token cache cleared');
  }

  /// Clear specific token from cache
  void clearTokenFromCache(String channelName, int uid, String role) {
    final cacheKey = '${channelName}_${uid}_$role';
    _tokenCache.remove(cacheKey);
    debugPrint('🎫 [TokenService] Token removed from cache: $cacheKey');
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    final validTokens = _tokenCache.values.where((t) => !t.isExpired).length;
    final expiredTokens = _tokenCache.values.where((t) => t.isExpired).length;
    final expiringSoon = _tokenCache.values.where((t) => t.willExpireSoon && !t.isExpired).length;
    
    return {
      'totalTokens': _tokenCache.length,
      'validTokens': validTokens,
      'expiredTokens': expiredTokens,
      'expiringSoon': expiringSoon,
      'cacheKeys': _tokenCache.keys.toList(),
    };
  }

  /// Cleanup expired tokens from cache
  void cleanupExpiredTokens() {
    final expiredKeys = _tokenCache.entries
        .where((entry) => entry.value.isExpired)
        .map((entry) => entry.key)
        .toList();
    
    for (final key in expiredKeys) {
      _tokenCache.remove(key);
    }
    
    if (expiredKeys.isNotEmpty) {
      debugPrint('🎫 [TokenService] Cleaned up ${expiredKeys.length} expired tokens');
    }
  }

  /// Dispose and cleanup
  void dispose() {
    _tokenCache.clear();
    debugPrint('🎫 [TokenService] Token service disposed');
  }
}

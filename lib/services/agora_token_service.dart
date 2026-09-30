import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';
import '../models/agora_models.dart';
import 'global_settings_service.dart';

/// Agora role enumeration for strong typing while preserving String compatibility.
enum AgoraRole {
  publisher('publisher'),
  audience('audience');

  final String value;
  const AgoraRole(this.value);

  /// Parse role from string with default fallback to publisher.
  static AgoraRole fromString(String? role) {
    if (role == null) return AgoraRole.publisher;
    final normalized = role.trim().toLowerCase();
    if (normalized == 'audience' || normalized == 'subscriber') {
      return AgoraRole.audience;
    }
    return AgoraRole.publisher;
  }
}

/// Immutable cache key for Agora token storage.
class TokenCacheKey {
  final String channelName;
  final int uid;
  final String role;

  const TokenCacheKey({
    required this.channelName,
    required this.uid,
    required this.role,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TokenCacheKey &&
          runtimeType == other.runtimeType &&
          channelName == other.channelName &&
          uid == other.uid &&
          role == other.role;

  @override
  int get hashCode => Object.hash(channelName, uid, role);

  @override
  String toString() => '${channelName}_${uid}_$role';
}

/// Enterprise-grade service for fetching, validating, caching, and managing Agora RTC tokens securely.
///
/// Security Architecture:
/// - Tokens are strictly generated on trusted server backends (Firebase Cloud Functions / Railway endpoint).
/// - No Agora App Certificate is stored or used within the Flutter client.
/// - Hardcoded credential fallbacks are completely removed.
/// - Uses an LRU (Least Recently Used) cache with bounded size and automated TTL expiration.
class AgoraTokenService {
  // ---------------------------------------------------------------------------
  // Singleton
  // ---------------------------------------------------------------------------
  static AgoraTokenService? _instance;
  static AgoraTokenService get instance => _instance ??= AgoraTokenService._();
  AgoraTokenService._();

  // ---------------------------------------------------------------------------
  // Constants
  // ---------------------------------------------------------------------------
  static const String railwayFunctionUrl =
      'https://steadfast-vibrancy-production.up.railway.app/token';

  static const Duration _defaultRequestTimeout = Duration(seconds: 15);
  static const int _maxCacheSize = 100;
  static const int _defaultExpirationSeconds = 86400;

  // ---------------------------------------------------------------------------
  // LRU Token Cache
  // ---------------------------------------------------------------------------
  final LinkedHashMap<TokenCacheKey, TokenResponse> _tokenCache =
      LinkedHashMap<TokenCacheKey, TokenResponse>();

  // ===========================================================================
  // Centralized Logging
  // ===========================================================================
  void _logDebug(String message) {
    debugPrint('🎫 [TokenService] $message');
  }

  void _logWarning(String message) {
    debugPrint('🎫 [TokenService] ⚠️ $message');
  }

  void _logError(String message, [dynamic error]) {
    if (error != null) {
      debugPrint('🎫 [TokenService] ❌ $message: $error');
    } else {
      debugPrint('🎫 [TokenService] ❌ $message');
    }
  }

  // ===========================================================================
  // Configuration Layer
  // ===========================================================================

  /// Resolves the current Agora App ID from [GlobalSettingsService].
  /// Never returns a hardcoded default credential.
  String? _cachedAppId;
  String? _getAppId() {
    try {
      if (Get.isRegistered<GlobalSettingsService>()) {
        final settingsService = Get.find<GlobalSettingsService>();
        final val = settingsService.agoraAppId.value.trim();
        if (val.isNotEmpty) {
          if (_cachedAppId != null && _cachedAppId != val) {
            _tokenCache.clear();
            _logDebug('Agora App ID changed dynamically from $_cachedAppId to $val, cleared token cache.');
          }
          _cachedAppId = val;
          return val;
        }
      }
    } catch (e) {
      _logWarning('GlobalSettingsService lookup notice: $e');
    }
    return null;
  }

  /// Checks if dynamic App ID configuration is available.
  bool _isConfigured() {
    final appId = _getAppId();
    return appId != null && appId.isNotEmpty;
  }

  /// Backwards-compatible public getter for App ID.
  /// Returns dynamic App ID from settings, or empty string if not configured.
  String get dynamicAppId => _getAppId() ?? '';

  /// App Certificate is strictly kept on the backend; the client never stores or accesses it.
  String get dynamicAppCertificate => '';

  // ===========================================================================
  // Cache Helpers (LRU + Expiration)
  // ===========================================================================

  TokenCacheKey _createCacheKey(String channelName, int uid, String role) {
    return TokenCacheKey(
      channelName: channelName.trim(),
      uid: uid,
      role: role.trim().toLowerCase(),
    );
  }

  /// Checks if token is valid, non-empty, and not expiring soon.
  bool _isTokenValid(TokenResponse? token) {
    if (token == null || token.token.isEmpty) return false;
    return !token.willExpireSoon && !token.isExpired;
  }

  /// Removes expired tokens from the cache.
  void _removeExpiredTokens() {
    final expiredKeys = <TokenCacheKey>[];
    for (final entry in _tokenCache.entries) {
      if (entry.value.isExpired || entry.value.willExpireSoon) {
        expiredKeys.add(entry.key);
      }
    }
    for (final key in expiredKeys) {
      _tokenCache.remove(key);
    }
    if (expiredKeys.isNotEmpty) {
      _logDebug('Evicted ${expiredKeys.length} expired/stale tokens from cache');
    }
  }

  /// Caches a token with LRU eviction when exceeding [_maxCacheSize].
  void _cacheToken(TokenCacheKey key, TokenResponse response) {
    _tokenCache.remove(key);

    if (_tokenCache.length >= _maxCacheSize) {
      final oldestKey = _tokenCache.keys.first;
      _tokenCache.remove(oldestKey);
      _logDebug('Evicted oldest LRU token: $oldestKey');
    }

    _tokenCache[key] = response;
  }

  /// Pre-caches a token received directly from Push Notification, Firestore, or Call payload.
  void cachePreGeneratedToken({
    required String channelName,
    required String token,
    int uid = 0,
    String role = 'publisher',
  }) {
    if (token.isEmpty) return;
    final key = _createCacheKey(channelName, uid, role);
    final response = TokenResponse(
      token: token,
      channelName: channelName,
      uid: uid,
      expiresAt: DateTime.now().add(const Duration(hours: 24)),
    );
    _cacheToken(key, response);
    _logDebug('⚡ Cached pre-generated token for channel: $channelName (0ms latency)');
  }

  // ===========================================================================
  // Server Request Layer
  // ===========================================================================

  /// Requests token from Firebase Cloud Function (`generateAgoraToken`).
  Future<String?> _requestTokenFromFirebase({
    required String channelName,
    required int uid,
    required String role,
    required int expirationTimeInSeconds,
    Duration timeout = _defaultRequestTimeout,
  }) async {
    for (int attempt = 1; attempt <= 2; attempt++) {
      try {
        _logDebug(
            'Attempting Firebase Cloud Function token generation for $channelName (uid: $uid, attempt: $attempt)...');
        final HttpsCallable callable =
            FirebaseFunctions.instance.httpsCallable('generateAgoraToken');

        final response = await callable.call({
          'channelName': channelName,
          'uid': uid,
          'role': role,
          'expirationTimeInSeconds': expirationTimeInSeconds,
          'appId': dynamicAppId,
        }).timeout(timeout);

        if (response.data != null && response.data['success'] == true) {
          final token = response.data['token'] as String?;
          if (token != null && token.isNotEmpty) {
            _logDebug('Token successfully generated via Firebase Function ✅');
            return token;
          }
        }
      } on FirebaseFunctionsException catch (e) {
        _logError(
            'FirebaseFunctionsException [${e.code}]: ${e.message} (details: ${e.details})');
        if (e.code == 'not-found' || e.code == 'unimplemented') {
          break;
        }
      } on TimeoutException catch (_) {
        _logWarning(
            'Firebase Cloud Function token request timed out (${timeout.inSeconds}s, attempt: $attempt)');
      } on SocketException catch (e) {
        _logWarning(
            'Network socket exception during Firebase token request: $e (attempt: $attempt)');
      } on PlatformException catch (e) {
        _logError(
            'PlatformException during Firebase token request: ${e.message}');
      } catch (e) {
        _logWarning('Unexpected error calling Firebase token function: $e');
      }

      if (attempt < 2) {
        await Future.delayed(const Duration(milliseconds: 750));
      }
    }
    return null;
  }

  /// Requests token from HTTP server endpoint fallback (e.g. Railway / Node.js helper).
  Future<String?> _requestTokenFromHttp({
    required String channelName,
    required int uid,
    required String role,
    required int expirationTimeInSeconds,
    Duration timeout = _defaultRequestTimeout,
  }) async {
    try {
      _logDebug('Attempting HTTP server token generation fallback ($railwayFunctionUrl)...');
      final uri = Uri.parse(railwayFunctionUrl);
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'channelName': channelName,
              'uid': uid,
              'role': role,
              'expirationTimeInSeconds': expirationTimeInSeconds,
              'appId': dynamicAppId,
            }),
          )
          .timeout(timeout);

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          final token = (data['token'] ?? data['data']) as String?;
          if (token != null && token.isNotEmpty) {
            _logDebug('Token successfully generated via HTTP backend ✅');
            return token;
          }
        }
      } else {
        _logWarning('HTTP backend returned status code ${response.statusCode}');
      }
    } on TimeoutException catch (_) {
      _logWarning('HTTP token request timed out');
    } on SocketException catch (e) {
      _logWarning('HTTP token request network error: $e');
    } on FormatException catch (e) {
      _logWarning('HTTP token response format error: $e');
    } catch (e) {
      _logWarning('HTTP token generation error: $e');
    }
    return null;
  }

  /// Centralized server token request pipeline.
  Future<String?> _requestTokenFromServer({
    required String channelName,
    required int uid,
    required String role,
    required int expirationTimeInSeconds,
    Duration timeout = _defaultRequestTimeout,
  }) async {
    // 1. Primary: Firebase Cloud Functions (`generateAgoraToken`)
    final tokenFromFirebase = await _requestTokenFromFirebase(
      channelName: channelName,
      uid: uid,
      role: role,
      expirationTimeInSeconds: expirationTimeInSeconds,
      timeout: timeout,
    );
    if (tokenFromFirebase != null && tokenFromFirebase.isNotEmpty) {
      return tokenFromFirebase;
    }

    // 2. Secondary fallback: HTTP server if available (e.g. Railway / Node.js backend)
    final tokenFromHttp = await _requestTokenFromHttp(
      channelName: channelName,
      uid: uid,
      role: role,
      expirationTimeInSeconds: expirationTimeInSeconds,
      timeout: timeout,
    );
    if (tokenFromHttp != null && tokenFromHttp.isNotEmpty) {
      return tokenFromHttp;
    }

    _logError(
        'All token generation attempts failed for channel: $channelName, uid: $uid');
    return null;
  }

  // ===========================================================================
  // Public Token API
  // ===========================================================================

  /// Generates or retrieves a cached Agora RTC token for a channel session.
  ///
  /// Flow:
  /// 1. Checks LRU cache for unexpired valid token.
  /// 2. Requests new token from secure backend server.
  /// 3. Validates and caches response in LRU cache.
  Future<TokenResponse?> generateToken({
    required String channelName,
    required int uid,
    String role = 'publisher',
    int expirationTimeInSeconds = _defaultExpirationSeconds,
  }) async {
    try {
      final cleanChannel = channelName.trim();
      if (cleanChannel.isEmpty) {
        _logError('Invalid argument: channelName cannot be empty');
        return null;
      }

      final normalizedRole = AgoraRole.fromString(role).value;
      final cacheKey = _createCacheKey(cleanChannel, uid, normalizedRole);

      // 1. Check LRU Cache
      _removeExpiredTokens();
      if (_tokenCache.containsKey(cacheKey)) {
        final cached = _tokenCache[cacheKey]!;
        if (_isTokenValid(cached)) {
          _logDebug('Returning valid cached token for $cacheKey');
          // Promote to most recently used
          _cacheToken(cacheKey, cached);
          return cached;
        } else {
          _tokenCache.remove(cacheKey);
        }
      }

      // 2. Request Token from Trusted Server
      final tokenString = await _requestTokenFromServer(
        channelName: cleanChannel,
        uid: uid,
        role: normalizedRole,
        expirationTimeInSeconds: expirationTimeInSeconds,
      );

      if (tokenString == null || tokenString.isEmpty) {
        return null;
      }

      // 3. Create, Cache, and Return TokenResponse
      final expiresAt =
          DateTime.now().add(Duration(seconds: expirationTimeInSeconds));
      final response = TokenResponse(
        token: tokenString,
        uid: uid,
        channelName: cleanChannel,
        expiresAt: expiresAt,
      );

      _cacheToken(cacheKey, response);
      _logDebug('Token successfully acquired and cached for $cleanChannel (uid: $uid)');
      return response;
    } catch (e) {
      _logError('Exception in generateToken', e);
      return null;
    }
  }

  /// Generates tokens for multiple users concurrently in parallel.
  Future<List<TokenResponse>?> generateBatchTokens({
    required String channelName,
    required List<TokenRequest> users,
    int expirationTimeInSeconds = 3600,
  }) async {
    try {
      _logDebug(
          'Generating batch tokens in parallel for ${users.length} users in $channelName');
      if (users.isEmpty) return [];

      final futures = users.map((user) => generateToken(
            channelName: channelName,
            uid: user.uid,
            role: user.role,
            expirationTimeInSeconds: expirationTimeInSeconds,
          ));

      final results = await Future.wait(futures);
      final validTokens = results.whereType<TokenResponse>().toList();

      _logDebug(
          'Batch token generation completed: ${validTokens.length}/${users.length} succeeded');
      return validTokens.isNotEmpty ? validTokens : null;
    } catch (e) {
      _logError('Error generating batch tokens', e);
      return null;
    }
  }

  /// Refreshes an existing token by invalidating any cached matching token
  /// and requesting a fresh token from the server.
  Future<TokenResponse?> refreshToken({
    required String channelName,
    required int uid,
    required String currentToken,
    String role = 'publisher',
    int expirationTimeInSeconds = _defaultExpirationSeconds,
  }) async {
    try {
      _logDebug('Refreshing token for channel: $channelName, uid: $uid');
      final normalizedRole = AgoraRole.fromString(role).value;
      final cacheKey = _createCacheKey(channelName, uid, normalizedRole);

      // Invalidate existing cache if it matches the current expiring token
      final existing = _tokenCache[cacheKey];
      if (existing != null &&
          (existing.token == currentToken || existing.willExpireSoon)) {
        _tokenCache.remove(cacheKey);
      }

      return await generateToken(
        channelName: channelName,
        uid: uid,
        role: normalizedRole,
        expirationTimeInSeconds: expirationTimeInSeconds,
      );
    } catch (e) {
      _logError('Error refreshing token', e);
      return null;
    }
  }

  /// Returns diagnostic metadata regarding token cache and endpoint status.
  Future<Map<String, dynamic>?> getTokenInfo() async {
    try {
      final appId = _getAppId() ?? '';
      final maskedAppId =
          appId.length >= 5 ? '${appId.substring(0, 5)}...' : (appId.isNotEmpty ? '***' : 'not_configured');

      return {
        'success': true,
        'service': 'Dynamic Server-Backed Agora Token Service',
        'endpoint': railwayFunctionUrl,
        'currentTimestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'serverTime': DateTime.now().toIso8601String(),
        'cacheSize': _tokenCache.length,
        'appId': maskedAppId,
        'isConfigured': _isConfigured(),
      };
    } catch (e) {
      _logError('Error getting token info', e);
      return null;
    }
  }

  /// Checks whether a given [TokenResponse] will expire soon or has expired.
  bool shouldRenewToken(TokenResponse token) {
    return token.willExpireSoon || token.isExpired;
  }

  /// Retrieves a valid cached token if present, otherwise returns `null`.
  TokenResponse? getCachedToken(String channelName, int uid, String role) {
    final key = _createCacheKey(channelName, uid, role);
    final cached = _tokenCache[key];

    if (_isTokenValid(cached)) {
      _cacheToken(key, cached!); // Promote to MRU
      return cached;
    }

    if (cached != null) {
      _tokenCache.remove(key);
    }
    return null;
  }

  /// Clears the entire token cache.
  void clearCache() {
    _tokenCache.clear();
    _logDebug('Token cache cleared');
  }

  /// Clears a specific token from the cache.
  void clearTokenFromCache(String channelName, int uid, String role) {
    final key = _createCacheKey(channelName, uid, role);
    _tokenCache.remove(key);
    _logDebug('Token removed from cache: $key');
  }

  /// Returns runtime statistics for cached tokens.
  Map<String, dynamic> getCacheStats() {
    final validTokens = _tokenCache.values.where((t) => !t.isExpired).length;
    final expiredTokens = _tokenCache.values.where((t) => t.isExpired).length;
    final expiringSoon =
        _tokenCache.values.where((t) => t.willExpireSoon && !t.isExpired).length;

    return {
      'totalTokens': _tokenCache.length,
      'validTokens': validTokens,
      'expiredTokens': expiredTokens,
      'expiringSoon': expiringSoon,
      'cacheKeys': _tokenCache.keys.map((k) => k.toString()).toList(),
    };
  }

  /// Manually cleans up expired tokens from the cache.
  void cleanupExpiredTokens() {
    _removeExpiredTokens();
  }

  /// Releases resources and resets singleton state.
  void dispose() {
    _tokenCache.clear();
    _logDebug('Token service disposed and cache reset');
  }
}

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'global_settings_service.dart';
import 'vps_api_service.dart';
import 'vps_socket_service.dart';

enum BackendEngineType {
  firebase,
  vps,
}

/// Unified Backend Engine Manager that decides dynamically whether to route
/// 1v1 chat, voice rooms, gifts, assets, and database operations through
/// Firebase Firestore or self-hosted VPS PostgreSQL Backend based on Admin settings.
class BackendEngineManager extends GetxService {
  static BackendEngineManager get instance {
    if (!Get.isRegistered<BackendEngineManager>()) {
      Get.put(BackendEngineManager(), permanent: true);
    }
    return Get.find<BackendEngineManager>();
  }

  static bool get isVps => instance.isVpsActive;
  static bool get isFirebase => instance.isFirebaseActive;

  final GlobalSettingsService _settings = Get.isRegistered<GlobalSettingsService>()
      ? Get.find<GlobalSettingsService>()
      : Get.put(GlobalSettingsService(), permanent: true);

  /// Returns the currently active backend engine type based on Admin Panel config
  BackendEngineType get activeEngine {
    final engineStr = _settings.activeBackendEngine.value.trim().toUpperCase();
    if (engineStr == 'VPS' || engineStr == 'POSTGRES' || engineStr == 'POSTGRESQL') {
      // Ensure VPS Base URL is configured
      if (_settings.vpsBaseUrl.value.trim().isNotEmpty) {
        return BackendEngineType.vps;
      }
    }
    // Default to Firebase for absolute stability & backwards compatibility
    return BackendEngineType.firebase;
  }

  bool get isVpsActive => activeEngine == BackendEngineType.vps;
  bool get isFirebaseActive => activeEngine == BackendEngineType.firebase;

  VpsApiService get apiService {
    if (!Get.isRegistered<VpsApiService>()) {
      Get.put(VpsApiService(), permanent: true);
    }
    return Get.find<VpsApiService>();
  }

  VpsSocketService get socketService {
    if (!Get.isRegistered<VpsSocketService>()) {
      Get.put(VpsSocketService(), permanent: true);
    }
    return Get.find<VpsSocketService>();
  }

  /// VPS Base REST URL
  String get vpsBaseUrl => _settings.vpsBaseUrl.value.trim();

  /// VPS WebSocket URL
  String get vpsSocketUrl => _settings.vpsSocketUrl.value.trim();

  /// Automatic failover to Firebase if VPS connection fails
  Future<void> handleVpsFailover({
    required VoidCallback onFallbackToFirebase,
  }) async {
    if (_settings.autoFailoverBackendToFirebase.value) {
      debugPrint('[BackendEngineManager] VPS Server unreachable, initiating auto-failover to Firebase Cloud...');
      onFallbackToFirebase();
    }
  }
}

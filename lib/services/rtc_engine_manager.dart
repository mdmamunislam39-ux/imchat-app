import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'agora_service.dart';
import 'global_settings_service.dart';
import 'livekit_service.dart';

enum RtcEngineType {
  agora,
  livekit,
}

/// Unified RTC Engine Manager that decides dynamically whether to route
/// voice/video rooms and calls through Agora or LiveKit based on Admin settings.
class RtcEngineManager extends GetxService {
  final GlobalSettingsService _settings = Get.find<GlobalSettingsService>();

  /// Returns the currently active RTC engine type based on Admin Panel config
  RtcEngineType get activeEngine {
    final engineStr = _settings.activeRtcEngine.value.trim().toUpperCase();
    if (engineStr == 'LIVEKIT' || engineStr == 'VPS') {
      return RtcEngineType.livekit;
    }
    // Default to Agora when explicitly set to AGORA
    return RtcEngineType.agora;
  }

  bool get isLiveKitActive => activeEngine == RtcEngineType.livekit;
  bool get isAgoraActive => activeEngine == RtcEngineType.agora;

  LiveKitService get livekitService {
    if (!Get.isRegistered<LiveKitService>()) {
      Get.put(LiveKitService(), permanent: true);
    }
    return Get.find<LiveKitService>();
  }

  AgoraService get agoraService {
    return AgoraService();
  }

  /// Get LiveKit WebSocket Server URL configured by Admin
  String get livekitServerUrl => _settings.livekitServerUrl.value.trim();

  /// Handle automatic failover to Agora if LiveKit server is unreachable
  Future<void> handleLiveKitFailover({
    required VoidCallback onFallbackToAgora,
  }) async {
    if (_settings.autoFailoverRtcToAgora.value) {
      debugPrint('[RtcEngineManager] LiveKit unreachable, initiating auto-failover to Agora...');
      onFallbackToAgora();
    }
  }
}

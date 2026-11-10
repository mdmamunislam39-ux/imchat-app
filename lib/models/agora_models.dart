import 'package:equatable/equatable.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';

/// Agora audio quality levels
enum AudioQuality {
  low,
  standard,
  high,
  ultra,
}

extension AudioQualityExtension on AudioQuality {
  String get displayName {
    switch (this) {
      case AudioQuality.low:
        return 'Low Quality';
      case AudioQuality.standard:
        return 'Standard Quality';
      case AudioQuality.high:
        return 'High Quality';
      case AudioQuality.ultra:
        return 'Ultra Quality';
    }
  }

  AudioProfileType get agoraProfile {
    switch (this) {
      case AudioQuality.low:
        return AudioProfileType.audioProfileSpeechStandard;
      case AudioQuality.standard:
        return AudioProfileType.audioProfileMusicStandard;
      case AudioQuality.high:
        return AudioProfileType.audioProfileMusicStandard;
      case AudioQuality.ultra:
        return AudioProfileType.audioProfileMusicHighQuality;
    }
  }

  AudioScenarioType get agoraScenario {
    switch (this) {
      case AudioQuality.low:
        return AudioScenarioType.audioScenarioGameStreaming;
      case AudioQuality.standard:
        return AudioScenarioType.audioScenarioGameStreaming;
      case AudioQuality.high:
        return AudioScenarioType.audioScenarioGameStreaming;
      case AudioQuality.ultra:
        return AudioScenarioType.audioScenarioGameStreaming;
    }
  }
}

/// Agora connection state
enum AgoraConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  failed,
}

extension AgoraConnectionStateExtension on AgoraConnectionState {
  String get displayName {
    switch (this) {
      case AgoraConnectionState.disconnected:
        return 'Disconnected';
      case AgoraConnectionState.connecting:
        return 'Connecting...';
      case AgoraConnectionState.connected:
        return 'Connected';
      case AgoraConnectionState.reconnecting:
        return 'Reconnecting...';
      case AgoraConnectionState.failed:
        return 'Connection Failed';
    }
  }

  bool get isConnected => this == AgoraConnectionState.connected;
  bool get canSpeak => this == AgoraConnectionState.connected;
}

/// Audio effects that can be applied
enum AudioEffect {
  none,
  ktv,
  concert,
  recording,
  phonograph,
  ethereal,
  spacial,
  electronic,
  vintage,
}

extension AudioEffectExtension on AudioEffect {
  String get displayName {
    switch (this) {
      case AudioEffect.none:
        return 'None';
      case AudioEffect.ktv:
        return 'KTV';
      case AudioEffect.concert:
        return 'Concert';
      case AudioEffect.recording:
        return 'Recording Studio';
      case AudioEffect.phonograph:
        return 'Phonograph';
      case AudioEffect.ethereal:
        return 'Ethereal';
      case AudioEffect.spacial:
        return '3D Spatial';
      case AudioEffect.electronic:
        return 'Electronic';
      case AudioEffect.vintage:
        return 'Vintage';
    }
  }

  AudioReverbType get agoraPreset {
    switch (this) {
      case AudioEffect.none:
        return AudioReverbType.audioReverbDryLevel;
      case AudioEffect.ktv:
        return AudioReverbType.audioReverbRoomSize;
      case AudioEffect.concert:
        return AudioReverbType.audioReverbRoomSize;
      case AudioEffect.recording:
        return AudioReverbType.audioReverbRoomSize;
      case AudioEffect.phonograph:
        return AudioReverbType.audioReverbRoomSize;
      case AudioEffect.ethereal:
        return AudioReverbType.audioReverbRoomSize;
      case AudioEffect.spacial:
        return AudioReverbType.audioReverbRoomSize;
      case AudioEffect.electronic:
        return AudioReverbType.audioReverbRoomSize;
      case AudioEffect.vintage:
        return AudioReverbType.audioReverbRoomSize;
    }
  }
}

/// Voice changer effects
enum VoiceChanger {
  none,
  oldMan,
  babyBoy,
  babyGirl,
  zhubajie,
  ethereal,
  hulk,
  robot,
  chipmunk,
}

extension VoiceChangerExtension on VoiceChanger {
  String get displayName {
    switch (this) {
      case VoiceChanger.none:
        return 'Original';
      case VoiceChanger.oldMan:
        return 'Old Man';
      case VoiceChanger.babyBoy:
        return 'Baby Boy';
      case VoiceChanger.babyGirl:
        return 'Baby Girl';
      case VoiceChanger.zhubajie:
        return 'Zhu Bajie';
      case VoiceChanger.ethereal:
        return 'Ethereal';
      case VoiceChanger.hulk:
        return 'Hulk';
      case VoiceChanger.robot:
        return 'Robot';
      case VoiceChanger.chipmunk:
        return 'Chipmunk';
    }
  }
}

/// Agora user information with enhanced audio properties
class AgoraUser extends Equatable {
  final int uid;
  final String userId; // Your app's user ID
  final String userName;
  final String? userImageUrl;
  final bool isMuted;
  final bool isSpeaking;
  final bool hasAudio;
  final int audioLevel; // 0-255
  final DateTime lastSpokeAt;
  final AudioQuality audioQuality;
  final AudioEffect audioEffect;
  final VoiceChanger voiceChanger;
  final int? seatNumber;

  const AgoraUser({
    required this.uid,
    required this.userId,
    required this.userName,
    this.userImageUrl,
    this.isMuted = false,
    this.isSpeaking = false,
    this.hasAudio = false,
    this.audioLevel = 0,
    required this.lastSpokeAt,
    this.audioQuality = AudioQuality.standard,
    this.audioEffect = AudioEffect.none,
    this.voiceChanger = VoiceChanger.none,
    this.seatNumber,
  });

  AgoraUser copyWith({
    int? uid,
    String? userId,
    String? userName,
    String? userImageUrl,
    bool? isMuted,
    bool? isSpeaking,
    bool? hasAudio,
    int? audioLevel,
    DateTime? lastSpokeAt,
    AudioQuality? audioQuality,
    AudioEffect? audioEffect,
    VoiceChanger? voiceChanger,
    int? seatNumber,
  }) {
    return AgoraUser(
      uid: uid ?? this.uid,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userImageUrl: userImageUrl ?? this.userImageUrl,
      isMuted: isMuted ?? this.isMuted,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      hasAudio: hasAudio ?? this.hasAudio,
      audioLevel: audioLevel ?? this.audioLevel,
      lastSpokeAt: lastSpokeAt ?? this.lastSpokeAt,
      audioQuality: audioQuality ?? this.audioQuality,
      audioEffect: audioEffect ?? this.audioEffect,
      voiceChanger: voiceChanger ?? this.voiceChanger,
      seatNumber: seatNumber ?? this.seatNumber,
    );
  }

  /// Check if user is actively speaking (spoke in last 3 seconds)
  bool get isActivelySpeaking {
    return isSpeaking &&
        DateTime.now().difference(lastSpokeAt).inSeconds < 3 &&
        audioLevel > 10;
  }

  /// Get audio level as percentage
  double get audioLevelPercentage => audioLevel / 255.0;

  @override
  List<Object?> get props => [
        uid,
        userId,
        userName,
        userImageUrl,
        isMuted,
        isSpeaking,
        hasAudio,
        audioLevel,
        lastSpokeAt,
        audioQuality,
        audioEffect,
        voiceChanger,
        seatNumber,
      ];
}

/// Agora room configuration
class AgoraRoomConfig extends Equatable {
  final String appId;
  final String channelName;
  final String? token;
  final int uid;
  final AudioQuality audioQuality;
  final bool enableAudioVolumeIndication;
  final int audioVolumeIndicationInterval; // milliseconds
  final bool enableAudioProcessing;
  final bool enableEchoCancellation;
  final bool enableNoiseReduction;
  final bool enableAutoGainControl;
  final AudioEffect defaultAudioEffect;
  final VoiceChanger defaultVoiceChanger;

  const AgoraRoomConfig({
    required this.appId,
    required this.channelName,
    this.token,
    required this.uid,
    this.audioQuality = AudioQuality.high,
    this.enableAudioVolumeIndication = true,
    this.audioVolumeIndicationInterval = 200,
    this.enableAudioProcessing = true,
    this.enableEchoCancellation = true,
    this.enableNoiseReduction = true,
    this.enableAutoGainControl = true,
    this.defaultAudioEffect = AudioEffect.none,
    this.defaultVoiceChanger = VoiceChanger.none,
  });

  AgoraRoomConfig copyWith({
    String? appId,
    String? channelName,
    String? token,
    int? uid,
    AudioQuality? audioQuality,
    bool? enableAudioVolumeIndication,
    int? audioVolumeIndicationInterval,
    bool? enableAudioProcessing,
    bool? enableEchoCancellation,
    bool? enableNoiseReduction,
    bool? enableAutoGainControl,
    AudioEffect? defaultAudioEffect,
    VoiceChanger? defaultVoiceChanger,
  }) {
    return AgoraRoomConfig(
      appId: appId ?? this.appId,
      channelName: channelName ?? this.channelName,
      token: token ?? this.token,
      uid: uid ?? this.uid,
      audioQuality: audioQuality ?? this.audioQuality,
      enableAudioVolumeIndication:
          enableAudioVolumeIndication ?? this.enableAudioVolumeIndication,
      audioVolumeIndicationInterval:
          audioVolumeIndicationInterval ?? this.audioVolumeIndicationInterval,
      enableAudioProcessing:
          enableAudioProcessing ?? this.enableAudioProcessing,
      enableEchoCancellation:
          enableEchoCancellation ?? this.enableEchoCancellation,
      enableNoiseReduction: enableNoiseReduction ?? this.enableNoiseReduction,
      enableAutoGainControl:
          enableAutoGainControl ?? this.enableAutoGainControl,
      defaultAudioEffect: defaultAudioEffect ?? this.defaultAudioEffect,
      defaultVoiceChanger: defaultVoiceChanger ?? this.defaultVoiceChanger,
    );
  }

  @override
  List<Object?> get props => [
        appId,
        channelName,
        token,
        uid,
        audioQuality,
        enableAudioVolumeIndication,
        audioVolumeIndicationInterval,
        enableAudioProcessing,
        enableEchoCancellation,
        enableNoiseReduction,
        enableAutoGainControl,
        defaultAudioEffect,
        defaultVoiceChanger,
      ];
}

/// Agora statistics and performance metrics
class AgoraStats extends Equatable {
  final int duration; // seconds
  final int txBytes;
  final int rxBytes;
  final int txKBitRate;
  final int rxKBitRate;
  final int userCount;
  final double cpuAppUsage;
  final double cpuTotalUsage;
  final int gatewayRtt;
  final double memoryAppUsageRatio;
  final int memoryTotalUsageRatio;
  final int memoryAppUsageInKbytes;

  const AgoraStats({
    required this.duration,
    required this.txBytes,
    required this.rxBytes,
    required this.txKBitRate,
    required this.rxKBitRate,
    required this.userCount,
    required this.cpuAppUsage,
    required this.cpuTotalUsage,
    required this.gatewayRtt,
    required this.memoryAppUsageRatio,
    required this.memoryTotalUsageRatio,
    required this.memoryAppUsageInKbytes,
  });

  factory AgoraStats.fromRtcStats(RtcStats stats) {
    return AgoraStats(
      duration: stats.duration ?? 0,
      txBytes: stats.txBytes ?? 0,
      rxBytes: stats.rxBytes ?? 0,
      txKBitRate: stats.txKBitRate ?? 0,
      rxKBitRate: stats.rxKBitRate ?? 0,
      userCount: stats.userCount ?? 0,
      cpuAppUsage: stats.cpuAppUsage ?? 0.0,
      cpuTotalUsage: stats.cpuTotalUsage ?? 0.0,
      gatewayRtt: stats.gatewayRtt ?? 0,
      memoryAppUsageRatio: stats.memoryAppUsageRatio ?? 0.0,
      memoryTotalUsageRatio: (stats.memoryTotalUsageRatio ?? 0).toInt(),
      memoryAppUsageInKbytes: stats.memoryAppUsageInKbytes ?? 0,
    );
  }

  /// Get connection quality based on RTT and packet loss
  String get connectionQuality {
    if (gatewayRtt < 100) return 'Excellent';
    if (gatewayRtt < 200) return 'Good';
    if (gatewayRtt < 400) return 'Fair';
    if (gatewayRtt < 800) return 'Poor';
    return 'Very Poor';
  }

  /// Get network usage in MB
  double get totalDataUsageMB => (txBytes + rxBytes) / (1024 * 1024);

  /// Get average bitrate
  int get avgBitRate => (txKBitRate + rxKBitRate) ~/ 2;

  @override
  List<Object?> get props => [
        duration,
        txBytes,
        rxBytes,
        txKBitRate,
        rxKBitRate,
        userCount,
        cpuAppUsage,
        cpuTotalUsage,
        gatewayRtt,
        memoryAppUsageRatio,
        memoryTotalUsageRatio,
        memoryAppUsageInKbytes,
      ];
}

/// Network quality information
class NetworkQuality extends Equatable {
  final int uid;
  final QualityType txQuality;
  final QualityType rxQuality;

  const NetworkQuality({
    required this.uid,
    required this.txQuality,
    required this.rxQuality,
  });

  factory NetworkQuality.fromAgora(
      int uid, QualityType txQuality, QualityType rxQuality) {
    return NetworkQuality(
      uid: uid,
      txQuality: txQuality,
      rxQuality: rxQuality,
    );
  }

  /// Get overall quality (worst of tx/rx)
  QualityType get overallQuality {
    final txValue = _qualityToInt(txQuality);
    final rxValue = _qualityToInt(rxQuality);
    return _intToQuality(txValue > rxValue ? txValue : rxValue);
  }

  /// Get quality as string
  String get qualityString {
    switch (overallQuality) {
      case QualityType.qualityExcellent:
        return 'Excellent';
      case QualityType.qualityGood:
        return 'Good';
      case QualityType.qualityPoor:
        return 'Poor';
      case QualityType.qualityBad:
        return 'Bad';
      case QualityType.qualityVbad:
        return 'Very Bad';
      case QualityType.qualityDown:
        return 'Down';
      default:
        return 'Unknown';
    }
  }

  int _qualityToInt(QualityType quality) {
    switch (quality) {
      case QualityType.qualityExcellent:
        return 1;
      case QualityType.qualityGood:
        return 2;
      case QualityType.qualityPoor:
        return 3;
      case QualityType.qualityBad:
        return 4;
      case QualityType.qualityVbad:
        return 5;
      case QualityType.qualityDown:
        return 6;
      default:
        return 7;
    }
  }

  QualityType _intToQuality(int value) {
    switch (value) {
      case 1:
        return QualityType.qualityExcellent;
      case 2:
        return QualityType.qualityGood;
      case 3:
        return QualityType.qualityPoor;
      case 4:
        return QualityType.qualityBad;
      case 5:
        return QualityType.qualityVbad;
      case 6:
        return QualityType.qualityDown;
      default:
        return QualityType.qualityUnknown;
    }
  }

  @override
  List<Object?> get props => [uid, txQuality, rxQuality];
}

/// Audio mixing configuration for background music
class AudioMixingConfig extends Equatable {
  final String filePath;
  final bool loopback;
  final bool replace;
  final int cycle;
  final int startPos;
  final int playoutVolume;
  final int publishVolume;

  const AudioMixingConfig({
    required this.filePath,
    this.loopback = false,
    this.replace = false,
    this.cycle = 1,
    this.startPos = 0,
    this.playoutVolume = 100,
    this.publishVolume = 100,
  });

  @override
  List<Object?> get props => [
        filePath,
        loopback,
        replace,
        cycle,
        startPos,
        playoutVolume,
        publishVolume,
      ];
}

/// Token generation request model
class TokenRequest extends Equatable {
  final String channelName;
  final int uid;
  final String role; // 'publisher' or 'subscriber'
  final int expirationTimeInSeconds;

  const TokenRequest({
    required this.channelName,
    required this.uid,
    this.role = 'publisher',
    this.expirationTimeInSeconds = 3600, // 1 hour default
  });

  Map<String, dynamic> toJson() {
    return {
      'channelName': channelName,
      'uid': uid,
      'role': role,
      'expirationTimeInSeconds': expirationTimeInSeconds,
    };
  }

  @override
  List<Object?> get props => [channelName, uid, role, expirationTimeInSeconds];
}

/// Token generation response model
class TokenResponse extends Equatable {
  final String token;
  final int uid;
  final String channelName;
  final DateTime expiresAt;

  const TokenResponse({
    required this.token,
    required this.uid,
    required this.channelName,
    required this.expiresAt,
  });

  factory TokenResponse.fromJson(Map<String, dynamic> json) {
    return TokenResponse(
      token: json['token'] ?? '',
      uid: json['uid'] ?? 0,
      channelName: json['channelName'] ?? '',
      expiresAt: DateTime.fromMillisecondsSinceEpoch(json['expiresAt'] ?? 0),
    );
  }

  /// Check if token is expired or will expire soon
  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get willExpireSoon =>
      DateTime.now().add(const Duration(minutes: 5)).isAfter(expiresAt);

  @override
  List<Object?> get props => [token, uid, channelName, expiresAt];
}

/// Generate a deterministic, collision-resistant non-zero 32-bit integer UID from string user ID
int generateAgoraUid(String userId) {
  if (userId.isEmpty) return 100001;
  int hash = 5381;
  for (int i = 0; i < userId.length; i++) {
    hash = (((hash << 5) + hash) + userId.codeUnitAt(i)) & 0x7FFFFFFF;
  }
  // Range: 100,000 to 899,999,999 (always positive, non-zero, safe for Agora 32-bit uint)
  final uid = (hash % 899900000) + 100000;
  return uid;
}

/// Represents audio output routing options detected by Agora
enum AgoraAudioRoute {
  defaultRoute,
  headset,
  earpiece,
  headsetNoMic,
  speakerphone,
  loudspeaker,
  bluetooth,
  usb,
  unknown,
}

extension AgoraAudioRouteExtension on AgoraAudioRoute {
  String get displayName {
    switch (this) {
      case AgoraAudioRoute.headset:
        return 'Headset';
      case AgoraAudioRoute.earpiece:
        return 'Earpiece';
      case AgoraAudioRoute.headsetNoMic:
        return 'Headphones';
      case AgoraAudioRoute.speakerphone:
        return 'Speakerphone';
      case AgoraAudioRoute.loudspeaker:
        return 'Loudspeaker';
      case AgoraAudioRoute.bluetooth:
        return 'Bluetooth Device';
      case AgoraAudioRoute.usb:
        return 'USB Audio';
      case AgoraAudioRoute.defaultRoute:
      case AgoraAudioRoute.unknown:
        return 'Default Audio';
    }
  }

  bool get isBluetooth => this == AgoraAudioRoute.bluetooth;
  bool get isHeadset =>
      this == AgoraAudioRoute.headset || this == AgoraAudioRoute.headsetNoMic;
  bool get isSpeaker =>
      this == AgoraAudioRoute.speakerphone ||
      this == AgoraAudioRoute.loudspeaker;
  bool get isEarpiece => this == AgoraAudioRoute.earpiece;

  static AgoraAudioRoute fromAgoraInt(int routing) {
    switch (routing) {
      case -1:
        return AgoraAudioRoute.defaultRoute;
      case 0:
        return AgoraAudioRoute.headset;
      case 1:
        return AgoraAudioRoute.earpiece;
      case 2:
        return AgoraAudioRoute.headsetNoMic;
      case 3:
        return AgoraAudioRoute.speakerphone;
      case 4:
        return AgoraAudioRoute.loudspeaker;
      case 5:
        return AgoraAudioRoute.bluetooth;
      case 6:
        return AgoraAudioRoute.usb;
      default:
        return AgoraAudioRoute.unknown;
    }
  }
}

/// Call session mode for AgoraService
enum AgoraCallType {
  audioRoom,
  audioCall,
  videoCall,
  groupCall,
}


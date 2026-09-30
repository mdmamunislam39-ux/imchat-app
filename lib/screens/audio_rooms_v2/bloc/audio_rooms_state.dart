import 'package:equatable/equatable.dart';
import 'package:chat_messenger/models/audio_room_v2.dart';
import 'package:chat_messenger/models/emoji_models.dart';
import 'package:chat_messenger/models/agora_models.dart';

/// Base class for Audio Rooms states
abstract class AudioRoomsState extends Equatable {
  const AudioRoomsState();

  @override
  List<Object?> get props => [];
}

/// Initial state
class AudioRoomsInitial extends AudioRoomsState {
  const AudioRoomsInitial();
}

/// Loading state
class AudioRoomsLoading extends AudioRoomsState {
  const AudioRoomsLoading();
}

/// Loaded state with rooms data
class AudioRoomsLoaded extends AudioRoomsState {
  final List<AudioRoomV2> rooms;
  final List<AudioRoomV2> userRooms;
  final List<AudioRoomV2> searchResults;
  final bool isSearching;
  final String searchQuery;

  const AudioRoomsLoaded({
    required this.rooms,
    required this.userRooms,
    this.searchResults = const [],
    this.isSearching = false,
    this.searchQuery = '',
  });

  /// Create a copy with updated fields
  AudioRoomsLoaded copyWith({
    List<AudioRoomV2>? rooms,
    List<AudioRoomV2>? userRooms,
    List<AudioRoomV2>? searchResults,
    bool? isSearching,
    String? searchQuery,
  }) {
    return AudioRoomsLoaded(
      rooms: rooms ?? this.rooms,
      userRooms: userRooms ?? this.userRooms,
      searchResults: searchResults ?? this.searchResults,
      isSearching: isSearching ?? this.isSearching,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  /// Get active rooms
  List<AudioRoomV2> get activeRooms => rooms.where((room) => room.isActive).toList();

  /// Get popular rooms (pinned first, then sorted by participant count)
  List<AudioRoomV2> get popularRooms {
    final sortedRooms = List<AudioRoomV2>.from(activeRooms);
    sortedRooms.sort((a, b) {
      if (a.isCurrentlyPinned && !b.isCurrentlyPinned) return -1;
      if (!a.isCurrentlyPinned && b.isCurrentlyPinned) return 1;
      return b.participantCount.compareTo(a.participantCount);
    });
    return sortedRooms;
  }

  /// Get recent rooms (pinned first, then sorted by creation date)
  List<AudioRoomV2> get recentRooms {
    final sortedRooms = List<AudioRoomV2>.from(activeRooms);
    sortedRooms.sort((a, b) {
      if (a.isCurrentlyPinned && !b.isCurrentlyPinned) return -1;
      if (!a.isCurrentlyPinned && b.isCurrentlyPinned) return 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return sortedRooms;
  }

  /// Get rooms to display (search results or all rooms)
  List<AudioRoomV2> get displayRooms => isSearching ? searchResults : rooms;

  @override
  List<Object?> get props => [
        rooms,
        userRooms,
        searchResults,
        isSearching,
        searchQuery,
      ];
}

/// Error state
class AudioRoomsError extends AudioRoomsState {
  final String message;
  final String? errorCode;

  const AudioRoomsError({
    required this.message,
    this.errorCode,
  });

  @override
  List<Object?> get props => [message, errorCode];
}

/// Creating room state
class CreatingAudioRoom extends AudioRoomsState {
  const CreatingAudioRoom();
}

/// Room created successfully
class AudioRoomCreated extends AudioRoomsState {
  final AudioRoomV2 room;

  const AudioRoomCreated({required this.room});

  @override
  List<Object?> get props => [room];
}

/// Room creation failed
class AudioRoomCreationFailed extends AudioRoomsState {
  final String message;

  const AudioRoomCreationFailed({required this.message});

  @override
  List<Object?> get props => [message];
}

/// Joining room state
class JoiningAudioRoom extends AudioRoomsState {
  final String roomId;

  const JoiningAudioRoom({required this.roomId});

  @override
  List<Object?> get props => [roomId];
}

/// Successfully joined room
class AudioRoomJoined extends AudioRoomsState {
  final AudioRoomV2 room;
  final AudioRoomParticipant participant;

  const AudioRoomJoined({
    required this.room,
    required this.participant,
  });

  @override
  List<Object?> get props => [room, participant];
}

/// Failed to join room
class AudioRoomJoinFailed extends AudioRoomsState {
  final String message;
  final String roomId;

  const AudioRoomJoinFailed({
    required this.message,
    required this.roomId,
  });

  @override
  List<Object?> get props => [message, roomId];
}

/// Leaving room state
class LeavingAudioRoom extends AudioRoomsState {
  final String roomId;

  const LeavingAudioRoom({required this.roomId});

  @override
  List<Object?> get props => [roomId];
}

/// Successfully left room
class AudioRoomLeft extends AudioRoomsState {
  final String roomId;

  const AudioRoomLeft({required this.roomId});

  @override
  List<Object?> get props => [roomId];
}

/// Deleting room state
class DeletingAudioRoom extends AudioRoomsState {
  final String roomId;

  const DeletingAudioRoom({required this.roomId});

  @override
  List<Object?> get props => [roomId];
}

/// Room deleted successfully
class AudioRoomDeleted extends AudioRoomsState {
  final String roomId;

  const AudioRoomDeleted({required this.roomId});

  @override
  List<Object?> get props => [roomId];
}

/// Room updated (real-time update)
class AudioRoomUpdated extends AudioRoomsState {
  final AudioRoomV2 room;

  const AudioRoomUpdated({required this.room});

  @override
  List<Object?> get props => [room];
}

/// Chat messages loaded
class ChatMessagesLoaded extends AudioRoomsState {
  final String roomId;
  final List<ChatMessage> messages;

  const ChatMessagesLoaded({
    required this.roomId,
    required this.messages,
  });

  @override
  List<Object?> get props => [roomId, messages];
}

/// Emoji chat messages loaded
class EmojiChatMessagesLoaded extends AudioRoomsState {
  final String roomId;
  final List<EmojiChatMessage> messages;

  const EmojiChatMessagesLoaded({
    required this.roomId,
    required this.messages,
  });

  @override
  List<Object?> get props => [roomId, messages];
}

/// Chat message sent successfully
class ChatMessageSent extends AudioRoomsState {
  final ChatMessage message;

  const ChatMessageSent({required this.message});

  @override
  List<Object?> get props => [message];
}

/// Seat lock toggled successfully
class SeatLockToggled extends AudioRoomsState {
  final String roomId;
  final int seatNumber;
  final bool isLocked;

  const SeatLockToggled({
    required this.roomId,
    required this.seatNumber,
    required this.isLocked,
  });

  @override
  List<Object?> get props => [roomId, seatNumber, isLocked];
}

/// Participant moved to seat successfully
class ParticipantMovedToSeat extends AudioRoomsState {
  final String roomId;
  final String userId;
  final int fromSeat;
  final int toSeat;

  const ParticipantMovedToSeat({
    required this.roomId,
    required this.userId,
    required this.fromSeat,
    required this.toSeat,
  });

  @override
  List<Object?> get props => [roomId, userId, fromSeat, toSeat];
}

/// Participant removed from seat successfully
class ParticipantRemovedFromSeat extends AudioRoomsState {
  final String roomId;
  final String participantId;
  final int seatNumber;

  const ParticipantRemovedFromSeat({
    required this.roomId,
    required this.participantId,
    required this.seatNumber,
  });

  @override
  List<Object?> get props => [roomId, participantId, seatNumber];
}

/// Participant kicked successfully
class ParticipantKicked extends AudioRoomsState {
  final String roomId;
  final String participantId;
  final String reason;

  const ParticipantKicked({
    required this.roomId,
    required this.participantId,
    required this.reason,
  });

  @override
  List<Object?> get props => [roomId, participantId, reason];
}

/// Participant blocked successfully
class ParticipantBlocked extends AudioRoomsState {
  final String roomId;
  final String participantId;
  final String reason;

  const ParticipantBlocked({
    required this.roomId,
    required this.participantId,
    required this.reason,
  });

  @override
  List<Object?> get props => [roomId, participantId, reason];
}

/// Participant unblocked successfully
class ParticipantUnblocked extends AudioRoomsState {
  final String roomId;
  final String participantId;

  const ParticipantUnblocked({
    required this.roomId,
    required this.participantId,
  });

  @override
  List<Object?> get props => [roomId, participantId];
}

// ========================================
// AGORA-SPECIFIC STATES
// ========================================

/// Agora initialization states
class AgoraInitializing extends AudioRoomsState {
  const AgoraInitializing();
}

class AgoraInitialized extends AudioRoomsState {
  const AgoraInitialized();
}

class AgoraInitializationFailed extends AudioRoomsState {
  final String error;

  const AgoraInitializationFailed({required this.error});

  @override
  List<Object?> get props => [error];
}

/// Agora channel states
class AgoraChannelJoining extends AudioRoomsState {
  final String channelName;

  const AgoraChannelJoining({required this.channelName});

  @override
  List<Object?> get props => [channelName];
}

class AgoraChannelJoined extends AudioRoomsState {
  final String channelName;
  final int uid;
  final AgoraConnectionState connectionState;
  final List<AgoraUser> users;
  final bool isMuted;
  final bool isRoomMuted;
  final bool isSpeakerOn;
  final AudioQuality audioQuality;
  final AudioEffect audioEffect;
  final VoiceChanger voiceChanger;
  final AgoraStats? stats;
  final Map<int, NetworkQuality> networkQualities;

  const AgoraChannelJoined({
    required this.channelName,
    required this.uid,
    required this.connectionState,
    this.users = const [],
    this.isMuted = false,
    this.isRoomMuted = false,
    this.isSpeakerOn = true,
    this.audioQuality = AudioQuality.high,
    this.audioEffect = AudioEffect.none,
    this.voiceChanger = VoiceChanger.none,
    this.stats,
    this.networkQualities = const {},
  });

  AgoraChannelJoined copyWith({
    String? channelName,
    int? uid,
    AgoraConnectionState? connectionState,
    List<AgoraUser>? users,
    bool? isMuted,
    bool? isRoomMuted,
    bool? isSpeakerOn,
    AudioQuality? audioQuality,
    AudioEffect? audioEffect,
    VoiceChanger? voiceChanger,
    AgoraStats? stats,
    Map<int, NetworkQuality>? networkQualities,
  }) {
    return AgoraChannelJoined(
      channelName: channelName ?? this.channelName,
      uid: uid ?? this.uid,
      connectionState: connectionState ?? this.connectionState,
      users: users ?? this.users,
      isMuted: isMuted ?? this.isMuted,
      isRoomMuted: isRoomMuted ?? this.isRoomMuted,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      audioQuality: audioQuality ?? this.audioQuality,
      audioEffect: audioEffect ?? this.audioEffect,
      voiceChanger: voiceChanger ?? this.voiceChanger,
      stats: stats ?? this.stats,
      networkQualities: networkQualities ?? this.networkQualities,
    );
  }

  @override
  List<Object?> get props => [
        channelName,
        uid,
        connectionState,
        users,
        isMuted,
        isRoomMuted,
        isSpeakerOn,
        audioQuality,
        audioEffect,
        voiceChanger,
        stats,
        networkQualities,
      ];
}

class AgoraChannelJoinFailed extends AudioRoomsState {
  final String channelName;
  final String error;

  const AgoraChannelJoinFailed({
    required this.channelName,
    required this.error,
  });

  @override
  List<Object?> get props => [channelName, error];
}

class AgoraChannelLeft extends AudioRoomsState {
  const AgoraChannelLeft();
}

/// Audio control states
class MicrophoneToggled extends AudioRoomsState {
  final bool isMuted;

  const MicrophoneToggled({required this.isMuted});

  @override
  List<Object?> get props => [isMuted];
}

class RoomMuteToggled extends AudioRoomsState {
  final bool isRoomMuted;

  const RoomMuteToggled({required this.isRoomMuted});

  @override
  List<Object?> get props => [isRoomMuted];
}

class SpeakerToggled extends AudioRoomsState {
  final bool isSpeakerOn;

  const SpeakerToggled({required this.isSpeakerOn});

  @override
  List<Object?> get props => [isSpeakerOn];
}

class AudioQualityChanged extends AudioRoomsState {
  final AudioQuality quality;

  const AudioQualityChanged({required this.quality});

  @override
  List<Object?> get props => [quality];
}

class AudioEffectApplied extends AudioRoomsState {
  final AudioEffect effect;

  const AudioEffectApplied({required this.effect});

  @override
  List<Object?> get props => [effect];
}

class VoiceChangerApplied extends AudioRoomsState {
  final VoiceChanger changer;

  const VoiceChangerApplied({required this.changer});

  @override
  List<Object?> get props => [changer];
}

/// Background music states
class BackgroundMusicStarting extends AudioRoomsState {
  const BackgroundMusicStarting();
}

class BackgroundMusicStarted extends AudioRoomsState {
  final AudioMixingConfig config;

  const BackgroundMusicStarted({required this.config});

  @override
  List<Object?> get props => [config];
}

class BackgroundMusicStopped extends AudioRoomsState {
  const BackgroundMusicStopped();
}

class BackgroundMusicPaused extends AudioRoomsState {
  const BackgroundMusicPaused();
}

class BackgroundMusicResumed extends AudioRoomsState {
  const BackgroundMusicResumed();
}

class BackgroundMusicFailed extends AudioRoomsState {
  final String error;

  const BackgroundMusicFailed({required this.error});

  @override
  List<Object?> get props => [error];
}

/// User interaction states
class AgoraUserUpdated extends AudioRoomsState {
  final AgoraUser user;
  final String action; // 'joined', 'left', 'muted', 'unmuted', 'speaking', 'stopped_speaking'

  const AgoraUserUpdated({
    required this.user,
    required this.action,
  });

  @override
  List<Object?> get props => [user, action];
}

class AudioVolumeUpdated extends AudioRoomsState {
  final Map<int, int> userVolumes;
  final int totalVolume;

  const AudioVolumeUpdated({
    required this.userVolumes,
    required this.totalVolume,
  });

  @override
  List<Object?> get props => [userVolumes, totalVolume];
}

/// Connection and performance states
class AgoraConnectionUpdated extends AudioRoomsState {
  final AgoraConnectionState state;

  const AgoraConnectionUpdated({required this.state});

  @override
  List<Object?> get props => [state];
}

class NetworkQualityUpdated extends AudioRoomsState {
  final NetworkQuality quality;

  const NetworkQualityUpdated({required this.quality});

  @override
  List<Object?> get props => [quality];
}

class AgoraStatsUpdated extends AudioRoomsState {
  final AgoraStats stats;

  const AgoraStatsUpdated({required this.stats});

  @override
  List<Object?> get props => [stats];
}

/// Token management states
class TokenRenewing extends AudioRoomsState {
  const TokenRenewing();
}

class TokenRenewed extends AudioRoomsState {
  final String token;

  const TokenRenewed({required this.token});

  @override
  List<Object?> get props => [token];
}

class TokenRenewalFailed extends AudioRoomsState {
  final String error;

  const TokenRenewalFailed({required this.error});

  @override
  List<Object?> get props => [error];
}

/// General Agora error state
class AgoraError extends AudioRoomsState {
  final String message;
  final String code;

  const AgoraError({
    required this.message,
    required this.code,
  });

  @override
  List<Object?> get props => [message, code];
}
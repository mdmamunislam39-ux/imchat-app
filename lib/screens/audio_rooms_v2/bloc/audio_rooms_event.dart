import 'dart:io';
import 'package:equatable/equatable.dart';
import 'package:chat_messenger/models/audio_room_v2.dart';
import 'package:chat_messenger/models/emoji_models.dart';
import 'package:chat_messenger/models/agora_models.dart';
import 'package:chat_messenger/models/user.dart';

/// Base class for Audio Rooms events
abstract class AudioRoomsEvent extends Equatable {
  const AudioRoomsEvent();

  @override
  List<Object?> get props => [];
}

/// Load all audio rooms
class LoadAudioRooms extends AudioRoomsEvent {
  const LoadAudioRooms();
}

/// Refresh audio rooms list
class RefreshAudioRooms extends AudioRoomsEvent {
  const RefreshAudioRooms();
}

/// Load user's audio rooms
class LoadUserAudioRooms extends AudioRoomsEvent {
  final String userId;

  const LoadUserAudioRooms({required this.userId});

  @override
  List<Object?> get props => [userId];
}

/// Create new audio room
class CreateAudioRoom extends AudioRoomsEvent {
  final String name;
  final String description;
  final File? imageFile;
  final String creatorId;
  final String creatorName;
  final String? creatorImageUrl;
  final String? creatorFrameId;
  final AudioRoomSettings? settings;
  final String? category;

  const CreateAudioRoom({
    required this.name,
    required this.description,
    this.imageFile,
    required this.creatorId,
    required this.creatorName,
    this.creatorImageUrl,
    this.creatorFrameId,
    this.settings,
    this.category,
  });

  @override
  List<Object?> get props => [
        name,
        description,
        imageFile,
        creatorId,
        creatorName,
        creatorImageUrl,
        creatorFrameId,
        settings,
        category,
      ];
}

/// Resume hidden audio room
class ResumeAudioRoom extends AudioRoomsEvent {
  final AudioRoomV2 room;

  const ResumeAudioRoom({required this.room});

  @override
  List<Object?> get props => [room];
}

/// Join audio room
class JoinAudioRoom extends AudioRoomsEvent {
  final String roomId;
  final String userId;
  final String userName;
  final String? userImageUrl;
  final String? userFrameId;

  const JoinAudioRoom({
    required this.roomId,
    required this.userId,
    required this.userName,
    this.userImageUrl,
    this.userFrameId,
  });

  @override
  List<Object?> get props =>
      [roomId, userId, userName, userImageUrl, userFrameId];
}

/// Leave audio room
class LeaveAudioRoom extends AudioRoomsEvent {
  final String roomId;
  final String userId;

  const LeaveAudioRoom({
    required this.roomId,
    required this.userId,
  });

  @override
  List<Object?> get props => [roomId, userId];
}

/// Delete audio room (only creator can delete)
class DeleteAudioRoom extends AudioRoomsEvent {
  final String roomId;
  final String userId;

  const DeleteAudioRoom({
    required this.roomId,
    required this.userId,
  });

  @override
  List<Object?> get props => [roomId, userId];
}

/// Update room participant (mute/unmute, speaker status, etc.)
class UpdateRoomParticipant extends AudioRoomsEvent {
  final String roomId;
  final String userId;
  final AudioRoomParticipant updatedParticipant;

  const UpdateRoomParticipant({
    required this.roomId,
    required this.userId,
    required this.updatedParticipant,
  });

  @override
  List<Object?> get props => [roomId, userId, updatedParticipant];
}

/// Search audio rooms
class SearchAudioRooms extends AudioRoomsEvent {
  final String query;

  const SearchAudioRooms({required this.query});

  @override
  List<Object?> get props => [query];
}

/// Clear search
class ClearSearch extends AudioRoomsEvent {
  const ClearSearch();
}

/// Update room settings (only creator/host can update)
class UpdateRoomSettings extends AudioRoomsEvent {
  final String roomId;
  final String userId;
  final AudioRoomSettings settings;

  const UpdateRoomSettings({
    required this.roomId,
    required this.userId,
    required this.settings,
  });

  @override
  List<Object?> get props => [roomId, userId, settings];
}

/// Update PK battle state (only host can initiate)
class UpdatePKBattleState extends AudioRoomsEvent {
  final String roomId;
  final String userId;
  final PKBattleState pkBattleState;

  const UpdatePKBattleState({
    required this.roomId,
    required this.userId,
    required this.pkBattleState,
  });

  @override
  List<Object?> get props => [roomId, userId, pkBattleState];
}

/// Listen to room updates (real-time)
class ListenToRoomUpdates extends AudioRoomsEvent {
  final String roomId;

  const ListenToRoomUpdates({required this.roomId});

  @override
  List<Object?> get props => [roomId];
}

/// Stop listening to room updates
class StopListeningToRoomUpdates extends AudioRoomsEvent {
  const StopListeningToRoomUpdates();
}

/// Internal event for room updates from stream
class RoomUpdatedFromStream extends AudioRoomsEvent {
  final AudioRoomV2 room;

  const RoomUpdatedFromStream({required this.room});

  @override
  List<Object?> get props => [room];
}

/// Event when the list of all rooms is updated from stream
class RoomsListUpdatedFromStream extends AudioRoomsEvent {
  final List<AudioRoomV2> rooms;

  const RoomsListUpdatedFromStream({required this.rooms});

  @override
  List<Object?> get props => [rooms];
}

/// Event to update seat configuration
class UpdateSeatConfiguration extends AudioRoomsEvent {
  final String roomId;
  final String userId;
  final int seatCount;

  const UpdateSeatConfiguration({
    required this.roomId,
    required this.userId,
    required this.seatCount,
  });

  @override
  List<Object?> get props => [roomId, userId, seatCount];
}

/// Event to update background image
class UpdateBackgroundImage extends AudioRoomsEvent {
  final String roomId;
  final String userId;
  final String? imageUrl;
  final File? imageFile;

  const UpdateBackgroundImage({
    required this.roomId,
    required this.userId,
    this.imageUrl,
    this.imageFile,
  });

  @override
  List<Object?> get props => [roomId, userId, imageUrl, imageFile];
}

/// Event to update room name
class UpdateRoomName extends AudioRoomsEvent {
  final String roomId;
  final String userId;
  final String newName;

  const UpdateRoomName({
    required this.roomId,
    required this.userId,
    required this.newName,
  });

  @override
  List<Object?> get props => [roomId, userId, newName];
}

/// Event to update room description for the audio room
class UpdateRoomDescription extends AudioRoomsEvent {
  final String roomId;
  final String userId;
  final String newDescription;

  const UpdateRoomDescription({
    required this.roomId,
    required this.userId,
    required this.newDescription,
  });

  @override
  List<Object?> get props => [roomId, userId, newDescription];
}

/// Event to update room image
class UpdateRoomImage extends AudioRoomsEvent {
  final String roomId;
  final String userId;
  final File imageFile;

  const UpdateRoomImage({
    required this.roomId,
    required this.userId,
    required this.imageFile,
  });

  @override
  List<Object?> get props => [roomId, userId, imageFile];
}

/// Event to update room announcement
class UpdateRoomAnnouncement extends AudioRoomsEvent {
  final String roomId;
  final String userId;
  final String? announcement;

  const UpdateRoomAnnouncement({
    required this.roomId,
    required this.userId,
    required this.announcement,
  });

  @override
  List<Object?> get props => [roomId, userId, announcement];
}

/// Event to update music settings
class UpdateMusicSettings extends AudioRoomsEvent {
  final String roomId;
  final String userId;
  final bool musicEnabled;
  final String? musicUrl;

  const UpdateMusicSettings({
    required this.roomId,
    required this.userId,
    required this.musicEnabled,
    this.musicUrl,
  });

  @override
  List<Object?> get props => [roomId, userId, musicEnabled, musicUrl];
}

/// Event to update room mode
class UpdateRoomMode extends AudioRoomsEvent {
  final String roomId;
  final String userId;
  final RoomMode roomMode;

  const UpdateRoomMode({
    required this.roomId,
    required this.userId,
    required this.roomMode,
  });

  @override
  List<Object?> get props => [roomId, userId, roomMode];
}

/// Event to send chat message
class SendChatMessage extends AudioRoomsEvent {
  final String roomId;
  final String userId;
  final String username;
  final String? userAvatar;
  final String message;

  const SendChatMessage({
    required this.roomId,
    required this.userId,
    required this.username,
    this.userAvatar,
    required this.message,
  });

  @override
  List<Object?> get props => [roomId, userId, username, userAvatar, message];
}

/// Event when chat messages are updated from stream
class ChatMessagesUpdated extends AudioRoomsEvent {
  final String roomId;
  final List<ChatMessage> messages;

  const ChatMessagesUpdated({
    required this.roomId,
    required this.messages,
  });

  @override
  List<Object?> get props => [roomId, messages];
}

/// Event when emoji chat messages are updated from stream
class EmojiChatMessagesUpdated extends AudioRoomsEvent {
  final String roomId;
  final List<EmojiChatMessage> messages;

  const EmojiChatMessagesUpdated({
    required this.roomId,
    required this.messages,
  });

  @override
  List<Object?> get props => [roomId, messages];
}

/// Event to enforce real-time bans on the user (e.g. mic ban)
class EnforceRealTimeBans extends AudioRoomsEvent {
  final User user;

  const EnforceRealTimeBans(this.user);

  @override
  List<Object?> get props => [user];
}

/// Event to lock/unlock a seat
class ToggleSeatLock extends AudioRoomsEvent {
  final String roomId;
  final String hostId;
  final int seatNumber;
  final bool isLocked;

  const ToggleSeatLock({
    required this.roomId,
    required this.hostId,
    required this.seatNumber,
    required this.isLocked,
  });

  @override
  List<Object?> get props => [roomId, hostId, seatNumber, isLocked];
}

/// Event to lock/unlock all seats
class ToggleAllSeatsLock extends AudioRoomsEvent {
  final String roomId;
  final String hostId;
  final bool isLocked;

  const ToggleAllSeatsLock({
    required this.roomId,
    required this.hostId,
    required this.isLocked,
  });

  @override
  List<Object?> get props => [roomId, hostId, isLocked];
}


/// Event to move participant to different seat
class MoveParticipantToSeat extends AudioRoomsEvent {
  final String roomId;
  final String userId;
  final int fromSeat;
  final int toSeat;

  const MoveParticipantToSeat({
    required this.roomId,
    required this.userId,
    required this.fromSeat,
    required this.toSeat,
  });

  @override
  List<Object?> get props => [roomId, userId, fromSeat, toSeat];
}

/// Event to remove participant from seat
class RemoveParticipantFromSeat extends AudioRoomsEvent {
  final String roomId;
  final String hostId;
  final String participantId;
  final int seatNumber;

  const RemoveParticipantFromSeat({
    required this.roomId,
    required this.hostId,
    required this.participantId,
    required this.seatNumber,
  });

  @override
  List<Object?> get props => [roomId, hostId, participantId, seatNumber];
}

/// Event to kick participant from room
class KickParticipant extends AudioRoomsEvent {
  final String roomId;
  final String hostId;
  final String participantId;
  final String reason;

  const KickParticipant({
    required this.roomId,
    required this.hostId,
    required this.participantId,
    this.reason = 'Removed by host',
  });

  @override
  List<Object?> get props => [roomId, hostId, participantId, reason];
}

/// Event to block participant from room
class BlockParticipant extends AudioRoomsEvent {
  final String roomId;
  final String hostId;
  final String participantId;
  final String reason;

  const BlockParticipant({
    required this.roomId,
    required this.hostId,
    required this.participantId,
    this.reason = 'Blocked by host',
  });

  @override
  List<Object?> get props => [roomId, hostId, participantId, reason];
}

/// Event to unblock participant
class UnblockParticipant extends AudioRoomsEvent {
  final String roomId;
  final String hostId;
  final String participantId;

  const UnblockParticipant({
    required this.roomId,
    required this.hostId,
    required this.participantId,
  });

  @override
  List<Object?> get props => [roomId, hostId, participantId];
}

/// Event to toggle admin mute
class ToggleAdminMute extends AudioRoomsEvent {
  final String roomId;
  final String participantId;
  final bool mutedByAdmin;

  const ToggleAdminMute({
    required this.roomId,
    required this.participantId,
    required this.mutedByAdmin,
  });

  @override
  List<Object?> get props => [roomId, participantId, mutedByAdmin];
}

/// Event to toggle messaging block
class ToggleMessagingBlock extends AudioRoomsEvent {
  final String roomId;
  final String participantId;
  final bool isBlocked;

  const ToggleMessagingBlock({
    required this.roomId,
    required this.participantId,
    required this.isBlocked,
  });

  @override
  List<Object?> get props => [roomId, participantId, isBlocked];
}

/// Event to toggle seat access block
class ToggleSeatBlock extends AudioRoomsEvent {
  final String roomId;
  final String participantId;
  final bool isBlocked;

  const ToggleSeatBlock({
    required this.roomId,
    required this.participantId,
    required this.isBlocked,
  });

  @override
  List<Object?> get props => [roomId, participantId, isBlocked];
}

// ========================================
// AGORA-SPECIFIC EVENTS
// ========================================

/// Initialize Agora for a room
class InitializeAgora extends AudioRoomsEvent {
  final String roomId;
  final String userId;
  final String userName;
  final String? userImageUrl;
  final String? userFrameId;
  final AudioQuality audioQuality;
  final bool isVideo;

  const InitializeAgora({
    required this.roomId,
    required this.userId,
    required this.userName,
    this.userImageUrl,
    this.userFrameId,
    this.audioQuality = AudioQuality.high,
    this.isVideo = false,
  });

  @override
  List<Object?> get props =>
      [roomId, userId, userName, userImageUrl, userFrameId, audioQuality, isVideo];
}

/// Fix seat configuration mismatch
class FixSeatConfigurationMismatch extends AudioRoomsEvent {
  final String roomId;

  const FixSeatConfigurationMismatch({required this.roomId});

  @override
  List<Object?> get props => [roomId];
}

/// Force leave Agora channel (for kicked participants)
class ForceLeaveAgoraChannel extends AudioRoomsEvent {
  const ForceLeaveAgoraChannel();

  @override
  List<Object?> get props => [];
}

/// Join Agora channel
class JoinAgoraChannel extends AudioRoomsEvent {
  final String channelName;
  final int uid;
  final String userId;
  final String userName;
  final String? userImageUrl;
  final String? userFrameId;
  final String? token;
  final bool isMuted;
  final bool isVideo;

  const JoinAgoraChannel({
    required this.channelName,
    required this.uid,
    required this.userId,
    required this.userName,
    this.userImageUrl,
    this.userFrameId,
    this.token,
    this.isMuted = true, // Default to muted for new participants
    this.isVideo = false,
  });

  @override
  List<Object?> get props =>
      [channelName, uid, userId, userName, userImageUrl, token, isMuted];
}

/// Leave Agora channel
class LeaveAgoraChannel extends AudioRoomsEvent {
  const LeaveAgoraChannel();
}

/// Toggle microphone mute
class ToggleMicrophone extends AudioRoomsEvent {
  const ToggleMicrophone();
}

/// Set microphone mute state
class SetMicrophoneMute extends AudioRoomsEvent {
  final bool muted;

  const SetMicrophoneMute({required this.muted});

  @override
  List<Object?> get props => [muted];
}

/// Toggle room mute (incoming audio)
class ToggleRoomMute extends AudioRoomsEvent {
  const ToggleRoomMute();
}

/// Set room mute state
class SetRoomMute extends AudioRoomsEvent {
  final bool muted;

  const SetRoomMute({required this.muted});

  @override
  List<Object?> get props => [muted];
}

/// Toggle speaker
class ToggleSpeaker extends AudioRoomsEvent {
  const ToggleSpeaker();
}

/// Set audio quality
class SetAudioQuality extends AudioRoomsEvent {
  final AudioQuality quality;

  const SetAudioQuality({required this.quality});

  @override
  List<Object?> get props => [quality];
}

/// Apply audio effect
class ApplyAudioEffect extends AudioRoomsEvent {
  final AudioEffect effect;

  const ApplyAudioEffect({required this.effect});

  @override
  List<Object?> get props => [effect];
}

/// Apply voice changer
class ApplyVoiceChanger extends AudioRoomsEvent {
  final VoiceChanger changer;

  const ApplyVoiceChanger({required this.changer});

  @override
  List<Object?> get props => [changer];
}

/// Start background music
class StartBackgroundMusic extends AudioRoomsEvent {
  final AudioMixingConfig config;

  const StartBackgroundMusic({required this.config});

  @override
  List<Object?> get props => [config];
}

/// Stop background music
class StopBackgroundMusic extends AudioRoomsEvent {
  const StopBackgroundMusic();
}

/// Pause background music
class PauseBackgroundMusic extends AudioRoomsEvent {
  const PauseBackgroundMusic();
}

/// Resume background music
class ResumeBackgroundMusic extends AudioRoomsEvent {
  const ResumeBackgroundMusic();
}

/// Renew Agora token
class RenewAgoraToken extends AudioRoomsEvent {
  final String token;

  const RenewAgoraToken({required this.token});

  @override
  List<Object?> get props => [token];
}

// ========================================
// AGORA CALLBACK EVENTS (Internal)
// ========================================

/// Agora user joined
class AgoraUserJoined extends AudioRoomsEvent {
  final AgoraUser user;

  const AgoraUserJoined({required this.user});

  @override
  List<Object?> get props => [user];
}

/// Agora user left
class AgoraUserLeft extends AudioRoomsEvent {
  final int uid;

  const AgoraUserLeft({required this.uid});

  @override
  List<Object?> get props => [uid];
}

/// Agora user muted/unmuted
class AgoraUserMuted extends AudioRoomsEvent {
  final int uid;
  final bool muted;

  const AgoraUserMuted({required this.uid, required this.muted});

  @override
  List<Object?> get props => [uid, muted];
}

/// Audio volume indication
class AudioVolumeIndication extends AudioRoomsEvent {
  final Map<int, int> userVolumes; // uid -> volume level
  final int totalVolume;

  const AudioVolumeIndication({
    required this.userVolumes,
    required this.totalVolume,
  });

  @override
  List<Object?> get props => [userVolumes, totalVolume];
}

/// Connection state changed
class AgoraConnectionStateChanged extends AudioRoomsEvent {
  final AgoraConnectionState state;

  const AgoraConnectionStateChanged({required this.state});

  @override
  List<Object?> get props => [state];
}

/// Network quality update
class NetworkQualityUpdate extends AudioRoomsEvent {
  final NetworkQuality quality;

  const NetworkQualityUpdate({required this.quality});

  @override
  List<Object?> get props => [quality];
}

/// Agora stats update
class AgoraStatsUpdate extends AudioRoomsEvent {
  final AgoraStats stats;

  const AgoraStatsUpdate({required this.stats});

  @override
  List<Object?> get props => [stats];
}

/// Token privilege will expire
class TokenPrivilegeWillExpire extends AudioRoomsEvent {
  const TokenPrivilegeWillExpire();
}

/// Audio mixing finished
class AudioMixingFinished extends AudioRoomsEvent {
  const AudioMixingFinished();
}

/// Audio effect finished
class AudioEffectFinished extends AudioRoomsEvent {
  final int soundId;

  const AudioEffectFinished({required this.soundId});

  @override
  List<Object?> get props => [soundId];
}

/// Agora error occurred
class AgoraErrorOccurred extends AudioRoomsEvent {
  final String message;
  final String code;

  const AgoraErrorOccurred({required this.message, required this.code});

  @override
  List<Object?> get props => [message, code];
}

/// Send join request to room (Live Video)
class SendJoinRequest extends AudioRoomsEvent {
  final String roomId;
  final String userId;

  const SendJoinRequest({required this.roomId, required this.userId});

  @override
  List<Object?> get props => [roomId, userId];
}

/// Accept join request
class AcceptJoinRequest extends AudioRoomsEvent {
  final String roomId;
  final String userId;

  const AcceptJoinRequest({required this.roomId, required this.userId});

  @override
  List<Object?> get props => [roomId, userId];
}

/// Reject join request
class RejectJoinRequest extends AudioRoomsEvent {
  final String roomId;
  final String userId;

  const RejectJoinRequest({required this.roomId, required this.userId});

  @override
  List<Object?> get props => [roomId, userId];
}

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';

class RoomPKMediaRelayService {
  final RtcEngine _engine;
  final String localUid;
  
  RoomPKMediaRelayService({required RtcEngine engine, required this.localUid}) : _engine = engine;

  /// Starts relaying the local media stream to the opponent's room channel.
  /// 
  /// [currentRoomId] is the name of our current Agora channel.
  /// [opponentRoomId] is the name of the opponent's Agora channel.
  /// [localToken] is our token for our channel.
  /// [opponentToken] is our token generated for the opponent's channel (if required by your backend).
  Future<void> startRelayToOpponentRoom({
    required String currentRoomId,
    required String opponentRoomId,
    required String localToken,
    required String opponentToken,
  }) async {
    try {
      // 1. Configure the Source (Our current room)
      ChannelMediaInfo srcInfo = ChannelMediaInfo(
        channelName: currentRoomId,
        uid: 0, // 0 usually refers to the local user
        token: localToken,
      );

      // 2. Configure the Destination (Opponent's room)
      ChannelMediaInfo destInfo = ChannelMediaInfo(
        channelName: opponentRoomId,
        uid: 0, // Using 0 assigns a random UID, or you can specify a specific UID for the relay
        token: opponentToken,
      );

      // 3. Setup the configuration
      ChannelMediaRelayConfiguration config = ChannelMediaRelayConfiguration(
        srcInfo: srcInfo,
        destInfos: [destInfo],
      );

      // 4. Start Relay
      await _engine.startOrUpdateChannelMediaRelay(config);
      debugPrint('Successfully started media relay from $currentRoomId to $opponentRoomId');
    } catch (e) {
      debugPrint('Error starting media relay: $e');
      throw Exception('Failed to start media relay');
    }
  }

  /// Stops the media relay
  Future<void> stopRelay() async {
    try {
      await _engine.stopChannelMediaRelay();
      debugPrint('Successfully stopped media relay');
    } catch (e) {
      debugPrint('Error stopping media relay: $e');
    }
  }
}

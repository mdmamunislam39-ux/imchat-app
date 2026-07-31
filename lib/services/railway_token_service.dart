import 'agora_token_service.dart';
import '../utils/debug.dart';

/// Generate Agora token using AgoraTokenService with dynamic settings and fallbacks
Future<String?> fetchAgoraToken({
  required String channelName,
  required int uid,
  int maxRetries = 2,
}) async {
  debug('=== FETCH AGORA TOKEN VIA DELEGATOR ===');
  debug('Channel Name: $channelName');
  debug('UID: $uid');
  
  final tokenResponse = await AgoraTokenService.instance.generateToken(
    channelName: channelName,
    uid: uid,
  );
  
  if (tokenResponse != null && tokenResponse.token.isNotEmpty) {
    debug('✅ Token fetch successful: ${tokenResponse.token.substring(0, 20)}...');
    return tokenResponse.token;
  }
  
  debug('❌ Token fetch failed');
  return null;
}

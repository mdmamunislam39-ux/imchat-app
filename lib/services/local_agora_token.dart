import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:archive/archive.dart';

/// Official Agora AccessToken2 (v007) generator for Flutter / Dart
/// Supports full RTC privileges: JoinChannel (1), PublishAudio (2), PublishVideo (3), PublishData (4)
class RtcTokenBuilder {
  static const String version = "007";

  static String buildTokenWithUid({
    required String appId,
    required String appCertificate,
    required String channelName,
    required int uid,
    int tokenExpireSeconds = 86400,
    int privilegeExpireSeconds = 86400,
  }) {
    final now = (DateTime.now().millisecondsSinceEpoch / 1000).floor();
    final issueTs = now;
    final expireTs = now + privilegeExpireSeconds;
    final salt = Random.secure().nextInt(0xFFFFFFFF);

    final uidStr = uid == 0 ? '' : uid.toString();

    // 1. Pack RTC Service (Service Type = 1)
    final rtcServiceBuf = BytesBuilder();

    // Service Type = 1 (RTC)
    _writeUint16(rtcServiceBuf, 1);

    // Channel Name (String)
    _writeString(rtcServiceBuf, channelName);

    // UID (String)
    _writeString(rtcServiceBuf, uidStr);

    // Privileges Map (Count = 4)
    _writeUint16(rtcServiceBuf, 4);
    
    // Privilege 1: JoinChannel
    _writeUint16(rtcServiceBuf, 1);
    _writeUint32(rtcServiceBuf, expireTs);

    // Privilege 2: PublishAudioStream
    _writeUint16(rtcServiceBuf, 2);
    _writeUint32(rtcServiceBuf, expireTs);

    // Privilege 3: PublishVideoStream
    _writeUint16(rtcServiceBuf, 3);
    _writeUint32(rtcServiceBuf, expireTs);

    // Privilege 4: PublishDataStream
    _writeUint16(rtcServiceBuf, 4);
    _writeUint32(rtcServiceBuf, expireTs);

    // 2. Pack Payload
    final payloadBuf = BytesBuilder();
    _writeString(payloadBuf, appId);
    _writeUint32(payloadBuf, issueTs);
    _writeUint32(payloadBuf, salt);
    _writeUint32(payloadBuf, now + tokenExpireSeconds);
    
    // Service Count = 1
    _writeUint16(payloadBuf, 1);
    payloadBuf.add(rtcServiceBuf.toBytes());

    final payloadBytes = payloadBuf.toBytes();

    // 3. Generate HMAC Signing Key
    final issueTsSaltBuf = BytesBuilder();
    _writeUint32(issueTsSaltBuf, issueTs);
    _writeUint32(issueTsSaltBuf, salt);

    final hmacCert = Hmac(sha256, utf8.encode(appCertificate));
    final signingKey = hmacCert.convert(issueTsSaltBuf.toBytes()).bytes;

    // 4. Generate Signature over Payload
    final hmacPayload = Hmac(sha256, signingKey);
    final signature = hmacPayload.convert(payloadBytes).bytes;

    // 5. Compress Payload using ZLib
    final compressedPayload = ZLibEncoder().encode(payloadBytes);

    // 6. Concatenate Signature + Compressed Payload
    final finalBuf = BytesBuilder();
    finalBuf.add(signature);
    finalBuf.add(compressedPayload);

    // 7. Return Version ("007") + Base64
    final token = "$version${base64.encode(finalBuf.toBytes())}";
    return token;
  }

  static void _writeUint16(BytesBuilder builder, int value) {
    builder.addByte(value & 0xFF);
    builder.addByte((value >> 8) & 0xFF);
  }

  static void _writeUint32(BytesBuilder builder, int value) {
    builder.addByte(value & 0xFF);
    builder.addByte((value >> 8) & 0xFF);
    builder.addByte((value >> 16) & 0xFF);
    builder.addByte((value >> 24) & 0xFF);
  }

  static void _writeString(BytesBuilder builder, String str) {
    final bytes = utf8.encode(str);
    _writeUint16(builder, bytes.length);
    builder.add(bytes);
  }
}

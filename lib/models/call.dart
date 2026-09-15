import 'package:chat_messenger/controllers/auth_controller.dart';

class Call {
  bool isVideo;
  // caller info
  String callerId;
  String callerName;
  String callerPhotoUrl;
  // receiver info
  String receiverName;
  String receiverPhotoUrl;
  String receiverId;
  String? agoraToken;

  Call({
    this.isVideo = false,
    // caller info
    this.callerId = '',
    this.callerName = '',
    this.callerPhotoUrl = '',
    // receiver info
    this.receiverName = '',
    this.receiverPhotoUrl = '',
    this.receiverId = '',
    this.agoraToken,
  });

  // Check caller id
  bool get isCaller => callerId == AuthController.instance.currentUser.userId;
  String get effectiveChannelName => callerId;
  bool get isGroup => receiverId == 'group_call';


  factory Call.fromMap({required Map<String, dynamic> data}) {
    return Call(
      isVideo: data['isVideo'] ?? false,
      // caller info
      callerId: data['callerId'] ?? '',
      callerName: data['callerName'] ?? '',
      callerPhotoUrl: data['callerPhotoUrl'] ?? '',
      // receiver info
      receiverName: data['receiverName'] ?? '',
      receiverPhotoUrl: data['receiverPhotoUrl'] ?? '',
      receiverId: data['receiverId'] ?? '',
      agoraToken: data['agoraToken'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "isVideo": isVideo,
      "callerId": callerId,
      "callerName": callerName,
      "callerPhotoUrl": callerPhotoUrl,
      "receiverName": receiverName,
      "receiverPhotoUrl": receiverPhotoUrl,
      "receiverId" : receiverId,
      if (agoraToken != null) "agoraToken": agoraToken,
    };
  }
}

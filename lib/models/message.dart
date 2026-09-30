import 'package:chat_messenger/helpers/encrypt_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';

import 'group_update.dart';
import 'location.dart';
import 'room_share.dart';

// Message types
enum MessageType { text, image, gif, audio, video, doc, location, groupUpdate, roomShare, hostInvitation, relationshipInvitation }

class Message {
  String msgId;
  String senderId;
  MessageType type;
  String textMsg;
  String fileUrl;
  String gifUrl;
  Location? location;
  String videoThumbnail;
  bool isRead;
  bool isDelivered;
  bool isRecAudio;
  bool isDeleted;
  bool isForwarded;
  DateTime? sentAt;
  DateTime? updatedAt;
  Message? replyMessage;
  // For Groups
  GroupUpdate? groupUpdate;
  RoomShare? roomShare;
  // For host invitation messages
  String? invitationId;
  String? invitationAgencyName;
  String? invitationAgencyId;
  // This reference help us update this message
  DocumentReference<Map<String, dynamic>>? docRef;

  Message({
    required this.msgId,
    this.docRef,
    this.senderId = '',
    this.type = MessageType.text,
    this.textMsg = '',
    this.fileUrl = '',
    this.gifUrl = '',
    this.location,
    this.videoThumbnail = '',
    this.isRead = false,
    this.isDelivered = false,
    this.isRecAudio = false,
    this.isDeleted = false,
    this.isForwarded = false,
    this.sentAt,
    this.updatedAt,
    this.replyMessage,
    this.groupUpdate,
    this.roomShare,
    this.invitationId,
    this.invitationAgencyName,
    this.invitationAgencyId,
  });

  bool get isSender => senderId == AuthController.instance.currentUser.userId;

  @override
  String toString() {
    return 'Message(msgId: $msgId, senderId: $senderId, type: $type, textMsg: $textMsg, fileUrl: $fileUrl, gifUrl: $gifUrl, videoThumbnail: $videoThumbnail, isRead: $isRead, isDelivered: $isDelivered, isRecAudio: $isRecAudio, sentAt: $sentAt, groupUpdate: $groupUpdate)';
  }

  // Get message type
  static MessageType getMsgType(String type) {
    return MessageType.values.firstWhere(
      (el) => el.name == type,
      orElse: () => MessageType.text,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  factory Message.fromMap({
    required bool isGroup,
    required Map<String, dynamic> data,
    DocumentReference<Map<String, dynamic>>? docRef,
  }) {
    final String messageId = data['msgId'] ?? '';
    final String textMessage = data['textMsg'] ?? '';

    String decryptedText = textMessage;
    if (!isGroup && textMessage.isNotEmpty && messageId.isNotEmpty) {
      try {
        decryptedText = EncryptHelper.decrypt(textMessage, messageId);
      } catch (_) {
        decryptedText = textMessage;
      }
    }

    return Message(
      docRef: docRef,
      msgId: messageId,
      senderId: data['senderId'] ?? '',
      type: getMsgType(data['type']),
      textMsg: isGroup ? textMessage : decryptedText,
      fileUrl: data['fileUrl'] ?? '',
      gifUrl: data['gifUrl'] ?? '',
      location: Location.fromMap(data['location'] ?? {}),
      roomShare: data['roomShare'] != null
          ? RoomShare.fromMap(Map<String, dynamic>.from(data['roomShare']))
          : null,
      invitationId: data['invitationId'],
      invitationAgencyName: data['invitationAgencyName'],
      invitationAgencyId: data['invitationAgencyId'],
      videoThumbnail: data['videoThumbnail'] ?? '',
      isRead: data['isRead'] ?? false,
      isDelivered: data['isDelivered'] ?? false,
      isRecAudio: data['isRecAudio'] ?? false,
      isDeleted: data['isDeleted'] ?? false,
      isForwarded: data['isForwarded'] ?? false,
      sentAt: _parseDate(data['sentAt']),
      updatedAt: _parseDate(data['updatedAt']),
      replyMessage: data['replyMessage'] != null
          ? Message.fromMap(
              data: Map<String, dynamic>.from(data['replyMessage']),
              isGroup: isGroup)
          : null,
      groupUpdate: GroupUpdate.froMap(
          Map<String, dynamic>.from(data['groupUpdate'] ?? {})),
    );
  }

  Map<String, dynamic> toMap({required bool isGroup}) {
    return {
      'msgId': msgId,
      'senderId': senderId,
      'type': type.name,
      'textMsg': isGroup ? textMsg : EncryptHelper.encrypt(textMsg, msgId),
      'fileUrl': fileUrl,
      'gifUrl': gifUrl,
      'location': location?.toMap(),
      'roomShare': roomShare?.toMap(),
      'invitationId': invitationId,
      'invitationAgencyName': invitationAgencyName,
      'invitationAgencyId': invitationAgencyId,
      'videoThumbnail': videoThumbnail,
      'isRead': isRead,
      'isDelivered': isDelivered,
      'isRecAudio': isRecAudio,
      'isForwarded': isForwarded,
      'sentAt': FieldValue.serverTimestamp(),
      'replyMessage': replyMessage?.toMap(isGroup: isGroup),
      'groupUpdate': groupUpdate?.toMap(),
    };
  }

  Map<String, dynamic> toDeletedMap() {
    return {
      'isDeleted': true,
      'msgId': msgId,
      'type': 'text',
      'textMsg': 'deleted',
      'senderId': senderId,
      'replyMessage': null,
      'sentAt': sentAt,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'msgId': msgId,
      'senderId': senderId,
      'type': type.name,
      'textMsg': textMsg,
      'fileUrl': fileUrl,
      'gifUrl': gifUrl,
      'location': location?.toMap(),
      'videoThumbnail': videoThumbnail,
      'isRead': isRead,
      'isDelivered': isDelivered,
      'isRecAudio': isRecAudio,
      'isDeleted': isDeleted,
      'isForwarded': isForwarded,
      'sentAt': sentAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'invitationId': invitationId,
      'invitationAgencyName': invitationAgencyName,
      'invitationAgencyId': invitationAgencyId,
    };
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      msgId: json['msgId'] ?? '',
      senderId: json['senderId'] ?? '',
      type: getMsgType(json['type'] ?? 'text'),
      textMsg: json['textMsg'] ?? '',
      fileUrl: json['fileUrl'] ?? '',
      gifUrl: json['gifUrl'] ?? '',
      location: json['location'] != null ? Location.fromMap(Map<String, dynamic>.from(json['location'])) : null,
      videoThumbnail: json['videoThumbnail'] ?? '',
      isRead: json['isRead'] == true,
      isDelivered: json['isDelivered'] == true,
      isRecAudio: json['isRecAudio'] == true,
      isDeleted: json['isDeleted'] == true,
      isForwarded: json['isForwarded'] == true,
      sentAt: _parseDate(json['sentAt']),
      updatedAt: _parseDate(json['updatedAt']),
      invitationId: json['invitationId'],
      invitationAgencyName: json['invitationAgencyName'],
      invitationAgencyId: json['invitationAgencyId'],
    );
  }
}

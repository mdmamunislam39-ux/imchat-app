import 'package:chat_messenger/helpers/encrypt_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';

import 'message.dart';
import 'user.dart';

class Chat {
  String msgId;
  String lastMsg;
  MessageType msgType;
  String senderId;
  DateTime? sentAt;
  DateTime? updatedAt;
  int unread;
  bool isMuted;
  bool isDeleted;
  // Local fields
  User? receiver;
  DocumentSnapshot<Map<String, dynamic>>? doc;

  Chat({
    this.doc,
    this.senderId = '',
    this.receiver,
    this.msgType = MessageType.text,
    this.lastMsg = '',
    this.msgId = '',
    this.sentAt,
    this.updatedAt,
    this.unread = 0,
    this.isMuted = false,
    this.isDeleted = false,
  });

  bool get isSender => senderId == AuthController.instance.currentUser.userId;

  @override
  String toString() {
    return 'Chat(senderId: $senderId, msgType: $msgType, lastMsg: $lastMsg, sentAt: $sentAt, unread: $unread)';
  }

  // Get data from database
  factory Chat.fromMap(
    Map<String, dynamic> data, {
    DocumentSnapshot<Map<String, dynamic>>? doc,
    User? receiver,
  }) {
    final String messageId = data['msgId'] ?? '';
    final bool isOfficialChannel = data['type'] == 'official_channel' ||
        doc?.id == 'official_team' ||
        data['senderId'] == 'official_team';
    
    final String textMessage = isOfficialChannel 
        ? (data['lastMsg'] ?? data['lastMessage'] ?? data['message'] ?? '') 
        : (data['lastMsg'] ?? '');
        
    String decryptedMsg = textMessage;
    if (!isOfficialChannel) {
      decryptedMsg = EncryptHelper.decrypt(textMessage, messageId);
    } else {
      try {
        if (textMessage.contains(':') && textMessage.split(':')[0].length == 24) {
          decryptedMsg = EncryptHelper.decrypt(textMessage, messageId);
        }
      } catch (_) {
        decryptedMsg = textMessage;
      }
    }

    return Chat(
      doc: doc,
      msgId: messageId,
      receiver: receiver,
      senderId: data['senderId'] ?? '',
      msgType: isOfficialChannel ? MessageType.text : Message.getMsgType(data['msgType'] ?? 'text'),
      lastMsg: decryptedMsg,
      sentAt: (data['sentAt'] ?? data['timestamp'])?.toDate() as DateTime?,
      updatedAt: data['updatedAt']?.toDate() as DateTime?,
      unread: data['unread'] ?? data['unreadCount'] ?? 0,
      isMuted: data['isMuted'] ?? false,
      isDeleted: data['isDeleted'] ?? false,
    );
  }

  // Update unread counter
  void viewChat() {
    if (doc != null && doc!.exists) {
      doc!.reference.update({'unread': 0});
    }
  }

  // Delete the chat node
  void deleteChat() {
    if (doc != null && doc!.exists) {
      doc!.reference.delete();
    }
  }

  Map<String, dynamic> toMap([bool increment = true]) {
    return {
      'isDeleted': false,
      'senderId': senderId,
      'msgType': msgType.name,
      'lastMsg': EncryptHelper.encrypt(lastMsg, msgId),
      'msgId': msgId,
      'unread': increment ? FieldValue.increment(1) : unread,
      'sentAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toDeletedMap() {
    return {
      'isDeleted': true,
      'msgType': 'text',
      'lastMsg': 'deleted',
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

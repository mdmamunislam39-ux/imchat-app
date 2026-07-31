import 'package:cloud_firestore/cloud_firestore.dart';

enum RoomIdHistoryAction { assign, update, remove }

class CustomRoomIdHistoryModel {
  final String id;
  final String roomId;
  final String currentOwnerId;
  final String customRoomId;
  final RoomIdHistoryAction action;
  final String actionByAdminId;
  final DateTime timestamp;
  final String? notes;

  CustomRoomIdHistoryModel({
    required this.id,
    required this.roomId,
    required this.currentOwnerId,
    required this.customRoomId,
    required this.action,
    required this.actionByAdminId,
    required this.timestamp,
    this.notes,
  });

  factory CustomRoomIdHistoryModel.fromMap(String id, Map<String, dynamic> map) {
    return CustomRoomIdHistoryModel(
      id: id,
      roomId: map['roomId'] ?? '',
      currentOwnerId: map['currentOwnerId'] ?? '',
      customRoomId: map['customRoomId'] ?? '',
      action: _parseAction(map['action']),
      actionByAdminId: map['actionByAdminId'] ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'roomId': roomId,
      'currentOwnerId': currentOwnerId,
      'customRoomId': customRoomId,
      'action': action.toString().split('.').last,
      'actionByAdminId': actionByAdminId,
      'timestamp': FieldValue.serverTimestamp(),
      'notes': notes,
    };
  }

  static RoomIdHistoryAction _parseAction(String? actionStr) {
    switch (actionStr) {
      case 'assign':
        return RoomIdHistoryAction.assign;
      case 'update':
        return RoomIdHistoryAction.update;
      case 'remove':
        return RoomIdHistoryAction.remove;
      default:
        return RoomIdHistoryAction.assign;
    }
  }
}

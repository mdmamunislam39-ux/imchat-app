class RoomShare {
  final String roomId;
  final String roomName;
  final String roomImage;
  final String description;

  const RoomShare({
    this.roomId = '',
    this.roomName = '',
    this.roomImage = '',
    this.description = '',
  });

  @override
  String toString() {
    return "RoomShare(roomId: $roomId, roomName: $roomName, roomImage: $roomImage, description: $description)";
  }

  factory RoomShare.fromMap(Map<String, dynamic> data) {
    return RoomShare(
      roomId: data['roomId'] ?? '',
      roomName: data['roomName'] ?? '',
      roomImage: data['roomImage'] ?? '',
      description: data['description'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'roomId': roomId,
      'roomName': roomName,
      'roomImage': roomImage,
      'description': description,
    };
  }
}

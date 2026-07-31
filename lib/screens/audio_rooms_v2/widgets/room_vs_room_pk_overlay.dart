import 'package:flutter/material.dart';
import 'package:chat_messenger/models/audio_room_v2.dart';
import 'package:chat_messenger/models/room_pk_match.dart';
import 'package:chat_messenger/components/cached_circle_avatar.dart';

class RoomVsRoomPKOverlay extends StatefulWidget {
  final AudioRoomV2 localRoom;
  final RoomPKMatch match;
  final VoidCallback onEndPK;

  const RoomVsRoomPKOverlay({
    super.key,
    required this.localRoom,
    required this.match,
    required this.onEndPK,
  });

  @override
  State<RoomVsRoomPKOverlay> createState() => _RoomVsRoomPKOverlayState();
}

class _RoomVsRoomPKOverlayState extends State<RoomVsRoomPKOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  
  bool get isPunishment => widget.match.state == RoomPKMatchState.punishment;
  bool get isLeftRoom => widget.match.leftRoomId == widget.localRoom.id;
  
  int get ourScore => isLeftRoom ? widget.match.leftRoomScore : widget.match.rightRoomScore;
  int get oppScore => isLeftRoom ? widget.match.rightRoomScore : widget.match.leftRoomScore;
  
  String get ourName => isLeftRoom ? widget.match.leftRoomName : widget.match.rightRoomName;
  String get oppName => isLeftRoom ? widget.match.rightRoomName : widget.match.leftRoomName;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _formatTime(DateTime? startTime, int durationMinutes) {
    if (startTime == null) return "00:00";
    final endTime = startTime.add(Duration(minutes: durationMinutes));
    final remaining = endTime.difference(DateTime.now());
    if (remaining.isNegative) return "00:00";
    final m = remaining.inMinutes.toString().padLeft(2, '0');
    final s = (remaining.inSeconds % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  @override
  Widget build(BuildContext context) {
    // Determine progress bar percentage
    final totalScore = ourScore + oppScore;
    double ourPercentage = 0.5;
    if (totalScore > 0) {
      ourPercentage = ourScore / totalScore;
    }

    return Stack(
      children: [
        // Background split colors
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF3A0000), Color(0xFF5D0000), Color(0xFF8B0000)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ],
        ),

        // Main Content Layer
        SafeArea(
          child: Column(
            children: [
              // Top Header (PK Timer)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isPunishment ? 'Punishment' : 'PK',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                        shadows: [Shadow(color: Colors.pink, blurRadius: 10)],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(widget.match.startTime, widget.match.durationMinutes),
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              
              // Room Headers (Names and Host Avatar)
              Row(
                children: [
                  Expanded(
                    child: _buildRoomHeader(
                      isOurRoom: true, 
                      roomName: ourName,
                      roomImageUrl: isLeftRoom ? widget.match.leftRoomImageUrl : widget.match.rightRoomImageUrl,
                    ),
                  ),
                  Expanded(
                    child: _buildRoomHeader(
                      isOurRoom: false, 
                      roomName: oppName,
                      roomImageUrl: !isLeftRoom ? widget.match.leftRoomImageUrl : widget.match.rightRoomImageUrl,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),

              // The 15 Seats for each side (3 rows of 5)
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Room Seats (Our Room)
                    Expanded(child: _buildRoomSeatsGrid(isOurRoom: true)),
                    
                    // Right Room Seats (Opponent Room)
                    Expanded(child: _buildRoomSeatsGrid(isOurRoom: false)),
                  ],
                ),
              ),
              
              // Bottom Progress Bar
              _buildProgressBar(ourPercentage),
            ],
          ),
        ),
        
        // Close / End PK Button (Only for Host)
        Positioned(
          top: 40,
          right: 20,
          child: IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.white, size: 28),
            onPressed: () {
              // Might open a help dialog, or host can end PK here
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRoomHeader({required bool isOurRoom, required String roomName, required String roomImageUrl}) {
    return Container(
      margin: EdgeInsets.only(
        left: isOurRoom ? 12 : 6,
        right: isOurRoom ? 6 : 12,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: isOurRoom ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (isOurRoom) ...[
            _buildHostAvatar(roomImageUrl),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              roomName,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: isOurRoom ? TextAlign.left : TextAlign.right,
            ),
          ),
          if (!isOurRoom) ...[
            const SizedBox(width: 8),
            _buildHostAvatar(roomImageUrl),
          ],
        ],
      ),
    );
  }

  Widget _buildHostAvatar(String url) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.amber, width: 2),
      ),
      child: CachedCircleAvatar(
        imageUrl: url,
        radius: 20,
      ),
    );
  }

  Widget _buildRoomSeatsGrid({required bool isOurRoom}) {
    // 15 Seats per room based on screenshot
    // Since this is a massive cross-room PK, we mock the opponent seats for now 
    // unless we have their participant list streamed in (which we need Firestore for).
    // The UI should at least render 15 slots.
    
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 15,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, // 3 columns
        childAspectRatio: 0.85,
        crossAxisSpacing: 4,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (context, index) {
        // Seat 0 is the Host (top center usually, but in grid it's index 0)
        // If it's our room, we can actually map widget.localRoom.participants here!
        return _buildSeat(index, isOurRoom);
      },
    );
  }

  Widget _buildSeat(int index, bool isOurRoom) {
    bool isHost = index == 0;
    bool isOccupied = isHost; // For now, only host is occupied. Real logic would bind to participant list.
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isOccupied ? Colors.transparent : Colors.white.withValues(alpha: 0.15),
                border: isOccupied ? Border.all(color: isOurRoom ? Colors.blue : Colors.green, width: 2) : null,
              ),
              child: isOccupied 
                  ? CachedCircleAvatar(
                      imageUrl: isOurRoom ? widget.localRoom.creatorImageUrl ?? '' : '',
                      radius: 22,
                    )
                  : const Icon(Icons.weekend, color: Colors.white54, size: 20), // Armchair icon from screenshot
            ),
            if (isHost)
              Positioned(
                bottom: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isOurRoom ? Colors.green : Colors.green, // "Host" tag in screenshot is green for both
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('Host', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildProgressBar(double leftPercentage) {
    return Container(
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                Expanded(
                  flex: ((leftPercentage * 100).toInt()).clamp(1, 99),
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [Color(0xFF38B6FF), Color(0xFF004AAD)]),
                    ),
                  ),
                ),
                Expanded(
                  flex: (((1 - leftPercentage) * 100).toInt()).clamp(1, 99),
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [Color(0xFFFF3131), Color(0xFFFF914D)]),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Glowing Orb
          AnimatedAlign(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            alignment: Alignment((leftPercentage * 2) - 1, 0),
            child: Container(
              width: 14,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(7),
                boxShadow: [
                  BoxShadow(color: Colors.white.withValues(alpha: 0.8), blurRadius: 12, spreadRadius: 4),
                  BoxShadow(color: Colors.yellow.withValues(alpha: 0.5), blurRadius: 20, spreadRadius: 8),
                ],
              ),
            ),
          ),

          // Scores
          Positioned(
            left: 12, top: 0, bottom: 0,
            child: Row(
              children: [
                const Icon(Icons.local_fire_department, color: Colors.white, size: 14),
                const SizedBox(width: 4),
                Text('$ourScore', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Positioned(
            right: 12, top: 0, bottom: 0,
            child: Row(
              children: [
                Text('$oppScore', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(width: 4),
                const Icon(Icons.local_fire_department, color: Colors.white, size: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

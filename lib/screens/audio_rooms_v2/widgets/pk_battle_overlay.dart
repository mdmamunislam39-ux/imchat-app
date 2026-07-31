// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:chat_messenger/models/audio_room_v2.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/bloc/audio_rooms_bloc.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/bloc/audio_rooms_event.dart';
import 'package:chat_messenger/components/cached_circle_avatar.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/speaking_ripple_animation.dart';

class PKBattleOverlay extends StatefulWidget {
  final AudioRoomV2 room;
  final String currentUserId;
  final Function(int)? onSeatTap;

  const PKBattleOverlay({
    super.key,
    required this.room,
    required this.currentUserId,
    this.onSeatTap,
  });

  @override
  State<PKBattleOverlay> createState() => _PKBattleOverlayState();
}

class _PKBattleOverlayState extends State<PKBattleOverlay> with SingleTickerProviderStateMixin {
  Timer? _timer;
  int _secondsRemaining = 0;
  late AnimationController _animationController;
  
  // To track when battle ends
  bool _battleJustEnded = false;
  String _winnerText = '';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    
    _setupTimer();
  }

  @override
  void didUpdateWidget(covariant PKBattleOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Check if battle state changed
    if (oldWidget.room.pkBattleState.isActive != widget.room.pkBattleState.isActive ||
        oldWidget.room.pkBattleState.startTime != widget.room.pkBattleState.startTime) {
      _setupTimer();
    }
  }

  void _setupTimer() {
    _timer?.cancel();
    final pkState = widget.room.pkBattleState;
    if (pkState.isActive && pkState.startTime != null) {
      // Reset battle state flags when starting/setting up a new battle
      _battleJustEnded = false;
      _winnerText = '';
      _animationController.reset();

      final endTime = pkState.startTime!.add(Duration(minutes: pkState.durationMinutes));
      _secondsRemaining = endTime.difference(DateTime.now()).inSeconds;
      
      if (_secondsRemaining <= 0) {
        _handleBattleEnd();
      } else {
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!mounted) {
            timer.cancel();
            return;
          }
          
          setState(() {
            _secondsRemaining--;
            if (_secondsRemaining <= 0) {
              timer.cancel();
              _handleBattleEnd();
            }
          });
        });
      }
    }
  }

  void _handleBattleEnd() {
    if (_battleJustEnded) return;
    _battleJustEnded = true;
    
    final pkState = widget.room.pkBattleState;
    setState(() {
      if (pkState.leftTeamScore > pkState.rightTeamScore) {
        _winnerText = 'Team A (Blue) Wins!';
      } else if (pkState.rightTeamScore > pkState.leftTeamScore) {
        _winnerText = 'Team B (Red) Wins!';
      } else {
        _winnerText = 'It\'s a Draw!';
      }
    });
    
    _animationController.forward().then((_) {
      if (!mounted) return;
      
      // If current user is host, reset the PK state
      final isHost = widget.room.isCreator(widget.currentUserId) ||
          widget.room.participants.any((p) => p.userId == widget.currentUserId && p.isHost);
          
      if (isHost) {
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            final resetState = pkState.copyWith(isActive: false);
            context.read<AudioRoomsBloc>().add(UpdatePKBattleState(
              roomId: widget.room.id,
              userId: widget.currentUserId,
              pkBattleState: resetState,
            ));
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  String _formatTime(int totalSeconds) {
    if (totalSeconds <= 0) return '00:00';
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final pkState = widget.room.pkBattleState;
    if (!pkState.isActive) return const SizedBox.shrink();

    if (pkState.teamSize == 1) {
      return _build1vs1Banner();
    } else {
      return _buildTeamSplitScreen();
    }
  }

  Widget _build1vs1Banner() {
    final pkState = widget.room.pkBattleState;
    final totalScore = pkState.leftTeamScore + pkState.rightTeamScore;
    final leftPercentage = totalScore == 0 ? 0.5 : pkState.leftTeamScore / totalScore;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top: Timer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'PK ${_formatTime(_secondsRemaining)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          
          // Avatars and progress bar
          Row(
            children: [
              // Left Avatar (Seat 1)
              _buildPKSeat(1, true, is1vs1: true, overrideUserId: pkState.leftTeamUserIds.isNotEmpty ? pkState.leftTeamUserIds.first : null),
              
              const SizedBox(width: 8),
              
              // Middle section (Progress Bar + VS)
              Expanded(
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Progress Bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            height: 12,
                            child: Row(
                              children: [
                                Expanded(
                                  flex: ((leftPercentage * 100).toInt()).clamp(1, 99),
                                  child: Container(color: Colors.redAccent),
                                ),
                                Expanded(
                                  flex: (((1 - leftPercentage) * 100).toInt()).clamp(1, 99),
                                  child: Container(color: Colors.blueAccent),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // VS Icon
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.amber,
                            shape: BoxShape.circle,
                          ),
                          child: const Text(
                            'VS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Scores text
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${pkState.leftTeamScore}', style: const TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                        Text('${pkState.rightTeamScore}', style: const TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 8),
              
              // Right Avatar (Seat 2)
              _buildPKSeat(2, false, is1vs1: true, overrideUserId: pkState.rightTeamUserIds.isNotEmpty ? pkState.rightTeamUserIds.first : null),
            ],
          ),
          
          if (_battleJustEnded && _winnerText.isNotEmpty) ...[
            const SizedBox(height: 12),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _winnerText,
                  style: const TextStyle(
                    color: Colors.yellowAccent,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                  ),
                ),
                const SizedBox(height: 8),
                if (widget.room.participants.any((p) => p.seatNumber == 1 && p.userId == widget.currentUserId))
                  ElevatedButton(
                    onPressed: () {
                      final resetState = pkState.copyWith(isActive: false);
                      context.read<AudioRoomsBloc>().add(UpdatePKBattleState(
                        roomId: widget.room.id,
                        userId: widget.currentUserId,
                        pkBattleState: resetState,
                      ));
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                    child: const Text('Close PK', style: TextStyle(color: Colors.white)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTeamSplitScreen() {
    final pkState = widget.room.pkBattleState;
    final totalScore = pkState.leftTeamScore + pkState.rightTeamScore;
    final leftPercentage = totalScore == 0 ? 0.5 : pkState.leftTeamScore / totalScore;
    
    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Timer
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'PK ${_formatTime(_secondsRemaining)}',
                style: const TextStyle(color: Colors.yellowAccent, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Split screen area
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left Team (Blue)
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF2E46E6), // Solid Blue
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Text(
                            'A',
                            style: TextStyle(
                              fontSize: 120,
                              fontWeight: FontWeight.w900,
                              color: Colors.white.withValues(alpha: 0.15),
                              height: 1.0,
                            ),
                          ),
                        ),
                        _buildTeamGrid(true),
                      ],
                    ),
                  ),
                ),
                
                // VS Divider - Optional, removed or kept thin based on screenshot
                Container(
                  width: 1,
                  color: Colors.black26,
                ),
                
                // Right Team (Red)
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFE21A42), // Solid Red
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Text(
                            'B',
                            style: TextStyle(
                              fontSize: 120,
                              fontWeight: FontWeight.w900,
                              color: Colors.white.withValues(alpha: 0.15),
                              height: 1.0,
                            ),
                          ),
                        ),
                        _buildTeamGrid(false),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Bottom Progress Bar
          Container(
            height: 24,
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Base progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Row(
                    children: [
                      Expanded(
                        flex: ((leftPercentage * 100).toInt()).clamp(1, 99),
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF38B6FF), Color(0xFF004AAD)],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: (((1 - leftPercentage) * 100).toInt()).clamp(1, 99),
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFFFF3131), Color(0xFFFF914D)],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Animated glowing orb/diamond
                AnimatedAlign(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                  alignment: Alignment(
                    // Map leftPercentage (0.0 to 1.0) to Alignment x (-1.0 to 1.0)
                    (leftPercentage * 2) - 1, 
                    0
                  ),
                  child: Container(
                    width: 14,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(7),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.8),
                          blurRadius: 12,
                          spreadRadius: 4,
                        ),
                        BoxShadow(
                          color: Colors.yellow.withValues(alpha: 0.5),
                          blurRadius: 20,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),

                // Score texts on top of progress bar
                Positioned(
                  left: 12,
                  top: 0,
                  bottom: 0,
                  child: Row(
                    children: [
                      const Icon(Icons.local_fire_department, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text('${pkState.leftTeamScore}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Positioned(
                  right: 12,
                  top: 0,
                  bottom: 0,
                  child: Row(
                    children: [
                      Text('${pkState.rightTeamScore}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 4),
                      const Icon(Icons.local_fire_department, color: Colors.white, size: 14),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Winner Overlay (if any, although we will move this to Leader overlay later)
          if (_battleJustEnded && _winnerText.isNotEmpty && pkState.teamSize == 1)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _winnerText,
                    style: const TextStyle(
                      color: Colors.yellowAccent,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (widget.room.participants.any((p) => p.seatNumber == 1 && p.userId == widget.currentUserId))
                    ElevatedButton(
                      onPressed: () {
                        final resetState = widget.room.pkBattleState.copyWith(isActive: false);
                        context.read<AudioRoomsBloc>().add(UpdatePKBattleState(
                          roomId: widget.room.id,
                          userId: widget.currentUserId,
                          pkBattleState: resetState,
                        ));
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                      child: const Text('Close PK', style: TextStyle(color: Colors.white)),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTeamGrid(bool isLeftTeam) {
    final pkState = widget.room.pkBattleState;
    final teamSize = pkState.teamSize;
    final startSeat = isLeftTeam ? 1 : teamSize + 1;
    
    // Leader is the first seat in the team
    final leaderSeat = startSeat;
    final memberSeats = List.generate(teamSize - 1, (i) => startSeat + 1 + i);
    
    List<Widget> memberRows = [];
    if (memberSeats.length == 3) {
      memberRows.add(Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly, 
        children: memberSeats.map((s) => _buildPKSeat(s, isLeftTeam)).toList(),
      ));
    } else if (memberSeats.length == 4) {
      memberRows.add(Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly, 
        children: memberSeats.take(2).map((s) => _buildPKSeat(s, isLeftTeam)).toList(),
      ));
      memberRows.add(const SizedBox(height: 12));
      memberRows.add(Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly, 
        children: memberSeats.skip(2).take(2).map((s) => _buildPKSeat(s, isLeftTeam)).toList(),
      ));
    } else {
      memberRows.add(Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.center,
        children: memberSeats.map((seatNum) => _buildPKSeat(seatNum, isLeftTeam)).toList(),
      ));
    }

    return Column(
      children: [
        // Leader
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: _buildPKSeat(leaderSeat, isLeftTeam, isLeader: true),
        ),
        const SizedBox(height: 12),
        // Members
        ...memberRows,
      ],
    );
  }

  Widget _buildPKSeat(int seatNum, bool isLeftTeam, {bool is1vs1 = false, bool isLeader = false, String? overrideUserId}) {
    AudioRoomParticipant? occupant;
    bool isOccupied = false;
    final isLocked = widget.room.isSeatLocked(seatNum);

    try {
      if (overrideUserId != null) {
        occupant = widget.room.participants.firstWhere((p) => p.userId == overrideUserId);
      } else {
        occupant = widget.room.participants.firstWhere((p) => p.seatNumber == seatNum);
      }
      isOccupied = true;
    } catch (e) {
      occupant = null;
      isOccupied = false;
    }

    // Determine avatar size
    double avatarSize = 56.0;
    if (is1vs1) avatarSize = 44.0;
    if (isLeader) avatarSize = 64.0;

    // Get individual score
    int score = 0;
    if (isOccupied && occupant != null) {
      score = widget.room.pkBattleState.individualScores[occupant.userId] ?? 0;
    }
    
    // Check if this team is the winner
    bool isWinnerTeam = false;
    if (_battleJustEnded) {
      final pkState = widget.room.pkBattleState;
      if (isLeftTeam && pkState.leftTeamScore > pkState.rightTeamScore) isWinnerTeam = true;
      if (!isLeftTeam && pkState.rightTeamScore > pkState.leftTeamScore) isWinnerTeam = true;
    }

    return GestureDetector(
      onTap: () => widget.onSeatTap?.call(seatNum),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Seat Base Circle
              Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isOccupied 
                      ? Colors.transparent 
                      : Colors.white.withValues(alpha: 0.3), // Matches screenshot empty seat style
                  border: isOccupied
                      ? Border.all(
                          color: isLeftTeam ? Colors.blueAccent : Colors.redAccent,
                          width: 2.5,
                        )
                      : null,
                ),
                child: isOccupied && occupant != null
                    ? SpeakingRippleAnimation(
                        isSpeaking: occupant.isSpeaker && !occupant.isMuted,
                        minRadius: occupant.frameId != null ? (avatarSize / 2 * 1.3) : (avatarSize / 2),
                        rippleColor: (isLeftTeam ? Colors.blueAccent : Colors.redAccent).withValues(alpha: 0.4),
                        child: CachedCircleAvatar(
                          imageUrl: occupant.userImageUrl ?? '',
                          radius: avatarSize / 2,
                          backgroundColor: Colors.grey[800],
                          frameId: null, // Removed frame for PK mode
                          userId: occupant.userId,
                          frameScale: 1.35,
                          borderWidth: 0,
                          padding: 0,
                        ),
                      )
                    : Icon(
                        isLocked ? Icons.lock : Icons.add,
                        color: Colors.white,
                        size: avatarSize * 0.5,
                      ),
              ),

              // Large Central Mute Icon Overlay (matching screenshot)
              if (isOccupied && occupant != null && occupant.isMuted)
                Container(
                  width: avatarSize,
                  height: avatarSize,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.mic_off,
                    color: Colors.white,
                    size: avatarSize * 0.55,
                  ),
                ),
                
              // Winner Animation Overlay on Leader
              if (isLeader && isWinnerTeam)
                Positioned(
                  top: -20,
                  child: ScaleTransition(
                    scale: CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2))],
                      ),
                      child: const Text('WINNER!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ),
                ),
            ],
          ),
          
          // Leader tag
          if (isLeader)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              decoration: BoxDecoration(
                color: isLeftTeam ? const Color(0xFF1E88E5) : const Color(0xFFEF5350),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('Leader', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          
          // Dynamic contribution points under the name (PK Points)
          if (isOccupied && occupant != null)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.local_fire_department,
                    color: isLeftTeam ? Colors.blue[300] : Colors.pink[300],
                    size: 10,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '$score',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )
          else if (!is1vs1)
            const SizedBox(height: 14), // Keeps layouts height-aligned
        ],
      ),
    );
  }
}




import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/models/audio_room_v2.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/voting/voting_controller.dart';
import 'dart:async';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/voting/voting_models.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/voting/voting_result_sheet.dart';

class VotingWidget extends StatefulWidget {
  final AudioRoomV2 room;
  final String currentUserId;
  final bool isHost;

  const VotingWidget({
    super.key,
    required this.room,
    required this.currentUserId,
    required this.isHost,
  }) ;

  @override
  State<VotingWidget> createState() => _VotingWidgetState();
}

class _VotingWidgetState extends State<VotingWidget> {
  late VotingController _controller;
  Timer? _timer;
  int _remainingSeconds = 0;
  bool _isMinimized = false;
  bool _hasDismissedEndedResult = false;
  Offset _minimizedPosition = const Offset(16, 400); // Default position for minimized pill

  @override
  void initState() {
    super.initState();
    _controller = Get.put(
      VotingController(widget.room.id, isHost: widget.isHost),
      tag: 'voting_${widget.room.id}',
    );

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      final state = _controller.gameState.value;
      if (state.isActive) {
        final elapsed = (DateTime.now().millisecondsSinceEpoch - state.startTime) ~/ 1000;
        final remaining = state.durationSeconds - elapsed;
        setState(() {
          _remainingSeconds = remaining > 0 ? remaining : 0;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTime(int seconds) {
    if (seconds < 0) return '00:00';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final state = _controller.gameState.value;
      if (!state.isActive) {
        if (state.id.isNotEmpty && !_hasDismissedEndedResult) {
          return _buildEndedFloatingIcon(state);
        }
        return const SizedBox.shrink();
      }

      final hasVoted = state.votes.containsKey(widget.currentUserId);
      final myVote = state.votes[widget.currentUserId];
      
      // Get current user details for chat message
      String username = 'User';
      String? userAvatar;
      try {
        final participant = widget.room.participants.firstWhere(
          (p) => p.userId == widget.currentUserId,
        );
        username = participant.userName.isNotEmpty ? participant.userName : 'User';
        userAvatar = participant.userImageUrl;
      } catch (_) {}

      if (_isMinimized) {
        return Positioned(
          left: _minimizedPosition.dx,
          top: _minimizedPosition.dy,
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                _minimizedPosition += details.delta;
              });
            },
            onTap: () {
              setState(() {
                _isMinimized = false;
              });
            },
            child: _buildMinimizedView(state),
          ),
        );
      }

      return Positioned(
        top: 140,
        left: 0,
        right: 0,
        child: TapRegion(
          onTapOutside: (_) {
            setState(() {
              _isMinimized = true;
            });
          },
          child: _buildMaximizedView(state, hasVoted, myVote, username, userAvatar),
        ),
      );
    });
  }

  Widget _buildMinimizedView(VotingState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F2046).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.5), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.how_to_vote, color: Colors.amber, size: 16),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                state.question.isNotEmpty ? state.question : 'Voting in progress...',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${_formatTime(_remainingSeconds)} remaining',
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMaximizedView(VotingState state, bool hasVoted, int? myVote, String username, String? userAvatar) {
    return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF0F2046), // Deep blue
              const Color(0xFF0A1024), // Darker blue
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 12,
              spreadRadius: 2,
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Stack(
              alignment: Alignment.center,
              children: [
                Column(
                  children: [
                    Text(
                      state.question.isNotEmpty ? state.question : 'ভোট করুন',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Free • ',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const Icon(Icons.schedule, color: Colors.white70, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          _formatTime(_remainingSeconds),
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isMinimized = true;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 18),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: GestureDetector(
                    onTap: widget.isHost ? () => _controller.endVoting() : null,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.isHost ? Icons.stop : Icons.close_fullscreen,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Options
            ...List.generate(state.options.length, (index) {
              final optionText = state.options[index];
              final voteCount = state.getVotesForOption(index);
              final percentage = state.getPercentageForOption(index);
              final isMyChoice = myVote == index;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFF1C2A52),
                  borderRadius: BorderRadius.circular(27),
                  border: Border.all(
                    color: isMyChoice ? Colors.amber : Colors.transparent,
                    width: 1,
                  ),
                ),
                child: Stack(
                  children: [
                    // Progress Bar
                    if (hasVoted || widget.isHost)
                      FractionallySizedBox(
                        widthFactor: percentage,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(27),
                          ),
                        ),
                      ),
                    
                    // Content
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          // Index Circle
                          Container(
                            width: 38,
                            height: 38,
                            decoration: const BoxDecoration(
                              color: Color(0xFF3B82F6), // Blue circle
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          
                          // Text and Votes
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  optionText,
                                  style: TextStyle(
                                    color: isMyChoice ? Colors.amber : Colors.white,
                                    fontWeight: isMyChoice ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 15,
                                  ),
                                ),
                                Row(
                                  children: [
                                    const Icon(Icons.people_alt, color: Colors.white54, size: 12),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$voteCount',
                                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          
                          // Vote Button or Percentage
                          if (!hasVoted)
                            ElevatedButton(
                              onPressed: () {
                                _controller.castVote(widget.currentUserId, username, userAvatar, index);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFB800), // Yellow button
                                foregroundColor: Colors.black87,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                                minimumSize: const Size(60, 32),
                              ),
                              child: const Text('Vote', style: TextStyle(fontWeight: FontWeight.bold)),
                            )
                          else if (hasVoted || widget.isHost)
                            Padding(
                              padding: const EdgeInsets.only(right: 12.0),
                              child: Text(
                                '${(percentage * 100).toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
            
            // Bottom Action (Anonymous Voting)
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF151F3D), // Slightly lighter than background
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Anonymous Voting',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  SizedBox(
                    height: 24,
                    width: 40,
                    child: Switch(
                      value: false, // UI only for now
                      onChanged: (val) {},
                      activeThumbColor: Colors.grey,
                      inactiveTrackColor: Colors.white12,
                      inactiveThumbColor: Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
  }

  Widget _buildEndedFloatingIcon(VotingState state) {
    int winner = -1;
    int maxVotes = -1;
    for (int i = 0; i < state.options.length; i++) {
      final v = state.getVotesForOption(i);
      if (v > maxVotes) {
        maxVotes = v;
        winner = i;
      }
    }

    return Positioned(
      right: 12,
      bottom: 250, // above the events portal
      child: GestureDetector(
        onTap: () {
          setState(() {
            _hasDismissedEndedResult = true;
          });
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            builder: (context) => VotingResultSheet(roomId: widget.room.id),
          );
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: const BoxDecoration(
                color: Colors.transparent,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Ended',
                    style: TextStyle(
                      color: Colors.lightBlue,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withValues(alpha: 0.8),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 2),
                      boxShadow: const [
                        BoxShadow(color: Colors.black45, blurRadius: 4),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        '${winner + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (widget.isHost)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _hasDismissedEndedResult = true;
                        });
                        _controller.clearVoting();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('End', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    )
                  else
                    const Text(
                      'Result',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

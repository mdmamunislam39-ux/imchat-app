import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/voting/voting_models.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/voting/voting_controller.dart';
import 'package:get/get.dart';

class VotingResultSheet extends StatelessWidget {
  final String roomId;

  const VotingResultSheet({super.key, required this.roomId}) ;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F2046),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white24, width: 0.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Voting Results',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('rooms')
                .doc(roomId)
                .collection('voting')
                .doc('state')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || !snapshot.data!.exists || snapshot.data!.data() == null) {
                return const Text('No voting data found.', style: TextStyle(color: Colors.white54));
              }

              final state = VotingState.fromJson(snapshot.data!.data() as Map<String, dynamic>);
              final totalVotes = state.votes.length;

              return Column(
                children: [
                  Text(
                    state.question.isNotEmpty ? state.question : 'Poll Results',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Total Votes: $totalVotes',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ...List.generate(state.options.length, (index) {
                    final optionText = state.options[index];
                    final voteCount = state.getVotesForOption(index);
                    final percentage = state.getPercentageForOption(index);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C2A52),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Stack(
                        children: [
                          FractionallySizedBox(
                            widthFactor: percentage,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                Text(
                                  '${index + 1}. $optionText',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${(percentage * 100).toStringAsFixed(0)}% ($voteCount)',
                                  style: const TextStyle(
                                    color: Colors.amber,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          const SizedBox(height: 16),
          // Clear button for Host
          Builder(builder: (ctx) {
            try {
              final controller = Get.find<VotingController>(tag: 'voting_$roomId');
              if (controller.isHost) {
                return ElevatedButton(
                  onPressed: () {
                    controller.clearVoting();
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                  ),
                  child: const Text('Clear Result', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                );
              }
            } catch (_) {}
            return const SizedBox.shrink();
          }),
        ],
      ),
    );
  }
}

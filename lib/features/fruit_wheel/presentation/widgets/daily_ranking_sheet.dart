import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:chat_messenger/components/dynamic_diamond_icon.dart';


class DailyRankingSheet extends StatelessWidget {
  const DailyRankingSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final String dateString = DateTime.now().toIso8601String().split('T')[0];
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Color(0xFF1E0845),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.white10,
                ),
              ),
            ),
            child: const Center(
              child: Text(
                '🏆 Daily Top 10 Winners',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance
                  .collection('fruit_wheel_rankings')
                  .doc(dateString)
                  .collection('top_winners')
                  .orderBy('totalWon', descending: true)
                  .limit(10)
                  .get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)));
                }
                
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading rankings', style: TextStyle(color: Colors.white54)));
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No winners yet today!',
                      style: TextStyle(color: Colors.white54, fontSize: 16),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: docs.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final name = data['name'] ?? 'Player';
                    final photo = data['photo'] ?? '';
                    final totalWon = (data['totalWon'] as num?)?.toInt() ?? 0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: index < 3
                            ? Border.all(
                                color: index == 0
                                    ? const Color(0xFFFFD700)
                                    : index == 1
                                        ? const Color(0xFFC0C0C0)
                                        : const Color(0xFFCD7F32),
                                width: 1.5,
                              )
                            : null,
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 32,
                            child: Text(
                              '#${index + 1}',
                              style: TextStyle(
                                color: index == 0
                                    ? const Color(0xFFFFD700)
                                    : index == 1
                                        ? const Color(0xFFC0C0C0)
                                        : index == 2
                                            ? const Color(0xFFCD7F32)
                                            : Colors.white54,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          CircleAvatar(
                            radius: 18,
                            backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                            child: photo.isEmpty ? const Icon(Icons.person, size: 20) : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          DynamicDiamondIcon(width: 14, height: 14),
                          const SizedBox(width: 4),
                          Text(
                            '+$totalWon',
                            style: const TextStyle(
                              color: Color(0xFF81C784),
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

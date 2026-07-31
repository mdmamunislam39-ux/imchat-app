import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/gready_game_sheet.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/pink_greedy_game_sheet.dart';
import 'package:chat_messenger/features/fruit_wheel/presentation/pages/fruit_wheel_page.dart';

class GameWallBottomSheet extends StatelessWidget {
  const GameWallBottomSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const GameWallBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E2C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
              color: Colors.black54, blurRadius: 16, offset: Offset(0, -4)),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white12)),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.sports_esports, color: Colors.amber, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Game Wall',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Game List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('games')
                  .where('isEnabled', isEqualTo: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: Colors.amber));
                }
                final docs = snapshot.hasData ? snapshot.data!.docs : [];
                final itemCount = docs.length + 3;

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: itemCount,
                  itemBuilder: (context, index) {
                    // Hardcoded games first
                    if (index == 0) {
                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          GreadyGameSheet.show(context);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF2D2D44),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: Colors.amber.withValues(alpha: 0.3),
                                width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.amber.withValues(alpha: 0.1),
                                blurRadius: 8,
                                spreadRadius: 1,
                              )
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              StreamBuilder<DocumentSnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('config')
                                      .doc('greedy_game')
                                      .snapshots(),
                                  builder: (context, snapshot) {
                                    String? thumbUrl;
                                    if (snapshot.hasData &&
                                        snapshot.data!.exists) {
                                      final data = snapshot.data!.data()
                                          as Map<String, dynamic>?;
                                      thumbUrl =
                                          data?['thumbnailUrl'] as String?;
                                    }
                                    return Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        color: Colors.black26,
                                        image: (thumbUrl != null &&
                                                thumbUrl.isNotEmpty)
                                            ? DecorationImage(
                                                image: NetworkImage(thumbUrl),
                                                fit: BoxFit.cover,
                                              )
                                            : null,
                                      ),
                                      child: (thumbUrl == null ||
                                              thumbUrl.isEmpty)
                                          ? const Center(
                                              child: Text('🎡',
                                                  style:
                                                      TextStyle(fontSize: 30)),
                                            )
                                          : null,
                                    );
                                  }),
                              const SizedBox(height: 12),
                              const Text(
                                'Gready Game',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    if (index == 1) {
                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          showFruitWheelSheet(context);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF2D2D44),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: Colors.pinkAccent.withValues(alpha: 0.3),
                                width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.pinkAccent.withValues(alpha: 0.1),
                                blurRadius: 8,
                                spreadRadius: 1,
                              )
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              StreamBuilder<DocumentSnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('config')
                                      .doc('fruit_wheel')
                                      .snapshots(),
                                  builder: (context, snapshot) {
                                    String? thumbUrl;
                                    if (snapshot.hasData &&
                                        snapshot.data!.exists) {
                                      final data = snapshot.data!.data()
                                          as Map<String, dynamic>?;
                                      thumbUrl =
                                          data?['thumbnailUrl'] as String?;
                                    }
                                    return Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        color: Colors.black26,
                                        image: (thumbUrl != null &&
                                                thumbUrl.isNotEmpty)
                                            ? DecorationImage(
                                                image: NetworkImage(thumbUrl),
                                                fit: BoxFit.cover,
                                              )
                                            : null,
                                      ),
                                      child: (thumbUrl == null ||
                                              thumbUrl.isEmpty)
                                          ? const Center(
                                              child: Text('🍉',
                                                  style:
                                                      TextStyle(fontSize: 30)),
                                            )
                                          : null,
                                    );
                                  }),
                              const SizedBox(height: 12),
                              const Text(
                                'Fruit Wheel',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    if (index == 2) {
                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          PinkGreedyGameSheet.show(context);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF2D2D44),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: Colors.pinkAccent.withValues(alpha: 0.3),
                                width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.pinkAccent.withValues(alpha: 0.1),
                                blurRadius: 8,
                                spreadRadius: 1,
                              )
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              StreamBuilder<DocumentSnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('config')
                                      .doc('pink_greedy_game')
                                      .snapshots(),
                                  builder: (context, snapshot) {
                                    String? thumbUrl;
                                    if (snapshot.hasData &&
                                        snapshot.data!.exists) {
                                      final data = snapshot.data!.data()
                                          as Map<String, dynamic>?;
                                      thumbUrl =
                                          data?['thumbnailUrl'] as String?;
                                    }
                                    return Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        color: Colors.black26,
                                        image: (thumbUrl != null &&
                                                thumbUrl.isNotEmpty)
                                            ? DecorationImage(
                                                image: NetworkImage(thumbUrl),
                                                fit: BoxFit.cover,
                                              )
                                            : null,
                                      ),
                                      child: (thumbUrl == null ||
                                              thumbUrl.isEmpty)
                                          ? const Center(
                                              child: Text('🌸',
                                                  style:
                                                      TextStyle(fontSize: 30)),
                                            )
                                          : null,
                                    );
                                  }),
                              const SizedBox(height: 12),
                              const Text(
                                'Greedy Pink',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    // Dynamic games from firestore
                    final docIndex = index - 3;
                    final doc = docs[docIndex];
                    final data = doc.data() as Map<String, dynamic>;
                    final name = data['name'] ?? 'Game';
                    final picture = data['picture'] ?? '';

                    return GestureDetector(
                      onTap: () {
                        // Close the wall and open the game
                        Navigator.pop(context);
                        GreadyGameSheet.show(context);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF2D2D44),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: Colors.amber.withValues(alpha: 0.3),
                              width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withValues(alpha: 0.1),
                              blurRadius: 8,
                              spreadRadius: 1,
                            )
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                image: picture.isNotEmpty
                                    ? DecorationImage(
                                        image: NetworkImage(picture),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                                color: Colors.black26,
                              ),
                              child: picture.isEmpty
                                  ? const Icon(Icons.videogame_asset,
                                      color: Colors.white54, size: 30)
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
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

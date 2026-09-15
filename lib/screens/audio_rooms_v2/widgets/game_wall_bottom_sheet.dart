import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chat_messenger/models/audio_room_v2.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/gready_game_sheet.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/pink_greedy_game_sheet.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/food_spin_game_sheet.dart';
import 'package:chat_messenger/features/fruit_wheel/presentation/pages/fruit_wheel_page.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/html5_game_sheet.dart';

class GameWallBottomSheet extends StatelessWidget {
  final bool isInAudioRoom;
  final String? roomId;
  final AudioRoomV2? room;

  const GameWallBottomSheet({
    super.key,
    this.isInAudioRoom = true,
    this.roomId,
    this.room,
  });

  static void show(
    BuildContext context, {
    bool isInAudioRoom = true,
    String? roomId,
    AudioRoomV2? room,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => GameWallBottomSheet(
        isInAudioRoom: isInAudioRoom,
        roomId: roomId ?? room?.id,
        room: room,
      ),
    );
  }

  static bool _isDocActive(Map<String, dynamic>? data) {
    if (data == null) return true;
    if (data['isActive'] == false || data['isActive'] == 0 || data['isActive'] == 'false') {
      return false;
    }
    if (data['isEnabled'] == false || data['isEnabled'] == 0 || data['isEnabled'] == 'false') {
      return false;
    }
    final status = (data['status'] ?? '').toString().toLowerCase();
    if (status == 'inactive' || status == 'disabled' || status == 'hidden') {
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: const BoxDecoration(
        color: Color(0xFF1E2438),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 20,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.only(top: 12, bottom: 12),
            child: Column(
              children: [
                // Drag handle
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Centered Title
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('🎮', style: TextStyle(fontSize: 20)),
                    SizedBox(width: 8),
                    Text(
                      'Game Wall',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Games Grid (Strictly standalone/mini games only - NO Room Games)
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('config').snapshots(),
              builder: (context, configSnapshot) {
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('games').snapshots(),
                  builder: (context, gamesSnapshot) {
                    if (configSnapshot.connectionState == ConnectionState.waiting &&
                        gamesSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.amber),
                      );
                    }

                    // 1. Build config map for system games
                    final Map<String, Map<String, dynamic>> configMap = {};
                    if (configSnapshot.hasData) {
                      for (final doc in configSnapshot.data!.docs) {
                        configMap[doc.id] = (doc.data() as Map<String, dynamic>?) ?? {};
                      }
                    }

                    final List<_GameWallCardData> activeGames = [];

                    // 2. Greedy Game (greedycat)
                    final greedyConfig = configMap['greedy_game'];
                    if (_isDocActive(greedyConfig)) {
                      final thumb = greedyConfig?['thumbnailUrl'] as String?;
                      final name = (greedyConfig?['gameCode'] ?? greedyConfig?['name'] ?? 'greedycat').toString();
                      activeGames.add(_GameWallCardData(
                        id: 'greedy_game',
                        title: name,
                        thumbnailUrl: (thumb != null && thumb.isNotEmpty) ? thumb : null,
                        fallbackEmoji: '🎡',
                        pillColor: const Color(0xFF2196F3),
                        onTap: () {
                          Navigator.pop(context);
                          GreadyGameSheet.show(context, isInAudioRoom: isInAudioRoom);
                        },
                      ));
                    }

                    // 3. Fruit Wheel (eliminateslot)
                    final fruitConfig = configMap['fruit_wheel'];
                    if (_isDocActive(fruitConfig)) {
                      final thumb = fruitConfig?['thumbnailUrl'] as String?;
                      final name = (fruitConfig?['gameCode'] ?? fruitConfig?['name'] ?? 'eliminateslot').toString();
                      activeGames.add(_GameWallCardData(
                        id: 'fruit_wheel',
                        title: name,
                        thumbnailUrl: (thumb != null && thumb.isNotEmpty) ? thumb : null,
                        fallbackEmoji: '🍉',
                        pillColor: const Color(0xFF5C6BC0),
                        onTap: () {
                          Navigator.pop(context);
                          showFruitWheelSheet(context, isInAudioRoom: isInAudioRoom);
                        },
                      ));
                    }

                    // 4. Food Spin Game (yummy)
                    final foodSpinConfig = configMap['food_spin_game'];
                    if (_isDocActive(foodSpinConfig)) {
                      final thumb = foodSpinConfig?['thumbnailUrl'] as String?;
                      final name = (foodSpinConfig?['gameCode'] ?? foodSpinConfig?['name'] ?? 'yummy').toString();
                      activeGames.add(_GameWallCardData(
                        id: 'food_spin_game',
                        title: name,
                        thumbnailUrl: (thumb != null && thumb.isNotEmpty) ? thumb : null,
                        fallbackEmoji: '🍔',
                        pillColor: const Color(0xFF7E57C2),
                        onTap: () {
                          Navigator.pop(context);
                          FoodSpinGameSheet.show(context, isInAudioRoom: isInAudioRoom);
                        },
                      ));
                    }

                    // 5. Greedy Pink (pinkgreedy)
                    final pinkConfig = configMap['pink_greedy_game'];
                    if (pinkConfig != null && _isDocActive(pinkConfig)) {
                      final thumb = pinkConfig['thumbnailUrl'] as String?;
                      final name = (pinkConfig['gameCode'] ?? pinkConfig['name'] ?? 'Pink Greedy').toString();
                      activeGames.add(_GameWallCardData(
                        id: 'pink_greedy_game',
                        title: name,
                        thumbnailUrl: (thumb != null && thumb.isNotEmpty) ? thumb : null,
                        fallbackEmoji: '🌸',
                        pillColor: const Color(0xFFE91E63),
                        onTap: () {
                          Navigator.pop(context);
                          PinkGreedyGameSheet.show(context, isInAudioRoom: isInAudioRoom);
                        },
                      ));
                    }

                    // Exclude codes of built-in games and strictly filter out ALL room games
                    final Set<String> registeredCodes = {
                      'greedy_game',
                      'greedy',
                      'greedycat',
                      'fruit_wheel',
                      'fruitwheel',
                      'eliminateslot',
                      'pink_greedy_game',
                      'pink_greedy',
                      'pinkgreedy',
                      'food_spin_game',
                      'food_spin',
                      'foodspin',
                      'yummy',
                    };

                    // Dynamic colors palette for custom games
                    final List<Color> customColors = [
                      const Color(0xFF00BCD4), // Cyan (Greedy Delicious)
                      const Color(0xFF00ACC1), // Cyan Dark (Greedy Market)
                      const Color(0xFF3949AB), // Indigo (King Queen)
                      const Color(0xFF2979FF), // Vivid Blue (Fishing)
                      const Color(0xFF4527A0), // Deep Purple (Slot Frenzy)
                      const Color(0xFF43A047), // Green (Pachinko)
                      const Color(0xFFD81B60), // Deep Pink
                      const Color(0xFFFF8F00), // Amber
                    ];

                    // 6. Dynamic Games from 'games' collection ONLY
                    // (Strictly NO room games: no Ludo, no Carrom, no room modes)
                    if (gamesSnapshot.hasData) {
                      int colorIndex = 0;
                      for (final doc in gamesSnapshot.data!.docs) {
                        final data = (doc.data() as Map<String, dynamic>?) ?? {};
                        if (!_isDocActive(data)) continue;

                        final code = (data['gameCode'] ?? doc.id).toString().toLowerCase();
                        final name = (data['name'] ?? data['title'] ?? '').toString();
                        final lowerName = name.toLowerCase();
                        final category = (data['category'] ?? '').toString().toLowerCase();

                        // Strict room game exclusions
                        if (category == 'mode' || category == 'room_mode') continue;
                        if (code.contains('ludo') || code.contains('ludu') || lowerName.contains('ludo') || lowerName.contains('ludu')) continue;
                        if (code.contains('carrom') || lowerName.contains('carrom')) continue;
                        if (code.contains('pk_battle') || code.contains('vote_pro') || code.contains('youtube') || code.contains('dice')) continue;

                        if (registeredCodes.contains(code)) continue;
                        registeredCodes.add(code);

                        final picture = (data['picture'] ?? data['thumbnailUrl'] ?? data['icon'] ?? '').toString();
                        final gameUrl = (data['gameUrl'] ?? data['url'] ?? data['link'] ?? data['webViewUrl'] ?? '').toString().trim();

                        // Specific color assignments for known games to match the UI photo
                        Color pillColor = customColors[colorIndex % customColors.length];
                        if (code.contains('delicious') || lowerName.contains('delicious')) {
                          pillColor = const Color(0xFF00BCD4);
                        } else if (code.contains('market') || lowerName.contains('market')) {
                          pillColor = const Color(0xFF00ACC1);
                        } else if (code.contains('king_queen') || lowerName.contains('king queen')) {
                          pillColor = const Color(0xFF3949AB);
                        } else if (code.contains('fishing') || lowerName.contains('fishing')) {
                          pillColor = const Color(0xFF2979FF);
                        } else if (code.contains('frenzy') || lowerName.contains('frenzy')) {
                          pillColor = const Color(0xFF4527A0);
                        } else if (code.contains('pachinko') || lowerName.contains('pachinko')) {
                          pillColor = const Color(0xFF43A047);
                        }

                        colorIndex++;

                        activeGames.add(_GameWallCardData(
                          id: doc.id,
                          title: name.isNotEmpty ? name : code,
                          thumbnailUrl: picture.isNotEmpty ? picture : null,
                          fallbackEmoji: '🎮',
                          pillColor: pillColor,
                          onTap: () {
                            Navigator.pop(context);
                            String effectiveUrl = gameUrl;
                            if (effectiveUrl.isEmpty) {
                              if (code.contains('delicious') || lowerName.contains('delicious')) {
                                effectiveUrl = 'https://greedy-delicious-game.web.app';
                              } else if (code.contains('market') || lowerName.contains('market')) {
                                effectiveUrl = 'https://greedy-market-game.web.app';
                              } else if (code.contains('arabian') || lowerName.contains('arabian')) {
                                effectiveUrl = 'https://arabian-spin-game.web.app';
                              } else if (code.contains('king') || lowerName.contains('king')) {
                                effectiveUrl = 'https://king-queen-slot-game.web.app';
                              }
                            }

                            if (effectiveUrl.isNotEmpty) {
                              Html5GameSheet.show(
                                context,
                                url: effectiveUrl,
                                title: name.isNotEmpty ? name : code,
                                isInAudioRoom: isInAudioRoom,
                                roomId: roomId,
                              );
                            } else {
                              GreadyGameSheet.show(context, isInAudioRoom: isInAudioRoom);
                            }
                          },
                        ));
                      }
                    }

                    if (activeGames.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('🎮', style: TextStyle(fontSize: 48)),
                            SizedBox(height: 12),
                            Text(
                              'No games available right now',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return GridView.builder(
                      padding: EdgeInsets.fromLTRB(14, 8, 14, 16 + bottomPadding),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.82,
                      ),
                      itemCount: activeGames.length,
                      itemBuilder: (context, index) {
                        return _buildCard(activeGames[index]);
                      },
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

  Widget _buildCard(_GameWallCardData game) {
    final bool isIconOnly = game.thumbnailUrl != null &&
        (game.thumbnailUrl!.contains('cdn-icons') ||
            game.thumbnailUrl!.contains('flaticon') ||
            game.thumbnailUrl!.contains('icon'));

    return GestureDetector(
      onTap: game.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF22283E),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Top Section (Banner / Icon)
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: (game.thumbnailUrl != null && game.thumbnailUrl!.isNotEmpty)
                    ? Padding(
                        padding: EdgeInsets.all(isIconOnly ? 14.0 : 0.0),
                        child: Image.network(
                          game.thumbnailUrl!,
                          fit: isIconOnly ? BoxFit.contain : BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (ctx, err, stack) => Center(
                            child: Text(game.fallbackEmoji, style: const TextStyle(fontSize: 32)),
                          ),
                          loadingBuilder: (ctx, child, progress) {
                            if (progress == null) return child;
                            return const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white24,
                                ),
                              ),
                            );
                          },
                        ),
                      )
                    : Center(
                        child: Text(game.fallbackEmoji, style: const TextStyle(fontSize: 32)),
                      ),
              ),
            ),

            // Bottom Section (Colored Pill with Game Name)
            Container(
              width: double.infinity,
              height: 26,
              decoration: BoxDecoration(
                color: game.pillColor,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
              ),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                game.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameWallCardData {
  final String id;
  final String title;
  final String? thumbnailUrl;
  final String fallbackEmoji;
  final Color pillColor;
  final VoidCallback onTap;

  _GameWallCardData({
    required this.id,
    required this.title,
    this.thumbnailUrl,
    required this.fallbackEmoji,
    required this.pillColor,
    required this.onTap,
  });
}

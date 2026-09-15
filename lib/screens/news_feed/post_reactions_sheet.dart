import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chat_messenger/components/cached_circle_avatar.dart';
import 'package:chat_messenger/components/loading_indicator.dart';
import 'package:chat_messenger/models/news_feed_post.dart';
import 'package:chat_messenger/screens/room/roomprofile_screen.dart';
import 'package:get/get.dart';

/// Sheet displaying reactions breakdown and list of reactors for a post (Screenshot 2).
class PostReactionsSheet extends StatefulWidget {
  final String postId;
  final String? initialReactionFilter; // null = 'All'

  const PostReactionsSheet({
    super.key,
    required this.postId,
    this.initialReactionFilter,
  });

  static void show(BuildContext context, {required String postId, String? initialReactionFilter}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PostReactionsSheet(
        postId: postId,
        initialReactionFilter: initialReactionFilter,
      ),
    );
  }

  @override
  State<PostReactionsSheet> createState() => _PostReactionsSheetState();
}

class _PostReactionsSheetState extends State<PostReactionsSheet> {
  String? _selectedFilter; // null means 'All'
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // In-memory cache for user data to avoid redundant Firestore queries
  static final Map<String, Map<String, dynamic>> _userCache = {};

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.initialReactionFilter;
    _searchController.addListener(() {
      if (mounted) {
        setState(() {
          _searchQuery = _searchController.text.trim().toLowerCase();
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1).replaceAll('.0', '')}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1).replaceAll('.0', '')}K';
    } else {
      return '$count';
    }
  }

  Color _getReactionBgColor(ReactionType type) {
    switch (type) {
      case ReactionType.like:
        return const Color(0xFF1877F2);
      case ReactionType.love:
        return const Color(0xFFE41E3F);
      case ReactionType.haha:
      case ReactionType.wow:
      case ReactionType.sad:
        return const Color(0xFFF7B125);
      case ReactionType.angry:
        return const Color(0xFFE94B35);
    }
  }

  Future<Map<String, dynamic>?> _getUserData(String userId) async {
    if (_userCache.containsKey(userId)) {
      return _userCache[userId];
    }
    try {
      final doc = await FirebaseFirestore.instance.collection('Users').doc(userId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _userCache[userId] = data;
        return data;
      }
    } catch (e) {
      debugPrint('Error fetching user $userId for reactions: $e');
    }
    return null;
  }

  void _navigateToProfile(String userId, {String? userName, String? userPhoto}) {
    Get.to(() => ProfilePageForRoom(
          userID: userId,
          userName: userName ?? '',
          userImage: userPhoto ?? '',
        ));
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF161622) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('news_feed_posts')
            .doc(widget.postId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: LoadingIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Post unavailable'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final Map<String, dynamic> rawReactions = data['reactions'] ?? {};
          // Format: Map<userId, reactionTypeString>
          final Map<String, String> reactionsMap = {};
          rawReactions.forEach((key, value) {
            if (value is String) {
              reactionsMap[key] = value;
            } else if (value is Map && value['reaction'] != null) {
              reactionsMap[key] = value['reaction'].toString();
            }
          });

          // Fallback to likedBy if reactions map is empty but likedBy exists
          if (reactionsMap.isEmpty && data['likedBy'] != null) {
            final List likedBy = data['likedBy'] ?? [];
            for (var uid in likedBy) {
              reactionsMap[uid.toString()] = 'like';
            }
          }

          // Count per reaction type
          final Map<String, int> reactionCounts = {};
          reactionsMap.forEach((userId, reactionStr) {
            reactionCounts[reactionStr] = (reactionCounts[reactionStr] ?? 0) + 1;
          });

          final totalReactions = reactionsMap.length;

          // Filter reactors list
          List<MapEntry<String, String>> filteredReactors = reactionsMap.entries.where((entry) {
            if (_selectedFilter == null) return true;
            return entry.value == _selectedFilter;
          }).toList();

          return Column(
            children: [
              // Drag handle
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.white24 : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header: Back button / Title / Search button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 20,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _isSearching
                          ? TextField(
                              controller: _searchController,
                              autofocus: true,
                              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                              decoration: InputDecoration(
                                hintText: 'Search reactors...',
                                hintStyle: TextStyle(color: isDarkMode ? Colors.white54 : Colors.grey[500]),
                                border: InputBorder.none,
                              ),
                            )
                          : Text(
                              'Reactions',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                            ),
                    ),
                    IconButton(
                      icon: Icon(
                        _isSearching ? Icons.close : Icons.search,
                        color: isDarkMode ? Colors.white70 : Colors.black87,
                      ),
                      onPressed: () {
                        setState(() {
                          _isSearching = !_isSearching;
                          if (!_isSearching) {
                            _searchController.clear();
                            _searchQuery = '';
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, thickness: 0.5),

              // Filter Tabs Row (All 7.9K, 😆 4.4K, 👍 3.3K, etc.)
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    // All Tab
                    _buildFilterChip(
                      label: 'All ${_formatCount(totalReactions)}',
                      isSelected: _selectedFilter == null,
                      onTap: () => setState(() => _selectedFilter = null),
                      isDarkMode: isDarkMode,
                    ),
                    const SizedBox(width: 8),

                    // Reaction Specific Tabs
                    ...ReactionType.values.map((reactType) {
                      final count = reactionCounts[reactType.name] ?? 0;
                      if (count == 0 && _selectedFilter != reactType.name) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _buildFilterChip(
                          label: '${reactType.emoji} ${_formatCount(count)}',
                          isSelected: _selectedFilter == reactType.name,
                          onTap: () => setState(() => _selectedFilter = reactType.name),
                          isDarkMode: isDarkMode,
                        ),
                      );
                    }),
                  ],
                ),
              ),

              const Divider(height: 1, thickness: 0.5),

              // Reactors List
              Expanded(
                child: filteredReactors.isEmpty
                    ? Center(
                        child: Text(
                          'No reactions yet',
                          style: TextStyle(color: isDarkMode ? Colors.white54 : Colors.grey[500]),
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredReactors.length,
                        itemBuilder: (context, index) {
                          final entry = filteredReactors[index];
                          final userId = entry.key;
                          final reactionStr = entry.value;

                          ReactionType type = ReactionType.like;
                          try {
                            type = ReactionType.values.firstWhere((r) => r.name == reactionStr);
                          } catch (_) {}

                          return FutureBuilder<Map<String, dynamic>?>(
                            future: _getUserData(userId),
                            builder: (context, userSnapshot) {
                              final userData = userSnapshot.data;
                              final userName = userData?['fullname'] ?? 'User';
                              final userPhoto = userData?['photoUrl'] ?? '';
                              final searchId = userData?['searchId'] ?? '';

                              // Filter by search query if typing
                              if (_searchQuery.isNotEmpty &&
                                  !userName.toLowerCase().contains(_searchQuery) &&
                                  !searchId.toLowerCase().contains(_searchQuery)) {
                                return const SizedBox.shrink();
                              }

                              return Material(
                                color: Colors.transparent,
                                child: ListTile(
                                  onTap: () => _navigateToProfile(userId, userName: userName, userPhoto: userPhoto),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  leading: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      CachedCircleAvatar(
                                        imageUrl: userPhoto,
                                        radius: 22,
                                      ),
                                      Positioned(
                                        right: -2,
                                        bottom: -2,
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: BoxDecoration(
                                            color: _getReactionBgColor(type),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: isDarkMode ? const Color(0xFF161622) : Colors.white,
                                              width: 1.5,
                                            ),
                                          ),
                                          child: Text(
                                            type.emoji,
                                            style: const TextStyle(fontSize: 10),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  title: Text(
                                    userName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: isDarkMode ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  subtitle: searchId.isNotEmpty
                                      ? Text(
                                          'ID: $searchId',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDarkMode ? Colors.white54 : Colors.grey[600],
                                          ),
                                        )
                                      : null,
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDarkMode,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blue
              : (isDarkMode ? Colors.white10 : Colors.grey[200]),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? Colors.white
                  : (isDarkMode ? Colors.white70 : Colors.black87),
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

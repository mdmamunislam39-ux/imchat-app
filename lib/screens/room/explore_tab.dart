import 'package:flutter/material.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/banner_carousel.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chat_messenger/models/audio_room_v2.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/audio_room_screen.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/bloc/audio_rooms_bloc.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/repository/audio_rooms_repository.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';

class ExploreTabContent extends StatefulWidget {
  const ExploreTabContent({super.key});

  @override
  State<ExploreTabContent> createState() => _ExploreTabContentState();
}

class _ExploreTabContentState extends State<ExploreTabContent> {
  String _selectedCategory = 'All';

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _selectedCategory == 'All',
      onPopInvoked: (bool didPop) {
        if (didPop) return;
        setState(() {
          _selectedCategory = 'All';
        });
      },
      child: SingleChildScrollView(
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Carousel from Admin Panel
          const BannerCarousel(),

          // --- Trending Events ---
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Trending Events',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(
            height: 180, // Height for horizontal cards
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 4, // Example count
              itemBuilder: (context, index) {
                return _buildTrendingEventCard(
                  title: 'ভালো বাসার ময়না', // Example Bengali title
                  subtitle: 'Live',
                  imageColor: Colors.blueGrey, // Placeholder color
                );
              },
            ),
          ),
          const Divider(height: 30, thickness: 8, color: Colors.grey), // Separator

          // --- Ranking Section ---
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Ranking',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(child: _buildRankingCard('Popular Rooms', Colors.orange, '2')),
                const SizedBox(width: 10),
                Expanded(child: _buildRankingCard('Top Gifters', Colors.blue, '2')),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildRankingCard('Popular Users', Colors.purple, '2'),
          ),
          const Divider(height: 30, thickness: 8, color: Colors.grey), // Separator

          // --- Channel Rank ---
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Channel Rank',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Tap to view all rankings',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildChannelRankIcon(),
                _buildChannelRankIcon(),
                _buildChannelRankIcon(),
              ],
            ),
          ),
          const Divider(height: 30, thickness: 8, color: Colors.grey), // Separator

          // --- Recommended Room Categories ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 0, 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recommended Room',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios, size: 18),
                  onPressed: () {},
                ),
              ],
            ),
          ),
          SizedBox(
            height: 40, // Height for category pills
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              children: ['All', 'Party', 'লাইভ', 'কাপল', 'ইসলামী', 'সংগীত', 'বিষয়', 'imo Sho'].map((category) {
                return _CategoryPill(
                  text: category,
                  isSelected: _selectedCategory == category,
                  onTap: () {
                    setState(() {
                      _selectedCategory = category;
                    });
                  },
                );
              }).toList(),
            ),
          ),
          // --- Recommended Room List ---
          if (_selectedCategory == 'All' || _selectedCategory == 'Party' || _selectedCategory == 'Live' || _selectedCategory == 'লাইভ')
            Column(
              children: [
                if (_selectedCategory == 'All' || _selectedCategory == 'Party') ...[
                  _buildRecommendedRoomCard(
                    imageColor: Colors.red[200]!,
                    title: 'কম দামে কালো 🌳 গাছ 🌳',
                    participants: '92',
                    description: 'পার্টিতে লাগলে যোগাযোগ ...',
                    tags: ['PK'],
                    users: 3, // Number of user circles
                  ),
                  _buildRecommendedRoomCard(
                    imageColor: Colors.green[200]!,
                    title: 'ইসলামিক ইভেন্ট সম্পর্কে',
                    participants: '49',
                    description: 'জানতে এখনি জয়েন করুন।।',
                    tags: ['আপনার বন্ধু ফলোয়ার'],
                    users: 2,
                  ),
                ],
                if (_selectedCategory == 'All' || _selectedCategory == 'Live' || _selectedCategory == 'লাইভ') ...[
                  StreamBuilder<QuerySnapshot>(
                    stream: _selectedCategory == 'All'
                        ? FirebaseFirestore.instance
                            .collection('audio_rooms_v2')
                            .where('isActive', isEqualTo: true)
                            .snapshots()
                        : FirebaseFirestore.instance
                            .collection('audio_rooms_v2')
                            .where('category', isEqualTo: 'Live')
                            .where('isActive', isEqualTo: true)
                            .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
                      }
                      
                      final docs = snapshot.data?.docs ?? [];
                      final currentUser = AuthController.instance.currentUser;
                      
                      // Check if current user has an active live room
                      final bool hasActiveLiveRoom = docs.any((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return data['creatorId'] == currentUser.userId;
                      });
                      
                      List<Widget> roomWidgets = [];
                      
                      // If user has no active live room, show Create button
                      if (!hasActiveLiveRoom) {
                        roomWidgets.add(
                          _buildLiveRoomGridCard(
                            title: 'Start Live Video',
                            imageUrl: currentUser.photoUrl,
                            creatorName: 'Create yours now',
                            creatorAvatar: currentUser.photoUrl,
                            viewersCount: 0,
                            onTap: () async {
                               // Show loading
                               Get.dialog(const Center(child: CircularProgressIndicator()), barrierDismissible: false);
                               try {
                                 final repository = AudioRoomsRepository();
                                 
                                 // Check if user already has an active room to prevent duplicates
                                 final existingQuery = await FirebaseFirestore.instance
                                     .collection('audio_rooms_v2')
                                     .where('creatorId', isEqualTo: currentUser.userId)
                                     .where('isActive', isEqualTo: true)
                                     .limit(1)
                                     .get();
                                     
                                 if (existingQuery.docs.isNotEmpty) {
                                   Get.back(); // close loading
                                   final existingRoom = AudioRoomV2.fromFirestore(existingQuery.docs.first);
                                   Get.to(() => AudioRoomScreen(
                                     room: existingRoom,
                                     audioRoomsBloc: AudioRoomsBloc(repository: repository),
                                   ));
                                   return;
                                 }

                                 final newRoom = await repository.createRoom(
                                   name: '${currentUser.fullname}\'s Live',
                                   description: 'Welcome to my live stream!',
                                   creatorId: currentUser.userId,
                                   creatorName: currentUser.fullname,
                                   creatorImageUrl: currentUser.photoUrl,
                                   category: 'Live',
                                 );
                                 
                                 Get.back(); // close loading
                                 Get.to(() => AudioRoomScreen(
                                   room: newRoom,
                                   audioRoomsBloc: AudioRoomsBloc(repository: repository),
                                 ));
                               } catch (e) {
                                 Get.back();
                                 Get.snackbar('Error', 'Failed to create live room: $e', backgroundColor: Colors.red, colorText: Colors.white);
                               }
                            },
                          )
                        );
                      }
                      
                      // Add actual live rooms
                      for (var doc in docs) {
                         final roomV2 = AudioRoomV2.fromFirestore(doc);
                         
                         roomWidgets.add(
                           _buildLiveRoomGridCard(
                             title: roomV2.name,
                             imageUrl: roomV2.imageUrl ?? '',
                             creatorName: roomV2.creatorName,
                             creatorAvatar: roomV2.creatorImageUrl ?? '',
                             viewersCount: roomV2.participants.length,
                             onTap: () {
                                Get.to(() => AudioRoomScreen(
                                  room: roomV2,
                                  audioRoomsBloc: AudioRoomsBloc(repository: AudioRoomsRepository()),
                                ));
                             }
                           )
                         );
                      }
                      
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.85,
                        ),
                        itemCount: roomWidgets.length,
                        itemBuilder: (context, index) {
                          return roomWidgets[index];
                        },
                      );
                    }
                  ),
                ],
                // Add more cards as needed
              ],
            )
          else
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Center(
                child: Text(
                  'No rooms available for $_selectedCategory',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            ),
          const SizedBox(height: 20), // Padding at the bottom
        ],
      ),
    ));
  }

  Widget _buildTrendingEventCard({
    required String title,
    required String subtitle,
    required Color imageColor,
  }) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(left: 16.0, right: 8.0),
      child: Card(
        clipBehavior: Clip.antiAlias, // For rounded corners on image
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        elevation: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 100,
              color: imageColor, // Placeholder for image
              child: const Center(
                child: Icon(Icons.live_tv, color: Colors.white, size: 40),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.red[600],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
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

  Widget _buildRankingCard(String title, Color color, String count) {
    return Container(
      height: 150, // Fixed height for ranking cards
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: color,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  count,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Placeholder for ranking items (e.g., user avatars and names)
          Expanded(
            child: ListView.builder(
              physics: const NeverScrollableScrollPhysics(), // Disable scrolling
              itemCount: 2, // Example ranking items
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.grey[300],
                        child: const Icon(Icons.person, size: 14, color: Colors.grey),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'User Name ${index + 1}',
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelRankIcon() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Center(
        child: Icon(Icons.mic_none, size: 30, color: Colors.grey),
      ),
    );
  }

  Widget _buildRecommendedRoomCard({
    required Color imageColor,
    required String title,
    required String participants,
    required String description,
    required List<String> tags,
    required int users,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: imageColor, // Placeholder for room image
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Icon(Icons.group, color: Colors.white, size: 40),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '‧‧‧ $participants',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6.0,
                    runSpacing: 4.0,
                    children: tags.map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  // User thumbnails
                  Row(
                    children: List.generate(users, (index) {
                      return Align(
                        widthFactor: 0.7, // Overlap effect
                        child: CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.grey[300],
                          child: const Icon(Icons.person, size: 14, color: Colors.grey),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }

  Widget _buildLiveRoomGridCard({
    required String title,
    required String imageUrl,
    required String creatorName,
    required String creatorAvatar,
    required int viewersCount,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          color: Colors.grey[800],
          image: imageUrl.isNotEmpty
              ? DecorationImage(
                  image: NetworkImage(imageUrl),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: Stack(
          children: [
            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.1),
                    Colors.black.withValues(alpha: 0.0),
                    Colors.black.withValues(alpha: 0.6),
                  ],
                ),
              ),
            ),
            // Top Left: LIVE badge
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'LIVE',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            // Top Right: Viewers count
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.group, color: Colors.white, size: 10),
                    const SizedBox(width: 4),
                    Text(
                      '$viewersCount',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
            // Bottom Info
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 8,
                        backgroundColor: Colors.grey,
                        backgroundImage: creatorAvatar.isNotEmpty ? NetworkImage(creatorAvatar) : null,
                        child: creatorAvatar.isEmpty ? const Icon(Icons.person, size: 10, color: Colors.white) : null,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          creatorName,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
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

class _CategoryPill extends StatelessWidget {
  final String text;
  final bool isSelected;
  final VoidCallback? onTap;

  const _CategoryPill({
    required this.text,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? Border.all(color: Colors.blue) : null,
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
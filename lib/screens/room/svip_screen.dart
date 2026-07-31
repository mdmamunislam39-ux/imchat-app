import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:chat_messenger/models/user.dart' as model;
import 'package:chat_messenger/components/cached_circle_avatar.dart';
import 'package:flutter_svga/flutter_svga.dart';
import 'package:chat_messenger/api/official_team_api.dart';

class SvipScreen extends StatefulWidget {
  final model.User currentUser;
  const SvipScreen({super.key, required this.currentUser});

  @override
  State<SvipScreen> createState() => _SvipScreenState();
}

class _SvipScreenState extends State<SvipScreen> with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  List<Map<String, dynamic>> _vipLevels = [];
  final Map<String, bool> _claimedStatus = {};

  int _currentMonthlyRecharge = 0;
  TabController? _tabController;
  StreamSubscription<DocumentSnapshot>? _userSubscription;

  @override
  void initState() {
    super.initState();
    _checkMonthlyReset(widget.currentUser.monthlyRechargeAmount, widget.currentUser.lastRechargeMonth);
    _listenToUserUpdates();
    _loadVipConfigs();
  }

  void _listenToUserUpdates() {
    _userSubscription = _firestore.collection('Users').doc(widget.currentUser.userId).snapshots().listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data()!;
        final int monthlyAmount = (data['monthlyRechargeAmount'] ?? 0) is int 
            ? data['monthlyRechargeAmount'] as int 
            : (data['monthlyRechargeAmount'] as num?)?.toInt() ?? 0;
        final String lastMonth = data['lastRechargeMonth'] as String? ?? '';
        
        if (mounted) {
          setState(() {
            _checkMonthlyReset(monthlyAmount, lastMonth);
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    _tabController?.dispose();
    super.dispose();
  }

  void _checkMonthlyReset(int amount, String? lastMonth) {
    final now = DateTime.now();
    final currentMonth = "${now.year}-${now.month.toString().padLeft(2, '0')}";

    if (lastMonth == currentMonth) {
      _currentMonthlyRecharge = amount;
    } else {
      _currentMonthlyRecharge = 0;
    }
  }

  Future<void> _loadVipConfigs() async {
    try {
      final snapshot = await _firestore
          .collection('config')
          .doc('svip_levels')
          .collection('levels')
          .get();

      final levels = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id; // vip1, vip2...
        return data;
      }).toList();

      levels.sort((a, b) {
        final aNum = int.tryParse((a['id'] as String).replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        final bNum = int.tryParse((b['id'] as String).replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        return aNum.compareTo(bNum);
      });

      // Load claimed status for current month
      final now = DateTime.now();
      final currentMonth = "${now.year}-${now.month.toString().padLeft(2, '0')}";

      final claimSnapshot = await _firestore
          .collection('Users')
          .doc(widget.currentUser.userId)
          .collection('claimed_svips')
          .doc(currentMonth)
          .get();

      if (claimSnapshot.exists) {
        final data = claimSnapshot.data()!;
        for (var lvl in levels) {
          _claimedStatus[lvl['id']] = data[lvl['id']] == true;
        }
      } else {
        for (var lvl in levels) {
          _claimedStatus[lvl['id']] = false;
        }
      }

      setState(() {
        _vipLevels = levels;
        _tabController = TabController(length: _vipLevels.length, vsync: this);
        
        // Try to set initial tab to the user's active level or next target
        int targetIndex = 0;
        for (int i = 0; i < _vipLevels.length; i++) {
          final rawTarget = _vipLevels[i]['rechargeTarget'];
          final target = rawTarget is int ? rawTarget : (rawTarget is double ? rawTarget.toInt() : (int.tryParse(rawTarget?.toString() ?? '0') ?? 0));
          if (_currentMonthlyRecharge < target) {
            targetIndex = i;
            break;
          }
        }
        final lastRawTarget = _vipLevels.last['rechargeTarget'];
        final lastTarget = lastRawTarget is int ? lastRawTarget : (lastRawTarget is double ? lastRawTarget.toInt() : (int.tryParse(lastRawTarget?.toString() ?? '0') ?? 0));
        if (targetIndex == 0 && _vipLevels.isNotEmpty && _currentMonthlyRecharge >= lastTarget) {
           targetIndex = _vipLevels.length - 1;
        }
        _tabController!.index = targetIndex;
        
        int currentIndex = _tabController!.index;
        _tabController!.addListener(() {
          if (_tabController!.index != currentIndex) {
            currentIndex = _tabController!.index;
            setState(() {}); // Rebuild only when tab index officially changes
          }
        });

        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading SVIP configs: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _claimReward() async {
    if (_tabController == null || _vipLevels.isEmpty) return;
    
    final selectedLevel = _vipLevels[_tabController!.index];
    final levelId = selectedLevel['id'] as String;
    final levelNum = int.tryParse(levelId.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
    final rawTarget = selectedLevel['rechargeTarget'];
    final target = rawTarget is int ? rawTarget : (rawTarget is double ? rawTarget.toInt() : (int.tryParse(rawTarget?.toString() ?? '0') ?? 0));

    if (_currentMonthlyRecharge < target) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Target not reached! Recharge more to level up.'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_claimedStatus[levelId] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Already claimed for this month!'), backgroundColor: Colors.orange),
      );
      return;
    }

    try {
      final now = DateTime.now();
      final currentMonth = "${now.year}-${now.month.toString().padLeft(2, '0')}";

      await _firestore
          .collection('Users')
          .doc(widget.currentUser.userId)
          .collection('claimed_svips')
          .doc(currentMonth)
          .set({levelId: true}, SetOptions(merge: true));

      final userRef = _firestore.collection('Users').doc(widget.currentUser.userId);

      await _firestore.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        final userData = userDoc.data() ?? {};

        int currentActiveLevel = userData['activeSvipLevel'] ?? 0;
        if (levelNum > currentActiveLevel) {
          transaction.update(userRef, {
            'activeSvipLevel': levelNum,
            'svipValidUntilMonth': currentMonth,
          });
        }

        Map<String, dynamic> custData = userData['customization'] ?? {};

        void addAssetToInventory(String listKey, String url) {
          if (url.isNotEmpty) {
            List<String> currentList = List<String>.from(custData[listKey] ?? []);
            if (!currentList.contains(url)) {
              currentList.add(url);
              custData[listKey] = currentList;
            }
          }
        }

        addAssetToInventory('ownedBadges', (selectedLevel['badgeMediaUrl']?.toString() ?? '').isNotEmpty ? selectedLevel['badgeMediaUrl'] : selectedLevel['badgeUrl'] ?? '');
        addAssetToInventory('ownedFrames', (selectedLevel['frameMediaUrl']?.toString() ?? '').isNotEmpty ? selectedLevel['frameMediaUrl'] : selectedLevel['frameUrl'] ?? '');
        addAssetToInventory('ownedEntryEffects', (selectedLevel['entryEffectMediaUrl']?.toString() ?? '').isNotEmpty ? selectedLevel['entryEffectMediaUrl'] : selectedLevel['entryEffectUrl'] ?? '');
        addAssetToInventory('ownedBackgroundThemes', (selectedLevel['profileSkinMediaUrl']?.toString() ?? '').isNotEmpty ? selectedLevel['profileSkinMediaUrl'] : selectedLevel['profileSkinUrl'] ?? '');
        addAssetToInventory('ownedNameplates', (selectedLevel['nameplateMediaUrl']?.toString() ?? '').isNotEmpty ? selectedLevel['nameplateMediaUrl'] : selectedLevel['nameplateUrl'] ?? '');

        transaction.update(userRef, {'customization': custData});
      });

      // Send imChat Team Notification about SVIP level claim
      try {
        await OfficialTeamApi.sendOfficialMessage(
          receiverId: widget.currentUser.userId,
          receiverDeviceToken: widget.currentUser.deviceToken,
          messageText: "🎉 Congratulations! You have successfully claimed rewards for SVIP level ${levelId.toUpperCase()}. SVIP rewards (Frames, Entry Effects, and Background Skins) have been unlocked and added to your profile/room customization settings!",
        );
      } catch (e) {
        debugPrint('⚠️ SvipScreen: Error sending notification: $e');
      }

      setState(() {
        _claimedStatus[levelId] = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('${levelId.toUpperCase()} Claimed Successfully!'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint('Error claiming SVIP reward: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to claim: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'imChat ',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
                fontSize: 22,
                fontFamily: 'Inter',
              ),
            ),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
              ).createShader(bounds),
              child: const Text(
                'VIP',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  fontSize: 22,
                  letterSpacing: 1.2,
                  fontFamily: 'Inter',
                ),
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Color(0xFFFFD700)),
            onPressed: () {
              // Help info
            },
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF3D0C5A), // Deep Magenta/Purple top
              Color(0xFF1E0234), // Darker mid
              Color(0xFF120020), // Almost black bottom
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)))
            : _vipLevels.isEmpty
                ? const Center(child: Text('No SVIP configs found', style: TextStyle(color: Colors.white)))
                : Column(
                    children: [
                      SizedBox(height: MediaQuery.of(context).padding.top + kToolbarHeight),
                      
                      // Custom Tab Bar
                      _buildTabBar(),
                      
                      // Main Content Scrollable Area
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              // Large SVIP Badge Image
                              _buildMainBadgeDisplay(),
                              
                              // SVIP Identification Section (Grid)
                              _buildSectionTitle('VIP Identification', '9/9'),
                              _buildRewardsGrid(),
                              
                              const SizedBox(height: 20),
                              
                              // Exclusive Privileges Section
                              _buildSectionTitle('Exclusive Privileges', '18/25'),
                              _buildPrivilegesGrid(),
                              
                              // Bottom padding for the sticky footer
                              const SizedBox(height: 120),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
      
      // Sticky Bottom Bar
      bottomSheet: _isLoading || _vipLevels.isEmpty ? null : _buildStickyBottomBar(),
    );
  }

  Widget _buildTabBar() {
    return Container(
      height: 45,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: const Color(0xFFFFD700),
        indicatorWeight: 3,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white54,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 15),
        tabs: _vipLevels.map((lvl) {
          String levelName = lvl['id'].toString().toUpperCase(); // e.g., VIP1 -> VIP 1
          if (levelName.startsWith('VIP') && levelName.length > 3) {
            levelName = 'VIP ${levelName.substring(3)}';
          } else if (levelName.startsWith('SVIP') && levelName.length > 4) {
            levelName = 'VIP ${levelName.substring(4)}';
          }
          return Tab(text: levelName);
        }).toList(),
      ),
    );
  }

  Widget _buildMainBadgeDisplay() {
    if (_tabController == null || _vipLevels.isEmpty) return const SizedBox();
    
    final selectedLevel = _vipLevels[_tabController!.index];
    final badgeUrl = selectedLevel['badgeUrl'] as String? ?? '';
    
    return Container(
      width: double.infinity,
      height: 300,
      margin: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      decoration: BoxDecoration(
        // The background hanging banner graphic look
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF6A0DAD).withValues(alpha: 0.8),
            const Color(0xFF3D0C5A).withValues(alpha: 0.9),
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(50),
          bottomRight: Radius.circular(50),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withValues(alpha: 0.2),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
        border: Border(
          bottom: BorderSide(color: const Color(0xFFFFD700).withValues(alpha: 0.5), width: 3),
          left: BorderSide(color: const Color(0xFFFFD700).withValues(alpha: 0.5), width: 2),
          right: BorderSide(color: const Color(0xFFFFD700).withValues(alpha: 0.5), width: 2),
        ),
      ),
      child: Center(
        child: _buildMediaPreview(
          (selectedLevel['badgeMediaUrl']?.toString() ?? '').isNotEmpty 
              ? selectedLevel['badgeMediaUrl'].toString() 
              : badgeUrl,
          width: 200,
          height: 200,
        ),
      ),
    );
  }
  
  Widget _buildMediaPreview(String url, {double width = 200, double height = 200}) {
    if (url.isEmpty) return _buildFallbackBadge();
    
    if (url.toLowerCase().contains('.svga')) {
      return SizedBox(
        width: width,
        height: height,
        child: SVGAEasyPlayer(resUrl: url),
      );
    } else if (url.toLowerCase().contains('.mp4')) {
      // For MP4 without full player integration, fallback to placeholder
      return Container(
        width: width,
        height: height,
        color: Colors.black26,
        child: const Center(child: Icon(Icons.video_file, color: Colors.white, size: 40)),
      );
    } else {
      return Image.network(
        url,
        width: width,
        height: height,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _buildFallbackBadge(),
      );
    }
  }
  
  Widget _buildFallbackBadge() {
    return Container(
      width: 150,
      height: 150,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.amber,
        boxShadow: [
          BoxShadow(color: Colors.amberAccent, blurRadius: 20, spreadRadius: 5)
        ]
      ),
      child: const Icon(Icons.stars_rounded, size: 100, color: Colors.white),
    );
  }

  Widget _buildSectionTitle(String title, String countText) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/images/wing_left.png', width: 30, errorBuilder: (_,__,___) => const Icon(Icons.eco, color: Colors.amber, size: 16)),
          const SizedBox(width: 8),
          Column(
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              Text(
                countText,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Image.asset('assets/images/wing_right.png', width: 30, errorBuilder: (_,__,___) => const Icon(Icons.eco, color: Colors.amber, size: 16)),
        ],
      ),
    );
  }

  Widget _buildRewardsGrid() {
    if (_tabController == null || _vipLevels.isEmpty) return const SizedBox();
    
    final selectedLevel = _vipLevels[_tabController!.index];
    
    final List<Map<String, dynamic>> gridItems = [
      {'title': 'SVIP Tag', 'url': selectedLevel['nameplateUrl']?.toString() ?? '', 'mediaUrl': selectedLevel['nameplateMediaUrl']?.toString() ?? ''},
      {'title': 'SVIP Badge', 'url': selectedLevel['badgeUrl']?.toString() ?? '', 'mediaUrl': selectedLevel['badgeMediaUrl']?.toString() ?? ''},
      {'title': 'Entry Tag', 'url': selectedLevel['entryEffectUrl']?.toString() ?? '', 'mediaUrl': selectedLevel['entryEffectMediaUrl']?.toString() ?? ''},
      {'title': 'Profile Card', 'url': selectedLevel['profileSkinUrl']?.toString() ?? '', 'mediaUrl': selectedLevel['profileSkinMediaUrl']?.toString() ?? ''},
      {'title': 'SVIP Frame', 'url': selectedLevel['frameUrl']?.toString() ?? '', 'mediaUrl': selectedLevel['frameMediaUrl']?.toString() ?? ''},
      {'title': 'SVIP Chat Bubble', 'url': '', 'mediaUrl': ''}, // Dummy
      {'title': 'Mic Voice Wave', 'url': '', 'mediaUrl': ''},     // Dummy
      {'title': 'Entrance Effect', 'url': '', 'mediaUrl': ''},    // Dummy
      {'title': 'Room Theme', 'url': '', 'mediaUrl': ''},         // Dummy
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: gridItems.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 1.05,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemBuilder: (context, index) {
          return _buildGridCard(
            gridItems[index]['title'] as String, 
            gridItems[index]['url'] as String, 
            gridItems[index]['mediaUrl'] as String
          );
        },
      ),
    );
  }

  Widget _buildPrivilegesGrid() {
    final List<Map<String, String>> privItems = [
      {'title': 'Upgrade notification', 'icon': 'rocket'},
      {'title': 'Visitors', 'icon': 'group'},
      {'title': 'SVIP Gifts', 'icon': 'card_giftcard'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: privItems.map((item) {
          IconData iconData = Icons.star;
          if (item['icon'] == 'rocket') iconData = Icons.rocket_launch;
          if (item['icon'] == 'group') iconData = Icons.people;
          if (item['icon'] == 'card_giftcard') iconData = Icons.card_giftcard;
          
          return Column(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF531E7A), Color(0xFF280B42)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.3)),
                ),
                child: Center(
                  child: Icon(iconData, color: Colors.white, size: 28),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 80,
                child: Text(
                  item['title']!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGridCard(String title, String imageUrl, String mediaUrl) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2E004F), // dark purple
            Color(0xFF4A0080), // darker purple
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.8), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8A2BE2).withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Play icon at top right
          if (mediaUrl.isNotEmpty)
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () => _showMediaPreviewDialog(mediaUrl),
                child: const Icon(Icons.play_circle_fill, color: Colors.white, size: 20),
              ),
            )
          else
            const Positioned(
              top: 4,
              right: 4,
              child: Icon(Icons.play_circle_fill, color: Colors.white30, size: 16),
            ),
          
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Center(
                  child: imageUrl.isNotEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(Icons.image, color: Colors.white30, size: 40),
                          ),
                        )
                      : const Icon(Icons.auto_awesome, color: Colors.white30, size: 40), // Placeholder
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(14),
                    bottomRight: Radius.circular(14),
                  ),
                ),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showMediaPreviewDialog(String mediaUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          children: [
            _buildMediaPreview(mediaUrl, width: 300, height: 300),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStickyBottomBar() {
    if (_tabController == null || _vipLevels.isEmpty) return const SizedBox();
    
    final selectedLevel = _vipLevels[_tabController!.index];
    final rawTarget = selectedLevel['rechargeTarget'];
    final target = rawTarget is int ? rawTarget : (rawTarget is double ? rawTarget.toInt() : (int.tryParse(rawTarget?.toString() ?? '0') ?? 0));
    final levelId = selectedLevel['id'] as String;
    String levelName = levelId.toUpperCase();
    if (levelName.startsWith('VIP') && levelName.length > 3) {
      levelName = 'VIP ${levelName.substring(3)}';
    } else if (levelName.startsWith('SVIP') && levelName.length > 4) {
      levelName = 'VIP ${levelName.substring(4)}';
    }
    
    final bool isUnlocked = _currentMonthlyRecharge >= target;
    final bool isClaimed = _claimedStatus[levelId] == true;
    
    // Format large numbers
    String formatPoints(int p) {
      if (p >= 1000000) return '${(p / 1000000).toStringAsFixed(1)}M';
      if (p >= 1000) return '${(p / 1000).toStringAsFixed(1)}k';
      return p.toString();
    }
    
    String progressText = '${formatPoints(_currentMonthlyRecharge)}/${formatPoints(target)}';
    double progressRatio = target == 0 ? 1.0 : (_currentMonthlyRecharge / target).clamp(0.0, 1.0);

    return Container(
      height: 100,
      decoration: const BoxDecoration(
        color: Color(0xFF1E0234),
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar
          CachedCircleAvatar(
            imageUrl: widget.currentUser.photoUrl,
            radius: 24,
            userId: widget.currentUser.userId,
            isOnline: true,
          ),
          const SizedBox(width: 12),
          
          // Texts and progress
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.currentUser.activeSvipLevel > 0 
                      ? 'You are VIP ${widget.currentUser.activeSvipLevel}' 
                      : 'You are not a VIP yet',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  'Total Recharge (1st-30th): $_currentMonthlyRecharge 💎',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        isUnlocked 
                            ? 'Target reached for VIP ${levelName.replaceAll(RegExp(r'[^0-9]'), '')}!' 
                            : 'Need ${target - _currentMonthlyRecharge} more for VIP ${levelName.replaceAll(RegExp(r'[^0-9]'), '')}',
                        style: const TextStyle(color: Colors.white54, fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      progressText,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progressRatio,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Level Up / Claim Button
          GestureDetector(
            onTap: isClaimed ? null : () => _claimReward(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isClaimed 
                      ? [Colors.grey[700]!, Colors.grey[800]!]
                      : (isUnlocked 
                          ? [const Color(0xFFFFE259), const Color(0xFFFFA751)]
                          : [const Color(0xFF4A4A4A), const Color(0xFF2D2D2D)]),
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: isUnlocked && !isClaimed ? [
                  BoxShadow(
                    color: const Color(0xFFFFA751).withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ] : null,
              ),
              child: Text(
                isClaimed ? 'Claimed' : (isUnlocked ? 'Claim' : 'Level Up'),
                style: TextStyle(
                  color: isUnlocked && !isClaimed ? Colors.black : Colors.white54,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

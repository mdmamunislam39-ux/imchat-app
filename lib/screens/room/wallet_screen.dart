// Enhanced wallet screen with Firebase integration
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chat_messenger/helpers/app_helper.dart';
import 'package:chat_messenger/components/dynamic_diamond_icon.dart';
import 'package:chat_messenger/components/dynamic_bean_icon.dart';
import 'package:chat_messenger/components/cached_circle_avatar.dart';
import 'package:chat_messenger/helpers/nameplate_helper.dart';
import 'package:chat_messenger/config/theme_config.dart';
import 'dart:async';
import 'package:chat_messenger/models/user.dart';
import 'package:chat_messenger/screens/room/roomprofile_screen.dart';
import 'package:chat_messenger/screens/profile/invite_screen.dart';
import 'package:chat_messenger/screens/room/seller_list_screen.dart';
import 'package:chat_messenger/services/wallet_service.dart';
import 'package:chat_messenger/services/gift_economy_service.dart';
import 'package:chat_messenger/services/store_service.dart';
import 'package:chat_messenger/screens/room/store_screen.dart';
import 'package:chat_messenger/screens/room/svip_screen.dart';
import 'package:chat_messenger/screens/room/level_screen.dart';
import 'package:chat_messenger/screens/room/badge_screen.dart';
import 'package:chat_messenger/screens/room/agency_screen.dart';
import 'package:chat_messenger/screens/room/earnings_screen.dart';
import 'package:chat_messenger/screens/room/family_screen.dart';
import 'package:chat_messenger/screens/room/diamond_seller_screen.dart';
import 'package:chat_messenger/screens/room/my_items_screen.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/game_wall_bottom_sheet.dart';
import 'package:chat_messenger/screens/room/feedback_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chat_messenger/screens/room/role_dashboard_screen.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/services/role_service.dart';
import 'package:chat_messenger/components/universal_asset_widget.dart';

// মূল ওয়ালেট স্ক্রিন
class UserWalletScreen extends StatefulWidget {
  final User currentUser;
  const UserWalletScreen({super.key, required this.currentUser});

  @override
  State<UserWalletScreen> createState() => _UserWalletScreenState();
}

class _UserWalletScreenState extends State<UserWalletScreen> {
  // Services
  final WalletService _walletService = WalletService();
  final StoreService _storeService = StoreService();

  // State variables
  User? _currentUser;
  bool _isLoading = true;
  String _errorMessage = '';
  String? _currentFrameUrl;
  String _userRole = 'user';
  StreamSubscription<DocumentSnapshot>? _roleSubscription;

  @override
  void initState() {
    super.initState();
    // Guarantee global RoleService is listening to the user's role and super admin permissions in real-time
    RoleService.instance.listenToUserRole(widget.currentUser.userId);
    _listenToUserRole();
    _loadUserData();
  }

  Future<String?>? _vip1BadgeFuture;

  Future<String?> _fetchVip1BadgeUrl() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('config')
          .doc('svip_levels')
          .collection('levels')
          .get();
      if (snapshot.docs.isNotEmpty) {
        final levels = snapshot.docs.map((doc) => doc.data()).toList();
        
        levels.sort((a, b) {
          final aReq = int.tryParse(a['requiredRechargeAmount']?.toString() ?? '0') ?? 0;
          final bReq = int.tryParse(b['requiredRechargeAmount']?.toString() ?? '0') ?? 0;
          return aReq.compareTo(bReq);
        });
        
        final data = levels.first;
        if (data['badgeMediaUrl'] != null && data['badgeMediaUrl'].toString().isNotEmpty) {
          return data['badgeMediaUrl'].toString();
        } else if (data['badgeUrl'] != null && data['badgeUrl'].toString().isNotEmpty) {
          return data['badgeUrl'].toString();
        }
      }
    } catch (e) {
      debugPrint('Failed to load VIP 1 badge: $e');
    }
    return null;
  }

  @override
  void dispose() {
    _roleSubscription?.cancel();
    super.dispose();
  }

  void _listenToUserRole() {
    _roleSubscription?.cancel();
    // Listen to Users/{userId} for real-time balances, roles, and customizations
    _roleSubscription = FirebaseFirestore.instance
        .collection('Users')
        .doc(widget.currentUser.userId)
        .snapshots()
        .listen((userSnapshot) {
      if (mounted) {
        if (userSnapshot.exists && userSnapshot.data() != null) {
          final data = userSnapshot.data()!;
          final updatedUser = User.fromMap(data);
          
          final oldFrameId = _currentUser?.customization?.selectedFrameId;
          
          setState(() {
            _currentUser = updatedUser;
            _isLoading = false;
          });

          // Reload equipped frame if it has changed
          if (updatedUser.customization?.selectedFrameId != oldFrameId) {
            _loadFrame();
          }

          // Parse role fields from Users document
          if (data.containsKey('role')) {
            final role = data['role'] ?? 'user';
            final roleActive = data['roleActive'] ?? true;
            final dashboardAccess = data['dashboardAccess'] ?? true;

            setState(() {
              if (roleActive && dashboardAccess) {
                _userRole = role;
              } else {
                _userRole = 'user';
              }
            });
            debugPrint('🔑 Realtime role updated from Users document: $_userRole');
            return;
          }
        }

        // Fallback: Listen to user_roles/{userId} for roles
        FirebaseFirestore.instance
            .collection('user_roles')
            .doc(widget.currentUser.userId)
            .get()
            .then((roleSnapshot) {
          if (mounted && roleSnapshot.exists && roleSnapshot.data() != null) {
            final data = roleSnapshot.data()!;
            final isActive = data['isActive'] ?? data['roleActive'] ?? true;
            setState(() {
              if (isActive) {
                _userRole = data['role'] ?? 'user';
              } else {
                _userRole = 'user';
              }
            });
            debugPrint('🔑 Realtime role updated from user_roles document: $_userRole');
          }
        });
      }
    }, onError: (error) {
      debugPrint('Error listening to user document: $error');
    });
  }

  // Load user data from Firebase
  Future<void> _loadUserData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      debugPrint('💰 Loading user wallet data...');

      // Get user wallet data
      final userData =
          await _walletService.getUserWallet(widget.currentUser.userId);

      if (userData != null) {
        setState(() {
          _currentUser = userData;
        });
      } else {
        // Use current user data if wallet data not found
        setState(() {
          _currentUser = widget.currentUser;
        });
      }

      setState(() {
        _isLoading = false;
      });

      debugPrint('💰 User wallet data loaded successfully');

      // Load frame after user data is ready
      _loadFrame();
    } catch (e) {
      debugPrint('❌ Error loading user data: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load wallet data: $e';
      });
    }
  }

  // Load equipped frame
  Future<void> _loadFrame() async {
    final user = _currentUser ?? widget.currentUser;
    if (user.customization?.selectedFrameId != null) {
      try {
        final frameDetails = await _storeService
            .getStoreItemDetails(user.customization!.selectedFrameId!);
        if (frameDetails != null) {
          setState(() {
            _currentFrameUrl = frameDetails['fileUrl'] ??
                frameDetails['thumbnailUrl'] ??
                frameDetails['imageUrl'] ??
                frameDetails['image'];
          });
        }
      } catch (e) {
        debugPrint('❌ Error loading frame: $e');
      }
    } else {
      setState(() {
        _currentFrameUrl = null;
      });
    }
  }

  // Refresh user data
  Future<void> _refreshUserData() async {
    await _loadUserData();
  }

  // Navigate to diamond recharge page
  void _navigateToDiamondRechargePage() async {
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DiamondRechargePage(
            userId: _currentUser?.userId ?? widget.currentUser.userId,
            diamondBalance: _currentUser?.diamonds ?? widget.currentUser.diamonds,
            walletService: _walletService,
              ),
        ),
      );

      if (result != null && result is int) {
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..removeCurrentSnackBar()
            ..showSnackBar(SnackBar(
              content: Text('$result diamonds added successfully!'),
              backgroundColor: Colors.green,
            ));
        }
      }
    } catch (e) {
      debugPrint('❌ Error in diamond recharge: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ));
      }
    }
  }

  // Navigate to bean management page
  void _navigateToBeanManagementPage() async {
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BeanManagementPage(
            userData: _currentUser!,
            walletService: _walletService,
          ),
        ),
      );

      if (result != null && result is User) {
        setState(() {
          _currentUser = result;
        });
      }
    } catch (e) {
      debugPrint('❌ Error in bean management: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ));
      }
    }
  }

  // Handle menu item clicks with proper navigation
  void _handleMenuClick(String title) async {
    try {
      switch (title) {
        case 'Store':
          await _navigateToStore();
          break;
        case 'My Level':
          await _navigateToLevelScreen();
          break;
        case 'Badge':
          await _navigateToBadgeScreen();
          break;
        case 'Agency':
        case 'Agency Manager':
          await _navigateToAgencyScreen();
          break;
        case 'Task Earnings':
          await _navigateToEarningsScreen();
          break;
        case 'Family':
          await _navigateToFamilyScreen();
          break;
        case 'Diamondseller':
          await _navigateToDiamondSellerScreen();
          break;
        case 'Offline Seller':
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SellerListScreen(requestedAmount: 0),
            ),
          );
          break;
        case 'My Items':
          await _navigateToMyItemsScreen();
          break;
        case 'Game Wall':
          GameWallBottomSheet.show(context);
          break;
        case 'Admin Dashboard':
        case 'BD Dashboard':
          await Navigator.push(context, MaterialPageRoute(builder: (_) => RoleDashboardScreen(currentUser: _currentUser ?? widget.currentUser)));
          break;
        case 'Invite':
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const InviteScreen()));
          break;
        case 'Help':
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const FeedbackScreen()));
          break;
        default:
          ScaffoldMessenger.of(context)
            ..removeCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text('$title feature coming soon!')),
            );
      }
    } catch (e) {
      debugPrint('❌ Error handling menu click: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
      }
    }
  }

  // Navigation methods
  Future<void> _navigateToStore() async {
    try {
      final user = _currentUser ?? widget.currentUser;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => StoreScreen(
            currentUser: user,
            walletService: _walletService,
            storeService: _storeService,
          ),
        ),
      );

      // Refresh user data after returning from store
      await _refreshUserData();
    } catch (e) {
      debugPrint('❌ Error navigating to store: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Error opening store: $e'),
              backgroundColor: Colors.red,
            ),
          );
      }
    }
  }

  Future<void> _navigateToLevelScreen() async {
    try {
      final user = _currentUser ?? widget.currentUser;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LevelScreen(currentUser: user),
        ),
      );

      // Refresh user data after returning from level screen
      await _refreshUserData();
    } catch (e) {
      debugPrint('❌ Error navigating to level screen: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Error opening level screen: $e'),
              backgroundColor: Colors.red,
            ),
          );
      }
    }
  }

  Future<void> _navigateToBadgeScreen() async {
    try {
      final user = _currentUser ?? widget.currentUser;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BadgeScreen(currentUser: user),
        ),
      );

      // Refresh user data after returning from badge screen
      await _refreshUserData();
    } catch (e) {
      debugPrint('❌ Error navigating to badge screen: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Error opening badge screen: $e'),
              backgroundColor: Colors.red,
            ),
          );
      }
    }
  }

  Future<void> _navigateToAgencyScreen() async {
    try {
      final user = _currentUser ?? widget.currentUser;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AgencyScreen(currentUser: user),
        ),
      );

      // Refresh user data after returning
      await _refreshUserData();
    } catch (e) {
      debugPrint('❌ Error navigating to agency screen: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Error opening agency screen: $e'),
              backgroundColor: Colors.red,
            ),
          );
      }
    }
  }

  Future<void> _navigateToEarningsScreen() async {
    try {
      final user = _currentUser ?? widget.currentUser;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EarningsScreen(currentUser: user),
        ),
      );

      // Refresh user data after returning from earnings screen
      await _refreshUserData();
    } catch (e) {
      debugPrint('❌ Error navigating to earnings screen: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Error opening earnings screen: $e'),
              backgroundColor: Colors.red,
            ),
          );
      }
    }
  }

  Future<void> _navigateToFamilyScreen() async {
    try {
      final user = _currentUser ?? widget.currentUser;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FamilyScreen(currentUser: user),
        ),
      );

      // Refresh user data after returning from family screen
      await _refreshUserData();
    } catch (e) {
      debugPrint('❌ Error navigating to family screen: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Error opening family screen: $e'),
              backgroundColor: Colors.red,
            ),
          );
      }
    }
  }

  Future<void> _navigateToDiamondSellerScreen() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(widget.currentUser.userId)
          .get();

      if (userDoc.exists) {
        final user = User.fromMap(userDoc.data()!);
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DiamondSellerScreen(currentUser: user),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error navigating to diamond seller screen: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening diamond seller: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _navigateToMyItemsScreen() async {
    try {
      final user = _currentUser ?? widget.currentUser;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MyItemsScreen(
            currentUser: user,
            storeService: _storeService,
            walletService: _walletService,
          ),
        ),
      );

      await _refreshUserData();
    } catch (e) {
      debugPrint('❌ Error navigating to my items screen: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Error opening my items: $e'),
              backgroundColor: Colors.red,
            ),
          );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white.withValues(alpha: 0.9),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        backgroundColor: Colors.white.withValues(alpha: 0.9),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _refreshUserData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final user = _currentUser ?? widget.currentUser;

    return Scaffold(
      backgroundColor: Colors.white.withValues(alpha: 0.9),
      body: RefreshIndicator(
        onRefresh: _refreshUserData,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 220.0,
              backgroundColor: Colors.white,
              flexibleSpace: FlexibleSpaceBar(
                background: _buildProfileHeader(user),
              ),
            ),
            SliverToBoxAdapter(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  _buildSvipBanner(),
                  const SizedBox(height: 10),
                  _buildMyAccountSection(),
                  const SizedBox(height: 10),
                  _buildMainMenu2(),
                  const SizedBox(height: 20),
                  _buildMainMenu()
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRealTimeProfileStat({
    required String label,
    required Stream<QuerySnapshot> stream,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (context, snapshot) {
          final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
          return Column(
            children: [
              Text(
                count.toString(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          );
        },
      ),
    );
  }

  // প্রোফাইলের উপরের অংশ
  Widget _buildProfileHeader(User user) {
    final bool isMe = user.userId == AuthController.instance.currentUser.userId;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => ProfilePageForRoom(
                            userID: user.userId,
                            userName: user.fullname,
                            userImage: user.photoUrl)));
              },
              child: Row(
                children: [
                  CachedCircleAvatar(
                    radius: 30,
                    iconSize: 40,
                    borderColor: primaryColor,
                    backgroundColor: primaryColor,
                    imageUrl: user.photoUrl,
                    frameUrl: _currentFrameUrl,
                    frameScale: 1.3,
                  ),
                  const SizedBox(width: 15),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullname.formattedUsername,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: Colors.black),
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () async {
                          await Clipboard.setData(ClipboardData(text: user.searchId));
                          if (!mounted) return;
                          final overlay = Overlay.of(context);
                          final entry = OverlayEntry(
                            builder: (ctx) => Positioned(
                              top: MediaQuery.of(context).size.height * 0.42,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Material(
                                  color: Colors.transparent,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.75),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.check_circle, color: Colors.greenAccent, size: 16),
                                        const SizedBox(width: 8),
                                        Text(
                                          'ID ${user.searchId} copied!',
                                          style: const TextStyle(color: Colors.white, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                          overlay.insert(entry);
                          await Future.delayed(const Duration(seconds: 2));
                          entry.remove();
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'ID : ${user.searchId}',
                              style: const TextStyle(color: Colors.grey, fontSize: 14),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.copy_rounded, size: 13, color: Colors.grey),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      _buildLevelBadgesRow(user),
                    ],
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_ios, color: Colors.grey),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildRealTimeProfileStat(
                  label: 'Friends',
                  stream: FirebaseFirestore.instance.collection('Users/${user.userId}/Contacts').snapshots(),
                  onTap: isMe
                      ? () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SocialUsersListPage(
                                userId: user.userId,
                                listType: 'Friends',
                              ),
                            ),
                          )
                      : null,
                ),
                Container(
                  height: 30,
                  width: 1,
                  color: Colors.grey.shade300,
                ),
                _buildRealTimeProfileStat(
                  label: 'Following',
                  stream: FirebaseFirestore.instance.collection('Users/${user.userId}/following').snapshots(),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SocialUsersListPage(
                        userId: user.userId,
                        listType: 'Following',
                      ),
                    ),
                  ),
                ),
                Container(
                  height: 30,
                  width: 1,
                  color: Colors.grey.shade300,
                ),
                _buildRealTimeProfileStat(
                  label: 'Followers',
                  stream: FirebaseFirestore.instance.collection('Users/${user.userId}/followers').snapshots(),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SocialUsersListPage(
                        userId: user.userId,
                        listType: 'Followers',
                      ),
                    ),
                  ),
                ),
                Container(
                  height: 30,
                  width: 1,
                  color: Colors.grey.shade300,
                ),
                _buildRealTimeProfileStat(
                  label: 'Visitor',
                  stream: FirebaseFirestore.instance.collection('Users/${user.userId}/visitors').snapshots(),
                  onTap: isMe
                      ? () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SocialUsersListPage(
                                userId: user.userId,
                                listType: 'Visitor',
                              ),
                            ),
                          )
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelBadgesRow(User user) {
    return Row(
      children: [
        if (user.sendingLevel != null)
          _buildSingleLevelBadge('sending_config', user.sendingLevel!.level),
        if (user.sendingLevel != null && user.receivingLevel != null)
          const SizedBox(width: 8),
        if (user.receivingLevel != null)
          _buildSingleLevelBadge('receiving_config', user.receivingLevel!.level),
        if (user.customization?.selectedNameplateId != null && user.customization!.selectedNameplateId!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: FutureBuilder<String?>(
              future: NameplateHelper.getNameplateUrl(user.customization!.selectedNameplateId),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                  return CachedNetworkImage(
                    imageUrl: snapshot.data!,
                    height: 20,
                    fit: BoxFit.contain,
                  );
                }
                return const SizedBox(height: 20);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildSingleLevelBadge(String configDoc, int levelNumber) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('level_configurations').doc(configDoc).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox(height: 18);
        final data = snapshot.data!.data() as Map<String, dynamic>?;
        if (data == null || data['levels'] == null) return const SizedBox(height: 18);
        
        final levels = List<Map<String, dynamic>>.from(data['levels']);
        String? imageUrl;
        for (final lvl in levels) {
          if (lvl['levelNumber']?.toString() == levelNumber.toString()) {
            imageUrl = lvl['imageUrl'] as String?;
            break;
          }
        }
        
        if (imageUrl == null || imageUrl.isEmpty) return const SizedBox(height: 18);
        
        return CachedNetworkImage(
          imageUrl: imageUrl,
          height: 18,
          fit: BoxFit.contain,
        );
      },
    );
  }



  // SVIP ব্যানার
  Widget _buildSvipBanner() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SvipScreen(currentUser: _currentUser ?? widget.currentUser),
          ),
        ).then((_) {
          // Refresh user data if they claimed something
          _refreshUserData();
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF3B1A54), Color(0xFF180A2B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.6), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD700).withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Text(
              'imChat VIP',
              style: TextStyle(
                color: Color(0xFFFFD700),
                fontWeight: FontWeight.w900,
                fontSize: 18,
                fontStyle: FontStyle.italic,
                letterSpacing: 1.2,
                shadows: [
                  Shadow(
                    color: Colors.black54,
                    offset: Offset(1, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '|',
              style: TextStyle(color: const Color(0xFFFFD700).withValues(alpha: 0.5), fontSize: 16),
            ),
            const SizedBox(width: 10),
            const Text(
              'Total of 15 privileges',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            FutureBuilder<String?>(
              future: _vip1BadgeFuture ??= _fetchVip1BadgeUrl(),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                  return Transform.translate(
                    offset: const Offset(-5, 0),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: Transform.scale(
                        scale: 4.0,
                        child: UniversalAssetWidget(
                          url: snapshot.data!,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  );
                }
                return const Icon(Icons.shield, color: Color(0xFFFFD700), size: 24);
              },
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_forward_ios, color: Color(0xFFFFD700), size: 16),
          ],
        ),
      ),
    );
  }

  // "My Account" section with real data
  Widget _buildMyAccountSection() {
    final user = _currentUser ?? widget.currentUser;
    final diamonds = user.diamonds;
    final totalDiamonds = user.totalDiamonds;
    final beans = user.beans;

    debugPrint('💰 [WalletScreen] Displaying balances:');
    debugPrint('   Diamonds: $diamonds');
    debugPrint('   Total Diamonds: $totalDiamonds');
    debugPrint('   Beans: $beans');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Diamonds section - Spendable balance (labeled as Diamonds per request)
          _buildBalanceItem(
            iconWidget: const Center(child: DynamicDiamondIcon(width: 35, height: 35)),
            textColor: Colors.pink,
            label: 'Diamonds',
            balance: diamonds,
            onTap: _navigateToDiamondRechargePage,
          ),
          const SizedBox(
            height: 50,
            child: VerticalDivider(color: Colors.grey),
          ),
          // Beans section - Earned balance (labeled as Beans)
          _buildBalanceItem(
            iconWidget: const DynamicBeanIcon(width: 55, height: 55),
            textColor: Colors.orange,
            label: 'Beans',
            balance: beans,
            onTap: _navigateToBeanManagementPage,
          ),
        ],
      ),
    );
  }

  // ব্যালেন্স আইটেম
  Widget _buildBalanceItem({
    required Widget iconWidget,
    required Color textColor,
    required String label,
    required int balance,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          SizedBox(
            height: 55,
            width: 55,
            child: iconWidget,
          ),
          SizedBox(
            width: 5,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                balance.toString(),
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(label, style: TextStyle(color: textColor, fontSize: 12)),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: textColor,
                  )
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // প্রধান মেন্যু
  Widget _buildMainMenu() {
    return Obx(() {
      final roleService = RoleService.instance;
      
      final menuItems = [
        {
          'icon': Icons.diamond,
          'title': 'Diamondseller',
          'color': Colors.amberAccent
        },
        {'icon': Icons.person_add, 'title': 'Invite', 'color': Colors.yellow},
        {
          'icon': Icons.wifi_off,
          'title': 'Offline Seller',
          'color': Colors.lightBlue
        },
        {'icon': Icons.settings, 'title': 'Setting', 'color': Colors.lightBlue},
        {'icon': Icons.help_outline, 'title': 'Help', 'color': Colors.yellow},
        {
          'icon': Icons.info,
          'title': 'About',
          'color': const Color.fromARGB(255, 158, 171, 158)
        },
      ];

      debugPrint('🔍 [WalletScreen] Role: ${roleService.userRole.value}, SuperAdmin: ${roleService.isSuperAdmin.value}, isBD: ${roleService.isBD}');
      if (roleService.userRole.value == AppRoles.admin || roleService.isSuperAdmin.value) {
        menuItems.insert(0, {'icon': Icons.admin_panel_settings, 'title': 'Admin Dashboard', 'color': Colors.purple});
      } else if (roleService.isBD) {
        menuItems.insert(0, {'icon': Icons.business_center, 'title': 'BD Dashboard', 'color': Colors.orange});
      }

      return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.all(8),
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 10,
          // mainAxisSpacing: 20,
        ),
        itemCount: menuItems.length,
        itemBuilder: (context, index) {
          final item = menuItems[index];
          return GestureDetector(
            onTap: () => _handleMenuClick(item['title'] as String),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(item['icon'] as IconData,
                    color: item['color'] as Color, size: 30),
                const SizedBox(height: 8),
                Text(
                  item['title'] as String,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          );
        },
      ),
      );
    });
  }

  Widget _buildMainMenu2() {
    return Obx(() {
      final roleService = RoleService.instance;
      final checkRole = roleService.isAgency; // Evaluated unconditionally to register GetX dependency
      final user = _currentUser ?? widget.currentUser;
      final isAgency = user.isAgency || checkRole;

      final menuItems = [
        {'icon': 'assets/images/my_level.png', 'title': 'My Level'},
        {'icon': 'assets/images/store.png', 'title': 'Store'},
        {'icon': 'assets/images/bedge.png', 'title': 'Badge'},
        {'icon': 'assets/images/store.png', 'title': 'My Items'},
        {'icon': 'assets/images/family.png', 'title': 'Family'},
        if (isAgency)
          {'icon': 'assets/images/agency.png', 'title': 'Agency Manager'},
        {'icon': 'assets/images/diamond_icon.png', 'title': 'Task Earnings'},
        {'icon': 'assets/images/game_icon.png', 'title': 'Game Wall'},
      ];

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: GridView.builder(
          shrinkWrap: true,
          padding: const EdgeInsets.all(8),
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 10,
            childAspectRatio: 0.9,
          ),
          itemCount: menuItems.length,
          itemBuilder: (context, index) {
            final item = menuItems[index];
            return GestureDetector(
              onTap: () => _handleMenuClick(item['title'] as String),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  item['icon']! == 'assets/images/diamond_icon.png'
                      ? const DynamicDiamondIcon(height: 48, width: 48)
                      : Image.asset(
                          item['icon']!,
                          fit: BoxFit.contain,
                          height: 48,
                          width: 48,
                        ),
                  const SizedBox(height: 4),
                  Text(
                    item['title'] as String,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          },
        ),
      );
    });
  }

}

// Diamond recharge page with Firebase integration
class DiamondRechargePage extends StatefulWidget {
  final int diamondBalance;
  final WalletService walletService;
  final String userId;

  const DiamondRechargePage({
    super.key,
    required this.diamondBalance,
    required this.walletService,
    required this.userId,
  });

  @override
  State<DiamondRechargePage> createState() => _DiamondRechargePageState();
}

class _DiamondRechargePageState extends State<DiamondRechargePage> {
  late int _currentDiamondBalance;
  int _selectedDiamondAmount =
      0; // To keep track of the selected amount for the button

  final List<Map<String, dynamic>> diamondPackages = [
    {'diamonds': 5000, 'bdt': 150},
    {'diamonds': 25000, 'bdt': 700},
    {'diamonds': 50000, 'bdt': 1400},
    {'diamonds': 90000, 'bdt': 2500},
  ];

  @override
  void initState() {
    super.initState();
    _currentDiamondBalance = widget.diamondBalance;
    if (diamondPackages.isNotEmpty) {
      _selectedDiamondAmount =
          diamondPackages[0]['bdt']; // Set default selected amount
    }
  }

  void _handleRecharge(BuildContext context) async {
    if (_selectedDiamondAmount == 0) {
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Please select a diamond package.')),
        );
      return;
    }

    try {
      final selectedPackage = diamondPackages
          .firstWhere((pkg) => pkg['bdt'] == _selectedDiamondAmount);
      final diamondsToAdd = selectedPackage['diamonds'] as int;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SellerListScreen(requestedAmount: diamondsToAdd),
        ),
      );
    } catch (e) {
      debugPrint('❌ Error routing to seller list: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recharge'),
        backgroundColor: Colors.white, // Changed background to white
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        titleTextStyle: const TextStyle(
            color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Details clicked')),
              );
            },
            child: const Text('Details', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            color: Colors.white,
            child: Column(
              children: [
                DynamicDiamondIcon(height: 60, width: 60), // Placeholder for diamond icon
                const SizedBox(height: 10),
                const Text('Balance',
                    style: TextStyle(color: Colors.grey, fontSize: 16)),
                const SizedBox(height: 5),
                Text(
                  _currentDiamondBalance.toString(),
                  style: const TextStyle(
                      color: Colors.black,
                      fontSize: 36,
                      fontWeight: FontWeight.bold),
                ),
                const Text('Diamonds',
                    style: TextStyle(color: Colors.black, fontSize: 16)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: const DecorationImage(
                image: NetworkImage(
                    'https://via.placeholder.com/300x80/9C27B0/FFFFFF?text=WEEKLY+RECHARGE+BENEFIT'), // Placeholder image
                fit: BoxFit.cover,
              ),
            ),
            child: const SizedBox(
                height: 50), // Adjust height as needed for banner image
          ),
          const SizedBox(height: 20),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                childAspectRatio: 2.5, // Adjust as needed
              ),
              itemCount: diamondPackages.length,
              itemBuilder: (context, index) {
                final pkg = diamondPackages[index];
                final isSelected = _selectedDiamondAmount == pkg['bdt'];
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDiamondAmount = pkg['bdt'];
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? Colors.pink : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withAlpha(25),
                          spreadRadius: 1,
                          blurRadius: 3,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.diamond,
                                color: Colors.pink, size: 20),
                            const SizedBox(width: 5),
                            Text(
                              pkg['diamonds'].toString(),
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'BDT ${pkg['bdt'].toStringAsFixed(2)}',
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () => _handleRecharge(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25)),
              ),
              child: Text(
                'Recharge BDT ${_selectedDiamondAmount.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

// Bean management page with Firebase integration
class BeanManagementPage extends StatefulWidget {
  final User userData;
  final WalletService walletService;

  const BeanManagementPage({
    super.key,
    required this.userData,
    required this.walletService,
  });

  @override
  State<BeanManagementPage> createState() => _BeanManagementPageState();
}

class _BeanManagementPageState extends State<BeanManagementPage> {
  late User _userData;
  final bool _isLoading = false;
  List<Map<String, dynamic>> _withdrawals = [];

  @override
  void initState() {
    super.initState();
    _userData = widget.userData;
    _loadConfigAndWithdrawals();
  }

  Future<void> _loadConfigAndWithdrawals() async {
    final history = await GiftEconomyService.instance
        .getUserWithdrawals(_userData.userId);

    if (mounted) {
      setState(() {
        _withdrawals = history;
      });
    }
  }

  void _showWithdrawBottomSheet() {
    final amountController = TextEditingController();
    final accountController = TextEditingController();
    final noteController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Withdraw Beans',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              Text('Available: ${_userData.beans} beans',
                  style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 15),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount (beans)',
                  hintText: 'Minimum 10,000',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: accountController,
                decoration: InputDecoration(
                  labelText: 'Account Number',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                decoration: InputDecoration(
                  labelText: 'Note (optional)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => _submitWithdrawal(
                    ctx,
                    amountController.text,
                    accountController.text,
                    noteController.text,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25)),
                  ),
                  child: const Text('Submit Withdrawal',
                      style: TextStyle(fontSize: 16, color: Colors.white)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submitWithdrawal(
    BuildContext ctx,
    String amountStr,
    String accountNumber,
    String note,
  ) async {
    // Capture navigator before any await to avoid async BuildContext issues
    final navigator = Navigator.of(ctx);
    final amount = int.tryParse(amountStr) ?? 0;

    if (amount < 10000) {
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Minimum withdrawal is 10,000 beans.'),
            backgroundColor: Colors.orange,
          ),
        );
      return;
    }

    if (amount > _userData.beans) {
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Insufficient beans.'),
            backgroundColor: Colors.red,
          ),
        );
      return;
    }

    if (accountNumber.trim().isEmpty) {
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Please enter an account number.'),
            backgroundColor: Colors.orange,
          ),
        );
      return;
    }

    // Check no pending withdrawal
    final canWithdraw = await GiftEconomyService.instance
        .canUserWithdraw(_userData.userId);
    if (!canWithdraw) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                  'You already have a pending withdrawal. Please wait for it to be processed.'),
              backgroundColor: Colors.orange,
            ),
          );
      }
      return;
    }

    try {
      await GiftEconomyService.instance.createWithdrawalRequest(
        userId: _userData.userId,
        username: _userData.fullname,
        userType: _userData.userType,
        amount: amount,
        accountNumber: accountNumber.trim(),
        note: note.trim(),
      );

      // Update local state
      setState(() {
        _userData.beans -= amount;
      });

      if (mounted) {
        navigator.pop();
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Withdrawal request submitted!'),
              backgroundColor: Colors.green,
            ),
          );
      }

      // Refresh withdrawal list
      _loadConfigAndWithdrawals();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Withdrawal failed: $e'),
              backgroundColor: Colors.red,
            ),
          );
      }
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  void _showBeansHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            const Text(
              "What's the use of beans?",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "What are Beans?",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              SizedBox(height: 4),
              Text(
                "Beans represent your earnings. You receive Beans when other users send you gifts in Live Streams, Voice Rooms, or Chats.",
                style: TextStyle(color: Colors.black87, fontSize: 13),
              ),
              SizedBox(height: 16),
              Text(
                "How to use Beans?",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              SizedBox(height: 6),
              Text(
                "• Withdraw Cash: You can withdraw your Beans as real cash (minimum 10,000 Beans) via the 'Withdraw' button.\n"
                "• Exchange to Diamonds: Convert your Beans to Diamonds at a direct rate to send gifts, purchase SVIP status, frames, or store items.",
                style: TextStyle(color: Colors.black87, fontSize: 13),
              ),
              SizedBox(height: 16),
              Text(
                "Important Rules:",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              SizedBox(height: 4),
              Text(
                "• Exchanges from Beans to Diamonds are final and cannot be reversed.\n"
                "• Withdrawals are processed according to the official platform processing timeline.",
                style: TextStyle(color: Colors.black87, fontSize: 13),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Beans',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () {
            Navigator.pop(context, _userData);
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GiftReceivedRecordPage(
                    userId: _userData.userId,
                  ),
                ),
              );
            },
            child: const Text(
              'LIVE Record',
              style: TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) Navigator.pop(context, _userData);
        },
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Beans available section (header banner style)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                color: const Color(0xFFF5F7FA),
                child: const Text(
                  'Beans available',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              // Balance display card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                color: Colors.white,
                child: Row(
                  children: [
                    Image.asset(
                      'assets/images/cashout.png',
                      height: 35,
                      width: 35,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _userData.beans.toString(),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Hint text
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'If you receive a gift, you will receive diamonds by rate',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 180), // Space to push buttons down
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    // Withdraw Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _showWithdrawBottomSheet,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF03A9F4),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: const Text(
                          'Withdraw',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    // Exchange to Diamonds Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : () async {
                          final updatedUser = await Navigator.push<User>(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ExchangeBeansPage(
                                userData: _userData,
                                walletService: widget.walletService,
                              ),
                            ),
                          );
                          if (updatedUser != null && mounted) {
                            setState(() {
                              _userData = updatedUser;
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00C853),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: const Text(
                          'Exchange To Diamonds',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),
                    // Help link
                    GestureDetector(
                      onTap: _showBeansHelpDialog,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.help_outline,
                            color: Colors.grey.shade400,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "What's the use of beans?",
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Withdrawal history
              if (_withdrawals.isNotEmpty) ...[
                const SizedBox(height: 40),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Withdrawal History',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _withdrawals.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final w = _withdrawals[index];
                      final status = w['status'] ?? 'pending';
                      final amount = w['amount'] ?? 0;
                      final createdAt = w['createdAt'];
                      String dateStr = '';
                      if (createdAt is Timestamp) {
                        final dt = createdAt.toDate();
                        dateStr = '${dt.day}/${dt.month}/${dt.year}';
                      }
                      return ListTile(
                        tileColor: Colors.transparent,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.monetization_on,
                          color: _statusColor(status),
                        ),
                        title: Text('$amount beans'),
                        subtitle: dateStr.isNotEmpty ? Text(dateStr) : null,
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _statusColor(status).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              color: _statusColor(status),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// Exchange Beans to Diamonds Page based on package selection
class ExchangeBeansPage extends StatefulWidget {
  final User userData;
  final WalletService walletService;

  const ExchangeBeansPage({
    super.key,
    required this.userData,
    required this.walletService,
  });

  @override
  State<ExchangeBeansPage> createState() => _ExchangeBeansPageState();
}

class _ExchangeBeansPageState extends State<ExchangeBeansPage> {
  late User _userData;
  bool _isLoading = false;

  final List<Map<String, int>> exchangePackages = [
    {'diamonds': 1000, 'beans': 1000},
    {'diamonds': 5000, 'beans': 5000},
    {'diamonds': 15100, 'beans': 15000},
    {'diamonds': 60800, 'beans': 60000},
    {'diamonds': 245000, 'beans': 240000},
    {'diamonds': 1225000, 'beans': 1200000},
    {'diamonds': 6125000, 'beans': 6000000},
  ];

  @override
  void initState() {
    super.initState();
    _userData = widget.userData;
  }

  String _formatNumber(int number) {
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    String mathFunc(Match match) => '${match[1]},';
    return number.toString().replaceAllMapped(reg, mathFunc);
  }

  void _handleExchange(Map<String, int> package) async {
    final beansSpent = package['beans']!;
    final diamondsReceived = package['diamonds']!;

    if (_userData.beans < beansSpent) {
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Insufficient Beans to perform this exchange.'),
            backgroundColor: Colors.red,
          ),
        );
      return;
    }

    // Confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Exchange'),
        content: Text(
            'Are you sure you want to exchange ${_formatNumber(beansSpent)} Beans for ${_formatNumber(diamondsReceived)} Diamonds?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Exchange', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      setState(() {
        _isLoading = true;
      });

      await widget.walletService.exchangeBeansForDiamondsPackage(
        userId: _userData.userId,
        beansSpent: beansSpent,
        diamondsReceived: diamondsReceived,
      );

      setState(() {
        _userData.beans -= beansSpent;
        _userData.diamonds += diamondsReceived;
      });

      if (mounted) {
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                  'Successfully exchanged ${_formatNumber(beansSpent)} Beans for ${_formatNumber(diamondsReceived)} Diamonds!'),
              backgroundColor: Colors.green,
            ),
          );
      }
    } catch (e) {
      debugPrint('❌ Error performing exchange: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Exchange failed: $e'),
              backgroundColor: Colors.red,
            ),
          );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) Navigator.pop(context, _userData);
        },
        child: Column(
          children: [
            // Custom Gradient Header
            Container(
              width: double.infinity,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 10,
                bottom: 25,
                left: 10,
                right: 20,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFF8A65), Color(0xFFF4511E)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                children: [
                  // Custom AppBar Row
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                        onPressed: () => Navigator.pop(context, _userData),
                      ),
                      const Text(
                        'Exchange To Diamonds',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  // Current Diamonds balance centered
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      DynamicDiamondIcon(height: 35,
                        width: 35,
                        fit: BoxFit.contain,),
                      const SizedBox(width: 8),
                      Text(
                        _formatNumber(_userData.diamonds),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Grid of Packages
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.9,
                      ),
                      itemCount: exchangePackages.length,
                      itemBuilder: (context, index) {
                        final pkg = exchangePackages[index];
                        final diamonds = pkg['diamonds']!;
                        final beans = pkg['beans']!;
                        return GestureDetector(
                          onTap: () => _handleExchange(pkg),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Diamond Icon
                                DynamicDiamondIcon(height: 28,
                                  width: 28,
                                  fit: BoxFit.contain,),
                                const SizedBox(height: 8),
                                // Diamonds to gain
                                Text(
                                  _formatNumber(diamonds),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                // Cost in Beans
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Image.asset(
                                      'assets/images/cashout.png',
                                      height: 12,
                                      width: 12,
                                      fit: BoxFit.contain,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _formatNumber(beans),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            
            // Footer displaying available Beans
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Beans Available: ',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Image.asset(
                    'assets/images/cashout.png',
                    height: 16,
                    width: 16,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatNumber(_userData.beans),
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
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

// LIVE Record page showing received gifts history for the last 1 month (30 days)
class GiftReceivedRecordPage extends StatefulWidget {
  final String userId;

  const GiftReceivedRecordPage({
    super.key,
    required this.userId,
  });

  @override
  State<GiftReceivedRecordPage> createState() => _GiftReceivedRecordPageState();
}

class _GiftReceivedRecordPageState extends State<GiftReceivedRecordPage> {
  String _formatDateTime(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $hour:$minute $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final oneMonthAgo = DateTime.now().subtract(const Duration(days: 30));

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'Gift Records',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('user_received_gifts')
            .where('receiverId', isEqualTo: widget.userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error loading records: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No gift records found for the last 30 days.',
                style: TextStyle(color: Colors.grey, fontSize: 15),
              ),
            );
          }

          // Parse and filter transactions locally to avoid complex Firestore composite indexes
          final transactions = snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final txId = doc.id;
            final giftName = data['giftName'] ?? 'Gift';
            final giftPngUrl = data['giftPngUrl'] ?? '';
            final senderName = data['senderName'] ?? 'Anonymous';
            final credits = data['credits'] ?? 0;
            
            DateTime dt = DateTime.now();
            if (data['timestamp'] is Timestamp) {
              dt = (data['timestamp'] as Timestamp).toDate();
            } else if (data['timestamp'] is String) {
              dt = DateTime.tryParse(data['timestamp']) ?? DateTime.now();
            }

            return {
              'id': txId,
              'giftName': giftName,
              'giftPngUrl': giftPngUrl,
              'senderName': senderName,
              'credits': credits,
              'timestamp': dt,
            };
          }).where((tx) => (tx['timestamp'] as DateTime).isAfter(oneMonthAgo)).toList();

          if (transactions.isEmpty) {
            return const Center(
              child: Text(
                'No gift records found for the last 30 days.',
                style: TextStyle(color: Colors.grey, fontSize: 15),
              ),
            );
          }

          // Sort descending by timestamp
          transactions.sort((a, b) => (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: transactions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final tx = transactions[index];
              final String giftName = tx['giftName'];
              final String giftPngUrl = tx['giftPngUrl'];
              final String senderName = tx['senderName'];
              final int credits = tx['credits'];
              final DateTime timestamp = tx['timestamp'];

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  clipBehavior: Clip.antiAlias,
                  borderRadius: BorderRadius.circular(12),
                  child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F7FA),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: giftPngUrl.isNotEmpty
                        ? Image.network(
                            giftPngUrl,
                            errorBuilder: (_, __, ___) => Icon(Icons.card_giftcard, color: Colors.orange.shade400, size: 28),
                          )
                        : Icon(Icons.card_giftcard, color: Colors.orange.shade400, size: 28),
                  ),
                  title: Text(
                    giftName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        'From: $senderName',
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDateTime(timestamp),
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                      ),
                    ],
                  ),
                  trailing: Text(
                    '+$credits Beans',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            );
            },
          );
        },
      ),
    );
  }
}

// Social users list page (Friends, Following, Followers, Visitors)
class SocialUsersListPage extends StatefulWidget {
  final String userId;
  final String listType; // 'Friends', 'Following', 'Followers', 'Visitor'

  const SocialUsersListPage({
    super.key,
    required this.userId,
    required this.listType,
  });

  @override
  State<SocialUsersListPage> createState() => _SocialUsersListPageState();
}

class _SocialUsersListPageState extends State<SocialUsersListPage> {
  String _formatDateTime(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $hour:$minute $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final oneMonthAgo = DateTime.now().subtract(const Duration(days: 30));
    
    CollectionReference getCollection() {
      final baseRef = FirebaseFirestore.instance.collection('Users').doc(widget.userId);
      switch (widget.listType) {
        case 'Friends':
          return baseRef.collection('Contacts');
        case 'Following':
          return baseRef.collection('following');
        case 'Followers':
          return baseRef.collection('followers');
        case 'Visitor':
          return baseRef.collection('visitors');
        default:
          return baseRef.collection('Contacts');
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: Text(
          widget.listType == 'Visitor' ? 'Visitors (Last 30 Days)' : widget.listType,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: getCollection().snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                'No ${widget.listType.toLowerCase()} found.',
                style: const TextStyle(color: Colors.grey, fontSize: 15),
              ),
            );
          }

          var docs = snapshot.data!.docs;

          List<Map<String, dynamic>> visitorList = [];
          if (widget.listType == 'Visitor') {
            for (var doc in docs) {
              final data = doc.data() as Map<String, dynamic>;
              DateTime dt = DateTime.now();
              if (data['timestamp'] is Timestamp) {
                dt = (data['timestamp'] as Timestamp).toDate();
              } else if (data['timestamp'] is String) {
                dt = DateTime.tryParse(data['timestamp']) ?? DateTime.now();
              }

              if (dt.isAfter(oneMonthAgo)) {
                visitorList.add({
                  'userId': doc.id,
                  'timestamp': dt,
                });
              }
            }

            if (visitorList.isEmpty) {
              return const Center(
                child: Text(
                  'No visitors in the last 30 days.',
                  style: TextStyle(color: Colors.grey, fontSize: 15),
                ),
              );
            }

            visitorList.sort((a, b) => (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: widget.listType == 'Visitor' ? visitorList.length : docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              String targetUserId;
              String? extraText;

              if (widget.listType == 'Visitor') {
                final visitor = visitorList[index];
                targetUserId = visitor['userId'];
                extraText = _formatDateTime(visitor['timestamp']);
              } else {
                targetUserId = docs[index].id;
              }

              return SocialUserTile(userId: targetUserId, extraText: extraText);
            },
          );
        },
      ),
    );
  }
}

// Social user tile supporting real-time profile loading
class SocialUserTile extends StatelessWidget {
  final String userId;
  final String? extraText;

  const SocialUserTile({
    super.key,
    required this.userId,
    this.extraText,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('Users').doc(userId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final name = data['fullname'] ?? data['name'] ?? 'User';
        final avatarUrl = data['photoUrl'] ?? data['imageUrl'] ?? '';
        final searchId = data['searchId'] ?? '';

        return Material(
          color: Colors.white,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: CircleAvatar(
              radius: 24,
              backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
              child: avatarUrl.isEmpty ? const Icon(Icons.person) : null,
            ),
            title: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black),
            ),
            subtitle: Text(
              'ID: $searchId',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
            trailing: extraText != null
                ? Text(
                    extraText!,
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                  )
                : const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfilePageForRoom(
                    userID: userId,
                    userName: name,
                    userImage: avatarUrl,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

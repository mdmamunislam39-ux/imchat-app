import 'package:chat_messenger/widgets/user_id_badge_widget.dart';
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
import 'package:chat_messenger/services/online_recharge_service.dart';
import 'package:chat_messenger/models/recharge_models.dart';
import 'package:chat_messenger/screens/room/online_recharge_screen.dart';
import 'package:chat_messenger/screens/room/recharge_and_gift_record_screen.dart';
import 'package:chat_messenger/screens/room/withdraw_screen.dart';
import 'package:chat_messenger/services/app_theme_service.dart';

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
  StreamSubscription<DocumentSnapshot>? _configSubscription;

  @override
  void initState() {
    super.initState();
    // Guarantee global RoleService is listening to the user's role and super admin permissions in real-time
    RoleService.instance.listenToUserRole(widget.currentUser.userId);
    _listenToUserRole();
    _listenToEconomyConfig();
    _loadUserData();
  }

  Future<String?>? _vipBadgeFuture;
  Future<String?>? _svipBadgeFuture;

  Future<String?> _fetchVipBadgeUrl() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('config')
          .doc('vip_levels')
          .collection('levels')
          .get();
      if (snapshot.docs.isNotEmpty) {
        final levels = snapshot.docs.map((doc) {
          final d = doc.data();
          d['id'] = doc.id;
          return d;
        }).toList();

        levels.sort((a, b) {
          final aNum =
              int.tryParse(
                (a['id'] as String).replaceAll(RegExp(r'[^0-9]'), ''),
              ) ??
              0;
          final bNum =
              int.tryParse(
                (b['id'] as String).replaceAll(RegExp(r'[^0-9]'), ''),
              ) ??
              0;
          return aNum.compareTo(bNum);
        });

        final data = levels.first;
        if (data['badgeMediaUrl'] != null &&
            data['badgeMediaUrl'].toString().isNotEmpty) {
          return data['badgeMediaUrl'].toString();
        } else if (data['badgeUrl'] != null &&
            data['badgeUrl'].toString().isNotEmpty) {
          return data['badgeUrl'].toString();
        }
      }
    } catch (e) {
      debugPrint('Failed to load VIP badge: $e');
    }
    return null;
  }

  Future<String?> _fetchSvipBadgeUrl() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('config')
          .doc('svip_levels')
          .collection('levels')
          .get();
      if (snapshot.docs.isNotEmpty) {
        final levels = snapshot.docs.map((doc) {
          final d = doc.data();
          d['id'] = doc.id;
          return d;
        }).toList();

        levels.sort((a, b) {
          final aNum =
              int.tryParse(
                (a['id'] as String).replaceAll(RegExp(r'[^0-9]'), ''),
              ) ??
              0;
          final bNum =
              int.tryParse(
                (b['id'] as String).replaceAll(RegExp(r'[^0-9]'), ''),
              ) ??
              0;
          return aNum.compareTo(bNum);
        });

        final data = levels.first;
        if (data['badgeMediaUrl'] != null &&
            data['badgeMediaUrl'].toString().isNotEmpty) {
          return data['badgeMediaUrl'].toString();
        } else if (data['badgeUrl'] != null &&
            data['badgeUrl'].toString().isNotEmpty) {
          return data['badgeUrl'].toString();
        }
      }
    } catch (e) {
      debugPrint('Failed to load SVIP badge: $e');
    }
    return null;
  }

  @override
  void dispose() {
    _roleSubscription?.cancel();
    _configSubscription?.cancel();
    super.dispose();
  }

  void _listenToEconomyConfig() {
    _configSubscription?.cancel();
    _configSubscription = FirebaseFirestore.instance
        .collection('platform_config')
        .doc('gift_conversion')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        GiftEconomyService.instance.getConfig();
        setState(() {});
      }
    });
  }

  void _listenToUserRole() {
    _roleSubscription?.cancel();
    // Listen to Users/{userId} for real-time balances, roles, and customizations
    _roleSubscription = FirebaseFirestore.instance
        .collection('Users')
        .doc(widget.currentUser.userId)
        .snapshots()
        .listen(
          (userSnapshot) {
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
                  debugPrint(
                    '🔑 Realtime role updated from Users document: $_userRole',
                  );
                  return;
                }
              }

              // Fallback: Listen to user_roles/{userId} for roles
              FirebaseFirestore.instance
                  .collection('user_roles')
                  .doc(widget.currentUser.userId)
                  .get()
                  .then((roleSnapshot) {
                    if (mounted &&
                        roleSnapshot.exists &&
                        roleSnapshot.data() != null) {
                      final data = roleSnapshot.data()!;
                      final isActive =
                          data['isActive'] ?? data['roleActive'] ?? true;
                      setState(() {
                        if (isActive) {
                          _userRole = data['role'] ?? 'user';
                        } else {
                          _userRole = 'user';
                        }
                      });
                      debugPrint(
                        '🔑 Realtime role updated from user_roles document: $_userRole',
                      );
                    }
                  });
            }
          },
          onError: (error) {
            debugPrint('Error listening to user document: $error');
          },
        );
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
      final userData = await _walletService.getUserWallet(
        widget.currentUser.userId,
      );

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
        final frameDetails = await _storeService.getStoreItemDetails(
          user.customization!.selectedFrameId!,
        );
        if (frameDetails != null) {
          setState(() {
            _currentFrameUrl =
                frameDetails['fileUrl'] ??
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
            diamondBalance:
                _currentUser?.diamonds ?? widget.currentUser.diamonds,
            walletService: _walletService,
          ),
        ),
      );

      if (result != null && result is int) {
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..removeCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text('$result diamonds added successfully!'),
                backgroundColor: Colors.green,
              ),
            );
        }
      }
    } catch (e) {
      debugPrint('❌ Error in diamond recharge: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
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
          ..showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
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
          await _navigateToAgencyScreen(isHostCentre: false);
          break;
        case 'Host Centre':
        case 'Host Center':
          await _navigateToAgencyScreen(isHostCentre: true);
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
          GameWallBottomSheet.show(context, isInAudioRoom: false);
          break;
        case 'Admin Dashboard':
        case 'BD Dashboard':
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RoleDashboardScreen(
                currentUser: _currentUser ?? widget.currentUser,
              ),
            ),
          );
          break;
        case 'Withdraw':
          if (!GiftEconomyService.instance.isWithdrawalEnabled) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Withdrawal is currently paused for maintenance.'),
                backgroundColor: Colors.orange,
              ),
            );
            break;
          }
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WithdrawScreen(
                currentUser: _currentUser ?? widget.currentUser,
              ),
            ),
          );
          await _refreshUserData();
          break;
        case 'Invite':
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const InviteScreen()),
          );
          break;
        case 'Help':
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FeedbackScreen()),
          );
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
        MaterialPageRoute(builder: (context) => LevelScreen(currentUser: user)),
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
        MaterialPageRoute(builder: (context) => BadgeScreen(currentUser: user)),
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

  Future<void> _navigateToAgencyScreen({bool isHostCentre = false}) async {
    try {
      final user = _currentUser ?? widget.currentUser;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AgencyScreen(
            currentUser: user,
            isHostCentre: isHostCentre,
          ),
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

        // Verify active seller status in sellers collection
        final sellerSnap = await FirebaseFirestore.instance
            .collection('sellers')
            .where('userId', isEqualTo: user.userId)
            .limit(1)
            .get();

        final isSellerDocActive = sellerSnap.docs.isNotEmpty &&
            (sellerSnap.docs.first.data()['isActive'] ?? true) == true;

        if (!isSellerDocActive && user.isSeller != true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('You are not authorized as an active diamond seller.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

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
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDarkMode ? Colors.black : Colors.white.withValues(alpha: 0.9),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        backgroundColor: isDarkMode ? Colors.black : Colors.white.withValues(alpha: 0.9),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                style: TextStyle(
                  fontSize: 16,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
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
      backgroundColor: isDarkMode ? Colors.black : const Color(0xFFF5F5F7),
      body: RefreshIndicator(
        onRefresh: _refreshUserData,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 220.0,
              backgroundColor: isDarkMode ? const Color(0xFF18181C) : Colors.white,
              elevation: 0,
              iconTheme: IconThemeData(
                color: isDarkMode ? Colors.white : Colors.black,
              ),
              systemOverlayStyle: isDarkMode
                  ? SystemUiOverlayStyle.light
                  : SystemUiOverlayStyle.dark,
              flexibleSpace: FlexibleSpaceBar(
                background: _buildProfileHeader(user, isDarkMode),
              ),
            ),
            SliverToBoxAdapter(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  _buildVipAndSvipSection(),
                  const SizedBox(height: 10),
                  _buildMyAccountSection(isDarkMode),
                  const SizedBox(height: 10),
                  _buildMainMenu2(isDarkMode),
                  const SizedBox(height: 20),
                  _buildMainMenu(isDarkMode),
                  const SizedBox(height: 24),
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
    required bool isDarkMode,
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
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isDarkMode ? Colors.white60 : Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // প্রোফাইলের উপরের অংশ
  Widget _buildProfileHeader(User user, bool isDarkMode) {
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
                      userImage: user.photoUrl,
                    ),
                  ),
                );
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
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () async {
                          await Clipboard.setData(
                            ClipboardData(text: user.searchId),
                          );
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
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.75,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.check_circle,
                                          color: Colors.greenAccent,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'ID ${user.searchId} copied!',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                          ),
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
                            UserIdBadgeWidget(
                              searchId: user.searchId,
                              textStyle: TextStyle(
                                color: isDarkMode ? Colors.white70 : Colors.grey,
                                fontSize: 14,
                              ),
                              showCopyIcon: false,
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.copy_rounded,
                              size: 13,
                              color: isDarkMode ? Colors.white70 : Colors.grey,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      _buildLevelBadgesRow(user),
                    ],
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: isDarkMode ? Colors.white54 : Colors.grey,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildRealTimeProfileStat(
                  label: 'Friends'.tr,
                  stream: FirebaseFirestore.instance
                      .collection('Users/${user.userId}/Contacts')
                      .snapshots(),
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
                  isDarkMode: isDarkMode,
                ),
                Container(
                  height: 30,
                  width: 1,
                  color: isDarkMode ? Colors.white24 : Colors.grey.shade300,
                ),
                _buildRealTimeProfileStat(
                  label: 'Following'.tr,
                  stream: FirebaseFirestore.instance
                      .collection('Users/${user.userId}/following')
                      .snapshots(),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SocialUsersListPage(
                        userId: user.userId,
                        listType: 'Following',
                      ),
                    ),
                  ),
                  isDarkMode: isDarkMode,
                ),
                Container(
                  height: 30,
                  width: 1,
                  color: isDarkMode ? Colors.white24 : Colors.grey.shade300,
                ),
                _buildRealTimeProfileStat(
                  label: 'Followers'.tr,
                  stream: FirebaseFirestore.instance
                      .collection('Users/${user.userId}/followers')
                      .snapshots(),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SocialUsersListPage(
                        userId: user.userId,
                        listType: 'Followers',
                      ),
                    ),
                  ),
                  isDarkMode: isDarkMode,
                ),
                Container(
                  height: 30,
                  width: 1,
                  color: isDarkMode ? Colors.white24 : Colors.grey.shade300,
                ),
                _buildRealTimeProfileStat(
                  label: 'Visitor'.tr,
                  stream: FirebaseFirestore.instance
                      .collection('Users/${user.userId}/visitors')
                      .snapshots(),
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
                  isDarkMode: isDarkMode,
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
          _buildSingleLevelBadge(
            'receiving_config',
            user.receivingLevel!.level,
          ),
        if (user.customization?.selectedNameplateId != null &&
            user.customization!.selectedNameplateId!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: FutureBuilder<String?>(
              future: NameplateHelper.getNameplateUrl(
                user.customization!.selectedNameplateId,
              ),
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
      stream: FirebaseFirestore.instance
          .collection('level_configurations')
          .doc(configDoc)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox(height: 18);
        }
        final data = snapshot.data!.data() as Map<String, dynamic>?;
        if (data == null || data['levels'] == null) {
          return const SizedBox(height: 18);
        }

        final levels = List<Map<String, dynamic>>.from(data['levels']);
        String? imageUrl;
        for (final lvl in levels) {
          if (lvl['levelNumber']?.toString() == levelNumber.toString()) {
            imageUrl = lvl['imageUrl'] as String?;
            break;
          }
        }

        if (imageUrl == null || imageUrl.isEmpty) {
          return const SizedBox(height: 18);
        }

        return CachedNetworkImage(
          imageUrl: imageUrl,
          height: 18,
          fit: BoxFit.contain,
        );
      },
    );
  }

  // VIP এবং SVIP সেকশন (পাশাপাশি কার্ড)
  Widget _buildVipAndSvipSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          // VIP কার্ড
          Expanded(
            child: _buildMembershipCard(
              title: 'imChat VIP',
              subtitle: 'Privileges',
              isSvip: false,
              badgeFuture: _vipBadgeFuture ??= _fetchVipBadgeUrl(),
              gradient: const LinearGradient(
                colors: [Color(0xFF281145), Color(0xFF130623)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderColor: const Color(0xFFFFD700).withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(width: 10),
          // SVIP কার্ড
          Expanded(
            child: _buildMembershipCard(
              title: 'imChat SVIP',
              subtitle: '15 Privileges',
              isSvip: true,
              badgeFuture: _svipBadgeFuture ??= _fetchSvipBadgeUrl(),
              gradient: const LinearGradient(
                colors: [Color(0xFF421035), Color(0xFF1B0520)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderColor: const Color(0xFFFF9500).withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembershipCard({
    required String title,
    required String subtitle,
    required bool isSvip,
    required Future<String?> badgeFuture,
    required Gradient gradient,
    required Color borderColor,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SvipScreen(
              currentUser: _currentUser ?? widget.currentUser,
              isSvip: isSvip,
            ),
          ),
        ).then((_) {
          _refreshUserData();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: gradient,
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: borderColor.withValues(alpha: 0.18),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFFFD700),
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      letterSpacing: 0.8,
                      shadows: [
                        Shadow(
                          color: Colors.black54,
                          offset: Offset(1, 1),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Obx(() {
              String? dynamicVipIcon;
              if (Get.isRegistered<AppThemeService>()) {
                final theme = Get.find<AppThemeService>();
                dynamicVipIcon = isSvip
                    ? theme.getWalletIcon('svip_badge')
                    : theme.getWalletIcon('vip_badge');
              }
              if (dynamicVipIcon != null && dynamicVipIcon.isNotEmpty) {
                return SizedBox(
                  width: 28,
                  height: 28,
                  child: Transform.scale(
                    scale: 2.2,
                    child: UniversalAssetWidget(
                      url: dynamicVipIcon,
                      fit: BoxFit.contain,
                    ),
                  ),
                );
              }
              return FutureBuilder<String?>(
                future: badgeFuture,
                builder: (context, snapshot) {
                  if (snapshot.hasData &&
                      snapshot.data != null &&
                      snapshot.data!.isNotEmpty) {
                    return SizedBox(
                      width: 28,
                      height: 28,
                      child: Transform.scale(
                        scale: 2.2,
                        child: UniversalAssetWidget(
                          url: snapshot.data!,
                          fit: BoxFit.contain,
                        ),
                      ),
                    );
                  }
                  return Icon(
                    isSvip ? Icons.workspace_premium : Icons.shield,
                    color: const Color(0xFFFFD700),
                    size: 24,
                  );
                },
              );
            }),
            const SizedBox(width: 2),
            const Icon(
              Icons.arrow_forward_ios,
              color: Color(0xFFFFD700),
              size: 12,
            ),
          ],
        ),
      ),
    );
  }

  // "My Account" section with real data
  Widget _buildMyAccountSection(bool isDarkMode) {
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
        color: isDarkMode ? const Color(0xFF1E1E24) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isDarkMode ? Border.all(color: Colors.white10) : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Diamonds section - Spendable balance (labeled as Diamonds per request)
          _buildBalanceItem(
            iconWidget: const Center(
              child: DynamicDiamondIcon(width: 35, height: 35),
            ),
            textColor: Colors.pink,
            label: 'Diamonds'.tr,
            balance: diamonds,
            onTap: _navigateToDiamondRechargePage,
            isDarkMode: isDarkMode,
          ),
          SizedBox(
            height: 50,
            child: VerticalDivider(
              color: isDarkMode ? Colors.white24 : Colors.grey.shade300,
            ),
          ),
          // Beans section - Earned balance (labeled as Beans)
          _buildBalanceItem(
            iconWidget: const DynamicBeanIcon(width: 55, height: 55),
            textColor: Colors.orange,
            label: 'Beans'.tr,
            balance: beans,
            onTap: _navigateToBeanManagementPage,
            isDarkMode: isDarkMode,
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
    required bool isDarkMode,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          SizedBox(height: 55, width: 55, child: iconWidget),
          const SizedBox(width: 5),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                balance.toString(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(label, style: TextStyle(color: textColor, fontSize: 12)),
                  Icon(Icons.arrow_forward_ios, size: 12, color: textColor),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String? _getWalletMenuCustomIcon(String title) {
    if (!Get.isRegistered<AppThemeService>()) return null;
    final theme = Get.find<AppThemeService>();
    switch (title) {
      case 'My Level':
        return theme.getWalletIcon('my_level');
      case 'Store':
        return theme.getWalletIcon('store');
      case 'Badge':
        return theme.getWalletIcon('badge');
      case 'My Items':
        return theme.getWalletIcon('my_items');
      case 'Family':
        return theme.getWalletIcon('family');
      case 'Agency Manager':
        return theme.getWalletIcon('agency_manager');
      case 'Host Centre':
      case 'Host Center':
        return theme.getWalletIcon('host_centre') ??
            theme.getWalletIcon('host_center') ??
            theme.getWalletIcon('agency_manager');
      case 'Task Earnings':
        return theme.getWalletIcon('task_earnings');
      case 'Game Wall':
        return theme.getWalletIcon('game_wall');
      case 'Admin Dashboard':
        return theme.getWalletIcon('admin_dashboard');
      case 'BD Dashboard':
        return theme.getWalletIcon('bd_dashboard') ??
            theme.getWalletIcon('admin_dashboard');
      case 'Diamondseller':
        return theme.getWalletIcon('diamond_seller');
      case 'Invite':
        return theme.getWalletIcon('invite');
      case 'Offline Seller':
        return theme.getWalletIcon('offline_seller');
      case 'Setting':
        return theme.getWalletIcon('setting');
      case 'Help':
        return theme.getWalletIcon('help');
      case 'About':
        return theme.getWalletIcon('about');
      default:
        return null;
    }
  }

  // প্রধান মেন্যু
  Widget _buildMainMenu(bool isDarkMode) {
    return Obx(() {
      final roleService = RoleService.instance;
      // Also register dependency on AppThemeService walletMenuIcons for real-time reactivity
      if (Get.isRegistered<AppThemeService>()) {
        Get.find<AppThemeService>().walletMenuIcons.length;
      }

      final isSellerActive = roleService.isSellerActive.value;
      final user = _currentUser ?? widget.currentUser;
      final isSeller = isSellerActive || (user.isSeller == true && isSellerActive);

      final menuItems = <Map<String, dynamic>>[
        if (isSeller)
          {
            'icon': Icons.diamond,
            'title': 'Diamondseller',
            'color': Colors.amberAccent,
          },
        {'icon': Icons.person_add, 'title': 'Invite', 'color': Colors.yellow},
        {
          'icon': Icons.wifi_off,
          'title': 'Offline Seller',
          'color': Colors.lightBlue,
        },
        {'icon': Icons.settings, 'title': 'Setting', 'color': Colors.lightBlue},
        {'icon': Icons.help_outline, 'title': 'Help', 'color': Colors.yellow},
        {
          'icon': Icons.info,
          'title': 'About',
          'color': const Color.fromARGB(255, 158, 171, 158),
        },
      ];

      debugPrint(
        '🔍 [WalletScreen] Role: ${roleService.userRole.value}, SuperAdmin: ${roleService.isSuperAdmin.value}, isBD: ${roleService.isBD}, isSeller: $isSeller',
      );
      if (roleService.userRole.value == AppRoles.admin ||
          roleService.isSuperAdmin.value) {
        menuItems.insert(0, {
          'icon': Icons.admin_panel_settings,
          'title': 'Admin Dashboard',
          'color': Colors.purple,
        });
      } else if (roleService.isBD) {
        menuItems.insert(0, {
          'icon': Icons.business_center,
          'title': 'BD Dashboard',
          'color': Colors.orange,
        });
      }

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1E1E24) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isDarkMode ? Border.all(color: Colors.white10) : null,
        ),
        child: GridView.builder(
          shrinkWrap: true,
          padding: const EdgeInsets.all(8),
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 10,
          ),
          itemCount: menuItems.length,
          itemBuilder: (context, index) {
            final item = menuItems[index];
            final customIconUrl =
                _getWalletMenuCustomIcon(item['title'] as String);

            return GestureDetector(
              onTap: () => _handleMenuClick(item['title'] as String),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  customIconUrl != null && customIconUrl.isNotEmpty
                      ? SizedBox(
                          height: 32,
                          width: 32,
                          child: UniversalAssetWidget(
                            url: customIconUrl,
                            fit: BoxFit.contain,
                          ),
                        )
                      : Icon(
                          item['icon'] as IconData,
                          color: item['color'] as Color,
                          size: 30,
                        ),
                  const SizedBox(height: 8),
                  Text(
                    (item['title'] as String).tr,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    });
  }

  Widget _buildMainMenu2(bool isDarkMode) {
    return Obx(() {
      final roleService = RoleService.instance;
      final checkRoleAgency = roleService
          .isAgency; // Evaluated unconditionally to register GetX dependency
      final checkRoleHost = roleService
          .isHost; // Evaluated unconditionally to register GetX dependency
      final user = _currentUser ?? widget.currentUser;
      final isAgency = (user.isAgency == true) ||
          checkRoleAgency ||
          user.roles.contains('agency') ||
          user.userType == 'agency' ||
          user.userType == 'agency_owner';
      final isHost = (user.isHost == true) ||
          checkRoleHost ||
          user.roles.contains('host') ||
          user.userType == 'host';

      // Also register dependency on AppThemeService walletMenuIcons for real-time reactivity
      if (Get.isRegistered<AppThemeService>()) {
        Get.find<AppThemeService>().walletMenuIcons.length;
      }

      final menuItems = [
        {'icon': 'assets/images/my_level.webp', 'title': 'My Level'},
        {'icon': 'assets/images/store.webp', 'title': 'Store'},
        {'icon': 'assets/images/bedge.webp', 'title': 'Badge'},
        {'icon': 'assets/images/store.webp', 'title': 'My Items'},
        {'icon': 'assets/images/family.webp', 'title': 'Family'},
        if (isAgency)
          {'icon': 'assets/images/agency.webp', 'title': 'Agency Manager'},
        if (isHost)
          {'icon': 'assets/images/agency.webp', 'title': 'Host Centre'},
        {'icon': 'assets/images/game_icon.webp', 'title': 'Game Wall'},
      ];

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1E1E24) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isDarkMode ? Border.all(color: Colors.white10) : null,
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
            final customIconUrl =
                _getWalletMenuCustomIcon(item['title'] as String);

            return GestureDetector(
              onTap: () => _handleMenuClick(item['title'] as String),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  customIconUrl != null && customIconUrl.isNotEmpty
                      ? SizedBox(
                          height: 48,
                          width: 48,
                          child: UniversalAssetWidget(
                            url: customIconUrl,
                            fit: BoxFit.contain,
                          ),
                        )
                      : (item['icon']! == 'assets/images/diamond_icon.webp' ||
                              item['icon']! == 'assets/images/diamond_icon.png'
                          ? const DynamicDiamondIcon(height: 48, width: 48)
                          : Image.asset(
                              item['icon']!,
                              fit: BoxFit.contain,
                              height: 48,
                              width: 48,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(
                                    Icons.image_not_supported,
                                    size: 40,
                                    color: Colors.grey,
                                  ),
                            )),
                  const SizedBox(height: 4),
                  Text(
                    (item['title'] as String).tr,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDarkMode ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
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

// Live // Countdown Widget for Weekly Recharge Event
class WeeklyRechargeCountdownWidget extends StatefulWidget {
  final DateTime? endDate;

  const WeeklyRechargeCountdownWidget({super.key, this.endDate});

  @override
  State<WeeklyRechargeCountdownWidget> createState() =>
      _WeeklyRechargeCountdownWidgetState();
}

class _WeeklyRechargeCountdownWidgetState
    extends State<WeeklyRechargeCountdownWidget> {
  late Timer _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _calculateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _calculateRemaining();
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant WeeklyRechargeCountdownWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.endDate != widget.endDate) {
      _calculateRemaining();
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _calculateRemaining() {
    final now = DateTime.now();
    final target = widget.endDate ?? _getNextSundayEnd(now);
    if (target.isBefore(now)) {
      _remaining = Duration.zero;
    } else {
      _remaining = target.difference(now);
    }
  }

  DateTime _getNextSundayEnd(DateTime now) {
    final daysUntilSunday = 7 - now.weekday;
    return DateTime(now.year, now.month, now.day + daysUntilSunday, 23, 59, 59);
  }

  Widget _buildTimePill(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white24, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFFFD700),
              fontWeight: FontWeight.bold,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final days = _remaining.inDays;
    final hours = _remaining.inHours % 24;
    final minutes = _remaining.inMinutes % 60;
    final seconds = _remaining.inSeconds % 60;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.timer_outlined, color: Color(0xFFFFD700), size: 16),
              SizedBox(width: 6),
              Text(
                'Event Ends In:',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Row(
            children: [
              if (days > 0) ...[
                _buildTimePill(days.toString().padLeft(2, '0'), 'd'),
                const SizedBox(width: 4),
              ],
              _buildTimePill(hours.toString().padLeft(2, '0'), 'h'),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  ':',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _buildTimePill(minutes.toString().padLeft(2, '0'), 'm'),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  ':',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _buildTimePill(seconds.toString().padLeft(2, '0'), 's'),
            ],
          ),
        ],
      ),
    );
  }
}

// Diamond recharge page with Firebase integration
class DiamondRechargePage extends StatefulWidget {
  final int diamondBalance;
  final WalletService walletService;
  final String userId;
  final User? currentUser;

  const DiamondRechargePage({
    super.key,
    required this.diamondBalance,
    required this.walletService,
    required this.userId,
    this.currentUser,
  });

  @override
  State<DiamondRechargePage> createState() => _DiamondRechargePageState();
}

class _DiamondRechargePageState extends State<DiamondRechargePage> {
  late int _currentDiamondBalance;
  int _selectedDiamondAmount = 0;
  List<RechargePackageModel> _streamedPackages = [];
  StreamSubscription<DocumentSnapshot>? _diamondSubscription;

  final List<Map<String, dynamic>> fallbackPackages = [
    {'diamonds': 5000, 'bdt': 150, 'bonus': 0},
    {'diamonds': 25000, 'bdt': 700, 'bonus': 0},
    {'diamonds': 50000, 'bdt': 1400, 'bonus': 0},
    {'diamonds': 90000, 'bdt': 2500, 'bonus': 0},
  ];

  @override
  void initState() {
    super.initState();
    _currentDiamondBalance = widget.diamondBalance;
    _listenToRealtimeBalance();
  }

  void _listenToRealtimeBalance() {
    final effectiveUserId = widget.currentUser?.userId.isNotEmpty == true
        ? widget.currentUser!.userId
        : widget.userId;
    if (effectiveUserId.isNotEmpty) {
      _diamondSubscription = FirebaseFirestore.instance
          .collection('Users')
          .doc(effectiveUserId)
          .snapshots()
          .listen((doc) {
        if (doc.exists && mounted) {
          final dia = (doc.data()?['diamonds'] as num?)?.toInt();
          if (dia != null) {
            setState(() {
              _currentDiamondBalance = dia;
            });
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _diamondSubscription?.cancel();
    super.dispose();
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
      int bonusToAdd = 0;
      num bdtPrice = 0;
      final matchedPkg = _streamedPackages
          .where((p) => p.diamondAmount == _selectedDiamondAmount)
          .firstOrNull;
      if (matchedPkg != null) {
        bonusToAdd = matchedPkg.bonusDiamonds;
        bdtPrice = matchedPkg.bdtPrice;
      } else {
        bdtPrice = _selectedDiamondAmount * 0.03;
      }

      final userToPass =
          widget.currentUser ??
          User(
            userId: widget.userId,
            fullname: 'User',
            photoUrl: '',
            searchId: widget.userId,
          );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OnlineRechargeScreen(
            currentUser: userToPass,
            initialAmount: bdtPrice > 0 ? bdtPrice : null,
            initialDiamonds: _selectedDiamondAmount > 0 ? _selectedDiamondAmount : null,
            initialBonusDiamonds: bonusToAdd > 0 ? bonusToAdd : null,
          ),
        ),
      );
    } catch (e) {
      debugPrint('❌ Error routing to online recharge: $e');
    }
  }

  void _showWeeklyRechargeBenefitsModal(BuildContext context) {
    final effectiveUserId = widget.currentUser?.userId.isNotEmpty == true
        ? widget.currentUser!.userId
        : widget.userId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomCtx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.78,
          decoration: const BoxDecoration(
            color: Color(0xFF181024),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 20,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title & Close Button
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF8E24AA), Color(0xFFD81B60)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.card_giftcard_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Weekly Recharge Benefits',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'সাপ্তাহিক রিচার্জ বোনাস রিওয়ার্ডস',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(bottomCtx),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 6),

              // Live Real-Time Reverse Countdown Timer
              StreamBuilder<List<WeeklyRechargeBenefitModel>>(
                stream: OnlineRechargeService.instance
                    .getWeeklyBenefitsStream(),
                builder: (context, snap) {
                  final firstActive = snap.data?.firstOrNull;
                  return WeeklyRechargeCountdownWidget(
                    endDate: firstActive?.endDate,
                  );
                },
              ),

              // User Weekly Recharge Progress Card with Real-time Dynamic Diamond Icon
              StreamBuilder<int>(
                stream: OnlineRechargeService.instance
                    .getUserWeeklyRechargeStream(effectiveUserId),
                builder: (context, userRechargeSnap) {
                  final weeklyRecharge = userRechargeSnap.data ?? 0;

                  return Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF8E24AA).withValues(alpha: 0.25),
                          const Color(0xFFD81B60).withValues(alpha: 0.18),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF8E24AA).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'This Week Recharged',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            Row(
                              children: [
                                const DynamicDiamondIcon(width: 20, height: 20),
                                const SizedBox(width: 6),
                                Text(
                                  '$weeklyRecharge',
                                  style: const TextStyle(
                                    color: Color(0xFFFFD700),
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  'Diamonds',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Recharge diamonds this week to reach targets and unlock exclusive rewards below.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              // Live Benefits List
              Expanded(
                child: StreamBuilder<List<WeeklyRechargeBenefitModel>>(
                  stream: OnlineRechargeService.instance
                      .getWeeklyBenefitsStream(),
                  builder: (context, benefitsSnap) {
                    if (benefitsSnap.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFD81B60),
                        ),
                      );
                    }

                    final benefits = benefitsSnap.data ?? [];
                    if (benefits.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.card_giftcard_outlined,
                              size: 48,
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No weekly benefits active at the moment.',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return StreamBuilder<Set<String>>(
                      stream: OnlineRechargeService.instance
                          .getClaimedBenefitIdsStream(effectiveUserId),
                      builder: (context, claimsSnap) {
                        final claimedIds = claimsSnap.data ?? {};

                        return StreamBuilder<int>(
                          stream: OnlineRechargeService.instance
                              .getUserWeeklyRechargeStream(effectiveUserId),
                          builder: (context, rechargeSnap) {
                            final userRecharged = rechargeSnap.data ?? 0;

                            return ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              itemCount: benefits.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final benefit = benefits[index];
                                final isClaimed = claimedIds.contains(
                                  benefit.id,
                                );
                                final isReached =
                                    userRecharged >= benefit.targetDiamonds;
                                final canClaim = isReached && !isClaimed;

                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF231638),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: canClaim
                                          ? const Color(
                                              0xFFFFD700,
                                            ).withValues(alpha: 0.7)
                                          : isClaimed
                                          ? const Color(
                                              0xFF10B981,
                                            ).withValues(alpha: 0.4)
                                          : Colors.white12,
                                      width: canClaim ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      // Item Thumbnail
                                      Container(
                                        width: 60,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF140A20),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: Colors.white12,
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          child: benefit.itemIcon.isNotEmpty
                                              ? CachedNetworkImage(
                                                  imageUrl: benefit.itemIcon,
                                                  fit: BoxFit.contain,
                                                  placeholder: (_, __) =>
                                                      const Center(
                                                        child: SizedBox(
                                                          width: 16,
                                                          height: 16,
                                                          child:
                                                              CircularProgressIndicator(
                                                                strokeWidth: 2,
                                                              ),
                                                        ),
                                                      ),
                                                  errorWidget: (_, __, ___) =>
                                                      const Icon(
                                                        Icons.auto_awesome,
                                                        color: Color(
                                                          0xFFFFD700,
                                                        ),
                                                        size: 28,
                                                      ),
                                                )
                                              : const Icon(
                                                  Icons.auto_awesome,
                                                  color: Color(0xFFFFD700),
                                                  size: 28,
                                                ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),

                                      // Item Info & Target
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              benefit.itemName.isNotEmpty
                                                  ? benefit.itemName
                                                  : 'Reward Item',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 3),
                                            Row(
                                              children: [
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFF10B981,
                                                    ).withValues(alpha: 0.2),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    '${benefit.validityDays} Days Validity',
                                                    style: const TextStyle(
                                                      color: Color(0xFF34D399),
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                if (benefit.bonusDiamonds >
                                                    0) ...[
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      gradient:
                                                          const LinearGradient(
                                                            colors: [
                                                              Color(0xFFEC4899),
                                                              Color(0xFF8B5CF6),
                                                            ],
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        const DynamicDiamondIcon(
                                                          width: 10,
                                                          height: 10,
                                                        ),
                                                        const SizedBox(
                                                          width: 3,
                                                        ),
                                                        Text(
                                                          '+${benefit.bonusDiamonds} Bonus',
                                                          style:
                                                              const TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 10,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                const DynamicDiamondIcon(
                                                  width: 14,
                                                  height: 14,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Target: ${benefit.targetDiamonds}',
                                                  style: const TextStyle(
                                                    color: Color(0xFFFFD700),
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  '($userRecharged/${benefit.targetDiamonds})',
                                                  style: TextStyle(
                                                    color: isReached
                                                        ? const Color(
                                                            0xFF34D399,
                                                          )
                                                        : Colors.white54,
                                                    fontSize: 10,
                                                    fontWeight: isReached
                                                        ? FontWeight.bold
                                                        : FontWeight.normal,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Claim / Status Button
                                      if (isClaimed)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFF10B981,
                                            ).withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: const Color(
                                                0xFF10B981,
                                              ).withValues(alpha: 0.5),
                                            ),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.check_circle_rounded,
                                                color: Color(0xFF34D399),
                                                size: 14,
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                'Claimed',
                                                style: TextStyle(
                                                  color: Color(0xFF34D399),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      else if (canClaim)
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFFFFD700,
                                            ),
                                            foregroundColor: Colors.black,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 8,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            elevation: 4,
                                          ),
                                          onPressed: () async {
                                            try {
                                              await OnlineRechargeService
                                                  .instance
                                                  .claimWeeklyBenefit(
                                                    userId: effectiveUserId,
                                                    benefit: benefit,
                                                  );
                                              if (bottomCtx.mounted) {
                                                ScaffoldMessenger.of(
                                                  bottomCtx,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      benefit.bonusDiamonds > 0
                                                          ? '🎉 Congratulations! You claimed ${benefit.itemName} + ${benefit.bonusDiamonds} Bonus Diamonds!'
                                                          : '🎉 Congratulations! You claimed ${benefit.itemName} for ${benefit.validityDays} days!',
                                                    ),
                                                    backgroundColor:
                                                        const Color(0xFF10B981),
                                                    behavior: SnackBarBehavior
                                                        .floating,
                                                  ),
                                                );
                                              }
                                            } catch (e) {
                                              if (bottomCtx.mounted) {
                                                ScaffoldMessenger.of(
                                                  bottomCtx,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Failed to claim: $e',
                                                    ),
                                                    backgroundColor: Colors.red,
                                                    behavior: SnackBarBehavior
                                                        .floating,
                                                  ),
                                                );
                                              }
                                            }
                                          },
                                          child: const Text(
                                            'CLAIM',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        )
                                      else
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(
                                              alpha: 0.08,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            '${(benefit.targetDiamonds - userRecharged).clamp(0, benefit.targetDiamonds)} left',
                                            style: const TextStyle(
                                              color: Colors.white54,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            );
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recharge'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        titleTextStyle: const TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RechargeAndGiftRecordScreen(
                    userId: widget.userId,
                    initialTabIndex: 1, // Opens Gift Record tab (Screenshot 2)
                  ),
                ),
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
            padding: const EdgeInsets.symmetric(vertical: 14),
            color: Colors.white,
            child: Column(
              children: [
                const DynamicDiamondIcon(height: 52, width: 52),
                const SizedBox(height: 6),
                const Text(
                  'Balance',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  _currentDiamondBalance.toString(),
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'Diamonds',
                  style: TextStyle(color: Colors.black, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Interactive Weekly Recharge Benefit Banner
          GestureDetector(
            onTap: () => _showWeeklyRechargeBenefitsModal(context),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  colors: [Color(0xFF8E24AA), Color(0xFFD81B60)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8E24AA).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.card_giftcard_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'WEEKLY RECHARGE BENEFIT',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Recharge diamonds and claim bonus rewards!',
                          style: TextStyle(color: Colors.white70, fontSize: 10.5),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 3),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Colors.white,
                          size: 9,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Offline Seller Recharge Option Card (From Screenshot 2)
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SellerListScreen(
                    requestedAmount: _selectedDiamondAmount > 0
                        ? _selectedDiamondAmount
                        : 0,
                  ),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF8C00), Color(0xFFE55D00)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'OFFICIAL SELLERS',
                            style: TextStyle(
                              color: Color(0xFFE65100),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Offline Seller Recharge',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Recharge via Seller (Chat & direct diamond transfer)',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 3-Column Diamond Package Grid
          Expanded(
            child: StreamBuilder<List<RechargePackageModel>>(
              stream: OnlineRechargeService.instance
                  .getRechargePackagesStream(),
              builder: (context, snapshot) {
                final livePkgs = snapshot.data ?? [];
                if (livePkgs.isNotEmpty) {
                  _streamedPackages = livePkgs;
                  if (_selectedDiamondAmount == 0 ||
                      !livePkgs.any(
                        (p) => p.diamondAmount == _selectedDiamondAmount,
                      )) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() {
                          _selectedDiamondAmount = livePkgs.first.diamondAmount;
                        });
                      }
                    });
                  }
                }

                final List<Map<String, dynamic>> displayList =
                    livePkgs.isNotEmpty
                    ? livePkgs
                          .map(
                            (p) => {
                              'diamonds': p.diamondAmount,
                              'bdt': p.bdtPrice,
                              'bonus': p.bonusDiamonds,
                              'bonusText': p.bonusPercentText,
                            },
                          )
                          .toList()
                    : fallbackPackages;

                return GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: displayList.length,
                  itemBuilder: (context, index) {
                    final pkg = displayList[index];
                    final dia = pkg['diamonds'] as int;
                    final bonus = (pkg['bonus'] as num?)?.toInt() ?? 0;
                    final bonusPercent = dia > 0 && bonus > 0
                        ? ((bonus / dia) * 100).toInt()
                        : 0;
                    final isSelected = _selectedDiamondAmount == dia;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedDiamondAmount = dia;
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9F9F9),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFD81B60)
                                : Colors.grey.shade200,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            if (bonus > 0)
                              Positioned(
                                top: 0,
                                left: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 2,
                                  ),
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Color(0xFFFFB300),
                                        Color(0xFFF57C00),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(12),
                                      bottomRight: Radius.circular(8),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '+$bonusPercent%',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        '(+$bonus',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 8,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 1.5),
                                      const DynamicDiamondIcon(
                                        width: 10,
                                        height: 10,
                                        fit: BoxFit.contain,
                                      ),
                                      const Text(
                                        ')',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 8,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(height: 8),
                                  const DynamicDiamondIcon(
                                    height: 42,
                                    width: 42,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    dia.toString(),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.grey.shade200,
                                      ),
                                    ),
                                    child: Text(
                                      'BDT ${(pkg['bdt'] as num).toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
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
          SafeArea(
            top: false,
            bottom: true,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
              child: ElevatedButton(
                onPressed: () => _handleRecharge(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD81B60),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: Text(
                  _selectedDiamondAmount > 0
                      ? 'Recharge BDT ${(_streamedPackages.where((p) => p.diamondAmount == _selectedDiamondAmount).firstOrNull?.bdtPrice ?? (_selectedDiamondAmount * 0.03)).toStringAsFixed(2)}'
                      : 'Recharge Diamonds',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
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
  StreamSubscription<DocumentSnapshot>? _beanConfigSub;

  @override
  void initState() {
    super.initState();
    _userData = widget.userData;
    _listenToBeanEconomyConfig();
    _loadConfigAndWithdrawals();
  }

  @override
  void dispose() {
    _beanConfigSub?.cancel();
    super.dispose();
  }

  void _listenToBeanEconomyConfig() {
    _beanConfigSub?.cancel();
    _beanConfigSub = FirebaseFirestore.instance
        .collection('platform_config')
        .doc('gift_conversion')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        GiftEconomyService.instance.getConfig();
        setState(() {});
      }
    });
  }

  Future<void> _loadConfigAndWithdrawals() async {
    final history = await GiftEconomyService.instance.getUserWithdrawals(
      _userData.userId,
    );

    if (mounted) {
      setState(() {
        _withdrawals = history;
      });
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
            child: const Text(
              'Got it',
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
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
                  builder: (context) => RechargeAndGiftRecordScreen(
                    userId: _userData.userId,
                    initialTabIndex: 1,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
                color: Colors.white,
                child: Row(
                  children: [
                    Image.asset(
                      'assets/images/cashout.webp',
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
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                ),
              ),
              const SizedBox(height: 180), // Space to push buttons down
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    // Withdraw Button (Conditionally shown if enabled in admin panel)
                    if (GiftEconomyService.instance.isWithdrawalEnabled) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    WithdrawScreen(currentUser: _userData),
                              ),
                            );
                            if (mounted) {
                              _loadConfigAndWithdrawals();
                            }
                          },
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
                    ],
                    // Exchange to Diamonds Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : () async {
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

  static const List<Map<String, int>> defaultExchangePackages = [
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
          'Are you sure you want to exchange ${_formatNumber(beansSpent)} Beans for ${_formatNumber(diamondsReceived)} Diamonds?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Exchange',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
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
                'Successfully exchanged ${_formatNumber(beansSpent)} Beans for ${_formatNumber(diamondsReceived)} Diamonds!',
              ),
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
                        icon: const Icon(
                          Icons.arrow_back_ios,
                          color: Colors.white,
                        ),
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
                      DynamicDiamondIcon(
                        height: 35,
                        width: 35,
                        fit: BoxFit.contain,
                      ),
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

            // Grid of Packages (Real-time synced from Admin Panel)
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('bean_exchange_packages')
                          .orderBy('beans', descending: false)
                          .snapshots(),
                      builder: (context, snapshot) {
                        List<Map<String, int>> packages = defaultExchangePackages;
                        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                          packages = snapshot.data!.docs.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            return {
                              'diamonds': (data['diamonds'] as num?)?.toInt() ?? 0,
                              'beans': (data['beans'] as num?)?.toInt() ?? 0,
                            };
                          }).toList();
                        }

                        return GridView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 20,
                          ),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 0.9,
                              ),
                          itemCount: packages.length,
                          itemBuilder: (context, index) {
                            final pkg = packages[index];
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
                                DynamicDiamondIcon(
                                  height: 28,
                                  width: 28,
                                  fit: BoxFit.contain,
                                ),
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
                                      'assets/images/cashout.webp',
                                      height: 12,
                                      width: 12,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) =>
                                          const Icon(Icons.error, size: 12),
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
                    'assets/images/cashout.webp',
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

  const GiftReceivedRecordPage({super.key, required this.userId});

  @override
  State<GiftReceivedRecordPage> createState() => _GiftReceivedRecordPageState();
}

class _GiftReceivedRecordPageState extends State<GiftReceivedRecordPage> {
  String _formatDateTime(DateTime dt) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
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
            return Center(
              child: Text('Error loading records: ${snapshot.error}'),
            );
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
          final transactions = snapshot.data!.docs
              .map((doc) {
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
              })
              .where((tx) => (tx['timestamp'] as DateTime).isAfter(oneMonthAgo))
              .toList();

          if (transactions.isEmpty) {
            return const Center(
              child: Text(
                'No gift records found for the last 30 days.',
                style: TextStyle(color: Colors.grey, fontSize: 15),
              ),
            );
          }

          // Sort descending by timestamp
          transactions.sort(
            (a, b) => (b['timestamp'] as DateTime).compareTo(
              a['timestamp'] as DateTime,
            ),
          );

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
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
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
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.card_giftcard,
                                color: Colors.orange.shade400,
                                size: 28,
                              ),
                            )
                          : Icon(
                              Icons.card_giftcard,
                              color: Colors.orange.shade400,
                              size: 28,
                            ),
                    ),
                    title: Text(
                      giftName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          'From: $senderName',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatDateTime(timestamp),
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 11,
                          ),
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
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $hour:$minute $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final oneMonthAgo = DateTime.now().subtract(const Duration(days: 30));

    CollectionReference getCollection() {
      final baseRef = FirebaseFirestore.instance
          .collection('Users')
          .doc(widget.userId);
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
      backgroundColor: isDarkMode ? Colors.black : const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: Text(
          widget.listType == 'Visitor'
              ? 'Visitors (Last 30 Days)'
              : widget.listType,
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: isDarkMode ? const Color(0xFF18181C) : Colors.white,
        elevation: 0.5,
        iconTheme: IconThemeData(
          color: isDarkMode ? Colors.white : Colors.black,
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
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
                style: TextStyle(
                  color: isDarkMode ? Colors.white54 : Colors.grey,
                  fontSize: 15,
                ),
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
                visitorList.add({'userId': doc.id, 'timestamp': dt});
              }
            }

            if (visitorList.isEmpty) {
              return Center(
                child: Text(
                  'No visitors in the last 30 days.',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white54 : Colors.grey,
                    fontSize: 15,
                  ),
                ),
              );
            }

            visitorList.sort(
              (a, b) => (b['timestamp'] as DateTime).compareTo(
                a['timestamp'] as DateTime,
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: widget.listType == 'Visitor'
                ? visitorList.length
                : docs.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: isDarkMode ? Colors.white12 : Colors.grey.shade200,
            ),
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

  const SocialUserTile({super.key, required this.userId, this.extraText});

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Users')
          .doc(userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final name = data['fullname'] ?? data['name'] ?? 'User';
        final avatarUrl = data['photoUrl'] ?? data['imageUrl'] ?? '';
        final searchId = data['searchId'] ?? '';

        return Material(
          color: isDarkMode ? const Color(0xFF1E1E24) : Colors.white,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            leading: CircleAvatar(
              radius: 24,
              backgroundImage: avatarUrl.isNotEmpty
                  ? NetworkImage(avatarUrl)
                  : null,
              child: avatarUrl.isEmpty ? const Icon(Icons.person) : null,
            ),
            title: Text(
              name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            subtitle: Text(
              'ID: $searchId',
              style: TextStyle(
                color: isDarkMode ? Colors.white60 : Colors.grey.shade500,
                fontSize: 13,
              ),
            ),
            trailing: extraText != null
                ? Text(
                    extraText!,
                    style: TextStyle(
                      color: isDarkMode ? Colors.white38 : Colors.grey.shade400,
                      fontSize: 12,
                    ),
                  )
                : Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: isDarkMode ? Colors.white38 : Colors.grey,
                  ),
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

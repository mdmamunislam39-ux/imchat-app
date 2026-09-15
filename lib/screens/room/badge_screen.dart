import 'package:chat_messenger/config/theme_config.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:flutter/material.dart';

class BadgeScreen extends StatefulWidget {
  final User currentUser;
  
  const BadgeScreen({
    super.key, 
    required this.currentUser,
  });

  @override
  State<BadgeScreen> createState() => _BadgeScreenState();
}

class _BadgeScreenState extends State<BadgeScreen> with TickerProviderStateMixin {
  // State variables
  User? _currentUser;
  bool _isLoading = true;
  String _errorMessage = '';
  late TabController _tabController;
  
  // Badge data
  List<BadgeItem> _ownedBadges = [];
  List<BadgeItem> _availableBadges = [];
  String? _selectedBadgeId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Load user data and badges
  Future<void> _loadUserData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      debugPrint('🏆 Loading user badge data...');
      
      // Get user data
      setState(() {
        _currentUser = widget.currentUser;
      });
      
      // Load badges
      await _loadBadges();
      
      setState(() {
        _isLoading = false;
      });
      
      debugPrint('🏆 User badge data loaded successfully');
    } catch (e) {
      debugPrint('❌ Error loading user badge data: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load badge data: $e';
      });
    }
  }

  // Load badges from store
  Future<void> _loadBadges() async {
    try {
      // TODO: Implement actual badge loading from Firebase
      // For now, create sample badges
      _createSampleBadges();
    } catch (e) {
      debugPrint('❌ Error loading badges: $e');
      // Create sample badges for demo
      _createSampleBadges();
    }
  }

  // Create sample badges for demo
  void _createSampleBadges() {
    _ownedBadges = [
      BadgeItem(
        id: 'badge_1',
        name: 'Beginner Badge',
        description: 'Welcome to the community!',
        imageUrl: 'assets/images/bedge.webp',
        isActive: true,
      ),
      BadgeItem(
        id: 'badge_2',
        name: 'Active User',
        description: 'You are an active member',
        imageUrl: 'assets/images/bedge.webp',
        isActive: false,
      ),
    ];
    
    _availableBadges = [
      BadgeItem(
        id: 'badge_3',
        name: 'VIP Badge',
        description: 'Exclusive VIP member',
        imageUrl: 'assets/images/bedge.webp',
        isActive: false,
        diamondPrice: 1000,
      ),
      BadgeItem(
        id: 'badge_4',
        name: 'Premium Badge',
        description: 'Premium member badge',
        imageUrl: 'assets/images/bedge.webp',
        isActive: false,
        diamondPrice: 500,
      ),
    ];
  }

  // Select badge
  Future<void> _selectBadge(String badgeId) async {
    try {
      debugPrint('🏆 Selecting badge: $badgeId');
      
      // TODO: Implement actual badge selection logic
      setState(() {
        _selectedBadgeId = badgeId;
      });
      
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Badge selected successfully!'),
            backgroundColor: Colors.green,
          ),
        );
    } catch (e) {
      debugPrint('❌ Error selecting badge: $e');
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Failed to select badge: $e'),
            backgroundColor: Colors.red,
          ),
        );
    }
  }

  // Purchase badge
  Future<void> _purchaseBadge(BadgeItem badge) async {
    try {
      debugPrint('🏆 Purchasing badge: ${badge.name}');
      
      if (_currentUser!.diamonds < badge.diamondPrice!) {
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Not enough diamonds! You need ${badge.diamondPrice} diamonds.'),
              backgroundColor: Colors.red,
            ),
          );
        return;
      }
      
      // TODO: Implement actual badge purchase logic
      // Update local state
      setState(() {
        _ownedBadges.add(badge);
        _availableBadges.removeWhere((b) => b.id == badge.id);
        _currentUser!.diamonds -= badge.diamondPrice!;
      });
      
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Badge purchased successfully!'),
            backgroundColor: Colors.green,
          ),
        );
    } catch (e) {
      debugPrint('❌ Error purchasing badge: $e');
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Failed to purchase badge: $e'),
            backgroundColor: Colors.red,
          ),
        );
    }
  }

  // Refresh data
  Future<void> _refreshData() async {
    await _loadUserData();
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
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _refreshData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white.withValues(alpha: 0.9),
      appBar: AppBar(
        title: const Text('My Badges'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        titleTextStyle: const TextStyle(
          color: Colors.black, 
          fontSize: 18, 
          fontWeight: FontWeight.bold
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: primaryColor,
          tabs: const [
            Tab(text: 'My Badges'),
            Tab(text: 'Store'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildMyBadgesTab(),
            _buildStoreTab(),
          ],
        ),
      ),
    );
  }

  // My Badges Tab
  Widget _buildMyBadgesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current Badge
          _buildCurrentBadgeSection(),
          const SizedBox(height: 20),
          
          // Owned Badges
          _buildOwnedBadgesSection(),
        ],
      ),
    );
  }

  // Store Tab
  Widget _buildStoreTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Available Badges
          _buildAvailableBadgesSection(),
        ],
      ),
    );
  }

  // Current Badge Section
  Widget _buildCurrentBadgeSection() {
    final selectedBadge = _ownedBadges.firstWhere(
      (badge) => badge.id == _selectedBadgeId,
      orElse: () => BadgeItem(
        id: 'none',
        name: 'No Badge Selected',
        description: 'Select a badge to display',
        imageUrl: 'assets/images/bedge.webp',
        isActive: false,
      ),
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor.withValues(alpha: 0.1), primaryColor.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Current Badge',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Image.asset(
                selectedBadge.imageUrl,
                width: 60,
                height: 60,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.workspace_premium, size: 30),
                  );
                },
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedBadge.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      selectedBadge.description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Owned Badges Section
  Widget _buildOwnedBadgesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'My Badges',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        if (_ownedBadges.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                'No badges owned yet',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.8,
            ),
            itemCount: _ownedBadges.length,
            itemBuilder: (context, index) {
              final badge = _ownedBadges[index];
              final isSelected = badge.id == _selectedBadgeId;
              
              return GestureDetector(
                onTap: () => _selectBadge(badge.id),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected ? primaryColor.withValues(alpha: 0.1) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? primaryColor : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.1),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        badge.imageUrl,
                        width: 50,
                        height: 50,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.workspace_premium, size: 24),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        badge.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        badge.description,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isSelected) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: primaryColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'SELECTED',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  // Available Badges Section
  Widget _buildAvailableBadgesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Available Badges',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        if (_availableBadges.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                'No badges available',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.8,
            ),
            itemCount: _availableBadges.length,
            itemBuilder: (context, index) {
              final badge = _availableBadges[index];
              
              return GestureDetector(
                onTap: () => _purchaseBadge(badge),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.1),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        badge.imageUrl,
                        width: 50,
                        height: 50,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.workspace_premium, size: 24),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        badge.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        badge.description,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.pink,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.diamond, color: Colors.white, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              '${badge.diamondPrice}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
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
            },
          ),
      ],
    );
  }
}

// Badge Item model
class BadgeItem {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final bool isActive;
  final int? diamondPrice;

  BadgeItem({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.isActive,
    this.diamondPrice,
  });
}

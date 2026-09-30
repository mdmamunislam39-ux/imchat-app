import 'package:chat_messenger/widgets/user_id_badge_widget.dart';
import 'package:chat_messenger/components/cached_circle_avatar.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:chat_messenger/services/family_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:chat_messenger/helpers/app_helper.dart';
import 'package:chat_messenger/components/universal_asset_widget.dart';
import 'package:chat_messenger/services/global_settings_service.dart';
import 'package:chat_messenger/components/dynamic_diamond_icon.dart';


class FamilyScreen extends StatefulWidget {
  final User currentUser;
  
  const FamilyScreen({
    super.key, 
    required this.currentUser,
  });

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> with TickerProviderStateMixin {
  final FamilyService _familyService = FamilyService();
  bool _isLoading = true;
  String _errorMessage = '';
  TabController? _tabController;

  // Active user data
  User? _currentUser;
  Map<String, dynamic>? _myFamily;
  List<User> _membersList = [];
  List<Map<String, dynamic>> _leaderboard = [];
  List<Map<String, dynamic>> _incomingRequests = [];

  // Global configs loaded from Firestore
  int _requiredLevel = 1;
  int _requiredDiamonds = 100;
  int _memberLimit = 50;

  File? _selectedLogoFile;

  // Create Family Form Controllers
  final _createFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _logoController = TextEditingController();

  // Search Family Controller
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _nameController.dispose();
    _descController.dispose();
    _logoController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      // 1. Get updated user document
      final userSnapshot = await FirebaseFirestore.instance
          .collection('Users')
          .doc(widget.currentUser.userId)
          .get();
      
      if (!userSnapshot.exists) throw Exception('User document not found');
      _currentUser = User.fromMap(userSnapshot.data()!);

      // Fetch family configurations from system_configs/family_settings
      try {
        final configSnapshot = await FirebaseFirestore.instance
            .collection('system_configs')
            .doc('family_settings')
            .get();
        if (configSnapshot.exists && configSnapshot.data() != null) {
          final configData = configSnapshot.data()!;
          _requiredLevel = configData['requiredLevel'] ?? 1;
          _requiredDiamonds = configData['requiredDiamonds'] ?? 100;
          _memberLimit = configData['memberLimit'] ?? 50;
        }
      } catch (ex) {
        debugPrint('⚠️ Failed to load family settings: $ex');
      }

      // 2. Fetch Leaderboard (All Families ordered by points)
      _leaderboard = await _familyService.getAllFamilies();

      // 3. Load family details if user is in a family
      final String? familyId = _currentUser?.familyId;
      if (familyId != null && familyId.isNotEmpty) {
        _myFamily = await _familyService.getFamily(familyId);
        
        if (_myFamily != null) {
          _memberLimit = _myFamily!['memberLimit'] ?? _memberLimit;
          
          // Fetch members from family_members collection for roles
          final membersData = await _familyService.getFamilyMembers(familyId);
          _myFamily!['membersData'] = membersData;

          // Fetch members (users who have this familyId)
          final membersSnapshot = await FirebaseFirestore.instance
              .collection('Users')
              .where('familyId', isEqualTo: familyId)
              .get();
          
          _membersList = membersSnapshot.docs
              .map((doc) => User.fromMap(doc.data()))
              .toList();

          // Sort members: Leader first, then others by totalDiamonds desc
          _membersList.sort((a, b) {
            final String leaderId = _myFamily!['owner_id'] ?? _myFamily!['creatorId'];
            final bool isALeader = a.userId == leaderId;
            final bool isBLeader = b.userId == leaderId;
            if (isALeader) return -1;
            if (isBLeader) return 1;
            return b.totalDiamonds.compareTo(a.totalDiamonds);
          });

          // Fetch incoming requests if leader
          final String currentLeaderId = _myFamily!['owner_id'] ?? _myFamily!['creatorId'];
          if (currentLeaderId == _currentUser!.userId) {
            _incomingRequests = await _familyService.getFamilyRequests(familyId);
          }
        }
      } else {
        _myFamily = null;
        _membersList = [];
        _incomingRequests = [];
      }

      // Initialize tabs dynamically based on user's family status
      final bool isUserLeader = _myFamily != null && (_myFamily!['owner_id'] ?? _myFamily!['creatorId']) == _currentUser!.userId;
      final int tabCount = _myFamily != null ? (isUserLeader ? 4 : 3) : 2;
      
      if (_tabController != null && _tabController!.length != tabCount) {
        _tabController!.dispose();
        _tabController = TabController(length: tabCount, vsync: this);
      } else {
        _tabController ??= TabController(length: tabCount, vsync: this);
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '';
        });
      }
    } catch (e) {
      debugPrint('Error loading family data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load family data: $e';
        });
      }
    }
  }

  // Create Family action
  Future<void> _createFamily() async {
    if (!_createFormKey.currentState!.validate()) return;
    
    // Check level requirements
    final userLevel = _currentUser!.sendingLevel?.level ?? int.tryParse(_currentUser!.level) ?? 1;
    if (userLevel < _requiredLevel) {
      Get.snackbar(
        'Level Required',
        'You must be at least Level $_requiredLevel to create a Family. Your level: $userLevel.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    // Check diamonds balance
    final diamonds = _currentUser?.diamonds ?? 0;
    if (diamonds < _requiredDiamonds) {
      Get.snackbar(
        'Insufficient Diamonds',
        'You need at least $_requiredDiamonds diamonds to create a Family.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final name = _nameController.text.trim();
      final desc = _descController.text.trim();

      String logoUrl = 'https://cdn-icons-png.flaticon.com/512/9658/9658392.png';

      // Upload selected logo image to Firebase Storage
      if (_selectedLogoFile != null) {
        try {
          logoUrl = await AppHelper.uploadFile(
            file: _selectedLogoFile!,
            userId: _currentUser!.userId,
          );
        } catch (ex) {
          debugPrint('⚠️ Logo upload failed, falling back to default: $ex');
        }
      }

      await _familyService.createFamily(
        name: name,
        description: desc,
        logoUrl: logoUrl,
        creatorId: _currentUser!.userId,
        creatorName: _currentUser!.fullname,
        creatorPhoto: _currentUser!.photoUrl,
        requiredDiamonds: _requiredDiamonds,
      );

      _nameController.clear();
      _descController.clear();
      _selectedLogoFile = null;

      Get.snackbar(
        '🎉 Congratulations!',
        'Your Family "$name" has been created successfully!',
        backgroundColor: Colors.green.shade700,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );

      // Reload
      await _loadAllData();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to create family: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Send request to join
  Future<void> _requestToJoin(Map<String, dynamic> family) async {
    try {
      await _familyService.sendJoinRequest(
        familyId: family['familyId'],
        familyName: family['familyName'],
        userId: _currentUser!.userId,
        userName: _currentUser!.fullname,
        userPhoto: _currentUser!.photoUrl,
      );

      Get.snackbar(
        'Request Sent',
        'Request to join "${family['familyName']}" sent successfully!',
        backgroundColor: Colors.blue,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        e.toString().replaceAll('Exception: ', ''),
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  // Leave Family
  Future<void> _leaveFamily() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Family'),
        content: const Text('Are you sure you want to leave this family? You will lose your rank and chat access.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await _familyService.leaveFamily(_currentUser!.userId, _myFamily!['familyId']);
        Get.snackbar('Left Family', 'You have left the family.', backgroundColor: Colors.orange, colorText: Colors.white);
        await _loadAllData();
      } catch (e) {
        Get.snackbar('Error', 'Failed to leave family: $e', backgroundColor: Colors.red, colorText: Colors.white);
        setState(() => _isLoading = false);
      }
    }
  }

  // Accept Member Request
  Future<void> _acceptRequest(Map<String, dynamic> request) async {
    // Check member limit first
    if (_membersList.length >= _memberLimit) {
      Get.snackbar(
        'Member Limit Reached',
        'This Family has reached its limit of $_memberLimit members.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _familyService.acceptRequest(
        requestId: request['requestId'],
        familyId: request['familyId'],
        familyName: request['familyName'],
        userId: request['userId'],
      );
      Get.snackbar('Accepted', '${request['userName']} has joined the Family!', backgroundColor: Colors.green, colorText: Colors.white);
      await _loadAllData();
    } catch (e) {
      Get.snackbar('Error', 'Failed to accept request: $e', backgroundColor: Colors.red, colorText: Colors.white);
      setState(() => _isLoading = false);
    }
  }

  // Reject Member Request
  Future<void> _rejectRequest(Map<String, dynamic> request) async {
    setState(() => _isLoading = true);
    try {
      await _familyService.rejectRequest(request['requestId']);
      Get.snackbar('Rejected', 'Request rejected.', backgroundColor: Colors.orange, colorText: Colors.white);
      await _loadAllData();
    } catch (e) {
      Get.snackbar('Error', 'Failed to reject request: $e', backgroundColor: Colors.red, colorText: Colors.white);
      setState(() => _isLoading = false);
    }
  }



  void _showEditFamilyDialog() {
    _nameController.text = _myFamily!['familyName'] ?? '';
    _descController.text = _myFamily!['description'] ?? '';
    _selectedLogoFile = null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF16162A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Edit Family Info', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            content: Form(
              key: _createFormKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Edit Logo Picker Widget
                    GestureDetector(
                      onTap: () async {
                        final picker = ImagePicker();
                        final picked = await picker.pickImage(source: ImageSource.gallery);
                        if (picked != null) {
                          setDialogState(() {
                            _selectedLogoFile = File(picked.path);
                          });
                        }
                      },
                      child: Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF1F203C),
                          border: Border.all(color: Colors.amber, width: 2),
                          boxShadow: const [
                            BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2))
                          ],
                        ),
                        child: _selectedLogoFile != null
                            ? ClipOval(
                                child: Image.file(
                                  _selectedLogoFile!,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : ClipOval(
                                child: Image.network(
                                  _myFamily!['logoUrl'] ?? '',
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(Icons.family_restroom, color: Colors.amber, size: 28),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Tap to change logo', style: TextStyle(color: Colors.white60, fontSize: 12)),
                    const SizedBox(height: 16),

                    _buildDialogTextField(
                      controller: _nameController,
                      labelText: 'Family Name',
                      validator: (val) => val == null || val.trim().isEmpty ? 'Enter family name' : null,
                    ),
                    const SizedBox(height: 12),
                    _buildDialogTextField(
                      controller: _descController,
                      labelText: 'Slogan / Description',
                      validator: (val) => val == null || val.trim().isEmpty ? 'Enter description' : null,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _saveFamilyDetails();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text(
                  'Save Changes',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        }
      ),
    );
  }

  Future<void> _saveFamilyDetails() async {
    if (!_createFormKey.currentState!.validate()) return;

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final name = _nameController.text.trim();
      final desc = _descController.text.trim();
      
      String logoUrl = _myFamily!['logoUrl'] ?? '';

      // Upload new logo image if selected
      if (_selectedLogoFile != null) {
        logoUrl = await AppHelper.uploadFile(
          file: _selectedLogoFile!,
          userId: _currentUser!.userId,
        );
      }

      await _familyService.updateFamilyDetails(
        familyId: _myFamily!['familyId'],
        newName: name,
        newDescription: desc,
        newLogoUrl: logoUrl,
      );

      _nameController.clear();
      _descController.clear();
      _selectedLogoFile = null;

      Get.snackbar(
        'Success',
        'Family details updated successfully!',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );

      await _loadAllData();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to update family details: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Delete Family
  Future<void> _deleteFamily() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Family'),
        content: const Text('WARNING: This will delete the family permanently and kick all members. This cannot be undone!'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Permanently', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await _familyService.deleteFamily(_myFamily!['familyId']);
        Get.snackbar('Family Deleted', 'Your family has been deleted.', backgroundColor: Colors.red, colorText: Colors.white);
        await _loadAllData();
      } catch (e) {
        Get.snackbar('Error', 'Failed to delete family: $e', backgroundColor: Colors.red, colorText: Colors.white);
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.amber)),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(_errorMessage, style: const TextStyle(color: Colors.white, fontSize: 16)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadAllData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final bool isLeader = _myFamily != null && (_myFamily!['owner_id'] ?? _myFamily!['creatorId']) == _currentUser!.userId;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1E),
      appBar: AppBar(
        title: Text(_myFamily != null ? 'My Family' : 'Family Center'),
        backgroundColor: const Color(0xFF16162A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (isLeader)
            PopupMenuButton<String>(
              icon: const Icon(Icons.settings),
              color: const Color(0xFF282A4A),
              onSelected: (value) {
                if (value == 'setting') {
                  _showEditFamilyDialog();
                } else if (value == 'delete') {
                  _deleteFamily();
                }
              },
              itemBuilder: (BuildContext context) => [
                const PopupMenuItem<String>(
                  value: 'setting',
                  child: Text('Family Setting', style: TextStyle(color: Colors.white)),
                ),
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: Text('Delete Family', style: TextStyle(color: Colors.redAccent)),
                ),
              ],
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.amber,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.amber,
          tabs: [
            Tab(text: _myFamily != null ? 'Dashboard' : 'Explore'),
            const Tab(text: 'Leaderboard'),
            if (_myFamily != null) const Tab(text: 'Members Rank'),
            if (isLeader) const Tab(text: 'Requests'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _myFamily != null ? _buildDashboardTab() : _buildExploreTab(),
          _buildLeaderboardTab(),
          if (_myFamily != null) _buildMembersRankTab(),
          if (isLeader) _buildRequestsTab(),
        ],
      ),
    );
  }

  // ==================== DASHBOARD TAB ====================
  Widget _buildDashboardTab() {
    final family = _myFamily!;
    final bool isLeader = (family['owner_id'] ?? family['creatorId']) == _currentUser!.userId;
    final int flamePoints = family['flame_points'] ?? 0;
    final double progress = (flamePoints / 419000).clamp(0.0, 1.0);
    
    final String coverImage = family['cover_image'] ?? family['logoUrl'] ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Banner & Cover Image
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: const Color(0xFF282A4A), // Fallback color
              image: coverImage.isNotEmpty 
                ? DecorationImage(
                    image: NetworkImage(coverImage),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.4), BlendMode.darken),
                  )
                : null,
            ),
            padding: const EdgeInsets.all(20),
            height: 150,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  family['family_name'] ?? family['familyName'] ?? 'Unknown',
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                Text(
                  'ID: ${family['family_id'] ?? family['familyId'] ?? ''}',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Level & Progress Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF16162A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Level: ${family['level'] ?? 'steel'}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                    Text('$flamePoints / 419000 Flame Points', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.black.withValues(alpha: 0.2),
                  color: Colors.amber,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Family Bio
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF16162A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Family Bio', style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 8),
                Text(
                  family['family_bio'] ?? family['description'] ?? 'No bio available',
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Members Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Family Members ${_membersList.length}/$_memberLimit',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Text(
                'Active users 1, Lapsed users 0',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Horizontal ListView for Members
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _membersList.length,
              itemBuilder: (context, index) {
                final member = _membersList[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: CachedCircleAvatar(
                    imageUrl: member.photoUrl,
                    radius: 25,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          
          // Rules & FAQ Expansion Tile
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              title: const Text('Family Announcement / Rules', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
              collapsedBackgroundColor: const Color(0xFF16162A),
              backgroundColor: const Color(0xFF16162A),
              iconColor: Colors.amber,
              collapsedIconColor: Colors.amber,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance.collection('system_configs').doc('family_settings').snapshots(),
                      builder: (context, snapshot) {
                        String rulesText = _defaultRules();
                        if (snapshot.hasData && snapshot.data!.exists) {
                          final data = snapshot.data!.data() as Map<String, dynamic>?;
                          if (data != null && data.containsKey('familyRules') && data['familyRules'].toString().isNotEmpty) {
                            rulesText = data['familyRules'];
                          }
                        }
                        return Text(
                          rulesText,
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          if (!isLeader)
            ElevatedButton.icon(
              onPressed: _leaveFamily,
              icon: const Icon(Icons.exit_to_app, color: Colors.white),
              label: const Text('Leave Family'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, padding: const EdgeInsets.symmetric(vertical: 12)),
            ),
        ],
      ),
    );
  }


  // ==================== EXPLORE TAB ====================
  Widget _buildExploreTab() {
    final filtered = _leaderboard.where((f) {
      return f['familyName'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Column(
      children: [
        // Search & Creation Cost Warning Bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search families by name...',
                    hintStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.search, color: Colors.amber),
                    filled: true,
                    fillColor: const Color(0xFF16162A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _showCreateFamilyDialog,
                icon: const Icon(Icons.add, color: Colors.black, size: 16),
                label: const Text('Create', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('No families found. Create one now!', style: TextStyle(color: Colors.white60)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final f = filtered[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16162A),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: const BoxDecoration(shape: BoxShape.circle),
                            child: ClipOval(
                              child: Image.network(
                                f['logoUrl'],
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(Icons.family_restroom, color: Colors.amber, size: 28),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  f['familyName'],
                                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(6)),
                                      child: Text('Lv.${f['level'] ?? 1}', style: const TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 10),
                                    Text('${f['memberIds']?.length ?? 1} Members', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => _requestToJoin(f),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Join', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showCreateFamilyDialog() {
    _selectedLogoFile = null; // Reset picked logo file
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF16162A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Create Family', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            content: Form(
              key: _createFormKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Requirement: Level $_requiredLevel+\nCreation Cost: $_requiredDiamonds Diamonds',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, height: 1.5),
                    ),
                    const SizedBox(height: 16),
                    
                    // Logo Picker Widget
                    GestureDetector(
                      onTap: () async {
                        final picker = ImagePicker();
                        final picked = await picker.pickImage(source: ImageSource.gallery);
                        if (picked != null) {
                          setDialogState(() {
                            _selectedLogoFile = File(picked.path);
                          });
                        }
                      },
                      child: Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF1F203C),
                          border: Border.all(color: Colors.amber, width: 2),
                          boxShadow: const [
                            BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2))
                          ],
                        ),
                        child: _selectedLogoFile != null
                            ? ClipOval(
                                child: Image.file(
                                  _selectedLogoFile!,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo, color: Colors.white70, size: 28),
                                  SizedBox(height: 4),
                                  Text('Logo', style: TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold)),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildDialogTextField(
                      controller: _nameController,
                      labelText: 'Family Name',
                      validator: (val) => val == null || val.trim().isEmpty ? 'Enter family name' : null,
                    ),
                    const SizedBox(height: 12),
                    _buildDialogTextField(
                      controller: _descController,
                      labelText: 'Slogan / Description',
                      validator: (val) => val == null || val.trim().isEmpty ? 'Enter description' : null,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _createFamily();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  'Create ($_requiredDiamonds 💎)',
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String labelText,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: const Color(0xFF1F203C),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.amber, width: 1.5),
        ),
      ),
      validator: validator,
    );
  }

  // ==================== LEADERBOARD TAB ====================
  Widget _buildLeaderboardTab() {
    if (_leaderboard.isEmpty) {
      return const Center(child: Text('No families created yet.', style: TextStyle(color: Colors.white60)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _leaderboard.length,
      itemBuilder: (context, index) {
        final f = _leaderboard[index];
        final rank = index + 1;

        Color rankColor = Colors.white54;
        if (rank == 1) rankColor = Colors.amber;
        if (rank == 2) rankColor = const Color(0xFFC0C0C0);
        if (rank == 3) rankColor = const Color(0xFFCD7F32);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF16162A),
            borderRadius: BorderRadius.circular(16),
            border: rank <= 3 ? Border.all(color: rankColor.withValues(alpha: 0.5), width: 1) : null,
          ),
          child: Row(
            children: [
              // Rank badge
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: rank <= 3 ? rankColor.withValues(alpha: 0.2) : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$rank',
                  style: TextStyle(color: rank <= 3 ? rankColor : Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              _buildFamilyAvatar(f, rank),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      f['familyName'],
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Leader: ${f['creatorName']}',
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${f['points'] ?? 0}',
                    style: const TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Text('points', style: TextStyle(color: Colors.white38, fontSize: 10)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ==================== REQUESTS TAB ====================
  Widget _buildRequestsTab() {
    if (_incomingRequests.isEmpty) {
      return const Center(child: Text('No pending join requests.', style: TextStyle(color: Colors.white60)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _incomingRequests.length,
      itemBuilder: (context, index) {
        final req = _incomingRequests[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF16162A),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              CachedCircleAvatar(
                imageUrl: req['userPhoto'],
                radius: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      req['userName'] ?? 'Unknown User',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    const Text('Wants to join your Family', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.check_circle, color: Colors.green),
                    onPressed: () => _acceptRequest(req),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.redAccent),
                    onPressed: () => _rejectRequest(req),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ==================== MEMBERS RANK TAB ====================
  Widget _buildMembersRankTab() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            labelColor: Colors.amber,
            unselectedLabelColor: Colors.white54,
            indicatorColor: Colors.amber,
            tabs: [
              Tab(text: 'Recharge'),
              Tab(text: 'Sending'),
              Tab(text: 'Receiving'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildMemberRankList('recharge'),
                _buildMemberRankList('sending'),
                _buildMemberRankList('receiving'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberRankList(String type) {
    List<User> sortedMembers = List.from(_membersList);
    
    sortedMembers.sort((a, b) {
      if (type == 'receiving') {
        return b.beans.compareTo(a.beans);
      } else {
        return b.totalDiamonds.compareTo(a.totalDiamonds);
      }
    });

    if (sortedMembers.isEmpty) {
      return const Center(
        child: Text('No members found', style: TextStyle(color: Colors.white54)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedMembers.length,
      itemBuilder: (context, index) {
        final member = sortedMembers[index];
        final value = type == 'receiving' ? member.beans : member.totalDiamonds;
        
        return ListTile(
          leading: Stack(
            clipBehavior: Clip.none,
            children: [
              CachedCircleAvatar(imageUrl: member.photoUrl, radius: 24),
              if (index < 3)
                Positioned(
                  bottom: -4,
                  right: -4,
                  child: CircleAvatar(
                    radius: 10,
                    backgroundColor: index == 0 ? Colors.amber : (index == 1 ? Colors.grey[300] : Colors.brown[300]),
                    child: Text('${index + 1}', style: const TextStyle(fontSize: 10, color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
          title: Text(member.fullname, style: const TextStyle(color: Colors.white)),
          subtitle: UserIdBadgeWidget(
            searchId: member.searchId.isNotEmpty ? member.searchId : member.userId,
            badgeHeight: 14,
            textStyle: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              type == 'receiving' ? const Icon(Icons.favorite, color: Colors.pink, size: 16) : DynamicDiamondIcon(width: 16, height: 16),
              const SizedBox(width: 4),
              Text('$value', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFamilyAvatar(Map<String, dynamic> family, [int? rank]) {
    final int flamePoints = family['flame_points'] ?? 0;
    final dynamic globalSettings = Get.find<GlobalSettingsService>();
    final levels = globalSettings.familyLevels;
    
    String? currentFrameUrl;
    // Find the highest level the family has reached
    for (int i = levels.length - 1; i >= 0; i--) {
      if (flamePoints >= (levels[i]['requiredPoints'] ?? 0)) {
        currentFrameUrl = levels[i]['frameUrl'];
        break;
      }
    }

    final double size = rank != null ? 48.0 : 64.0;
    final String logoUrl = family['logoUrl'] ?? family['cover_image'] ?? '';

    return SizedBox(
      width: size + 16,
      height: size + 16,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Base Avatar
          Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(shape: BoxShape.circle),
            child: ClipOval(
              child: logoUrl.isNotEmpty
                ? Image.network(
                    logoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.family_restroom, color: Colors.amber, size: 24),
                  )
                : const Icon(Icons.family_restroom, color: Colors.amber, size: 24),
            ),
          ),
          // Frame overlay
          if (currentFrameUrl != null && currentFrameUrl.isNotEmpty)
            Positioned.fill(
              child: currentFrameUrl.toLowerCase().contains('.svga')
                  ? UniversalAssetWidget(url: currentFrameUrl, fit: BoxFit.cover)
                  : Image.network(currentFrameUrl, fit: BoxFit.cover),
            ),
        ],
      ),
    );
  }

  String _defaultRules() {
    return '''1. What is a family?
A family is an organization created by users on their own. Users join to join the family and work together like-minded partners to keep the family growing.

2. How to create / join a family?
Create a family: you can create a family after your wealth level meet the requirement. Upload the family cover, name and notice, you can run your family after passing the review.
Join the family: On the family homepage, click "Join Family" to initiate the application, and you can join the family after passing the family review.

3. Can I join multiple families?
No, one person can only create or join one family.

4. How many people can the family hold?
The number of members is related to the family level, and the initial number is 300. The higher the family level, the greater the capacity.

5. How many administrators can be set in a family?
A family can have up to 10 administrators.

6. How is the family list ranked?
Sort by the total contribution of family members.

7. What is the family level?
The family level represents the strength of the family. The stronger the family, the higher the level. The current family level is divided into four levels: steel, bronze, silver, and gold.

8. What can the family level upgrade bring?
As the level increases, the upper limit of members and administrators will continue to increase; at the same time, the style of family badge and family frame will continue to upgrade as the level increases. Upgrade to the Golden Family to unlock the exclusive gifts of the Golden Family.

9. How to improve the family level?
Calculate the sum of the contribution of family members in each season. The higher the contribution value, the higher the level. The level will be settled at the end of the season as the initial level for the next season.

10. How is the contribution calculated?
- Log in: 20 per person per day
- Watch a 10-minutes live broadcast: +50, 250 per person per day
- Have a 10-minutes guest call: +150, 750 per person per day
- Every 10 minutes of broadcasting: +150, 1500 per person per day
- 1 chat with a friend: +5, 100 per person per day
- Bet: 1000 = 1, 20K per person per day
- Recharge: 10 = 1, users who recharge > 50M daily receive 1M
- Gift giving: 10 = 1, users who send gifts > 100M daily receive 1M
- Receive gifts: 10 = 1

11. What are the rewards for the weekly clan rankings?
The top three Families on the weekly ranking will receive Family rewards, including:
1. World Notice during peak hours: Showcases the Family's weekly ranking.
2. Family member livestream notice: Showcases livestream information for the Family member with the highest contribution points this week.
3. Family contribution point rewards: 50M contribution points for TOP1, 30M contribution points for TOP2, and 10M contribution points for TOP3.''';
  }
}

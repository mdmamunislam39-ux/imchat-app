import 'dart:async';
import 'package:flutter/material.dart';
import '../services/admin_assets_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../components/universal_asset_widget.dart';
import '../widgets/asset_form_dialog.dart';
import '../../services/store_service.dart';

/// Redesigned premium Admin Dashboard for managing Gifts, Entry Effects, Frames, Badges, and Profile Skins.
class AdminAssetsScreen extends StatefulWidget {
  const AdminAssetsScreen({super.key});

  @override
  State<AdminAssetsScreen> createState() => _AdminAssetsScreenState();
}

class _AdminAssetsScreenState extends State<AdminAssetsScreen>
    with SingleTickerProviderStateMixin {
  final AdminAssetsService _assetsService = AdminAssetsService();
  late TabController _tabController;

  List<Map<String, dynamic>> _assets = [];
  bool _isLoading = false;
  String _searchQuery = '';

  final List<Map<String, String>> _categories = [
    {'type': 'badge', 'name': 'Badges', 'icon': '🎖️'},
    {'type': 'entryEffect', 'name': 'Entry Effects', 'icon': '🚀'},
    {'type': 'avatarFrame', 'name': 'Frames', 'icon': '🖼️'},
    {'type': 'roomTheme', 'name': 'Room Themes', 'icon': '🎙️'},
    {'type': 'backgroundTheme', 'name': 'Skins', 'icon': '🎨'},
    {'type': 'roomEntry', 'name': 'Room Entries', 'icon': '🚪'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _loadAssets();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) return;
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    final String selectedType = _categories[_tabController.index]['type']!;
    setState(() {
      _isLoading = true;
      _assets = [];
    });

    try {
      final assets = await _assetsService.getAssetsByType(selectedType);
      if (mounted) {
        setState(() {
          _assets = assets;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ AdminAssetsScreen: Error loading assets: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Failed to load assets: $e', isError: true);
      }
    }
  }

  // ignore: unused_element
  void _showAddAssetDialog() async {
    final String selectedType = _categories[_tabController.index]['type']!;
    final result = await showDialog(
      context: context,
      builder: (context) => AssetFormDialog(
        assetsService: _assetsService,
        initialType: selectedType,
      ),
    );

    if (result == true) {
      _loadAssets();
    }
  }

  // ignore: unused_element
  void _showEditAssetDialog(Map<String, dynamic> asset) async {
    final result = await showDialog(
      context: context,
      builder: (context) => AssetFormDialog(
        assetsService: _assetsService,
        asset: asset,
        initialType: asset['type'] ?? 'gift',
      ),
    );

    if (result == true) {
      _loadAssets();
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.teal,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _assignAsset(Map<String, dynamic> asset) async {
    // Gifts cannot be assigned to customization
    if (asset['type'] == 'gift') {
      _showSnackBar(
          'Gifts cannot be directly assigned to users from this dashboard.',
          isError: true);
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return _AssignAssetDialog(
          asset: asset,
          onShowSnackBar: (message, {bool isError = false}) {
            _showSnackBar(message, isError: isError);
          },
        );
      },
    );

    if (result == true) {
      _loadAssets();
    }
  }

  List<Map<String, dynamic>> get _filteredAssets {
    if (_searchQuery.trim().isEmpty) {
      return _assets;
    }
    final query = _searchQuery.toLowerCase();
    return _assets.where((asset) {
      final name = (asset['name'] as String).toLowerCase();
      final category = (asset['category'] as String).toLowerCase();
      return name.contains(query) || category.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121318),
      appBar: AppBar(
        title: const Text(
          'Custom Assets Manager',
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5),
        ),
        backgroundColor: const Color(0xFF1C1D24),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _loadAssets,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.tealAccent,
          labelColor: Colors.tealAccent,
          unselectedLabelColor: Colors.white60,
          indicatorWeight: 3,
          isScrollable: true,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: _categories.map((cat) {
            return Tab(
              child: Row(
                children: [
                  Text(cat['icon']!, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(cat['name']!),
                ],
              ),
            );
          }).toList(),
        ),
      ),
      body: Column(
        children: [
          // Search & Filter Panel
          _buildSearchPanel(),

          // Assets Grid/List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.tealAccent),
                  )
                : _filteredAssets.isEmpty
                    ? _buildEmptyState()
                    : GridView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 18,
                          mainAxisSpacing: 18,
                          childAspectRatio: 0.65,
                        ),
                        itemCount: _filteredAssets.length,
                        itemBuilder: (context, index) {
                          final asset = _filteredAssets[index];
                          return _buildAssetCard(asset);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      color: const Color(0xFF1C1D24),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withAlpha(15)),
              ),
              child: TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search by name or category...',
                  hintStyle: TextStyle(
                      color: Colors.white.withAlpha(77), fontSize: 13),
                  prefixIcon:
                      const Icon(Icons.search, color: Colors.white30, size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.only(top: 8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetCard(Map<String, dynamic> asset) {
    final String name = asset['name'] ?? '';
    final String category = asset['category'] ?? '';
    final int price = asset['price'] ?? 0;
    final bool isActive = asset['isActive'] ?? true;
    final String fileUrl = asset['fileUrl'] ?? '';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1D24),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(13), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(51),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Premium Player Preview inside Grid Card
          Expanded(
            flex: 6,
            child: Container(
              width: double.infinity,
              color: Colors.black.withAlpha(51),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.1,
                      child: CustomPaint(
                        painter: GridPainter(),
                      ),
                    ),
                  ),
                  if (fileUrl.isNotEmpty)
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: UniversalAssetWidget(
                          url: fileUrl,
                          fit: BoxFit.contain,
                          isAlphaVideo: true,
                        ),
                      ),
                    )
                  else
                    const Center(
                      child: Icon(Icons.broken_image,
                          color: Colors.white24, size: 36),
                    ),

                  // Active Badge
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isActive
                            ? Colors.teal.withAlpha(217)
                            : Colors.redAccent.withAlpha(217),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isActive ? 'Active' : 'Inactive',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  // Format Badge
                  if (fileUrl.isNotEmpty)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          fileUrl
                              .split('?')
                              .first
                              .split('.')
                              .last
                              .toUpperCase(),
                          style: const TextStyle(
                              color: Colors.tealAccent,
                              fontSize: 8,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Details & Action buttons
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Wrap(
                        spacing: 4,
                        runSpacing: 2,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.teal.withAlpha(38),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.teal.withAlpha(51)),
                            ),
                            child: Text(
                              category.toUpperCase(),
                              style: const TextStyle(
                                  color: Colors.tealAccent,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (asset['type'] == 'badge' &&
                              (asset['verifyLevel'] ?? 0) > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blueAccent.withAlpha(50),
                                borderRadius: BorderRadius.circular(4),
                                border:
                                    Border.all(color: Colors.blueAccent.withAlpha(80)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.verified,
                                      size: 10, color: Colors.lightBlueAccent),
                                  const SizedBox(width: 2),
                                  Text(
                                    'VL ${asset['verifyLevel']}',
                                    style: const TextStyle(
                                        color: Colors.lightBlueAccent,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          if ((asset['starRating'] ?? 1) > 1)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.withAlpha(40),
                                borderRadius: BorderRadius.circular(4),
                                border:
                                    Border.all(color: Colors.amber.withAlpha(70)),
                              ),
                              child: Text(
                                '★ ${asset['starRating']}',
                                style: const TextStyle(
                                    color: Colors.amber,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.diamond,
                              color: Colors.tealAccent, size: 14),
                          const SizedBox(width: 2),
                          Text(
                            '$price',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: asset['type'] == 'gift'
                            ? null
                            : () => _assignAsset(asset),
                        icon: const Icon(Icons.send,
                            size: 14, color: Colors.white),
                        label: Text(asset['type'] == 'gift' ? 'N/A' : 'Assign',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.withAlpha(200),
                          disabledBackgroundColor: Colors.grey.withAlpha(100),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 0),
                          minimumSize: const Size(0, 28),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.layers_clear_outlined,
            color: Colors.tealAccent.withAlpha(102), size: 56),
        const SizedBox(height: 16),
        const Text(
          'No Assets Found',
          style: TextStyle(
              color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          'Assignment available for Official Items only.',
          style: TextStyle(color: Colors.white30, fontSize: 12),
        ),
      ],
    );
  }
}

/// Custom painter to draw a checkered chess grid to highlight transparent assets
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double squareSize = 8;
    final Paint lightPaint = Paint()..color = Colors.white.withAlpha(15);
    final Paint darkPaint = Paint()..color = Colors.transparent;

    for (double y = 0; y < size.height; y += squareSize) {
      for (double x = 0; x < size.width; x += squareSize) {
        final bool isLight =
            ((x / squareSize).floor() + (y / squareSize).floor()) % 2 == 0;
        canvas.drawRect(
          Rect.fromLTWH(x, y, squareSize, squareSize),
          isLight ? lightPaint : darkPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AssignAssetDialog extends StatefulWidget {
  final Map<String, dynamic> asset;
  final Function(String message, {bool isError}) onShowSnackBar;

  const _AssignAssetDialog({
    required this.asset,
    required this.onShowSnackBar,
  });

  @override
  State<_AssignAssetDialog> createState() => _AssignAssetDialogState();
}

class _AssignAssetDialogState extends State<_AssignAssetDialog> {
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _customDaysController = TextEditingController();

  Map<String, dynamic>? _foundUser;
  String? _targetDocId;
  bool _isSearching = false;
  String? _searchError;
  Timer? _debounceTimer;

  int? _selectedDays; // null = Permanent
  bool _isCustomDays = false;
  bool _isAssigning = false;

  @override
  void dispose() {
    _userIdController.dispose();
    _customDaysController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      _performSearch(val.trim());
    });
  }

  Future<void> _performSearch(String input) async {
    if (input.isEmpty) {
      setState(() {
        _foundUser = null;
        _targetDocId = null;
        _searchError = null;
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = null;
    });

    try {
      // 1. Direct match by document ID
      final directDoc =
          await FirebaseFirestore.instance.collection('Users').doc(input).get();
      if (directDoc.exists && directDoc.data() != null) {
        if (mounted) {
          setState(() {
            _foundUser = directDoc.data();
            _targetDocId = directDoc.id;
            _isSearching = false;
          });
        }
        return;
      }

      // 2. Search by searchId field (string)
      final searchIdQuery = await FirebaseFirestore.instance
          .collection('Users')
          .where('searchId', isEqualTo: input)
          .limit(1)
          .get();

      if (searchIdQuery.docs.isNotEmpty) {
        final doc = searchIdQuery.docs.first;
        if (mounted) {
          setState(() {
            _foundUser = doc.data();
            _targetDocId = doc.id;
            _isSearching = false;
          });
        }
        return;
      }

      // 3. Search by searchId field (int fallback if numeric input)
      final numInput = int.tryParse(input);
      if (numInput != null) {
        final numSearchQuery = await FirebaseFirestore.instance
            .collection('Users')
            .where('searchId', isEqualTo: numInput)
            .limit(1)
            .get();

        if (numSearchQuery.docs.isNotEmpty) {
          final doc = numSearchQuery.docs.first;
          if (mounted) {
            setState(() {
              _foundUser = doc.data();
              _targetDocId = doc.id;
              _isSearching = false;
            });
          }
          return;
        }
      }

      // 4. Search by fullname
      final fullnameQuery = await FirebaseFirestore.instance
          .collection('Users')
          .where('fullname', isEqualTo: input)
          .limit(1)
          .get();

      if (fullnameQuery.docs.isNotEmpty) {
        final doc = fullnameQuery.docs.first;
        if (mounted) {
          setState(() {
            _foundUser = doc.data();
            _targetDocId = doc.id;
            _isSearching = false;
          });
        }
        return;
      }

      // 5. Search by username or name
      final nameQuery = await FirebaseFirestore.instance
          .collection('Users')
          .where('username', isEqualTo: input)
          .limit(1)
          .get();

      if (nameQuery.docs.isNotEmpty) {
        final doc = nameQuery.docs.first;
        if (mounted) {
          setState(() {
            _foundUser = doc.data();
            _targetDocId = doc.id;
            _isSearching = false;
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _foundUser = null;
          _targetDocId = null;
          _searchError = 'User not found with ID/Name "$input"';
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _foundUser = null;
          _targetDocId = null;
          _searchError = 'Search error: $e';
          _isSearching = false;
        });
      }
    }
  }

  int? get _finalExpirationDays {
    if (_isCustomDays) {
      final txt = _customDaysController.text.trim();
      final parsed = int.tryParse(txt);
      if (parsed != null && parsed > 0) return parsed;
      return null;
    }
    return _selectedDays;
  }

  String get _expiryPreviewText {
    final days = _finalExpirationDays;
    if (days == null || days <= 0) {
      return 'Infinity / Permanent (Never expires)';
    }
    final expiryDate = DateTime.now().add(Duration(days: days));
    final formattedDate =
        "${expiryDate.year}-${expiryDate.month.toString().padLeft(2, '0')}-${expiryDate.day.toString().padLeft(2, '0')}";
    return 'Valid for $days days (Expires on $formattedDate)';
  }

  Future<void> _submitAssignment() async {
    if (_targetDocId == null || _foundUser == null) {
      widget.onShowSnackBar('Please search and select a valid user first',
          isError: true);
      return;
    }

    setState(() => _isAssigning = true);

    try {
      final String finalDocId = _targetDocId!;
      final int? expirationDays = _finalExpirationDays;

      await StoreService().assignStoreItemToUser(
        userId: finalDocId,
        storeItemId: widget.asset['id'],
        assignedBy: 'admin_dashboard',
        expirationDays: expirationDays,
        assetData: widget.asset,
      );

      if (mounted) {
        Navigator.pop(context, true);
        final userName = (_foundUser!['fullname'] ??
                _foundUser!['name'] ??
                _foundUser!['username'] ??
                finalDocId)
            .toString();
        widget.onShowSnackBar(
            '✅ Successfully assigned "${widget.asset['name']}" to $userName!');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAssigning = false);
        widget.onShowSnackBar('❌ Assignment failed: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final assetName = widget.asset['name'] ?? 'Asset';
    final assetType = widget.asset['type'] ?? 'Item';
    final imageUrl = (widget.asset['thumbnailUrl'] ??
        widget.asset['fileUrl'] ??
        widget.asset['imageUrl'] ??
        widget.asset['image'] ??
        '') as String;

    final String? userPhotoUrl = _foundUser != null
        ? (_foundUser!['photoUrl'] ??
                _foundUser!['imageUrl'] ??
                _foundUser!['profileImageUrl'] ??
                _foundUser!['avatarUrl'])
            ?.toString()
        : null;

    final String userName = _foundUser != null
        ? (_foundUser!['fullname'] ??
                _foundUser!['name'] ??
                _foundUser!['username'] ??
                _foundUser!['displayName'] ??
                _foundUser!['nickname'] ??
                'User')
            .toString()
        : 'User';

    return Dialog(
      backgroundColor: const Color(0xFF1F2026),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dialog Header
              Row(
                children: [
                  if (imageUrl.isNotEmpty)
                    Container(
                      width: 44,
                      height: 44,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: UniversalAssetWidget(
                          url: imageUrl,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Assign "$assetName"',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.pinkAccent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            assetType.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.pinkAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close,
                        color: Colors.white54, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 16),

              // Search Section Header
              const Text(
                'Search Target User',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),

              // Search Field
              TextField(
                controller: _userIdController,
                onChanged: _onSearchChanged,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Enter User ID or Search ID...',
                  hintStyle:
                      const TextStyle(color: Colors.white30, fontSize: 13),
                  prefixIcon: const Icon(Icons.search,
                      color: Colors.pinkAccent, size: 20),
                  suffixIcon: _isSearching
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.pinkAccent),
                          ),
                        )
                      : (_userIdController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear,
                                  color: Colors.white30, size: 18),
                              onPressed: () {
                                _userIdController.clear();
                                _performSearch('');
                              },
                            )
                          : null),
                  filled: true,
                  fillColor: Colors.black26,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Colors.pinkAccent, width: 1.5),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // User Preview Card
              if (_foundUser != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: Colors.teal.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.teal.shade800,
                        backgroundImage:
                            (userPhotoUrl != null && userPhotoUrl.isNotEmpty)
                                ? NetworkImage(userPhotoUrl)
                                : null,
                        child: (userPhotoUrl == null || userPhotoUrl.isEmpty)
                            ? const Icon(Icons.person,
                                color: Colors.white, size: 24)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    userName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.check_circle,
                                    color: Colors.tealAccent, size: 16),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'ID: ${_foundUser!['searchId'] ?? _targetDocId}',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ] else if (_searchError != null) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Colors.redAccent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.redAccent, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _searchError!,
                          style: const TextStyle(
                              color: Colors.redAccent, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Expiration / Duration Section
              const Text(
                'Assign Expiration Duration',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildDurationChip(label: 'Permanent', days: null),
                  _buildDurationChip(label: '7 Days', days: 7),
                  _buildDurationChip(label: '30 Days', days: 30),
                  _buildDurationChip(label: '90 Days', days: 90),
                  _buildDurationChip(label: '365 Days', days: 365),
                  _buildDurationChip(label: 'Custom', isCustom: true),
                ],
              ),

              if (_isCustomDays) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _customDaysController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Enter number of days (e.g. 14)',
                    hintStyle:
                        const TextStyle(color: Colors.white30, fontSize: 12),
                    filled: true,
                    fillColor: Colors.black26,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // Expiry Preview Text Box
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    Icon(
                      _finalExpirationDays == null
                          ? Icons.all_inclusive
                          : Icons.event_available,
                      color: _finalExpirationDays == null
                          ? Colors.amberAccent
                          : Colors.tealAccent,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _expiryPreviewText,
                        style: TextStyle(
                          color: _finalExpirationDays == null
                              ? Colors.amberAccent
                              : Colors.tealAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _isAssigning ? null : () => Navigator.pop(context),
                    child: const Text('Cancel',
                        style: TextStyle(color: Colors.white54)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: (_isAssigning || _targetDocId == null)
                        ? null
                        : _submitAssignment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pinkAccent,
                      disabledBackgroundColor: Colors.grey.shade800,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isAssigning
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'Assign Item',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDurationChip(
      {required String label, int? days, bool isCustom = false}) {
    final bool isSelected =
        isCustom ? _isCustomDays : (!_isCustomDays && _selectedDays == days);

    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.white70,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
      ),
      selected: isSelected,
      selectedColor: Colors.pinkAccent,
      backgroundColor: Colors.black26,
      onSelected: (_) {
        setState(() {
          if (isCustom) {
            _isCustomDays = true;
          } else {
            _isCustomDays = false;
            _selectedDays = days;
          }
        });
      },
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? Colors.pinkAccent : Colors.white12,
        ),
      ),
    );
  }
}

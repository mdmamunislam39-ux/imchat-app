import 'package:flutter/material.dart';
import '../models/gift.dart';
import '../services/gift_service.dart';
import '../widgets/gift_form_dialog.dart';
import '../widgets/gift_card.dart';

/// Admin screen for managing gifts
class AdminGiftsScreen extends StatefulWidget {
  const AdminGiftsScreen({super.key});

  @override
  State<AdminGiftsScreen> createState() => _AdminGiftsScreenState();
}

class _AdminGiftsScreenState extends State<AdminGiftsScreen> {
  final GiftService _giftService = GiftService();
  List<Gift> _gifts = [];
  bool _isLoading = false;
  String _selectedCategory = 'all';

  @override
  void initState() {
    super.initState();
    _loadGifts();
  }

  Future<void> _loadGifts() async {
    try {
      debugPrint('🔄 AdminGiftsScreen: Starting to load gifts...');
      setState(() => _isLoading = true);
      
      final gifts = await _giftService.getAllGifts();
      debugPrint('📦 AdminGiftsScreen: Loaded ${gifts.length} gifts');
      
      setState(() {
        _gifts = gifts;
        _isLoading = false;
      });
      debugPrint('✅ AdminGiftsScreen: Gifts loaded successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ AdminGiftsScreen: Error loading gifts: $e');
      debugPrint('❌ AdminGiftsScreen: Stack trace: $stackTrace');
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to load gifts: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _testGiftService() async {
    try {
      debugPrint('🧪 AdminGiftsScreen: Testing gift service...');
      
      // Test adding a simple gift without files
      debugPrint('🧪 AdminGiftsScreen: Testing gift creation...');
      final giftId = await _giftService.addGift(
        name: 'Test Gift ${DateTime.now().millisecondsSinceEpoch}',
        category: 'love',
        credits: 100,
        pngFile: null,
        svgaFile: null,
        skipFileUpload: true, // Fast test mode
      );
      
      debugPrint('✅ AdminGiftsScreen: Test gift created with ID: $giftId');
      _showSuccessSnackBar('Test completed successfully! Gift ID: $giftId');
      
      // Reload gifts to show the test gift
      await _loadGifts();
      
    } catch (e, stackTrace) {
      debugPrint('❌ AdminGiftsScreen: Test failed: $e');
      debugPrint('❌ AdminGiftsScreen: Stack trace: $stackTrace');
      _showErrorSnackBar('Test failed: $e');
    }
  }

  Future<void> _addGift() async {
    try {
      debugPrint('🎁 AdminGiftsScreen: Opening add gift dialog...');
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => GiftFormDialog(
          giftService: _giftService,
        ),
      );

      debugPrint('🎁 AdminGiftsScreen: Dialog result: $result');
      if (result == true) {
        debugPrint('🔄 AdminGiftsScreen: Reloading gifts...');
        await _loadGifts();
        _showSuccessSnackBar('Gift added successfully!');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ AdminGiftsScreen: Error in _addGift: $e');
      debugPrint('❌ AdminGiftsScreen: Stack trace: $stackTrace');
      _showErrorSnackBar('Failed to add gift: $e');
    }
  }

  Future<void> _editGift(Gift gift) async {
    final result = await showDialog<Gift?>(
      context: context,
      builder: (context) => GiftFormDialog(
        giftService: _giftService,
        gift: gift,
      ),
    );

    if (result != null) {
      _loadGifts();
      _showSuccessSnackBar('Gift updated successfully!');
    }
  }

  Future<void> _deleteGift(Gift gift) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Gift'),
        content: Text('Are you sure you want to delete "${gift.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _giftService.deleteGift(gift.id);
        _loadGifts();
        _showSuccessSnackBar('Gift deleted successfully!');
      } catch (e) {
        _showErrorSnackBar('Failed to delete gift: $e');
      }
    }
  }

  List<Gift> get _filteredGifts {
    if (_selectedCategory == 'all') {
      return _gifts;
    }
    return _gifts.where((gift) => gift.category == _selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        title: const Text(
          'Gift Management',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF2A2A2A),
        elevation: 0,
        actions: [
          // Debug test button
          IconButton(
            onPressed: _testGiftService,
            icon: const Icon(Icons.bug_report, color: Colors.orange),
          ),
          IconButton(
            onPressed: _addGift,
            icon: const Icon(Icons.add, color: Colors.white),
          ),
        ],
      ),
      body: Column(
        children: [
          // Category filter
          Container(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildCategoryChip('all', 'All'),
                  const SizedBox(width: 8),
                  ..._gifts.map((g) => g.category).toSet().map(
                    (category) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _buildCategoryChip(
                        category,
                        category.toUpperCase(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Gifts list
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : _filteredGifts.isEmpty
                    ? const Center(
                        child: Text(
                          'No gifts found',
                          style: TextStyle(color: Colors.white70),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.8,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: _filteredGifts.length,
                        itemBuilder: (context, index) {
                          final gift = _filteredGifts[index];
                          return GiftCard(
                            gift: gift,
                            onEdit: () => _editGift(gift),
                            onDelete: () => _deleteGift(gift),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String value, String label) {
    final isSelected = _selectedCategory == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00BCD4) : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF00BCD4) : Colors.white.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

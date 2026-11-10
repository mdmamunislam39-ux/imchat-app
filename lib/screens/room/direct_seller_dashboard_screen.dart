import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:chat_messenger/components/dynamic_diamond_icon.dart';
import 'package:chat_messenger/api/official_team_api.dart';
import 'package:chat_messenger/services/role_service.dart';

/// Direct Seller Dashboard
/// Allows Direct Sellers to add regular sellers, transfer diamonds from their balance,
/// view real-time sales and balances of their sellers, and remove sellers.
class DirectSellerDashboardScreen extends StatefulWidget {
  final User currentUser;
  const DirectSellerDashboardScreen({super.key, required this.currentUser});

  @override
  State<DirectSellerDashboardScreen> createState() => _DirectSellerDashboardScreenState();
}

class _DirectSellerDashboardScreenState extends State<DirectSellerDashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchFilter = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied: $text'),
        backgroundColor: Colors.cyanAccent,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Transfer diamonds to seller dialog
  Future<void> _transferDiamondsDialog(Map<String, dynamic> sellerData, int currentDsBalance) async {
    final amountController = TextEditingController();
    final sellerId = sellerData['userId'] as String? ?? '';
    final sellerName = sellerData['sellerName'] ?? 'Seller';
    final sellerSearchId = sellerData['sellerSearchId'] ?? '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E142B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            DynamicDiamondIcon(width: 22, height: 22),
            SizedBox(width: 8),
            Text(
              'Transfer Diamonds',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('To Seller: $sellerName (ID: $sellerSearchId)',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A1D3B),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Text('Your Available Balance: ', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const DynamicDiamondIcon(width: 14, height: 14),
                    const SizedBox(width: 4),
                    Text(
                      '$currentDsBalance',
                      style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text('Amount to Transfer:', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: 'Enter diamond amount',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF2A1D3B),
                  prefixIcon: const Padding(
                    padding: EdgeInsets.all(12),
                    child: DynamicDiamondIcon(width: 18, height: 18),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('TRANSFER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    final amount = int.tryParse(amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid positive amount.'), backgroundColor: Colors.red),
      );
      return;
    }

    if (amount > currentDsBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Insufficient balance in your Direct Seller account!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.cyanAccent)),
      );

      final dsId = widget.currentUser.userId;
      final dsRef = _firestore.collection('direct_sellers').doc(dsId);

      // Locate seller doc
      final sellerQuery = await _firestore
          .collection('sellers')
          .where('userId', isEqualTo: sellerId)
          .limit(1)
          .get();

      if (sellerQuery.docs.isEmpty) {
        throw Exception('Seller record not found.');
      }

      final sellerRef = sellerQuery.docs.first.reference;

      // Atomic Transaction: deduct from direct seller and credit seller
      await _firestore.runTransaction((txn) async {
        final dsSnap = await txn.get(dsRef);
        final liveDsBalance = (dsSnap.data()?['accountBalance'] as num?)?.toInt() ?? 0;

        if (liveDsBalance < amount) {
          throw Exception('Insufficient balance in your Direct Seller account.');
        }

        // 1. Deduct DS balance & increment distributed
        txn.update(dsRef, {
          'accountBalance': FieldValue.increment(-amount),
          'totalDistributed': FieldValue.increment(amount),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // 2. Increment seller accountBalance
        txn.update(sellerRef, {
          'accountBalance': FieldValue.increment(amount),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // 3. Log transfer
        final transferRef = _firestore.collection('direct_seller_transfers').doc();
        txn.set(transferRef, {
          'id': transferRef.id,
          'directSellerId': dsId,
          'directSellerName': widget.currentUser.fullname,
          'sellerId': sellerId,
          'sellerName': sellerName,
          'sellerSearchId': sellerSearchId,
          'amount': amount,
          'timestamp': FieldValue.serverTimestamp(),
        });
      });

      // Send official notification to seller & direct seller confirmation
      try {
        await OfficialTeamApi.sendSellerBalanceNotification(
          sellerUserId: sellerId,
          amount: amount,
          creditedBy: 'Direct Seller (${widget.currentUser.fullname})',
          directSellerUserId: widget.currentUser.userId,
        );
      } catch (ex) {
        debugPrint('⚠️ Error sending official notification: $ex');
      }

      if (mounted) Navigator.pop(context); // close loading

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Successfully transferred $amount diamonds to $sellerName!'),
            backgroundColor: const Color(0xFF00B074),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Transfer failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Remove/terminate seller
  Future<void> _confirmRemoveSeller(Map<String, dynamic> sellerData) async {
    final sellerId = sellerData['userId'] as String? ?? '';
    final sellerName = sellerData['sellerName'] ?? 'Seller';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E142B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Seller', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to remove "$sellerName" as a seller?\n\nThey will lose access to the Diamond Seller portal and cannot sell diamonds.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('REMOVE SELLER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.cyanAccent)),
      );

      // Deactivate seller document
      final sellerSnap = await _firestore
          .collection('sellers')
          .where('userId', isEqualTo: sellerId)
          .limit(1)
          .get();

      if (sellerSnap.docs.isNotEmpty) {
        await sellerSnap.docs.first.reference.update({
          'isActive': false,
          'status': 'terminated',
          'terminatedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Update user in Users collection
      await _firestore.collection('Users').doc(sellerId).update({
        'isSeller': false,
        'userType': 'regular',
        'roles': FieldValue.arrayRemove([AppRoles.seller]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Decrement direct seller totalSellers count
      await _firestore.collection('direct_sellers').doc(widget.currentUser.userId).set({
        'totalSellers': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Send notification
      try {
        final userDoc = await _firestore.collection('Users').doc(sellerId).get();
        final deviceToken = userDoc.data()?['deviceToken'] ?? '';
        await OfficialTeamApi.sendOfficialMessage(
          receiverId: sellerId,
          receiverDeviceToken: deviceToken,
          messageText: '⚠️ Your seller privileges have been revoked by your Direct Seller.',
        );
      } catch (_) {}

      if (mounted) Navigator.pop(context); // close loading

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Seller "$sellerName" removed successfully.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing seller: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showAddSellerModal(int currentDsBalance) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddSellerModal(
        directSeller: widget.currentUser,
        currentDsBalance: currentDsBalance,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        title: const Text(
          'Direct Seller Panel',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        top: false,
        child: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('direct_sellers').doc(widget.currentUser.userId).snapshots(),
        builder: (context, dsSnap) {
          final dsData = dsSnap.data?.data() as Map<String, dynamic>? ?? {};
          final int availableBalance = (dsData['accountBalance'] as num?)?.toInt() ?? 0;
          final int totalDistributed = (dsData['totalDistributed'] as num?)?.toInt() ?? 0;

          return StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('sellers')
                .where('directSellerId', isEqualTo: widget.currentUser.userId)
                .snapshots(),
            builder: (context, sellersSnap) {
              final sellerDocs = sellersSnap.data?.docs ?? [];
              final allSellers = sellerDocs.map((d) => {'docId': d.id, ...d.data() as Map<String, dynamic>}).toList();

              final totalSellers = allSellers.length;
              final totalSalesAllSellers = allSellers.fold<int>(0, (sum, s) => sum + ((s['totalSales'] as num?)?.toInt() ?? 0));

              final filteredSellers = allSellers.where((s) {
                final name = (s['sellerName'] ?? '').toString().toLowerCase();
                final searchId = (s['sellerSearchId'] ?? '').toString().toLowerCase();
                final uid = (s['userId'] ?? '').toString().toLowerCase();
                return _searchFilter.isEmpty ||
                    name.contains(_searchFilter) ||
                    searchId.contains(_searchFilter) ||
                    uid.contains(_searchFilter);
              }).toList();

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // Header Profile Card
                          _buildProfileCard(),
                          const SizedBox(height: 16),
                          // Stats Grid
                          _buildStatsGrid(availableBalance, totalDistributed, totalSellers, totalSalesAllSellers),
                          const SizedBox(height: 20),
                          // Add Seller Button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: () => _showAddSellerModal(availableBalance),
                              icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
                              label: const Text(
                                '+ ADD NEW SELLER',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.cyan.shade700,
                                elevation: 4,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Search Bar
                          _buildSearchBar(),
                        ],
                      ),
                    ),
                  ),

                  // Sellers List
                  if (sellersSnap.connectionState == ConnectionState.waiting)
                    const SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(color: Colors.cyanAccent),
                        ),
                      ),
                    )
                  else if (filteredSellers.isEmpty)
                    SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.storefront_outlined, size: 64, color: Colors.white.withValues(alpha: 0.2)),
                              const SizedBox(height: 12),
                              Text(
                                _searchFilter.isNotEmpty
                                    ? 'No sellers match "$_searchFilter"'
                                    : 'You have not added any sellers yet.\nClick "+ ADD NEW SELLER" to appoint a seller under your account.',
                                style: const TextStyle(color: Colors.white54, fontSize: 14),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final seller = filteredSellers[index];
                            return _buildSellerCard(seller, availableBalance);
                          },
                          childCount: filteredSellers.length,
                        ),
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              );
            },
          );
        },
      ),
    ),
  );
  }

  Widget _buildProfileCard() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('Users').doc(widget.currentUser.userId).snapshots(),
      builder: (context, userSnap) {
        final userData = userSnap.data?.data() as Map<String, dynamic>?;

        final liveName = (userData?['fullname'] != null && userData!['fullname'].toString().trim().isNotEmpty)
            ? userData['fullname'].toString().trim()
            : (userData?['name'] != null && userData!['name'].toString().trim().isNotEmpty)
                ? userData['name'].toString().trim()
                : (widget.currentUser.fullname.isNotEmpty ? widget.currentUser.fullname : 'Direct Seller');

        final livePhotoUrl = (userData?['photoUrl'] != null && userData!['photoUrl'].toString().trim().isNotEmpty)
            ? userData['photoUrl'].toString().trim()
            : (userData?['photo_url'] != null && userData!['photo_url'].toString().trim().isNotEmpty)
                ? userData['photo_url'].toString().trim()
                : widget.currentUser.photoUrl;

        final liveSearchId = (userData?['searchId'] != null && userData!['searchId'].toString().trim().isNotEmpty)
            ? userData['searchId'].toString().trim()
            : (widget.currentUser.searchId.isNotEmpty ? widget.currentUser.searchId : 'N/A');

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0D324D), Color(0xFF1E142B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFF2E1A47),
                backgroundImage: livePhotoUrl.isNotEmpty ? NetworkImage(livePhotoUrl) : null,
                onBackgroundImageError: livePhotoUrl.isNotEmpty ? (_, __) {} : null,
                child: livePhotoUrl.isEmpty
                    ? const Icon(Icons.person, color: Colors.white, size: 28)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            liveName,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.cyanAccent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.cyanAccent, width: 1),
                          ),
                          child: const Text(
                            'DIRECT SELLER',
                            style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Search ID: $liveSearchId',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsGrid(int balance, int distributed, int sellersCount, int totalSales) {
    return Column(
      children: [
        Row(
          children: [
            // Available Balance
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E142B),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Available Balance', style: TextStyle(color: Colors.white60, fontSize: 11)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const DynamicDiamondIcon(width: 18, height: 18),
                        const SizedBox(width: 6),
                        Text(
                          '$balance',
                          style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text('Ready to transfer', style: TextStyle(color: Colors.white38, fontSize: 10)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Distributed
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E142B),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Distributed', style: TextStyle(color: Colors.white60, fontSize: 11)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const DynamicDiamondIcon(width: 18, height: 18),
                        const SizedBox(width: 6),
                        Text(
                          '$distributed',
                          style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text('Transferred to sellers', style: TextStyle(color: Colors.white38, fontSize: 10)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E142B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Your Sellers:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Text('$sellersCount', style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E142B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Sales:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Row(
                      children: [
                        const DynamicDiamondIcon(width: 12, height: 12),
                        const SizedBox(width: 4),
                        Text('$totalSales', style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      onChanged: (val) => setState(() => _searchFilter = val.trim().toLowerCase()),
      decoration: InputDecoration(
        hintText: 'Search your sellers by name or ID...',
        hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
        prefixIcon: const Icon(Icons.search, color: Colors.cyanAccent, size: 20),
        suffixIcon: _searchFilter.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchFilter = '');
                },
              )
            : null,
        filled: true,
        fillColor: const Color(0xFF1E142B),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildSellerCard(Map<String, dynamic> seller, int currentDsBalance) {
    final sellerId = (seller['userId'] ?? '').toString();
    final balance = seller['accountBalance'] ?? 0;
    final totalSales = seller['totalSales'] ?? 0;
    final isActive = seller['isActive'] ?? true;

    return StreamBuilder<DocumentSnapshot>(
      stream: sellerId.isNotEmpty
          ? _firestore.collection('Users').doc(sellerId).snapshots()
          : null,
      builder: (context, userSnap) {
        final userData = userSnap.data?.data() as Map<String, dynamic>?;

        // Real-time name from Users doc, fallback to seller collection
        final String liveName = (userData?['fullname'] != null && userData!['fullname'].toString().trim().isNotEmpty)
            ? userData['fullname'].toString().trim()
            : (userData?['name'] != null && userData!['name'].toString().trim().isNotEmpty)
                ? userData['name'].toString().trim()
                : (seller['sellerName']?.toString().trim().isNotEmpty == true
                    ? seller['sellerName'].toString().trim()
                    : 'Seller');

        // Real-time photoUrl from Users doc, fallback to seller collection
        final String livePhotoUrl = (userData?['photoUrl'] != null && userData!['photoUrl'].toString().trim().isNotEmpty)
            ? userData['photoUrl'].toString().trim()
            : (userData?['photo_url'] != null && userData!['photo_url'].toString().trim().isNotEmpty)
                ? userData['photo_url'].toString().trim()
                : (userData?['imageUrl'] != null && userData!['imageUrl'].toString().trim().isNotEmpty)
                    ? userData['imageUrl'].toString().trim()
                    : (userData?['profileImageUrl'] != null && userData!['profileImageUrl'].toString().trim().isNotEmpty)
                        ? userData['profileImageUrl'].toString().trim()
                        : (seller['photoUrl']?.toString().trim() ?? '');

        // Real-time searchId from Users doc, fallback to seller collection
        final String liveSearchId = (userData?['searchId'] != null && userData!['searchId'].toString().trim().isNotEmpty)
            ? userData['searchId'].toString().trim()
            : (seller['sellerSearchId'] != null &&
                    seller['sellerSearchId'].toString().trim().isNotEmpty &&
                    seller['sellerSearchId'].toString().trim() != 'N/A')
                ? seller['sellerSearchId'].toString().trim()
                : 'N/A';

        // Auto-sync missing or outdated searchId/name/photoUrl to sellers doc in background
        if (seller['docId'] != null && userSnap.hasData && userData != null) {
          final docId = seller['docId'] as String;
          final currentSearch = (seller['sellerSearchId'] ?? '').toString().trim();
          final currentName = (seller['sellerName'] ?? '').toString().trim();
          final currentPhoto = (seller['photoUrl'] ?? '').toString().trim();

          if ((currentSearch.isEmpty || currentSearch == 'N/A') && liveSearchId != 'N/A') {
            _firestore.collection('sellers').doc(docId).update({
              'sellerSearchId': liveSearchId,
              'sellerName': liveName,
              'photoUrl': livePhotoUrl,
              'updatedAt': FieldValue.serverTimestamp(),
            }).catchError((_) {});
          } else if (currentName != liveName || (livePhotoUrl.isNotEmpty && currentPhoto != livePhotoUrl)) {
            _firestore.collection('sellers').doc(docId).update({
              'sellerName': liveName,
              'photoUrl': livePhotoUrl,
              'updatedAt': FieldValue.serverTimestamp(),
            }).catchError((_) {});
          }
        }

        final updatedSeller = {
          ...seller,
          'sellerName': liveName,
          'sellerSearchId': liveSearchId,
          'photoUrl': livePhotoUrl,
        };

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E142B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive ? Colors.cyanAccent.withValues(alpha: 0.25) : Colors.redAccent.withValues(alpha: 0.3),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Avatar, Name, SearchID, Status
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: const Color(0xFF2E1A47),
                      backgroundImage: livePhotoUrl.isNotEmpty ? NetworkImage(livePhotoUrl) : null,
                      onBackgroundImageError: livePhotoUrl.isNotEmpty ? (_, __) {} : null,
                      child: livePhotoUrl.isEmpty
                          ? const Icon(Icons.person, color: Colors.white, size: 24)
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
                                  liveName,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isActive ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isActive ? 'ACTIVE' : 'INACTIVE',
                                  style: TextStyle(
                                    color: isActive ? Colors.greenAccent : Colors.redAccent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          GestureDetector(
                            onTap: () {
                              if (liveSearchId.isNotEmpty && liveSearchId != 'N/A') {
                                _copyToClipboard(liveSearchId, 'Seller Search ID');
                              }
                            },
                            child: Row(
                              children: [
                                Text(
                                  'Search ID: $liveSearchId',
                                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                                ),
                                if (liveSearchId.isNotEmpty && liveSearchId != 'N/A') ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.copy, color: Colors.white38, size: 12),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 10),

                // Real-time Balance & Sales Row
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A1D3B),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Wallet Balance', style: TextStyle(color: Colors.white54, fontSize: 10)),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const DynamicDiamondIcon(width: 14, height: 14),
                                const SizedBox(width: 4),
                                Text(
                                  '$balance',
                                  style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A1D3B),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total Sold', style: TextStyle(color: Colors.white54, fontSize: 10)),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const DynamicDiamondIcon(width: 14, height: 14),
                                const SizedBox(width: 4),
                                Text(
                                  '$totalSales',
                                  style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Actions: Transfer Diamonds & Remove Seller
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _transferDiamondsDialog(updatedSeller, currentDsBalance),
                        icon: const DynamicDiamondIcon(width: 14, height: 14),
                        label: const Text(
                          'TRANSFER DIAMONDS',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.cyan.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isActive)
                      ElevatedButton.icon(
                        onPressed: () => _confirmRemoveSeller(updatedSeller),
                        icon: const Icon(Icons.person_remove_rounded, size: 14, color: Colors.redAccent),
                        label: const Text(
                          'REMOVE',
                          style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.withValues(alpha: 0.1),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.4), width: 1),
                          ),
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
  }
}

/// Modal to search a user and assign them as a seller under this Direct Seller
class _AddSellerModal extends StatefulWidget {
  final User directSeller;
  final int currentDsBalance;

  const _AddSellerModal({
    required this.directSeller,
    required this.currentDsBalance,
  });

  @override
  State<_AddSellerModal> createState() => _AddSellerModalState();
}

class _AddSellerModalState extends State<_AddSellerModal> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _initialAmountController = TextEditingController(text: '0');
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isSearching = false;
  bool _isSubmitting = false;
  Map<String, dynamic>? _foundUser;
  String? _errorMessage;

  @override
  void dispose() {
    _searchController.dispose();
    _initialAmountController.dispose();
    super.dispose();
  }

  Future<void> _searchUser() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _foundUser = null;
      _errorMessage = null;
    });

    try {
      final doc = await _firestore.collection('Users').doc(query).get();
      if (doc.exists && doc.data() != null) {
        await _processFoundUser({'id': doc.id, ...doc.data()!});
        return;
      }

      final snapSearch = await _firestore
          .collection('Users')
          .where('searchId', isEqualTo: query)
          .limit(1)
          .get();
      if (snapSearch.docs.isNotEmpty) {
        await _processFoundUser({'id': snapSearch.docs.first.id, ...snapSearch.docs.first.data()});
        return;
      }

      final snapName = await _firestore
          .collection('Users')
          .where('fullname', isEqualTo: query)
          .limit(1)
          .get();
      if (snapName.docs.isNotEmpty) {
        await _processFoundUser({'id': snapName.docs.first.id, ...snapName.docs.first.data()});
        return;
      }

      setState(() {
        _errorMessage = 'No user found with that ID, Search ID, or Name.';
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Search failed: $e';
        _isSearching = false;
      });
    }
  }

  Future<void> _processFoundUser(Map<String, dynamic> userData) async {
    final targetUserId = userData['id'] as String;

    // Check if user is currently an active / running seller
    // 1. Check sellers collection
    final sellerSnap = await _firestore
        .collection('sellers')
        .where('userId', isEqualTo: targetUserId)
        .get();

    bool hasActiveSellerDoc = false;
    String? currentDsName;
    for (final doc in sellerSnap.docs) {
      final data = doc.data();
      final bool isActive = data['isActive'] == true || (data['isActive'] == null && data['status'] != 'terminated');
      if (isActive) {
        hasActiveSellerDoc = true;
        currentDsName = data['directSellerName'] as String?;
        break;
      }
    }

    // 2. Check user's own document flags
    final bool isUserSellerFlag = (userData['isSeller'] == true) ||
        (userData['userType'] == 'seller') ||
        (userData['roles'] is List && (userData['roles'] as List).contains(AppRoles.seller));

    final bool isRunningSeller = hasActiveSellerDoc || isUserSellerFlag;

    setState(() {
      _foundUser = {
        ...userData,
        'isRunningSeller': isRunningSeller,
        'activeDirectSellerName': currentDsName,
      };
      _isSearching = false;
    });
  }

  Future<void> _createSeller() async {
    if (_foundUser == null) return;

    if (_foundUser!['isRunningSeller'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot assign: User is already an active Seller.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final initialAmount = int.tryParse(_initialAmountController.text.trim()) ?? 0;
    if (initialAmount < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Initial diamonds cannot be negative.'), backgroundColor: Colors.red),
      );
      return;
    }

    if (initialAmount > widget.currentDsBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Initial amount exceeds your available diamond balance.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final targetUserId = _foundUser!['id'] as String;
      final targetName = _foundUser!['fullname'] ?? 'Seller';
      final targetSearchId = _foundUser!['searchId'] ?? '';
      final dsId = widget.directSeller.userId;
      final dsName = widget.directSeller.fullname;

      // Check if already active seller in Firestore
      final existingSellerSnap = await _firestore
          .collection('sellers')
          .where('userId', isEqualTo: targetUserId)
          .get();

      final bool hasActiveSeller = existingSellerSnap.docs.any((d) {
        final data = d.data();
        return data['isActive'] == true || (data['isActive'] == null && data['status'] != 'terminated');
      });

      final userCheckDoc = await _firestore.collection('Users').doc(targetUserId).get();
      final userCheckData = userCheckDoc.data() ?? {};
      final bool isUserSeller = (userCheckData['isSeller'] == true) ||
          (userCheckData['userType'] == 'seller') ||
          (userCheckData['roles'] is List && (userCheckData['roles'] as List).contains(AppRoles.seller));

      if (hasActiveSeller || isUserSeller) {
        setState(() {
          _isSubmitting = false;
          _foundUser!['isRunningSeller'] = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This user is already an active Seller and cannot be assigned again.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final dsRef = _firestore.collection('direct_sellers').doc(dsId);

      await _firestore.runTransaction((txn) async {
        if (initialAmount > 0) {
          final dsSnap = await txn.get(dsRef);
          final liveBalance = (dsSnap.data()?['accountBalance'] as num?)?.toInt() ?? 0;
          if (liveBalance < initialAmount) {
            throw Exception('Insufficient balance in your Direct Seller account.');
          }

          txn.update(dsRef, {
            'accountBalance': FieldValue.increment(-initialAmount),
            'totalDistributed': FieldValue.increment(initialAmount),
            'totalSellers': FieldValue.increment(1),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          txn.set(dsRef, {
            'totalSellers': FieldValue.increment(1),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }

        DocumentReference sellerRef;
        final targetPhotoUrl = (_foundUser!['photoUrl'] ?? '').toString();
        if (existingSellerSnap.docs.isNotEmpty) {
          sellerRef = existingSellerSnap.docs.first.reference;
          txn.update(sellerRef, {
            'directSellerId': dsId,
            'directSellerName': dsName,
            'sellerName': targetName,
            'sellerSearchId': targetSearchId,
            'photoUrl': targetPhotoUrl,
            'isActive': false,
            'status': 'pending_kyc',
            'kycStatus': 'not_submitted',
            if (initialAmount > 0) 'accountBalance': FieldValue.increment(initialAmount),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          sellerRef = _firestore.collection('sellers').doc();
          txn.set(sellerRef, {
            'userId': targetUserId,
            'sellerName': targetName,
            'sellerSearchId': targetSearchId,
            'photoUrl': targetPhotoUrl,
            'directSellerId': dsId,
            'directSellerName': dsName,
            'accountBalance': initialAmount,
            'totalSales': 0,
            'isActive': false,
            'status': 'pending_kyc',
            'kycStatus': 'not_submitted',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        // Update target user document - Seller option will appear with Pending status until KYC is approved by Admin
        final userRef = _firestore.collection('Users').doc(targetUserId);
        txn.update(userRef, {
          'isSeller': true,
          'sellerActive': false,
          'sellerAssigned': true,
          'sellerKycStatus': 'not_submitted',
          'roles': FieldValue.arrayUnion([AppRoles.seller]),
          'directSellerId': dsId,
          'directSellerName': dsName,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (initialAmount > 0) {
          final transferRef = _firestore.collection('direct_seller_transfers').doc();
          txn.set(transferRef, {
            'id': transferRef.id,
            'directSellerId': dsId,
            'directSellerName': dsName,
            'sellerId': targetUserId,
            'sellerName': targetName,
            'sellerSearchId': targetSearchId,
            'amount': initialAmount,
            'note': 'Initial balance upon seller creation',
            'timestamp': FieldValue.serverTimestamp(),
          });
        }
      });

      // Send official congratulation notification with KYC instructions
      try {
        final deviceToken = _foundUser!['deviceToken'] ?? '';
        await OfficialTeamApi.sendOfficialMessage(
          receiverId: targetUserId,
          receiverDeviceToken: deviceToken,
          messageText: '📋 Congratulations! You have been nominated as a Diamond Seller by Direct Seller ($dsName). Please complete your KYC verification (Real Name, NID front & back, Selfie with NID) from the Seller page to activate your seller account.\n\n📋 অভিনন্দন! আপনাকে ডিরেক্ট সেলার ($dsName) কর্তৃক ডায়মন্ড সেলার হিসেবে মনোনীত করা হয়েছে। আপনার সেলার একাউন্ট সক্রিয় করতে সেলার পেজ থেকে KYC ভেরিফিকেশন (রিয়াল নাম, এনআইডি কার্ডের ১ম ও ২য় পৃষ্ঠা এবং এনআইডি হাতে সেলফি) সাবমিট করুন।',
        );
      } catch (_) {}

      if (!mounted) return;
      Navigator.pop(context); // Close modal

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 Successfully assigned "$targetName" as a Seller! KYC verification is required to activate.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to assign seller: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final systemBottomPadding = mediaQuery.padding.bottom > 0
        ? mediaQuery.padding.bottom
        : mediaQuery.viewPadding.bottom;
    final effectiveBottom = bottomInset > 0 ? (bottomInset + 16.0) : (systemBottomPadding + 28.0);

    final bool isRunningSeller = _foundUser != null && _foundUser!['isRunningSeller'] == true;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, effectiveBottom),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Row(
                  children: const [
                    Icon(Icons.person_add_alt_1_rounded, color: Colors.cyanAccent),
                    SizedBox(width: 8),
                    Text(
                      'Add New Seller',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Search a user to appoint them as a Seller under your Direct Seller account.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'User ID, Search ID, or Full Name',
                          hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                          filled: true,
                          fillColor: const Color(0xFF2A1D3B),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          prefixIcon: const Icon(Icons.search, color: Colors.cyanAccent, size: 20),
                        ),
                        onSubmitted: (_) => _searchUser(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isSearching ? null : _searchUser,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyan.shade700,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSearching
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.search, color: Colors.white),
                    ),
                  ],
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                  ),
                ],

                if (_foundUser != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF221636),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isRunningSeller
                            ? Colors.redAccent.withValues(alpha: 0.5)
                            : Colors.cyanAccent.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundImage: _foundUser!['photoUrl'] != null &&
                                      (_foundUser!['photoUrl'] as String).isNotEmpty
                                  ? NetworkImage(_foundUser!['photoUrl'])
                                  : null,
                              child: _foundUser!['photoUrl'] == null ||
                                      (_foundUser!['photoUrl'] as String).isEmpty
                                  ? const Icon(Icons.person, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _foundUser!['fullname'] ?? 'User',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  Text(
                                    'UID: ${(_foundUser!['id'] as String).substring(0, 8)}... | SearchID: ${_foundUser!['searchId'] ?? "N/A"}',
                                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                                  ),
                                  if (isRunningSeller)
                                    const Text(
                                      '⚠️ Running Active Seller',
                                      style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Warning banner if user is currently an active seller
                        if (isRunningSeller) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.block_rounded, color: Colors.redAccent, size: 22),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Already an Active Seller',
                                        style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'This user is currently a running Seller${_foundUser!['activeDirectSellerName'] != null ? " under ${_foundUser!['activeDirectSellerName']}" : ""}. You cannot assign them. If their current seller role is removed or terminated, you will be able to assign them.',
                                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Initial Diamonds to Allocate:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                              Row(
                                children: [
                                  const Text('Max: ', style: TextStyle(color: Colors.white38, fontSize: 11)),
                                  const DynamicDiamondIcon(width: 12, height: 12),
                                  const SizedBox(width: 2),
                                  Text('${widget.currentDsBalance}', style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _initialAmountController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFF2E1A47),
                              prefixIcon: const Padding(
                                padding: EdgeInsets.all(12),
                                child: DynamicDiamondIcon(width: 16, height: 16),
                              ),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                            ),
                          ),
                        ],

                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: (_isSubmitting || isRunningSeller) ? null : _createSeller,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isRunningSeller ? Colors.grey.shade800 : Colors.cyan.shade700,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _isSubmitting
                                ? const CircularProgressIndicator(color: Colors.white)
                                : Text(
                                    isRunningSeller
                                        ? 'ALREADY AN ACTIVE SELLER'
                                        : 'ASSIGN AS SELLER',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chat_messenger/components/dynamic_bean_icon.dart';
import 'package:chat_messenger/components/dynamic_diamond_icon.dart';
import 'package:chat_messenger/api/official_team_api.dart';
import 'package:chat_messenger/models/user.dart';

class AdminWithdrawalsScreen extends StatefulWidget {
  const AdminWithdrawalsScreen({super.key});

  @override
  State<AdminWithdrawalsScreen> createState() => _AdminWithdrawalsScreenState();
}

class _AdminWithdrawalsScreenState extends State<AdminWithdrawalsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedFilter = 'all'; // all, pending, under_review, approved, rejected
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF8E44AD),
      ),
    );
  }

  void _showImagePreview(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 300,
                      color: Colors.black54,
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 200,
                    color: Colors.black87,
                    alignment: Alignment.center,
                    child: const Text('Failed to load image',
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.black87,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 22),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approveWithdrawal(
      Map<String, dynamic> data, String docId) async {
    final beanAmount = (data['beanAmount'] as num?)?.toInt() ??
        (data['amount'] as num?)?.toInt() ??
        0;
    final usdAmount = (data['usdAmount'] as num?)?.toDouble() ?? 0.0;
    final sellerId = data['sellerId'] as String? ?? data['dealerId'] as String? ?? '';
    final sellerName = data['sellerName'] as String? ?? data['dealerName'] as String? ?? 'Seller';
    final userId = data['userId'] as String? ?? '';
    final username = data['withdrawalName'] as String? ?? data['username'] as String? ?? 'User';
    final diamondReward = (beanAmount * 0.90).round();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E142B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF00C853)),
            SizedBox(width: 8),
            Text('Approve Withdrawal',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to approve this withdrawal of \$ $usdAmount ($beanAmount Beans)?',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2C1E3D),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF00C853).withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Reward Distribution (90%):',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const DynamicDiamondIcon(width: 18, height: 18),
                      const SizedBox(width: 6),
                      Text(
                        '+$diamondReward Diamonds',
                        style: const TextStyle(
                            color: Color(0xFF00E676),
                            fontSize: 15,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Will be credited to Seller: $sellerName',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C853),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Approve & Credit',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF00C853)),
      ),
    );

    try {
      // 1. Update withdrawal doc
      await _firestore.collection('withdrawals').doc(docId).update({
        'status': 'approved',
        'diamondReward': diamondReward,
        'approvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 2. Credit 90% diamonds to seller
      if (sellerId.isNotEmpty) {
        // Update seller document in 'sellers' collection
        final sellerSnap = await _firestore
            .collection('sellers')
            .where('userId', isEqualTo: sellerId)
            .limit(1)
            .get();

        String sellerDocId = '';
        if (sellerSnap.docs.isNotEmpty) {
          sellerDocId = sellerSnap.docs.first.id;
          await _firestore.collection('sellers').doc(sellerDocId).update({
            'accountBalance': FieldValue.increment(diamondReward),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          final newDoc = _firestore.collection('sellers').doc();
          sellerDocId = newDoc.id;
          await newDoc.set({
            'userId': sellerId,
            'sellerName': sellerName,
            'accountBalance': diamondReward,
            'isActive': true,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        // Also credit User diamonds
        await _firestore.collection('Users').doc(sellerId).update({
          'diamonds': FieldValue.increment(diamondReward),
        });

        // 3. Create log in seller_admin_credits
        final creditDoc = _firestore.collection('seller_admin_credits').doc();
        await creditDoc.set({
          'id': creditDoc.id,
          'sellerId': sellerId,
          'sellerDocId': sellerDocId,
          'sellerName': sellerName,
          'amount': diamondReward,
          'note': '90% Reward for processing withdrawal of $beanAmount beans (\$ $usdAmount) for user $username',
          'type': 'withdrawal_reward_90',
          'withdrawalId': docId,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Send official notification to seller
        try {
          final sellerUserDoc =
              await _firestore.collection('Users').doc(sellerId).get();
          if (sellerUserDoc.exists) {
            final sUser = User.fromMap(sellerUserDoc.data()!);
            OfficialTeamApi.sendOfficialMessage(
              receiverId: sUser.userId,
              receiverDeviceToken: sUser.deviceToken,
              messageText:
                  'Withdrawal verified! $diamondReward diamonds (90% stock) have been credited to your diamond balance for processing withdrawal #$docId.',
            );
          }
        } catch (_) {}
      }

      // Send official notification to user
      if (userId.isNotEmpty) {
        try {
          final userDoc =
              await _firestore.collection('Users').doc(userId).get();
          if (userDoc.exists) {
            final u = User.fromMap(userDoc.data()!);
            OfficialTeamApi.sendOfficialMessage(
              receiverId: u.userId,
              receiverDeviceToken: u.deviceToken,
              messageText:
                  'Your withdrawal request of \$ $usdAmount ($beanAmount Beans) has been approved and completed.',
            );
          }
        } catch (_) {}
      }

      if (mounted) {
        Navigator.pop(context); // close loader
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Withdrawal approved! +$diamondReward diamonds credited to seller.'),
            backgroundColor: const Color(0xFF00C853),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to approve withdrawal: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectWithdrawal(
      Map<String, dynamic> data, String docId) async {
    final reasonController = TextEditingController();
    final beanAmount = (data['beanAmount'] as num?)?.toInt() ??
        (data['amount'] as num?)?.toInt() ??
        0;
    final userId = data['userId'] as String? ?? '';
    final username = data['withdrawalName'] as String? ?? data['username'] as String? ?? 'User';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E142B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.cancel_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Reject Withdrawal',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rejecting this request will automatically refund $beanAmount beans back to $username\'s wallet.',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 2,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Rejection Reason (Optional)',
                labelStyle: const TextStyle(color: Colors.white60),
                hintText: 'e.g. Invalid Bkash number / Payment failed',
                hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                filled: true,
                fillColor: const Color(0xFF2C1E3D),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Reject & Refund Beans',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final reason = reasonController.text.trim().isNotEmpty
        ? reasonController.text.trim()
        : 'Request rejected by admin';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Colors.redAccent),
      ),
    );

    try {
      // 1. Update withdrawal status
      await _firestore.collection('withdrawals').doc(docId).update({
        'status': 'rejected',
        'rejectedReason': reason,
        'rejectedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 2. Refund beans to user in real time
      if (userId.isNotEmpty && beanAmount > 0) {
        await _firestore.collection('Users').doc(userId).update({
          'beans': FieldValue.increment(beanAmount),
        });

        // Send official message to user
        try {
          final userDoc =
              await _firestore.collection('Users').doc(userId).get();
          if (userDoc.exists) {
            final u = User.fromMap(userDoc.data()!);
            OfficialTeamApi.sendOfficialMessage(
              receiverId: u.userId,
              receiverDeviceToken: u.deviceToken,
              messageText:
                  'Your withdrawal request has been rejected ($reason). $beanAmount Beans have been returned to your wallet.',
            );
          }
        } catch (_) {}
      }

      if (mounted) {
        Navigator.pop(context); // close loader
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Withdrawal rejected. $beanAmount beans refunded to $username.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reject: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF130E20),
      appBar: AppBar(
        title: const Text('Withdrawal Management',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E142B),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Filter Chips and Search Bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            color: const Color(0xFF1E142B),
            child: Column(
              children: [
                // Search Input
                TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search by User, Bkash, or Seller...',
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFF2C1E3D),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                ),
                const SizedBox(height: 10),
                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All', 'all'),
                      _buildFilterChip('Pending Proof', 'pending_proof'),
                      _buildFilterChip('Under Review (Proof Submitted)', 'under_review'),
                      _buildFilterChip('Approved', 'approved'),
                      _buildFilterChip('Rejected', 'rejected'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Real-time List of Withdrawals
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('withdrawals')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.purpleAccent),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Error loading withdrawals: ${snapshot.error}',
                        style: const TextStyle(color: Colors.redAccent),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                final filteredDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final status = (data['status'] as String?)?.toLowerCase() ?? 'pending';
                  final bool proofSubmitted = data['proofSubmitted'] == true ||
                      (data['paymentScreenshots'] as List?)?.isNotEmpty == true;

                  // Filter by tab
                  if (_selectedFilter == 'pending_proof') {
                    if (status != 'pending' || proofSubmitted) return false;
                  } else if (_selectedFilter == 'under_review') {
                    if (status == 'approved' || status == 'rejected' || !proofSubmitted) return false;
                  } else if (_selectedFilter == 'approved') {
                    if (status != 'approved') return false;
                  } else if (_selectedFilter == 'rejected') {
                    if (status != 'rejected') return false;
                  }

                  // Search query
                  if (_searchQuery.isNotEmpty) {
                    final username = (data['username'] ?? '').toString().toLowerCase();
                    final wName = (data['withdrawalName'] ?? '').toString().toLowerCase();
                    final bkash = (data['accountNumber'] ?? data['withdrawalBkash'] ?? '')
                        .toString()
                        .toLowerCase();
                    final sellerName = (data['sellerName'] ?? data['dealerName'] ?? '')
                        .toString()
                        .toLowerCase();
                    final userId = (data['userId'] ?? '').toString().toLowerCase();

                    final match = username.contains(_searchQuery) ||
                        wName.contains(_searchQuery) ||
                        bkash.contains(_searchQuery) ||
                        sellerName.contains(_searchQuery) ||
                        userId.contains(_searchQuery);
                    if (!match) return false;
                  }

                  return true;
                }).toList();

                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_rounded,
                            size: 60, color: Colors.white.withValues(alpha: 0.2)),
                        const SizedBox(height: 12),
                        const Text(
                          'No withdrawal records found',
                          style: TextStyle(color: Colors.white54, fontSize: 15),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildWithdrawalCard(data, doc.id);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => setState(() => _selectedFilter = value),
        selectedColor: Colors.purpleAccent,
        backgroundColor: const Color(0xFF2C1E3D),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.white70,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? Colors.purpleAccent : Colors.transparent,
          ),
        ),
      ),
    );
  }

  Widget _buildWithdrawalCard(Map<String, dynamic> data, String docId) {
    final status = (data['status'] as String?)?.toLowerCase() ?? 'pending';
    final beanAmount = (data['beanAmount'] as num?)?.toInt() ??
        (data['amount'] as num?)?.toInt() ??
        0;
    final usdAmount = (data['usdAmount'] as num?)?.toDouble() ?? 0.0;
    final username = data['withdrawalName'] as String? ??
        data['username'] as String? ??
        'User';
    final userId = data['userId'] as String? ?? '';
    final bkash = data['withdrawalBkash'] as String? ??
        data['accountNumber'] as String? ??
        '';
    final sellerName = data['sellerName'] as String? ??
        data['dealerName'] as String? ??
        'Not assigned';
    final sellerId = data['sellerId'] as String? ?? data['dealerId'] as String? ?? '';
    final diamondReward = data['diamondReward'] ?? (beanAmount * 0.90).round();
    final screenshots = (data['paymentScreenshots'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final proofSubmitted = data['proofSubmitted'] == true || screenshots.isNotEmpty;
    final sellerNote = data['sellerNote'] as String? ?? '';
    final rejectedReason = data['rejectedReason'] as String? ?? '';

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (status == 'approved') {
      statusColor = const Color(0xFF00C853);
      statusText = 'Approved';
      statusIcon = Icons.check_circle_rounded;
    } else if (status == 'rejected') {
      statusColor = Colors.redAccent;
      statusText = 'Rejected';
      statusIcon = Icons.cancel_rounded;
    } else if (proofSubmitted) {
      statusColor = const Color(0xFF00B0FF);
      statusText = 'Proof Submitted (Review)';
      statusIcon = Icons.pending_actions_rounded;
    } else {
      statusColor = Colors.orangeAccent;
      statusText = 'Pending Seller Payment';
      statusIcon = Icons.hourglass_top_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E142B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Amount + Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF2C1E3D).withValues(alpha: 0.6),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const DynamicBeanIcon(width: 22, height: 22),
                    const SizedBox(width: 8),
                    Text(
                      '\$ $usdAmount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '($beanAmount Beans)',
                      style: const TextStyle(
                        color: Color(0xFF00B0FF),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: statusColor, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User & Bkash info
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Recipient / User:',
                              style: TextStyle(color: Colors.white54, fontSize: 11)),
                          const SizedBox(height: 2),
                          Text(
                            username,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text('ID: $userId',
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 11)),
                        ],
                      ),
                    ),
                    // Bkash number with Copy button
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2136E).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: const Color(0xFFE2136E).withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.phone_android_rounded,
                              color: Color(0xFFFF4081), size: 16),
                          const SizedBox(width: 6),
                          Text(
                            bkash.isNotEmpty ? bkash : 'N/A',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                          ),
                          if (bkash.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () => _copyToClipboard(bkash, 'Bkash number'),
                              child: const Padding(
                                padding: EdgeInsets.all(2.0),
                                child: Icon(Icons.copy_rounded,
                                    color: Colors.white70, size: 14),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Assigned Diamond Seller
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C1E3D),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.storefront_rounded,
                          color: Color(0xFFAB47BC), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Assigned Seller: $sellerName (ID: $sellerId)',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (status == 'approved') ...[
                        Row(
                          children: [
                            const DynamicDiamondIcon(width: 14, height: 14),
                            const SizedBox(width: 4),
                            Text('+$diamondReward',
                                style: const TextStyle(
                                    color: Color(0xFF00E676),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Payment Proof Screenshots
                if (screenshots.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text(
                    'Payment Proof Screenshot(s):',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 90,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: screenshots.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, i) {
                        final url = screenshots[i];
                        return GestureDetector(
                          onTap: () => _showImagePreview(context, url),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Stack(
                              children: [
                                Image.network(
                                  url,
                                  width: 90,
                                  height: 90,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, p) {
                                    if (p == null) return child;
                                    return Container(
                                      width: 90,
                                      height: 90,
                                      color: const Color(0xFF2C1E3D),
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.purpleAccent),
                                      ),
                                    );
                                  },
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 90,
                                    height: 90,
                                    color: Colors.grey.shade900,
                                    child: const Icon(Icons.broken_image,
                                        color: Colors.white54),
                                  ),
                                ),
                                Positioned(
                                  bottom: 4,
                                  right: 4,
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: const BoxDecoration(
                                      color: Colors.black87,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.zoom_in_rounded,
                                        color: Colors.white, size: 14),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],

                if (sellerNote.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text('Seller Note: $sellerNote',
                      style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                          fontStyle: FontStyle.italic)),
                ],

                if (status == 'rejected' && rejectedReason.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Text('Rejection Reason: $rejectedReason',
                        style: const TextStyle(
                            color: Colors.redAccent, fontSize: 12)),
                  ),
                ],

                // Action Buttons for Pending / Under Review
                if (status == 'pending' || status == 'pending_admin_approval') ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      // Reject Button (Red)
                      Expanded(
                        child: SizedBox(
                          height: 40,
                          child: OutlinedButton.icon(
                            onPressed: () => _rejectWithdrawal(data, docId),
                            icon: const Icon(Icons.close_rounded,
                                color: Colors.redAccent, size: 18),
                            label: const Text(
                              'Reject & Refund',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.redAccent),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Approve Button (Green)
                      Expanded(
                        child: SizedBox(
                          height: 40,
                          child: ElevatedButton.icon(
                            onPressed: () => _approveWithdrawal(data, docId),
                            icon: const Icon(Icons.check_rounded,
                                color: Colors.white, size: 18),
                            label: const Text(
                              'Approve (+90%)',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00C853),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

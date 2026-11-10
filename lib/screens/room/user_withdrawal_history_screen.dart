import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:chat_messenger/components/dynamic_bean_icon.dart';
import 'package:chat_messenger/components/dynamic_diamond_icon.dart';
import 'package:chat_messenger/config/theme_config.dart';
import 'package:chat_messenger/services/gift_economy_service.dart';

class UserWithdrawalHistoryScreen extends StatefulWidget {
  final User currentUser;

  const UserWithdrawalHistoryScreen({
    super.key,
    required this.currentUser,
  });

  @override
  State<UserWithdrawalHistoryScreen> createState() =>
      _UserWithdrawalHistoryScreenState();
}

class _UserWithdrawalHistoryScreenState
    extends State<UserWithdrawalHistoryScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedFilter = 'all'; // all, action_needed, pending, completed, rejected

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
                borderRadius: BorderRadius.circular(16),
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
                    child: const Text(
                      'Failed to load image',
                      style: TextStyle(color: Colors.white),
                    ),
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

  String _formatDateTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final dt = timestamp.toDate();
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    final monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${monthNames[dt.month - 1]} ${dt.day}, ${dt.year} • $hour:$minute $ampm';
  }

  Future<void> _handleUserAccept(
      Map<String, dynamic> data, String docId) async {
    final usdAmount = (data['usdAmount'] as num?)?.toDouble() ?? 0.0;
    final beanAmount = (data['beanAmount'] as num?)?.toInt() ??
        (data['amount'] as num?)?.toInt() ??
        0;
    final sellerName = data['sellerName'] as String? ??
        data['dealerName'] as String? ??
        'Seller';
    final sellerId = data['sellerId'] as String? ??
        data['dealerId'] as String? ??
        '';
    final bkash = data['withdrawalBkash'] as String? ??
        data['accountNumber'] as String? ??
        '';
    final int sellerDiamondPercent =
        (data['sellerDiamondPercent'] as num?)?.toInt() ?? 90;
    final int diamondReward = (data['diamondReward'] as num?)?.toInt() ??
        (beanAmount * (sellerDiamondPercent / 100.0)).round();

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F8F0),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF00C853),
                size: 24,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Confirm Payment Receipt',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Have you received \$ $usdAmount ($beanAmount Beans) in your payment account ($bkash)?',
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F6F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Reward Settlement Notice:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const DynamicDiamondIcon(width: 16, height: 16),
                      const SizedBox(width: 6),
                      Text(
                        '+$diamondReward Diamonds ($sellerDiamondPercent%)',
                        style: const TextStyle(
                          color: Color(0xFF00C853),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Will be credited to Seller: $sellerName',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '⚠️ Please ensure you have received the exact amount before accepting. Once accepted, this withdrawal is permanently completed.',
              style: TextStyle(
                fontSize: 11,
                color: Colors.orange.shade800,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C853),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Yes, I Received Payment',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
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
      await GiftEconomyService.instance.userAcceptWithdrawal(
        docId: docId,
        data: data,
        userId: widget.currentUser.userId,
        userName: widget.currentUser.fullname,
        userDeviceToken: widget.currentUser.deviceToken,
      );

      if (mounted) {
        Navigator.pop(context); // close loader
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Payment confirmed! +$diamondReward Diamonds credited to $sellerName.',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF00C853),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // close loader
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to confirm withdrawal: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        systemOverlayStyle: getSystemOverlayStyle(false),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Withdrawal History',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        child: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('withdrawals')
            .where('userId', isEqualTo: widget.currentUser.userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF8E44AD)),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Error loading history: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final docs = List<QueryDocumentSnapshot>.from(
              snapshot.data?.docs ?? []);

          // Sort client-side by createdAt descending to avoid composite index requirement
          docs.sort((a, b) {
            final dataA = a.data() as Map<String, dynamic>;
            final dataB = b.data() as Map<String, dynamic>;
            final tA = dataA['createdAt'] as Timestamp?;
            final tB = dataB['createdAt'] as Timestamp?;
            if (tA == null) return 1;
            if (tB == null) return -1;
            return tB.compareTo(tA);
          });

          // Compute summary stats
          int totalRequests = docs.length;
          int pendingCount = 0;
          int actionNeededCount = 0;
          int completedCount = 0;
          int rejectedCount = 0;

          for (final doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final status =
                (data['status'] as String?)?.toLowerCase() ?? 'pending';
            final screenshots = (data['paymentScreenshots'] as List?) ?? [];
            final proofSubmitted =
                data['proofSubmitted'] == true || screenshots.isNotEmpty;

            if (status == 'approved') {
              completedCount++;
            } else if (status == 'rejected') {
              rejectedCount++;
            } else if (proofSubmitted ||
                status == 'pending_admin_approval' ||
                status == 'seller_paid') {
              actionNeededCount++;
            } else {
              pendingCount++;
            }
          }

          // Filter documents
          final filteredDocs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status =
                (data['status'] as String?)?.toLowerCase() ?? 'pending';
            final screenshots = (data['paymentScreenshots'] as List?) ?? [];
            final proofSubmitted =
                data['proofSubmitted'] == true || screenshots.isNotEmpty;

            if (_selectedFilter == 'action_needed') {
              return status != 'approved' &&
                  status != 'rejected' &&
                  (proofSubmitted ||
                      status == 'pending_admin_approval' ||
                      status == 'seller_paid');
            } else if (_selectedFilter == 'pending') {
              return status == 'pending' &&
                  !proofSubmitted &&
                  status != 'pending_admin_approval' &&
                  status != 'seller_paid';
            } else if (_selectedFilter == 'completed') {
              return status == 'approved';
            } else if (_selectedFilter == 'rejected') {
              return status == 'rejected';
            }
            return true;
          }).toList();

          return Column(
            children: [
              // Summary & Filter bar
              _buildFilterChips(
                totalCount: totalRequests,
                actionNeededCount: actionNeededCount,
                pendingCount: pendingCount,
                completedCount: completedCount,
                rejectedCount: rejectedCount,
              ),

              // Action required banner (if any)
              if (actionNeededCount > 0 && _selectedFilter != 'action_needed')
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedFilter = 'action_needed';
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0288D1).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF0288D1).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.notifications_active_rounded,
                          color: Color(0xFF0288D1),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '$actionNeededCount withdrawal(s) have been paid by seller! Tap here to review & accept.',
                            style: const TextStyle(
                              color: Color(0xFF0277BD),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Color(0xFF0277BD),
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                ),

              // List of withdrawals
              Expanded(
                child: filteredDocs.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(14),
                        itemCount: filteredDocs.length,
                        itemBuilder: (context, index) {
                          final doc = filteredDocs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          return _buildWithdrawalCard(data, doc.id);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

  Widget _buildFilterChips({
    required int totalCount,
    required int actionNeededCount,
    required int pendingCount,
    required int completedCount,
    required int rejectedCount,
  }) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            _buildFilterChip('all', 'All ($totalCount)'),
            const SizedBox(width: 8),
            _buildFilterChip(
              'action_needed',
              'Payment Sent ($actionNeededCount)',
              badgeColor: const Color(0xFF0288D1),
              highlight: actionNeededCount > 0,
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              'pending',
              'Pending ($pendingCount)',
              badgeColor: Colors.orange,
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              'completed',
              'Completed ($completedCount)',
              badgeColor: const Color(0xFF00C853),
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              'rejected',
              'Rejected ($rejectedCount)',
              badgeColor: Colors.redAccent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(
    String key,
    String label, {
    Color? badgeColor,
    bool highlight = false,
  }) {
    final bool isSelected = _selectedFilter == key;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = key;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? (badgeColor ?? const Color(0xFF8E44AD))
              : (highlight
                  ? (badgeColor ?? const Color(0xFF8E44AD))
                      .withValues(alpha: 0.12)
                  : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : (highlight
                    ? (badgeColor ?? const Color(0xFF8E44AD))
                    : Colors.grey.shade300),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected || highlight
                ? FontWeight.bold
                : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (highlight
                    ? (badgeColor ?? const Color(0xFF8E44AD))
                    : Colors.black87),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_rounded,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 14),
          Text(
            _selectedFilter == 'action_needed'
                ? 'No payments waiting for confirmation'
                : 'No withdrawal records found in this category.',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your future withdrawal activities will appear here.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildWithdrawalCard(Map<String, dynamic> data, String docId) {
    final status = (data['status'] as String?)?.toLowerCase() ?? 'pending';
    final beanAmount = (data['beanAmount'] as num?)?.toInt() ??
        (data['amount'] as num?)?.toInt() ??
        0;
    final usdAmount = (data['usdAmount'] as num?)?.toDouble() ?? 0.0;
    final sellerName = data['sellerName'] as String? ??
        data['dealerName'] as String? ??
        'Seller';
    final sellerId = data['sellerId'] as String? ??
        data['dealerId'] as String? ??
        '';
    final bkash = data['withdrawalBkash'] as String? ??
        data['accountNumber'] as String? ??
        '';
    final withdrawalName = data['withdrawalName'] as String? ??
        data['username'] as String? ??
        '';
    final screenshots = (data['paymentScreenshots'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final proofSubmitted =
        data['proofSubmitted'] == true || screenshots.isNotEmpty;
    final sellerNote = data['sellerNote'] as String? ?? '';
    final rejectedReason = data['rejectedReason'] as String? ?? '';
    final createdAt = data['createdAt'] as Timestamp?;
    final userConfirmed = data['userConfirmed'] == true;
    final int sellerDiamondPercent =
        (data['sellerDiamondPercent'] as num?)?.toInt() ?? 90;
    final int diamondReward = (data['diamondReward'] as num?)?.toInt() ??
        (beanAmount * (sellerDiamondPercent / 100.0)).round();

    final bool isActionRequired = status != 'approved' &&
        status != 'rejected' &&
        (proofSubmitted ||
            status == 'pending_admin_approval' ||
            status == 'seller_paid');

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (status == 'approved') {
      statusColor = const Color(0xFF00C853);
      statusText = userConfirmed
          ? 'Completed (You Confirmed)'
          : 'Completed & Approved';
      statusIcon = Icons.check_circle_rounded;
    } else if (status == 'rejected') {
      statusColor = Colors.redAccent;
      statusText = 'Rejected (Beans Refunded)';
      statusIcon = Icons.cancel_rounded;
    } else if (isActionRequired) {
      statusColor = const Color(0xFF0288D1);
      statusText = 'Payment Sent (Action Needed)';
      statusIcon = Icons.notifications_active_rounded;
    } else {
      statusColor = Colors.orange;
      statusText = 'Processing (Waiting for Seller)';
      statusIcon = Icons.hourglass_top_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActionRequired
              ? const Color(0xFF0288D1).withValues(alpha: 0.6)
              : statusColor.withValues(alpha: 0.25),
          width: isActionRequired ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isActionRequired
                ? const Color(0xFF0288D1).withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const DynamicBeanIcon(width: 20, height: 20),
                    const SizedBox(width: 6),
                    Text(
                      '\$ $usdAmount',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '($beanAmount Beans)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
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
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Seller details & Account info
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.storefront_rounded,
                                  size: 15, color: Color(0xFF8E44AD)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Seller: $sellerName',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (sellerId.isNotEmpty)
                            Text(
                              'Seller ID: $sellerId',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          if (createdAt != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              _formatDateTime(createdAt),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Payment number (Bkash)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2136E).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color:
                              const Color(0xFFE2136E).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.phone_android_rounded,
                                  color: Color(0xFFE2136E), size: 14),
                              const SizedBox(width: 4),
                              Text(
                                bkash.isNotEmpty ? bkash : 'N/A',
                                style: const TextStyle(
                                  color: Color(0xFFC2185B),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              if (bkash.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                InkWell(
                                  onTap: () =>
                                      _copyToClipboard(bkash, 'Bkash number'),
                                  child: const Icon(Icons.copy_rounded,
                                      color: Color(0xFFE2136E), size: 13),
                                ),
                              ],
                            ],
                          ),
                          if (withdrawalName.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              withdrawalName,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                // Seller Note / TrxID
                if (sellerNote.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.receipt_rounded,
                            size: 16, color: Color(0xFF0288D1)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Seller Note / TrxID: $sellerNote',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () =>
                              _copyToClipboard(sellerNote, 'Transaction ID'),
                          child: const Icon(Icons.copy_rounded,
                              size: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],

                // Screenshots
                if (screenshots.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'Payment Screenshots from Seller (Tap to view):',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 75,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: screenshots.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final url = screenshots[i];
                        return GestureDetector(
                          onTap: () => _showImagePreview(context, url),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Stack(
                              children: [
                                Image.network(
                                  url,
                                  width: 75,
                                  height: 75,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, p) {
                                    if (p == null) return child;
                                    return Container(
                                      width: 75,
                                      height: 75,
                                      color: Colors.grey.shade200,
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFF8E44AD)),
                                      ),
                                    );
                                  },
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 75,
                                    height: 75,
                                    color: Colors.grey.shade200,
                                    child: const Icon(Icons.broken_image,
                                        color: Colors.grey),
                                  ),
                                ),
                                Positioned(
                                  bottom: 3,
                                  right: 3,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Colors.black87,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.zoom_in_rounded,
                                        color: Colors.white, size: 12),
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

                // Rejection Reason
                if (status == 'rejected' && rejectedReason.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      'Rejection Reason: $rejectedReason',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade900,
                      ),
                    ),
                  ),
                ],

                // Action Required Box & Accept Button
                if (isActionRequired) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE1F5FE),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF0288D1).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: Color(0xFF0288D1),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Seller has sent payment. Please check your account and tap "Accept" once you receive the funds.',
                            style: TextStyle(
                              color: Color(0xFF01579B),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: () => _handleUserAccept(data, docId),
                      icon: const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      label: const Text(
                        'পেমেন্ট বুঝে পেয়েছি (Accept Payment)',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00C853),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],

                // Completed Info
                if (status == 'approved') ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F8F0),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF00C853).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified_rounded,
                            size: 16, color: Color(0xFF00C853)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Settled: +$diamondReward Diamonds credited to Seller $sellerName.',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF1B5E20),
                              fontWeight: FontWeight.bold,
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
        ],
      ),
    );
  }
}


import 'package:chat_messenger/components/cached_circle_avatar.dart';
import 'package:chat_messenger/components/dynamic_diamond_icon.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Admin Panel screen to review, approve, reject seller diamond top-up requests
/// and directly credit seller diamond balance with custom Admin Notes.
class AdminSellerRequestsScreen extends StatefulWidget {
  const AdminSellerRequestsScreen({super.key});

  @override
  State<AdminSellerRequestsScreen> createState() =>
      _AdminSellerRequestsScreenState();
}

class _AdminSellerRequestsScreenState extends State<AdminSellerRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final List<String> _tabs = ['Pending', 'Approved', 'Rejected', 'All'];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
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
        backgroundColor: Colors.purpleAccent,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatDateTime(Timestamp? timestamp) {
    if (timestamp == null) return 'Recent';
    final date = timestamp.toDate();
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
      'Dec'
    ];
    final hour = date.hour > 12
        ? date.hour - 12
        : (date.hour == 0 ? 12 : date.hour);
    final ampm = date.hour >= 12 ? 'PM' : 'AM';
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.day} ${months[date.month - 1]} ${date.year}, $hour:$minute $ampm';
  }

  Future<void> _approveRequest(Map<String, dynamic> request) async {
    final currentAdmin = fb_auth.FirebaseAuth.instance.currentUser;
    final adminId = currentAdmin?.uid ?? 'admin';
    final adminName = currentAdmin?.displayName ?? 'Admin';
    final String reqId = request['id'] ?? '';
    final String sellerId = request['sellerId'] ?? '';
    final String sellerName = request['sellerName'] ?? 'Seller';
    final String sellerSearchId = request['sellerSearchId'] ?? '';
    final int amount = (request['amount'] as num?)?.toInt() ?? 0;
    final String paymentMethod = request['paymentMethod'] ?? 'bKash';
    final String trxId = request['transactionId'] ?? '';

    final noteController = TextEditingController(
      text: 'Approved payment via $paymentMethod${trxId.isNotEmpty ? ' (TrxID: $trxId)' : ''}',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E142B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Approve Seller Top-Up',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Seller: $sellerName (ID: $sellerSearchId)',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Text('Diamonds to Add: ', style: TextStyle(color: Colors.white70)),
                  const DynamicDiamondIcon(width: 14, height: 14),
                  const SizedBox(width: 4),
                  Text('+$amount',
                      style: const TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ],
              ),
              if (trxId.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('TrxID: $trxId', style: const TextStyle(color: Colors.white70, fontFamily: 'monospace')),
              ],
              const SizedBox(height: 14),
              const Text('Admin Note for Seller (Saved in Seller History):',
                  style: TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: noteController,
                maxLines: 2,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF2A1B3D),
                  hintText: 'Enter note/remarks for seller...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(10),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00B074),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('APPROVE & CREDIT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: Colors.purpleAccent),
        ),
      );

      // 1. Locate seller document
      final sellerSnap = await _firestore
          .collection('sellers')
          .where('userId', isEqualTo: sellerId)
          .limit(1)
          .get();

      String sellerDocId = '';
      if (sellerSnap.docs.isNotEmpty) {
        sellerDocId = sellerSnap.docs.first.id;
        await _firestore.collection('sellers').doc(sellerDocId).update({
          'accountBalance': FieldValue.increment(amount),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Create seller doc if not existing
        final newDoc = _firestore.collection('sellers').doc();
        sellerDocId = newDoc.id;
        await newDoc.set({
          'userId': sellerId,
          'sellerName': sellerName,
          'accountBalance': amount,
          'totalSales': 0,
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // 2. Add record in seller_admin_credits
      final creditDoc = _firestore.collection('seller_admin_credits').doc();
      await creditDoc.set({
        'id': creditDoc.id,
        'sellerId': sellerId,
        'sellerDocId': sellerDocId,
        'sellerName': sellerName,
        'sellerSearchId': sellerSearchId,
        'amount': amount,
        'note': noteController.text.trim(),
        'adminNote': noteController.text.trim(),
        'adminId': adminId,
        'adminName': adminName,
        'type': 'request_approved',
        'requestId': reqId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3. Update request status to approved
      await _firestore.collection('seller_diamond_requests').doc(reqId).update({
        'status': 'approved',
        'adminNote': noteController.text.trim(),
        'processedBy': adminName,
        'adminId': adminId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context); // close loader
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 Successfully credited $amount diamonds to $sellerName!'),
            backgroundColor: const Color(0xFF00B074),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // close loader
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error approving request: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _rejectRequest(Map<String, dynamic> request) async {
    final currentAdmin = fb_auth.FirebaseAuth.instance.currentUser;
    final adminId = currentAdmin?.uid ?? 'admin';
    final adminName = currentAdmin?.displayName ?? 'Admin';
    final String reqId = request['id'] ?? '';
    final String sellerName = request['sellerName'] ?? 'Seller';

    final noteController = TextEditingController(text: 'Payment not received / Invalid TrxID');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E142B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reject Top-Up Request', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to reject request from $sellerName?', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            const Text('Reason / Note for Seller:', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: noteController,
              maxLines: 2,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF2A1B3D),
                hintText: 'Enter rejection reason...',
                hintStyle: const TextStyle(color: Colors.white38),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(10),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('REJECT REQUEST', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _firestore.collection('seller_diamond_requests').doc(reqId).update({
        'status': 'rejected',
        'adminNote': noteController.text.trim(),
        'processedBy': adminName,
        'adminId': adminId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request marked as Rejected'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error rejecting: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _openDirectCreditDialog() {
    final searchController = TextEditingController();
    final amountController = TextEditingController();
    final noteController = TextEditingController(text: 'Admin manual diamond top-up');
    Map<String, dynamic>? selectedUser;
    bool isSearching = false;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E142B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: const Row(
                children: [
                  Icon(Icons.add_circle_outline_rounded, color: Colors.purpleAccent),
                  SizedBox(width: 8),
                  Text('Direct Credit Seller', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Search Seller by Search ID or User ID:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: searchController,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFF2A1B3D),
                              hintText: 'Enter Search ID',
                              hintStyle: const TextStyle(color: Colors.white38),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
                          onPressed: isSearching
                              ? null
                              : () async {
                                  final query = searchController.text.trim();
                                  if (query.isEmpty) return;
                                  setDialogState(() => isSearching = true);
                                  try {
                                    final snap = await _firestore
                                        .collection('Users')
                                        .where('searchId', isEqualTo: query)
                                        .limit(1)
                                        .get();
                                    if (snap.docs.isNotEmpty) {
                                      setDialogState(() {
                                        selectedUser = snap.docs.first.data();
                                        isSearching = false;
                                      });
                                    } else {
                                      // Search by docId
                                      final doc = await _firestore.collection('Users').doc(query).get();
                                      setDialogState(() {
                                        selectedUser = doc.exists ? doc.data() : null;
                                        isSearching = false;
                                      });
                                    }
                                  } catch (e) {
                                    setDialogState(() => isSearching = false);
                                  }
                                },
                          child: isSearching
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Search', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                    if (selectedUser != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A1B3D),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.purpleAccent.withOpacity(0.4)),
                        ),
                        child: Row(
                          children: [
                            CachedCircleAvatar(imageUrl: selectedUser!['photoUrl'] ?? '', radius: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(selectedUser!['fullname'] ?? 'User', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                  Text('ID: ${selectedUser!['searchId'] ?? ''}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                ],
                              ),
                            ),
                            const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 18),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          labelText: 'Diamond Amount *',
                          labelStyle: const TextStyle(color: Colors.purpleAccent),
                          filled: true,
                          fillColor: const Color(0xFF2A1B3D),
                          prefixIcon: const Padding(padding: EdgeInsets.all(10), child: DynamicDiamondIcon(width: 14, height: 14)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: noteController,
                        maxLines: 2,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Admin Note (visible to seller)',
                          labelStyle: const TextStyle(color: Colors.amberAccent),
                          filled: true,
                          fillColor: const Color(0xFF2A1B3D),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                ),
                if (selectedUser != null)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00B074)),
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final amt = int.tryParse(amountController.text.trim()) ?? 0;
                            if (amt <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please enter valid diamonds'), backgroundColor: Colors.red),
                              );
                              return;
                            }

                            setDialogState(() => isSubmitting = true);

                            try {
                              final currentAdmin = fb_auth.FirebaseAuth.instance.currentUser;
                              final adminId = currentAdmin?.uid ?? 'admin';
                              final adminName = currentAdmin?.displayName ?? 'Admin';
                              final sId = selectedUser!['userId'] ?? '';
                              final sName = selectedUser!['fullname'] ?? 'Seller';
                              final sSearchId = selectedUser!['searchId'] ?? '';

                              // 1. Update seller collection
                              final sellerSnap = await _firestore
                                  .collection('sellers')
                                  .where('userId', isEqualTo: sId)
                                  .limit(1)
                                  .get();

                              String sellerDocId = '';
                              if (sellerSnap.docs.isNotEmpty) {
                                sellerDocId = sellerSnap.docs.first.id;
                                await _firestore.collection('sellers').doc(sellerDocId).update({
                                  'accountBalance': FieldValue.increment(amt),
                                  'updatedAt': FieldValue.serverTimestamp(),
                                });
                              } else {
                                final newDoc = _firestore.collection('sellers').doc();
                                sellerDocId = newDoc.id;
                                await newDoc.set({
                                  'userId': sId,
                                  'sellerName': sName,
                                  'accountBalance': amt,
                                  'totalSales': 0,
                                  'isActive': true,
                                  'createdAt': FieldValue.serverTimestamp(),
                                  'updatedAt': FieldValue.serverTimestamp(),
                                });
                              }

                              // 2. Add credit record with note
                              final creditDoc = _firestore.collection('seller_admin_credits').doc();
                              await creditDoc.set({
                                'id': creditDoc.id,
                                'sellerId': sId,
                                'sellerDocId': sellerDocId,
                                'sellerName': sName,
                                'sellerSearchId': sSearchId,
                                'amount': amt,
                                'note': noteController.text.trim(),
                                'adminNote': noteController.text.trim(),
                                'adminId': adminId,
                                'adminName': adminName,
                                'type': 'direct_topup',
                                'createdAt': FieldValue.serverTimestamp(),
                              });

                              if (mounted) {
                                Navigator.pop(dialogCtx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('✅ Successfully loaded $amt diamonds to $sName!'),
                                    backgroundColor: const Color(0xFF00B074),
                                  ),
                                );
                              }
                            } catch (e) {
                              setDialogState(() => isSubmitting = false);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
                                );
                              }
                            }
                          },
                    child: isSubmitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('CREDIT DIAMONDS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF140C1F),
      appBar: AppBar(
        title: const Text(
          'Seller Diamond Management',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF1E142B),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: 'Direct Credit Seller',
            icon: const Icon(Icons.add_circle_rounded, color: Colors.purpleAccent, size: 26),
            onPressed: _openDirectCreditDialog,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.purpleAccent,
          labelColor: Colors.purpleAccent,
          unselectedLabelColor: Colors.white54,
          isScrollable: true,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search by Seller Name, Search ID, or TrxID...',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.white38),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white38),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF1E142B),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _tabs.map((tab) => _buildRequestsList(tab.toLowerCase())).toList(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.purpleAccent,
        onPressed: _openDirectCreditDialog,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Credit Seller Diamonds', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildRequestsList(String filterStatus) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('seller_diamond_requests').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.purpleAccent));
        }

        final allDocs = snapshot.data?.docs ?? [];
        final List<QueryDocumentSnapshot> docs = List.from(allDocs);

        // Sort descending by createdAt in memory
        docs.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>?;
          final dataB = b.data() as Map<String, dynamic>?;
          final tA = dataA?['createdAt'] as Timestamp?;
          final tB = dataB?['createdAt'] as Timestamp?;
          if (tA == null && tB == null) return 0;
          if (tA == null) return 1;
          if (tB == null) return -1;
          return tB.compareTo(tA);
        });

        final filteredDocs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = (data['status'] ?? 'pending').toString().toLowerCase();
          if (filterStatus != 'all' && status != filterStatus) {
            return false;
          }
          if (_searchQuery.isEmpty) return true;
          final name = (data['sellerName'] ?? '').toString().toLowerCase();
          final sId = (data['sellerSearchId'] ?? '').toString().toLowerCase();
          final trx = (data['transactionId'] ?? '').toString().toLowerCase();
          return name.contains(_searchQuery) || sId.contains(_searchQuery) || trx.contains(_searchQuery);
        }).toList();

        if (filteredDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined, size: 56, color: Colors.white24),
                const SizedBox(height: 12),
                Text('No ${filterStatus.toUpperCase()} requests found',
                    style: const TextStyle(color: Colors.white54, fontSize: 14)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(left: 12, right: 12, top: 4, bottom: 80),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final data = filteredDocs[index].data() as Map<String, dynamic>;
            final amount = (data['amount'] as num?)?.toInt() ?? 0;
            final sellerName = data['sellerName'] ?? 'Seller';
            final sellerSearchId = data['sellerSearchId'] ?? '';
            final sellerPhoto = data['sellerPhoto'] ?? '';
            final paymentMethod = data['paymentMethod'] ?? 'bKash';
            final trxId = data['transactionId'] ?? '';
            final sellerNote = data['note'] ?? '';
            final adminNote = data['adminNote'] ?? '';
            final status = (data['status'] as String?)?.toLowerCase() ?? 'pending';
            final timestamp = data['createdAt'] as Timestamp?;

            Color statusColor = Colors.orange;
            if (status == 'approved') statusColor = Colors.greenAccent;
            if (status == 'rejected') statusColor = Colors.redAccent;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E142B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: statusColor.withOpacity(0.3), width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CachedCircleAvatar(imageUrl: sellerPhoto, radius: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(sellerName,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                            Text('Search ID: $sellerSearchId',
                                style: const TextStyle(color: Colors.white54, fontSize: 12)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: statusColor.withOpacity(0.4)),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white12, height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const DynamicDiamondIcon(width: 18, height: 18),
                          const SizedBox(width: 6),
                          Text(
                            '+$amount',
                            style: const TextStyle(
                              color: Colors.amberAccent,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text('Diamonds', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.purpleAccent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(paymentMethod,
                            style: const TextStyle(color: Colors.purpleAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  if (trxId.toString().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => _copyToClipboard(trxId, 'TrxID'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A1B3D),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('TrxID: ', style: TextStyle(color: Colors.white54, fontSize: 12)),
                            Text(trxId,
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                            const SizedBox(width: 6),
                            const Icon(Icons.copy_rounded, color: Colors.white54, size: 14),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (sellerNote.toString().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Seller Note: $sellerNote',
                        style: const TextStyle(color: Colors.white70, fontSize: 12, fontStyle: FontStyle.italic)),
                  ],
                  if (adminNote.toString().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A1B3D),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('Admin Note: $adminNote',
                          style: const TextStyle(color: Colors.amberAccent, fontSize: 12)),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(_formatDateTime(timestamp), style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  if (status == 'pending') ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: const BorderSide(color: Colors.redAccent),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.close, size: 16),
                            label: const Text('REJECT'),
                            onPressed: () => _rejectRequest(data),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00B074),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.check, size: 16),
                            label: const Text('APPROVE'),
                            onPressed: () => _approveRequest(data),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

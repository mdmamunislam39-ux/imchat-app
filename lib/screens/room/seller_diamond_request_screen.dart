import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:chat_messenger/components/cached_circle_avatar.dart';
import 'package:chat_messenger/components/dynamic_diamond_icon.dart';
import 'package:chat_messenger/components/dynamic_bean_icon.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SellerDiamondRequestScreen extends StatefulWidget {
  final User currentUser;

  const SellerDiamondRequestScreen({super.key, required this.currentUser});

  @override
  State<SellerDiamondRequestScreen> createState() =>
      _SellerDiamondRequestScreenState();
}

class _SellerDiamondRequestScreenState extends State<SellerDiamondRequestScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

  void _openRequestDialog() {
    final amountController = TextEditingController();
    final trxIdController = TextEditingController();
    final noteController = TextEditingController();
    String selectedMethod = 'bKash';
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8E44AD).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const DynamicDiamondIcon(width: 22, height: 22),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Request Diamonds / Stock',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                'Send request to Admin for Seller Balance',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Quick select diamond amounts
                    const Text(
                      'Select Quick Amount',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [10000, 50000, 100000, 500000, 1000000].map((amt) {
                        return ActionChip(
                          avatar: const DynamicDiamondIcon(width: 14, height: 14),
                          label: Text(
                            amt >= 1000000
                                ? '${(amt / 1000000).toStringAsFixed(0)}M'
                                : (amt >= 1000 ? '${(amt / 1000).toStringAsFixed(0)}K' : '$amt'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          backgroundColor: Colors.purple.shade50,
                          side: BorderSide(color: Colors.purple.shade200),
                          onPressed: () {
                            setSheetState(() {
                              amountController.text = amt.toString();
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Diamond Amount Input
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Diamond Amount *',
                        hintText: 'e.g. 50000',
                        prefixIcon: const Padding(
                          padding: EdgeInsets.all(12),
                          child: DynamicDiamondIcon(width: 16, height: 16),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Payment Method Dropdown
                    DropdownButtonFormField<String>(
                      value: selectedMethod,
                      decoration: InputDecoration(
                        labelText: 'Payment Method',
                        prefixIcon: const Icon(Icons.payment_rounded,
                            color: Color(0xFF8E44AD)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'bKash', child: Text('bKash')),
                        DropdownMenuItem(value: 'Nagad', child: Text('Nagad')),
                        DropdownMenuItem(value: 'Rocket', child: Text('Rocket')),
                        DropdownMenuItem(
                            value: 'Bank Transfer', child: Text('Bank Transfer')),
                        DropdownMenuItem(value: 'Cash / Hand', child: Text('Cash / Hand')),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setSheetState(() => selectedMethod = val);
                        }
                      },
                    ),
                    const SizedBox(height: 14),

                    // TrxID Input
                    TextField(
                      controller: trxIdController,
                      decoration: InputDecoration(
                        labelText: 'Transaction ID / Reference (TrxID)',
                        hintText: 'e.g. 9J8K7L6M5N',
                        prefixIcon: const Icon(Icons.tag_rounded,
                            color: Colors.grey),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Note Input
                    TextField(
                      controller: noteController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Seller Note / Details (Optional)',
                        hintText: 'e.g. Paid from 017xxxxxxxx, urgent stock needed',
                        prefixIcon: const Icon(Icons.note_alt_outlined,
                            color: Colors.grey),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8E44AD),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 2,
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final amt =
                                    int.tryParse(amountController.text.trim()) ??
                                        0;
                                if (amt <= 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Please enter a valid diamond amount'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }

                                setSheetState(() => isSubmitting = true);

                                try {
                                  final reqDoc = _firestore
                                      .collection('seller_diamond_requests')
                                      .doc();

                                  await reqDoc.set({
                                    'id': reqDoc.id,
                                    'sellerId': widget.currentUser.userId,
                                    'userId': widget.currentUser.userId,
                                    'sellerName': widget.currentUser.fullname,
                                    'sellerSearchId':
                                        widget.currentUser.searchId,
                                    'sellerPhoto': widget.currentUser.photoUrl,
                                    'amount': amt,
                                    'paymentMethod': selectedMethod,
                                    'transactionId':
                                        trxIdController.text.trim(),
                                    'note': noteController.text.trim(),
                                    'status': 'pending',
                                    'createdAt': FieldValue.serverTimestamp(),
                                    'updatedAt': FieldValue.serverTimestamp(),
                                  });

                                  if (mounted) {
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            '✅ Diamond top-up request submitted successfully! Admin will review shortly.'),
                                        backgroundColor: Colors.green,
                                        duration: Duration(seconds: 4),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setSheetState(() => isSubmitting = false);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Failed to submit: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                        child: isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.send_rounded, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text(
                                    'SUBMIT REQUEST',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Diamond Stock & Top-Up'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        titleTextStyle: const TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        actions: [
          IconButton(
            tooltip: 'Request Diamonds',
            icon: const Icon(Icons.add_circle_outline_rounded,
                color: Color(0xFF8E44AD), size: 26),
            onPressed: _openRequestDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeaderStockCard(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAdminCreditsTab(),
                _buildMyRequestsTab(),
                _buildUserWithdrawalsTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF8E44AD),
        onPressed: _openRequestDialog,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Request Diamonds',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildHeaderStockCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('sellers')
          .where('userId', isEqualTo: widget.currentUser.userId)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        int balance = 0;
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final data =
              snapshot.data!.docs.first.data() as Map<String, dynamic>?;
          balance = (data?['accountBalance'] as num?)?.toInt() ?? 0;
        }

        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF9B51E0), Color(0xFF6B21A8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6B21A8).withOpacity(0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      CachedCircleAvatar(
                        imageUrl: widget.currentUser.photoUrl,
                        radius: 20,
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.currentUser.fullname,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'OFFICIAL SELLER',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _openRequestDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded,
                              size: 16, color: Color(0xFF6B21A8)),
                          SizedBox(width: 4),
                          Text(
                            'Request',
                            style: TextStyle(
                              color: Color(0xFF6B21A8),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'Current Available Diamond Stock',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const DynamicDiamondIcon(width: 24, height: 24),
                  const SizedBox(width: 8),
                  Text(
                    '$balance',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: const Color(0xFF8E44AD),
        unselectedLabelColor: Colors.grey.shade600,
        indicatorColor: const Color(0xFF8E44AD),
        indicatorWeight: 3,
        tabs: const [
          Tab(
            icon: Icon(Icons.verified_rounded, size: 20),
            text: 'Admin Credited Logs',
          ),
          Tab(
            icon: Icon(Icons.history_rounded, size: 20),
            text: 'My Top-Up Requests',
          ),
          Tab(
            icon: Icon(Icons.price_check_rounded, size: 20),
            text: 'Withdrawals',
          ),
        ],
      ),
    );
  }

  Widget _buildAdminCreditsTab() {
    final uid = widget.currentUser.userId;
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('seller_admin_credits').snapshots(),
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
                'Error loading logs: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final allDocs = snapshot.data?.docs ?? [];
        final List<QueryDocumentSnapshot> docs = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          final sId = data['sellerId']?.toString();
          final uId = data['userId']?.toString();
          final searchId = data['sellerSearchId']?.toString();
          return sId == uid ||
              uId == uid ||
              (searchId != null &&
                  searchId.isNotEmpty &&
                  searchId == widget.currentUser.searchId);
        }).toList();

        // Sort descending by createdAt in memory (avoids missing composite index error)
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

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2_outlined,
                    size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 14),
                Text(
                  'No Admin Credits Yet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'When Admin adds or approves diamonds into your seller account, the records with Admin notes will appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 80),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final amount = (data['amount'] as num?)?.toInt() ?? 0;
            final adminNote = data['note'] ?? data['adminNote'] ?? '';
            final adminName = data['adminName'] ?? 'Admin Panel';
            final timestamp = data['createdAt'] as Timestamp?;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.green.shade100),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_downward_rounded,
                              color: Colors.green, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        '+',
                                        style: TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                      const DynamicDiamondIcon(
                                          width: 16, height: 16),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$amount',
                                        style: const TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: Colors.green.shade200),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.check_circle_rounded,
                                            size: 12,
                                            color: Colors.green.shade700),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Added to Stock',
                                          style: TextStyle(
                                            color: Colors.green.shade800,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.admin_panel_settings_rounded,
                                      size: 13, color: Colors.grey.shade500),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Processed by $adminName',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    _formatDateTime(timestamp),
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (adminNote.toString().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.sticky_note_2_rounded,
                                size: 16, color: Color(0xFF8E44AD)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Admin Note: $adminNote',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF334155),
                                  fontWeight: FontWeight.w500,
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
            );
          },
        );
      },
    );
  }

  Widget _buildMyRequestsTab() {
    final uid = widget.currentUser.userId;
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('seller_diamond_requests').snapshots(),
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
                'Error loading requests: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final allDocs = snapshot.data?.docs ?? [];
        final List<QueryDocumentSnapshot> docs = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          final sId = data['sellerId']?.toString();
          final uId = data['userId']?.toString();
          final searchId = data['sellerSearchId']?.toString();
          return sId == uid ||
              uId == uid ||
              (searchId != null &&
                  searchId.isNotEmpty &&
                  searchId == widget.currentUser.searchId);
        }).toList();

        // Sort descending by createdAt in memory (avoids missing composite index error)
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

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history_toggle_off_rounded,
                    size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 14),
                Text(
                  'No Requests Found',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tap "Request Diamonds" to send a stock request to admin.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 80),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final amount = (data['amount'] as num?)?.toInt() ?? 0;
            final status = (data['status'] as String?)?.toLowerCase() ?? 'pending';
            final paymentMethod = data['paymentMethod'] ?? 'bKash';
            final trxId = data['transactionId'] ?? '';
            final note = data['note'] ?? '';
            final adminNote = data['adminNote'] ?? '';
            final timestamp = data['createdAt'] as Timestamp?;

            Color statusColor = Colors.orange;
            Color statusBg = Colors.orange.shade50;
            String statusText = 'Pending';
            IconData statusIcon = Icons.hourglass_top_rounded;

            if (status == 'approved') {
              statusColor = Colors.green;
              statusBg = Colors.green.shade50;
              statusText = 'Approved';
              statusIcon = Icons.check_circle_rounded;
            } else if (status == 'rejected') {
              statusColor = Colors.red;
              statusBg = Colors.red.shade50;
              statusText = 'Rejected';
              statusIcon = Icons.cancel_rounded;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: status == 'approved'
                      ? Colors.green.shade200
                      : (status == 'rejected'
                          ? Colors.red.shade200
                          : Colors.grey.shade200),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const DynamicDiamondIcon(width: 18, height: 18),
                          const SizedBox(width: 6),
                          Text(
                            '$amount',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Diamonds',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: statusColor.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, size: 13, color: statusColor),
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
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          paymentMethod,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple.shade700,
                          ),
                        ),
                      ),
                      if (trxId.toString().isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          'TrxID: $trxId',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const Spacer(),
                      Text(
                        _formatDateTime(timestamp),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                  if (note.toString().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Seller Note: $note',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  if (adminNote.toString().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: status == 'rejected'
                            ? Colors.red.shade50
                            : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: status == 'rejected'
                              ? Colors.red.shade200
                              : Colors.blue.shade200,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            status == 'rejected'
                                ? Icons.error_outline_rounded
                                : Icons.info_outline_rounded,
                            size: 14,
                            color: status == 'rejected'
                                ? Colors.red.shade700
                                : Colors.blue.shade700,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Admin Note: $adminNote',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: status == 'rejected'
                                    ? Colors.red.shade900
                                    : Colors.blue.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
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

  // =========================================================================
  // TAB 3: USER WITHDRAWALS (Real-time Seller Withdrawal Proof Management)
  // =========================================================================
  Widget _buildUserWithdrawalsTab() {
    final uid = widget.currentUser.userId;

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('withdrawals')
          .orderBy('createdAt', descending: true)
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
                'Error loading withdrawals: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        final myWithdrawals = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final sellerId = data['sellerId'] as String? ?? data['dealerId'] as String? ?? '';
          return sellerId == uid;
        }).toList();

        if (myWithdrawals.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.receipt_long_rounded,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 12),
                Text(
                  'No withdrawal requests assigned to you yet.',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: myWithdrawals.length,
          itemBuilder: (context, index) {
            final doc = myWithdrawals[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildSellerWithdrawalCard(data, doc.id);
          },
        );
      },
    );
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

  void _openUploadProofSheet(String docId, Map<String, dynamic> data) {
    final noteController = TextEditingController(text: data['sellerNote'] ?? '');
    List<File> selectedFiles = [];
    final existingScreenshots = (data['paymentScreenshots'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    bool isUploading = false;
    final ImagePicker picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Row(
                      children: [
                        Icon(Icons.cloud_upload_rounded,
                            color: Color(0xFF8E44AD), size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Upload Payment Screenshot',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Provide proof that payment was sent to user\'s Bkash account.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 16),

                    // Pick image buttons (Single & Multiple supported)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: isUploading
                                ? null
                                : () async {
                                    final List<XFile> images =
                                        await picker.pickMultiImage();
                                    if (images.isNotEmpty) {
                                      setSheetState(() {
                                        for (var img in images) {
                                          selectedFiles.add(File(img.path));
                                        }
                                      });
                                    }
                                  },
                            icon: const Icon(Icons.photo_library_rounded,
                                color: Color(0xFF8E44AD), size: 20),
                            label: const Text(
                              'Gallery / Multiple',
                              style: TextStyle(
                                color: Color(0xFF8E44AD),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF8E44AD)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: isUploading
                                ? null
                                : () async {
                                    final XFile? image = await picker.pickImage(
                                        source: ImageSource.camera);
                                    if (image != null) {
                                      setSheetState(() {
                                        selectedFiles.add(File(image.path));
                                      });
                                    }
                                  },
                            icon: const Icon(Icons.camera_alt_rounded,
                                color: Color(0xFF8E44AD), size: 20),
                            label: const Text(
                              'Camera',
                              style: TextStyle(
                                color: Color(0xFF8E44AD),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF8E44AD)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Previews of selected files
                    if (selectedFiles.isNotEmpty) ...[
                      const Text(
                        'Selected Screenshots:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 90,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: selectedFiles.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 8),
                          itemBuilder: (context, i) {
                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.file(
                                    selectedFiles[i],
                                    width: 90,
                                    height: 90,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: -6,
                                  right: -6,
                                  child: GestureDetector(
                                    onTap: () {
                                      setSheetState(() {
                                        selectedFiles.removeAt(i);
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close,
                                          color: Colors.white, size: 14),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Note / TxID
                    TextField(
                      controller: noteController,
                      decoration: InputDecoration(
                        labelText: 'Transaction ID / Note (Optional)',
                        hintText: 'e.g. TrxID: 9J3K28L9 Sent via Bkash App',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xFF8E44AD), width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: (isUploading ||
                                (selectedFiles.isEmpty &&
                                    existingScreenshots.isEmpty))
                            ? null
                            : () async {
                                setSheetState(() => isUploading = true);
                                try {
                                  List<String> uploadedUrls =
                                      List.from(existingScreenshots);

                                  for (int i = 0;
                                      i < selectedFiles.length;
                                      i++) {
                                    final file = selectedFiles[i];
                                    final fileName =
                                        '${docId}_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
                                    final ref = FirebaseStorage.instance
                                        .ref()
                                        .child('withdrawals/proofs/$fileName');
                                    final uploadTask = await ref.putFile(file);
                                    final downloadUrl =
                                        await uploadTask.ref.getDownloadURL();
                                    uploadedUrls.add(downloadUrl);
                                  }

                                  await _firestore
                                      .collection('withdrawals')
                                      .doc(docId)
                                      .update({
                                    'paymentScreenshots': uploadedUrls,
                                    'proofSubmitted': true,
                                    'sellerNote':
                                        noteController.text.trim(),
                                    'proofSubmittedAt':
                                        FieldValue.serverTimestamp(),
                                    'status': 'pending_admin_approval',
                                    'updatedAt': FieldValue.serverTimestamp(),
                                  });

                                  if (mounted) {
                                    Navigator.pop(sheetCtx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Payment proof submitted for admin approval!'),
                                        backgroundColor: Color(0xFF00C853),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  debugPrint('Error uploading proof: $e');
                                  if (mounted) {
                                    setSheetState(() => isUploading = false);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'Failed to upload proof: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00C853),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: isUploading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Submit Proof to Admin',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSellerWithdrawalCard(
      Map<String, dynamic> data, String docId) {
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
    final screenshots = (data['paymentScreenshots'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final proofSubmitted =
        data['proofSubmitted'] == true || screenshots.isNotEmpty;
    final sellerNote = data['sellerNote'] as String? ?? '';
    final rejectedReason = data['rejectedReason'] as String? ?? '';
    final diamondReward = data['diamondReward'] ?? (beanAmount * 0.90).round();
    final createdAt = data['createdAt'] as Timestamp?;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (status == 'approved') {
      statusColor = const Color(0xFF00C853);
      statusText = 'Approved (+90% Diamonds)';
      statusIcon = Icons.check_circle_rounded;
    } else if (status == 'rejected') {
      statusColor = Colors.red;
      statusText = 'Rejected (Refunded)';
      statusIcon = Icons.cancel_rounded;
    } else if (proofSubmitted) {
      statusColor = const Color(0xFF00B0FF);
      statusText = 'Proof Submitted (Review)';
      statusIcon = Icons.pending_actions_rounded;
    } else {
      statusColor = Colors.orange;
      statusText = 'Payment Pending';
      statusIcon = Icons.hourglass_top_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
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
                    const SizedBox(width: 4),
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
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: statusColor, size: 13),
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
                // User info & Bkash
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            username,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            'User ID: $userId',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          if (createdAt != null) ...[
                            Text(
                              _formatDateTime(createdAt),
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Bkash number with Copy button
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2136E).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color:
                              const Color(0xFFE2136E).withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.phone_android_rounded,
                              color: Color(0xFFE2136E), size: 16),
                          const SizedBox(width: 6),
                          Text(
                            bkash.isNotEmpty ? bkash : 'N/A',
                            style: const TextStyle(
                              color: Color(0xFFC2185B),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                          ),
                          if (bkash.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () =>
                                  _copyToClipboard(bkash, 'Bkash number'),
                              child: const Padding(
                                padding: EdgeInsets.all(2.0),
                                child: Icon(Icons.copy_rounded,
                                    color: Color(0xFFE2136E), size: 14),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                // Screenshot Preview Strip (if uploaded)
                if (screenshots.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Uploaded Payment Proof:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 80,
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
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, p) {
                                    if (p == null) return child;
                                    return Container(
                                      width: 80,
                                      height: 80,
                                      color: Colors.grey.shade200,
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFF8E44AD)),
                                      ),
                                    );
                                  },
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 80,
                                    height: 80,
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

                if (sellerNote.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Your Note: $sellerNote',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],

                if (status == 'approved') ...[
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F8F0),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color:
                              const Color(0xFF00C853).withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const DynamicDiamondIcon(width: 16, height: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Diamond Reward Credited: +$diamondReward Diamonds (90%)',
                          style: const TextStyle(
                            color: Color(0xFF1B5E20),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (status == 'rejected' && rejectedReason.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      'Admin Rejection Reason: $rejectedReason',
                      style: TextStyle(
                        color: Colors.red.shade900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],

                // Upload / Update Proof Button
                if (status == 'pending' ||
                    status == 'pending_admin_approval') ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: ElevatedButton.icon(
                      onPressed: () => _openUploadProofSheet(docId, data),
                      icon: Icon(
                        proofSubmitted
                            ? Icons.edit_rounded
                            : Icons.upload_file_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      label: Text(
                        proofSubmitted
                            ? 'Update / Add More Screenshots'
                            : 'Upload Payment Proof (স্ক্রিনশট দিন)',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: proofSubmitted
                            ? const Color(0xFF0288D1)
                            : const Color(0xFF8E44AD),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
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

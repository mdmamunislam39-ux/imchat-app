import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:get/get.dart';
import 'package:chat_messenger/api/official_team_api.dart';
import 'package:chat_messenger/components/cached_circle_avatar.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:chat_messenger/services/role_service.dart';
import 'package:intl/intl.dart';

class AdminSellerProcessingScreen extends StatefulWidget {
  const AdminSellerProcessingScreen({super.key});

  @override
  State<AdminSellerProcessingScreen> createState() =>
      _AdminSellerProcessingScreenState();
}

class _AdminSellerProcessingScreenState
    extends State<AdminSellerProcessingScreen> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showZoomDialog(BuildContext context, String imageUrl, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              backgroundColor: Colors.black,
              title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            Flexible(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (c, w, p) => p == null
                      ? w
                      : const Center(child: CircularProgressIndicator(color: Colors.purpleAccent)),
                  errorBuilder: (c, e, s) => const Center(
                    child: Icon(Icons.broken_image, color: Colors.white54, size: 50),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approveApplication(Map<String, dynamic> appData, String docId) async {
    final targetUserId = (appData['userId'] ?? '').toString();
    final targetName = (appData['userName'] ?? 'User').toString();
    final targetSearchId = (appData['userSearchId'] ?? '').toString();
    final dsId = (appData['directSellerId'] ?? '').toString();
    final dsName = (appData['directSellerName'] ?? '').toString();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A1C3D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.greenAccent),
            const SizedBox(width: 8),
            Text('Confirm Approval'.tr, style: const TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Text(
          'Are you sure you want to approve "$targetName" (ID: $targetSearchId) as an active Seller?\n\nApproving will immediately activate their seller dashboard.',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel'.tr, style: const TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Approve'.tr, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final currentAdminId = fb_auth.FirebaseAuth.instance.currentUser?.uid ?? 'admin';

      // 1. Update seller_kyc_applications
      await _firestore.collection('seller_kyc_applications').doc(docId).update({
        'status': 'approved',
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': currentAdminId,
      });

      // 2. Update sellers collection document
      final sellerSnap = await _firestore
          .collection('sellers')
          .where('userId', isEqualTo: targetUserId)
          .limit(1)
          .get();

      if (sellerSnap.docs.isNotEmpty) {
        await sellerSnap.docs.first.reference.update({
          'isActive': true,
          'status': 'active',
          'kycStatus': 'approved',
          'approvedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // If doc didn't exist somehow, create it
        await _firestore.collection('sellers').add({
          'userId': targetUserId,
          'sellerName': targetName,
          'sellerSearchId': targetSearchId,
          'photoUrl': appData['userPhoto'] ?? '',
          'directSellerId': dsId,
          'directSellerName': dsName,
          'accountBalance': 0,
          'totalSales': 0,
          'isActive': true,
          'status': 'active',
          'kycStatus': 'approved',
          'approvedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // 3. Update Users collection document
      final userRef = _firestore.collection('Users').doc(targetUserId);
      final userDoc = await userRef.get();
      final userDeviceToken = (userDoc.data()?['deviceToken'] ?? '').toString();

      await userRef.update({
        'isSeller': true,
        'userType': 'seller',
        'sellerActive': true,
        'sellerKycStatus': 'approved',
        'roles': FieldValue.arrayUnion([AppRoles.seller]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 4. Send official notification to the seller user
      try {
        await OfficialTeamApi.sendOfficialMessage(
          receiverId: targetUserId,
          receiverDeviceToken: userDeviceToken,
          messageText: '🎉 Congratulations! Your Seller KYC verification has been approved by Admin. Your Diamond Seller dashboard is now fully active.\n\n🎉 অভিনন্দন! আপনার সেলার ভেরিফিকেশন (KYC) আবেদন অ্যাডমিন কর্তৃক অনুমোদিত হয়েছে। এখন থেকে আপনার ডায়মন্ড সেলার ড্যাশবোর্ড পুরোপুরি সক্রিয়।',
        );
      } catch (_) {}

      // 5. Send official notification to direct seller (if exists)
      if (dsId.isNotEmpty) {
        try {
          final dsDoc = await _firestore.collection('direct_sellers').doc(dsId).get();
          final dsUserId = dsDoc.data()?['userId'] ?? dsId;
          final dsUserDoc = await _firestore.collection('Users').doc(dsUserId).get();
          final dsToken = (dsUserDoc.data()?['deviceToken'] ?? '').toString();

          await OfficialTeamApi.sendOfficialMessage(
            receiverId: dsUserId,
            receiverDeviceToken: dsToken,
            messageText: '✅ Your appointed seller "$targetName" (ID: $targetSearchId) has been approved by Admin.\n\n✅ আপনার নিযুক্ত সেলার "$targetName" (ID: $targetSearchId)-এর ভেরিফিকেশন অ্যাডমিন প্যানেল কর্তৃক অনুমোদিত হয়েছে।',
          );
        } catch (_) {}
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 Seller "$targetName" approved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Approval failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _rejectApplication(Map<String, dynamic> appData, String docId) async {
    final targetUserId = (appData['userId'] ?? '').toString();
    final targetName = (appData['userName'] ?? 'User').toString();
    final reasonController = TextEditingController();

    final List<String> quickReasons = [
      'Blurry NID front page image',
      'Blurry NID back page image',
      'Blurry selfie holding NID card',
      'Real name does not match NID',
      'Incomplete or forged documents',
    ];

    final confirmedReason = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF2A1C3D),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.cancel_rounded, color: Colors.redAccent),
                const SizedBox(width: 8),
                Text('Reject Application'.tr, style: const TextStyle(color: Colors.white, fontSize: 18)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Specify reason for rejecting "$targetName":',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: quickReasons.map((r) {
                      return ActionChip(
                        label: Text(r, style: const TextStyle(fontSize: 11, color: Colors.white)),
                        backgroundColor: const Color(0xFF3F2B59),
                        onPressed: () {
                          setDialogState(() {
                            reasonController.text = r;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonController,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Enter rejection reason...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF1E142B),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: Text('Cancel'.tr, style: const TextStyle(color: Colors.white60)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  final text = reasonController.text.trim();
                  if (text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a rejection reason'), backgroundColor: Colors.orange),
                    );
                    return;
                  }
                  Navigator.pop(ctx, text);
                },
                child: Text('Reject'.tr, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );

    if (confirmedReason == null || confirmedReason.isEmpty) return;

    try {
      final currentAdminId = fb_auth.FirebaseAuth.instance.currentUser?.uid ?? 'admin';

      // 1. Update seller_kyc_applications
      await _firestore.collection('seller_kyc_applications').doc(docId).update({
        'status': 'rejected',
        'rejectionReason': confirmedReason,
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': currentAdminId,
      });

      // 2. Update sellers
      final sellerSnap = await _firestore
          .collection('sellers')
          .where('userId', isEqualTo: targetUserId)
          .limit(1)
          .get();

      if (sellerSnap.docs.isNotEmpty) {
        await sellerSnap.docs.first.reference.update({
          'isActive': false,
          'status': 'rejected',
          'kycStatus': 'rejected',
          'rejectionReason': confirmedReason,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // 3. Update Users
      final userRef = _firestore.collection('Users').doc(targetUserId);
      final userDoc = await userRef.get();
      final userDeviceToken = (userDoc.data()?['deviceToken'] ?? '').toString();

      await userRef.update({
        'sellerKycStatus': 'rejected',
        'isSeller': false,
        'sellerActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 4. Send official notification to the user
      try {
        await OfficialTeamApi.sendOfficialMessage(
          receiverId: targetUserId,
          receiverDeviceToken: userDeviceToken,
          messageText: '❌ Your Seller KYC verification application was rejected.\nReason: $confirmedReason\nPlease submit accurate documents and re-apply from the seller page.\n\n❌ আপনার সেলার ভেরিফিকেশন আবেদন বাতিল করা হয়েছে।\nকারণ: $confirmedReason\nঅনুগ্রহ করে সঠিক তথ্য এবং পরিষ্কার ছবি দিয়ে পুনরায় আবেদন জমা দিন।',
        );
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Application rejected: $confirmedReason'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rejection failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E142B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A1C3D),
        elevation: 0,
        title: Text(
          'Seller Processing'.tr,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.purpleAccent,
          labelColor: Colors.purpleAccent,
          unselectedLabelColor: Colors.white60,
          tabs: [
            Tab(text: 'Pending'.tr),
            Tab(text: 'Approved'.tr),
            Tab(text: 'Rejected'.tr),
            Tab(text: 'All'.tr),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search by Name, Search ID, or Real Name...',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: Colors.purpleAccent),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF2A1C3D),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val.trim().toLowerCase());
              },
            ),
          ),

          // Tab content
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('seller_kyc_applications')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.purpleAccent));
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading data: ${snapshot.error}',
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildApplicationList(docs, filterStatus: 'pending'),
                    _buildApplicationList(docs, filterStatus: 'approved'),
                    _buildApplicationList(docs, filterStatus: 'rejected'),
                    _buildApplicationList(docs, filterStatus: null),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationList(List<QueryDocumentSnapshot> docs, {String? filterStatus}) {
    final filtered = docs.where((d) {
      final data = d.data() as Map<String, dynamic>;
      final status = (data['status'] ?? 'pending').toString().toLowerCase();

      if (filterStatus != null && status != filterStatus) {
        return false;
      }

      if (_searchQuery.isNotEmpty) {
        final name = (data['userName'] ?? '').toString().toLowerCase();
        final searchId = (data['userSearchId'] ?? '').toString().toLowerCase();
        final realName = (data['realName'] ?? '').toString().toLowerCase();
        final dsName = (data['directSellerName'] ?? '').toString().toLowerCase();

        return name.contains(_searchQuery) ||
            searchId.contains(_searchQuery) ||
            realName.contains(_searchQuery) ||
            dsName.contains(_searchQuery);
      }

      return true;
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_rounded, size: 60, color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 12),
            Text(
              filterStatus == 'pending'
                  ? 'No pending applications'
                  : filterStatus == 'approved'
                      ? 'No approved sellers'
                      : filterStatus == 'rejected'
                          ? 'No rejected applications'
                          : 'No applications found',
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final doc = filtered[index];
        final data = doc.data() as Map<String, dynamic>;
        return _buildApplicationCard(data, doc.id);
      },
    );
  }

  Widget _buildApplicationCard(Map<String, dynamic> data, String docId) {
    final userName = data['userName'] ?? 'Unknown User';
    final userSearchId = data['userSearchId'] ?? '---';
    final userPhoto = data['userPhoto'] ?? '';
    final realName = data['realName'] ?? 'Not Provided';
    final dsName = data['directSellerName'] ?? 'Direct Seller';
    final status = (data['status'] ?? 'pending').toString().toLowerCase();
    final rejectionReason = data['rejectionReason'] ?? '';

    final nidFront = data['nidFrontUrl'] as String?;
    final nidBack = data['nidBackUrl'] as String?;
    final selfie = data['selfieUrl'] as String?;

    String formattedDate = '';
    final createdAt = data['createdAt'];
    if (createdAt is Timestamp) {
      formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(createdAt.toDate());
    }

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    if (status == 'approved') {
      statusColor = Colors.greenAccent;
      statusLabel = 'Approved'.tr;
      statusIcon = Icons.check_circle_rounded;
    } else if (status == 'rejected') {
      statusColor = Colors.redAccent;
      statusLabel = 'Rejected'.tr;
      statusIcon = Icons.cancel_rounded;
    } else {
      statusColor = Colors.amberAccent;
      statusLabel = 'Pending'.tr;
      statusIcon = Icons.hourglass_top_rounded;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      color: const Color(0xFF2A1C3D),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: status == 'pending' ? Colors.amber.withOpacity(0.4) : Colors.white10,
          width: status == 'pending' ? 1.5 : 1,
        ),
      ),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: User Avatar + Name + Status Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CachedCircleAvatar(
                  imageUrl: userPhoto,
                  radius: 23,
                  borderColor: Colors.purpleAccent,
                  borderWidth: 1.5,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'ID: $userSearchId',
                          style: const TextStyle(color: Colors.purpleAccent, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: statusColor, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Real Name Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E142B),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.purpleAccent.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.badge_rounded, color: Colors.purpleAccent, size: 18),
                  const SizedBox(width: 8),
                  Text('${'Real Name'.tr}: ', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  Expanded(
                    child: Text(
                      realName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Direct Seller & Submission Date Info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Direct Seller: $dsName',
                      style: const TextStyle(color: Colors.white60, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (formattedDate.isNotEmpty)
                    Text(
                      formattedDate,
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                ],
              ),
            ),

            // Rejection reason banner (if rejected)
            if (status == 'rejected' && rejectionReason.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, color: Colors.redAccent, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Reason: $rejectionReason',
                        style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),

            // 3 KYC Document Thumbnails
            Text(
              'KYC Documents (tap to zoom):'.tr,
              style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildDocCard(
                    title: 'NID Front'.tr,
                    url: nidFront,
                    onTap: () {
                      if (nidFront != null) _showZoomDialog(context, nidFront, 'NID Front - $userName');
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildDocCard(
                    title: 'NID Back'.tr,
                    url: nidBack,
                    onTap: () {
                      if (nidBack != null) _showZoomDialog(context, nidBack, 'NID Back - $userName');
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildDocCard(
                    title: 'Selfie with NID'.tr,
                    url: selfie,
                    onTap: () {
                      if (selfie != null) _showZoomDialog(context, selfie, 'Selfie with NID - $userName');
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Action Buttons
            if (status == 'pending') ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onPressed: () => _rejectApplication(data, docId),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: Text('Reject'.tr, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        elevation: 2,
                      ),
                      onPressed: () => _approveApplication(data, docId),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: Text('Approve'.tr, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ] else if (status == 'rejected') ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.greenAccent,
                    side: const BorderSide(color: Colors.greenAccent),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _approveApplication(data, docId),
                  icon: const Icon(Icons.replay_rounded, size: 18),
                  label: Text('Re-approve'.tr, style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDocCard({
    required String title,
    required String? url,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: const Color(0xFF1E142B),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Expanded(
              child: url != null && url.isNotEmpty
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          url,
                          fit: BoxFit.cover,
                          loadingBuilder: (c, w, p) => p == null
                              ? w
                              : const Center(
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.purpleAccent),
                                  ),
                                ),
                          errorBuilder: (c, e, s) => const Center(
                            child: Icon(Icons.broken_image, color: Colors.white38, size: 28),
                          ),
                        ),
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                            child: const Icon(Icons.zoom_in, color: Colors.white, size: 14),
                          ),
                        ),
                      ],
                    )
                  : const Center(
                      child: Text('No Image', style: TextStyle(color: Colors.white38, fontSize: 11)),
                    ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4),
              color: const Color(0xFF140D1D),
              child: Text(
                title,
                style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

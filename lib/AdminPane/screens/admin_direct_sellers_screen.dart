import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:chat_messenger/components/dynamic_diamond_icon.dart';
import 'package:chat_messenger/services/role_service.dart';
import 'package:chat_messenger/api/official_team_api.dart';

/// Admin Panel screen to manage Direct Sellers and credit diamond balance to their accounts
class AdminDirectSellersScreen extends StatefulWidget {
  const AdminDirectSellersScreen({super.key});

  @override
  State<AdminDirectSellersScreen> createState() => _AdminDirectSellersScreenState();
}

class _AdminDirectSellersScreenState extends State<AdminDirectSellersScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

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
        backgroundColor: Colors.purpleAccent,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Credit balance to direct seller
  Future<void> _creditBalanceDialog(Map<String, dynamic> directSeller) async {
    final amountController = TextEditingController();
    final noteController = TextEditingController(text: 'Admin balance recharge');
    final userId = directSeller['id'] as String;
    final name = directSeller['fullname'] ?? 'Direct Seller';
    final searchId = directSeller['searchId'] ?? '';

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
              'Credit Balance',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Direct Seller: $name (ID: $searchId)',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              const SizedBox(height: 14),
              const Text('Diamond Amount to Add:', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: 'Enter diamonds (e.g. 10000)',
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
              const SizedBox(height: 12),
              const Text('Admin Note / Remarks:', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: noteController,
                maxLines: 2,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Reason for credit...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF2A1D3B),
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
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00B074)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('CREDIT DIAMONDS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    final amount = int.tryParse(amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid positive diamond amount.'), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.purpleAccent)),
      );

      final currentAdminId = fb_auth.FirebaseAuth.instance.currentUser?.uid ?? 'admin';
      final note = noteController.text.trim();

      // Ensure direct_sellers/{userId} document exists and update balance atomically
      final dsRef = _firestore.collection('direct_sellers').doc(userId);
      await _firestore.runTransaction((txn) async {
        final snap = await txn.get(dsRef);
        if (snap.exists) {
          txn.update(dsRef, {
            'accountBalance': FieldValue.increment(amount),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          txn.set(dsRef, {
            'userId': userId,
            'name': name,
            'searchId': searchId,
            'photoUrl': directSeller['photoUrl'] ?? '',
            'accountBalance': amount,
            'totalDistributed': 0,
            'totalSellers': 0,
            'isActive': true,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        // Record credit in audit log
        final creditLogRef = _firestore.collection('direct_seller_admin_credits').doc();
        txn.set(creditLogRef, {
          'id': creditLogRef.id,
          'directSellerId': userId,
          'directSellerName': name,
          'directSellerSearchId': searchId,
          'amount': amount,
          'adminId': currentAdminId,
          'note': note,
          'timestamp': FieldValue.serverTimestamp(),
        });
      });

      // Send official team notification
      try {
        final deviceToken = directSeller['deviceToken'] ?? '';
        await OfficialTeamApi.sendOfficialMessage(
          receiverId: userId,
          receiverDeviceToken: deviceToken,
          messageText: '💎 Admin credited $amount Diamonds to your Direct Seller balance. Note: $note',
        );
      } catch (ex) {
        debugPrint('⚠️ Error sending official message: $ex');
      }

      if (mounted) Navigator.pop(context); // close loading

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Successfully credited $amount diamonds to $name!'),
            backgroundColor: const Color(0xFF00B074),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to credit diamonds: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Revoke Direct Seller Role
  Future<void> _revokeDirectSellerRole(Map<String, dynamic> directSeller) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E142B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Revoke Direct Seller', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to remove Direct Seller role from ${directSeller['fullname'] ?? directSeller['id']}?\n\nThey will no longer be able to manage sellers or distribute diamonds.',
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
            child: const Text('REVOKE ROLE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    try {
      final currentAdmin = fb_auth.FirebaseAuth.instance.currentUser?.uid ?? 'admin';
      final userId = directSeller['id'] as String;

      final currentRoles = List<String>.from(
          directSeller['roles'] ?? [directSeller['userType'] ?? AppRoles.regular]);
      currentRoles.remove(AppRoles.directSeller);
      if (currentRoles.isEmpty) currentRoles.add(AppRoles.regular);

      await RoleService.instance.assignRoles(
        targetUserId: userId,
        newRoles: currentRoles,
        assignedByUserId: currentAdmin,
      );

      await _firestore.collection('Users').doc(userId).update({
        'isDirectSeller': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Mark direct_sellers doc inactive
      await _firestore.collection('direct_sellers').doc(userId).set({
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Send official position revocation notification
      try {
        await OfficialTeamApi.sendPositionNotification(
          userId: userId,
          positionName: 'Direct Seller',
          isAssigned: false,
        );
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Direct Seller role revoked for ${directSeller['fullname'] ?? userId}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to revoke role: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showAssignDirectSellerModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _AssignDirectSellerModal(),
    );
  }

  void _showSellersUnderDirectSellerModal(String directSellerId, String directSellerName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DirectSellerSellersModal(
        directSellerId: directSellerId,
        directSellerName: directSellerName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF140D20),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E142B),
        title: const Text(
          'Direct Sellers Management',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_rounded, color: Colors.cyanAccent),
            tooltip: 'Assign Direct Seller',
            onPressed: _showAssignDirectSellerModal,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('Users')
            .where('roles', arrayContains: AppRoles.directSeller)
            .snapshots(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];
          final directSellers = docs.map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>}).toList();

          final filteredSellers = directSellers.where((u) {
            final name = (u['fullname'] ?? '').toString().toLowerCase();
            final searchId = (u['searchId'] ?? '').toString().toLowerCase();
            final uid = (u['id'] ?? '').toString().toLowerCase();
            return _searchQuery.isEmpty ||
                name.contains(_searchQuery) ||
                searchId.contains(_searchQuery) ||
                uid.contains(_searchQuery);
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                            decoration: InputDecoration(
                              hintText: 'Search Direct Sellers...',
                              hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                              prefixIcon: const Icon(Icons.search, color: Colors.cyanAccent, size: 20),
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
                              fillColor: const Color(0xFF2A1D3B),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: _showAssignDirectSellerModal,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('ASSIGN DS'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.cyan.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.cyanAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            'Total Direct Sellers: ${directSellers.length}',
                            style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Expanded(
                child: snapshot.connectionState == ConnectionState.waiting
                    ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
                    : filteredSellers.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.store_mall_directory_outlined, size: 60, color: Colors.white.withValues(alpha: 0.2)),
                                  const SizedBox(height: 12),
                                  Text(
                                    _searchQuery.isNotEmpty
                                        ? 'No Direct Sellers match "$_searchQuery"'
                                        : 'No Direct Sellers assigned yet.\nClick "+ ASSIGN DS" to appoint a user.',
                                    style: const TextStyle(color: Colors.white54, fontSize: 14),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            itemCount: filteredSellers.length,
                            itemBuilder: (context, index) {
                              final ds = filteredSellers[index];
                              return _buildDirectSellerCard(ds);
                            },
                          ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDirectSellerCard(Map<String, dynamic> ds) {
    final userId = ds['id'] as String;
    final name = ds['fullname'] ?? 'Direct Seller';
    final searchId = ds['searchId'] ?? 'N/A';
    final photoUrl = ds['photoUrl'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E142B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.cyanAccent.withValues(alpha: 0.2),
                  backgroundImage: photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                  child: photoUrl == null || photoUrl.isEmpty ? const Icon(Icons.person, color: Colors.white) : null,
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
                              name,
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
                      const SizedBox(height: 3),
                      GestureDetector(
                        onTap: () => _copyToClipboard(userId, 'User ID'),
                        child: Row(
                          children: [
                            Text(
                              'UID: ${userId.substring(0, userId.length > 8 ? 8 : userId.length)}... | SearchID: $searchId',
                              style: const TextStyle(color: Colors.white54, fontSize: 11),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.copy, color: Colors.white38, size: 11),
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

            // Real-time Balance & Sellers stream
            StreamBuilder<DocumentSnapshot>(
              stream: _firestore.collection('direct_sellers').doc(userId).snapshots(),
              builder: (context, dsDocSnap) {
                final dsData = dsDocSnap.data?.data() as Map<String, dynamic>? ?? {};
                final int balance = (dsData['accountBalance'] as num?)?.toInt() ?? 0;
                final int distributed = (dsData['totalDistributed'] as num?)?.toInt() ?? 0;

                return Column(
                  children: [
                    Row(
                      children: [
                        // Balance Card
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A1D3B),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Available Balance', style: TextStyle(color: Colors.white54, fontSize: 10)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const DynamicDiamondIcon(width: 14, height: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$balance',
                                      style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Distributed Card
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A1D3B),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Total Distributed', style: TextStyle(color: Colors.white54, fontSize: 10)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const DynamicDiamondIcon(width: 14, height: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$distributed',
                                      style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Actions Row
                    Row(
                      children: [
                        // Credit Diamonds Button
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _creditBalanceDialog(ds),
                            icon: const DynamicDiamondIcon(width: 14, height: 14),
                            label: const Text('ADD BALANCE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00B074),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // View Sellers Button
                        OutlinedButton.icon(
                          onPressed: () => _showSellersUnderDirectSellerModal(userId, name),
                          icon: const Icon(Icons.people_alt_rounded, size: 14, color: Colors.cyanAccent),
                          label: const Text('SELLERS', style: TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.cyanAccent, width: 1),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Revoke button
                        IconButton(
                          icon: const Icon(Icons.person_remove_rounded, color: Colors.redAccent, size: 20),
                          tooltip: 'Revoke Direct Seller Role',
                          onPressed: () => _revokeDirectSellerRole(ds),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Modal to search and assign a user as Direct Seller
class _AssignDirectSellerModal extends StatefulWidget {
  const _AssignDirectSellerModal();

  @override
  State<_AssignDirectSellerModal> createState() => _AssignDirectSellerModalState();
}

class _AssignDirectSellerModalState extends State<_AssignDirectSellerModal> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _initialBalanceController = TextEditingController(text: '0');
  bool _isSearching = false;
  bool _isAssigning = false;
  Map<String, dynamic>? _foundUser;
  String? _errorMessage;

  @override
  void dispose() {
    _searchController.dispose();
    _initialBalanceController.dispose();
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
      final doc = await FirebaseFirestore.instance.collection('Users').doc(query).get();
      if (doc.exists && doc.data() != null) {
        setState(() {
          _foundUser = {'id': doc.id, ...doc.data()!};
          _isSearching = false;
        });
        return;
      }

      final snapSearch = await FirebaseFirestore.instance
          .collection('Users')
          .where('searchId', isEqualTo: query)
          .limit(1)
          .get();
      if (snapSearch.docs.isNotEmpty) {
        setState(() {
          _foundUser = {'id': snapSearch.docs.first.id, ...snapSearch.docs.first.data()};
          _isSearching = false;
        });
        return;
      }

      final snapName = await FirebaseFirestore.instance
          .collection('Users')
          .where('fullname', isEqualTo: query)
          .limit(1)
          .get();
      if (snapName.docs.isNotEmpty) {
        setState(() {
          _foundUser = {'id': snapName.docs.first.id, ...snapName.docs.first.data()};
          _isSearching = false;
        });
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

  Future<void> _assignDirectSeller() async {
    if (_foundUser == null) return;

    setState(() => _isAssigning = true);
    try {
      final currentAdmin = fb_auth.FirebaseAuth.instance.currentUser?.uid ?? 'admin';
      final userId = _foundUser!['id'] as String;
      final initialBalance = int.tryParse(_initialBalanceController.text.trim()) ?? 0;

      final currentRoles = List<String>.from(
          _foundUser!['roles'] ?? [_foundUser!['userType'] ?? AppRoles.regular]);

      if (!currentRoles.contains(AppRoles.directSeller)) {
        currentRoles.add(AppRoles.directSeller);
      }
      currentRoles.remove(AppRoles.regular);

      await RoleService.instance.assignRoles(
        targetUserId: userId,
        newRoles: currentRoles,
        assignedByUserId: currentAdmin,
      );

      await FirebaseFirestore.instance.collection('Users').doc(userId).update({
        'isDirectSeller': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Initialize direct_sellers document
      await FirebaseFirestore.instance.collection('direct_sellers').doc(userId).set({
        'userId': userId,
        'name': _foundUser!['fullname'] ?? 'Direct Seller',
        'searchId': _foundUser!['searchId'] ?? '',
        'photoUrl': _foundUser!['photoUrl'] ?? '',
        'accountBalance': initialBalance,
        'totalDistributed': 0,
        'totalSellers': 0,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Send official position assignment notification
      try {
        await OfficialTeamApi.sendPositionNotification(
          userId: userId,
          positionName: 'Direct Seller',
          isAssigned: true,
          note: 'You can now create and manage sellers and distribute diamonds from your Direct Seller Dashboard.',
        );
      } catch (_) {}

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 Assigned Direct Seller role to ${_foundUser!['fullname'] ?? userId}!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isAssigning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      decoration: const BoxDecoration(
        color: Color(0xFF1E142B),
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
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const Text(
              'Assign Direct Seller Role',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 4),
            const Text(
              'Grant a user Direct Seller privileges to add sellers and distribute diamonds.',
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
                  color: const Color(0xFF2E1A47),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.4)),
                ),
                child: Column(
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
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('Initial Diamond Balance (Optional):', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _initialBalanceController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF1E142B),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _isAssigning ? null : _assignDirectSeller,
                        icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.white),
                        label: _isAssigning
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                                'CONFIRM ASSIGNMENT',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                              ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.cyan.shade700,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
  }
}

/// Modal to view all sellers created by a specific Direct Seller
class _DirectSellerSellersModal extends StatelessWidget {
  final String directSellerId;
  final String directSellerName;

  const _DirectSellerSellersModal({
    required this.directSellerId,
    required this.directSellerName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF1E142B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
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
            children: [
              const Icon(Icons.people_alt_rounded, color: Colors.cyanAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Sellers under $directSellerName',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Direct Seller UID: ${directSellerId.substring(0, directSellerId.length > 8 ? 8 : directSellerId.length)}...',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('sellers')
                  .where('directSellerId', isEqualTo: directSellerId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(
                    child: Text('No sellers created by this Direct Seller yet.', style: TextStyle(color: Colors.white54)),
                  );
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final sellerName = data['sellerName'] ?? 'Seller';
                    final sellerSearchId = data['sellerSearchId'] ?? 'N/A';
                    final balance = data['accountBalance'] ?? 0;
                    final totalSales = data['totalSales'] ?? 0;
                    final isActive = data['isActive'] ?? true;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A1D3B),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isActive ? Colors.cyanAccent.withValues(alpha: 0.3) : Colors.redAccent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.cyanAccent.withValues(alpha: 0.2),
                            child: const Icon(Icons.storefront, color: Colors.white, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  sellerName,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                Text(
                                  'ID: $sellerSearchId',
                                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                children: [
                                  const DynamicDiamondIcon(width: 12, height: 12),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$balance',
                                    style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ],
                              ),
                              Text(
                                'Sales: $totalSales',
                                style: const TextStyle(color: Colors.white54, fontSize: 10),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

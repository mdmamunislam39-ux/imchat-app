import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:chat_messenger/services/role_service.dart';
import 'package:chat_messenger/services/agency_service.dart';
import 'package:chat_messenger/api/official_team_api.dart';

/// Admin Panel screen to view, assign, and manage BD (Business Development) users
class AdminBdManagementScreen extends StatefulWidget {
  const AdminBdManagementScreen({super.key});

  @override
  State<AdminBdManagementScreen> createState() => _AdminBdManagementScreenState();
}

class _AdminBdManagementScreenState extends State<AdminBdManagementScreen> {
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

  Future<void> _revokeBdRole(Map<String, dynamic> bdUser) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E142B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Revoke BD Role', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to remove BD role from ${bdUser['fullname'] ?? bdUser['id']}?\n\nThey will no longer be able to create or manage agencies as BD.',
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
            child: const Text('REVOKE BD', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    try {
      final currentAdmin = fb_auth.FirebaseAuth.instance.currentUser?.uid ?? 'admin';
      final userId = bdUser['id'] as String;

      final currentRoles = List<String>.from(bdUser['roles'] ?? [bdUser['userType'] ?? AppRoles.regular]);
      currentRoles.remove(AppRoles.bd);
      if (currentRoles.isEmpty) currentRoles.add(AppRoles.regular);

      await RoleService.instance.assignRoles(
        targetUserId: userId,
        newRoles: currentRoles,
        assignedByUserId: currentAdmin,
      );

      // Explicitly set isBD to false
      await _firestore.collection('Users').doc(userId).update({
        'isBD': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Send official position notification
      try {
        await OfficialTeamApi.sendPositionNotification(
          userId: userId,
          positionName: 'BD (Business Developer)',
          isAssigned: false,
        );
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ BD role revoked for ${bdUser['fullname'] ?? userId}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to revoke BD role: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showAssignBdModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _AssignBdModal(),
    );
  }

  void _showAgenciesUnderBdModal(String bdUserId, String bdName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BdAgenciesListModal(bdUserId: bdUserId, bdName: bdName),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF140D20),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E142B),
        title: const Text(
          'BD Management',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_rounded, color: Colors.purpleAccent),
            tooltip: 'Assign New BD',
            onPressed: _showAssignBdModal,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('Users')
            .where('roles', arrayContains: AppRoles.bd)
            .snapshots(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];
          final bdUsers = docs.map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>}).toList();

          final filteredBds = bdUsers.where((u) {
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
              // Search & Add Bar
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
                              hintText: 'Search BDs by name, searchId, or ID...',
                              hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                              prefixIcon: const Icon(Icons.search, color: Colors.purpleAccent, size: 20),
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
                          onPressed: _showAssignBdModal,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('ASSIGN BD'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purpleAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Summary Chips
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.tealAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            'Total BDs: ${bdUsers.length}',
                            style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // BD List
              Expanded(
                child: snapshot.connectionState == ConnectionState.waiting
                    ? const Center(child: CircularProgressIndicator(color: Colors.purpleAccent))
                    : filteredBds.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.badge_outlined, size: 60, color: Colors.white.withValues(alpha: 0.2)),
                                  const SizedBox(height: 12),
                                  Text(
                                    _searchQuery.isNotEmpty
                                        ? 'No BD users found matching "$_searchQuery"'
                                        : 'No BD users assigned yet.\nClick "+ ASSIGN BD" to assign a user to the BD role.',
                                    style: const TextStyle(color: Colors.white54, fontSize: 14),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            itemCount: filteredBds.length,
                            itemBuilder: (context, index) {
                              final bd = filteredBds[index];
                              return _buildBdUserCard(bd);
                            },
                          ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBdUserCard(Map<String, dynamic> bd) {
    final userId = bd['id'] as String;
    final name = bd['fullname'] ?? 'User';
    final searchId = bd['searchId'] ?? 'N/A';
    final photoUrl = bd['photoUrl'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E142B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.25)),
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
                  backgroundColor: Colors.tealAccent.withValues(alpha: 0.2),
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
                              color: Colors.tealAccent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.tealAccent, width: 1),
                            ),
                            child: const Text(
                              'BD',
                              style: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 10),
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

            // Agency Count streamer for this BD
            StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('agencies')
                  .where('createdByBdId', isEqualTo: userId)
                  .snapshots(),
              builder: (context, agencySnap) {
                final count = agencySnap.data?.docs.length ?? 0;
                return Row(
                  children: [
                    const Icon(Icons.business_rounded, color: Colors.orangeAccent, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '$count Agencies Created',
                      style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    // View Agencies Button
                    TextButton.icon(
                      onPressed: count > 0 ? () => _showAgenciesUnderBdModal(userId, name) : null,
                      icon: const Icon(Icons.list_alt_rounded, size: 16),
                      label: const Text('View Agencies', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.tealAccent,
                        disabledForegroundColor: Colors.white24,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Revoke BD button
                    IconButton(
                      icon: const Icon(Icons.person_remove_rounded, color: Colors.redAccent, size: 20),
                      tooltip: 'Revoke BD Role',
                      onPressed: () => _revokeBdRole(bd),
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

/// Modal to search a user and assign them the BD role
class _AssignBdModal extends StatefulWidget {
  const _AssignBdModal();

  @override
  State<_AssignBdModal> createState() => _AssignBdModalState();
}

class _AssignBdModalState extends State<_AssignBdModal> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  bool _isAssigning = false;
  Map<String, dynamic>? _foundUser;
  String? _errorMessage;

  @override
  void dispose() {
    _searchController.dispose();
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

  Future<void> _assignBd() async {
    if (_foundUser == null) return;

    setState(() => _isAssigning = true);
    try {
      final currentAdmin = fb_auth.FirebaseAuth.instance.currentUser?.uid ?? 'admin';
      final userId = _foundUser!['id'] as String;

      final currentRoles = List<String>.from(
          _foundUser!['roles'] ?? [_foundUser!['userType'] ?? AppRoles.regular]);

      if (!currentRoles.contains(AppRoles.bd)) {
        currentRoles.add(AppRoles.bd);
      }
      currentRoles.remove(AppRoles.regular);

      final success = await RoleService.instance.assignRoles(
        targetUserId: userId,
        newRoles: currentRoles,
        assignedByUserId: currentAdmin,
      );

      // Explicitly set isBD on user document
      await FirebaseFirestore.instance.collection('Users').doc(userId).update({
        'isBD': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Send official position notification
      try {
        await OfficialTeamApi.sendPositionNotification(
          userId: userId,
          positionName: 'BD (Business Developer)',
          isAssigned: true,
          note: 'You can now appoint agencies and manage agency growth from the BD Dashboard.',
        );
      } catch (_) {}

      if (!mounted) return;
      Navigator.pop(context);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 Successfully assigned BD role to ${_foundUser!['fullname'] ?? userId}!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to assign role. Check permissions.'), backgroundColor: Colors.red),
        );
      }
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
              'Assign BD Role',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 4),
            const Text(
              'Search a user to grant them Business Development (BD) access to manage agencies.',
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
                      prefixIcon: const Icon(Icons.search, color: Colors.purpleAccent, size: 20),
                    ),
                    onSubmitted: (_) => _searchUser(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isSearching ? null : _searchUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purpleAccent,
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
                  border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.4)),
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
                              Text(
                                'Current Roles: ${List<String>.from(_foundUser!['roles'] ?? [_foundUser!['userType'] ?? 'regular']).join(", ").toUpperCase()}',
                                style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _isAssigning ? null : _assignBd,
                        icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.white),
                        label: _isAssigning
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                                'ASSIGN AS BD',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                              ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade700,
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

/// Modal to view all agencies created under a specific BD
class _BdAgenciesListModal extends StatelessWidget {
  final String bdUserId;
  final String bdName;

  const _BdAgenciesListModal({required this.bdUserId, required this.bdName});

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
              const Icon(Icons.business_rounded, color: Colors.orangeAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Agencies under $bdName',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'BD ID: ${bdUserId.substring(0, bdUserId.length > 8 ? 8 : bdUserId.length)}...',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('agencies')
                  .where('createdByBdId', isEqualTo: bdUserId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.purpleAccent));
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(
                    child: Text('No agencies created by this BD yet.', style: TextStyle(color: Colors.white54)),
                  );
                }

                final agencies = docs.map((d) => Agency.fromMap(d.data() as Map<String, dynamic>)).toList();

                return ListView.builder(
                  itemCount: agencies.length,
                  itemBuilder: (context, index) {
                    final agency = agencies[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A1D3B),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: agency.isActive ? Colors.purpleAccent.withValues(alpha: 0.3) : Colors.redAccent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.purpleAccent.withValues(alpha: 0.2),
                            backgroundImage: agency.logoUrl.isNotEmpty ? NetworkImage(agency.logoUrl) : null,
                            child: agency.logoUrl.isEmpty ? const Icon(Icons.business, color: Colors.white, size: 18) : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  agency.agencyName,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                Text(
                                  'ID: ${agency.agencyIdNumber} • Owner: ${agency.owner.name}',
                                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: agency.isActive ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              agency.isActive ? 'ACTIVE' : 'TERMINATED',
                              style: TextStyle(
                                color: agency.isActive ? Colors.greenAccent : Colors.redAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:chat_messenger/services/agency_service.dart';
import 'package:chat_messenger/screens/room/agency_screen.dart';
import 'package:chat_messenger/services/role_service.dart';

/// Business Development (BD) Dashboard
/// Allows BD users to create/assign agencies, manage agencies under them,
/// view agency portals/history, and terminate agencies or hosts.
class BdDashboardScreen extends StatefulWidget {
  final User currentUser;
  const BdDashboardScreen({super.key, required this.currentUser});

  @override
  State<BdDashboardScreen> createState() => _BdDashboardScreenState();
}

class _BdDashboardScreenState extends State<BdDashboardScreen> {
  final AgencyService _agencyService = AgencyService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _searchFilter = '';
  String _statusFilter = 'all'; // 'all', 'active', 'terminated'
  final TextEditingController _searchController = TextEditingController();

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

  // Terminate agency confirmation
  Future<void> _confirmTerminateAgency(Agency agency) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E142B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text(
              'Terminate Agency',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to terminate "${agency.agencyName}"?',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('⚠️ What will happen:',
                      style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                  SizedBox(height: 4),
                  Text('• Agency will be permanently deactivated.',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Text('• Owner will lose agency status.',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Text('• All registered hosts under this agency will be released.',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('TERMINATE AGENCY', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: Colors.purpleAccent),
        ),
      );

      await _agencyService.terminateAgency(
        agencyId: agency.agencyId,
        terminatedByUserId: widget.currentUser.userId,
      );

      if (mounted) Navigator.pop(context); // close loading

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Agency "${agency.agencyName}" terminated successfully.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // close loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error terminating agency: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Open Agency portal in BD View mode
  Future<void> _openAgencyPortal(Agency agency) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.purpleAccent)),
      );

      // Fetch agency owner's user doc
      final ownerDoc = await _firestore.collection('Users').doc(agency.owner.userId).get();
      final ownerUser = ownerDoc.exists && ownerDoc.data() != null
          ? User.fromMap(ownerDoc.data()!)
          : widget.currentUser;

      if (mounted) Navigator.pop(context); // close loading

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AgencyScreen(
              currentUser: ownerUser,
              targetAgencyId: agency.agencyId,
              isBdView: true,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening agency portal: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Add Agency Dialog
  void _showAddAgencyDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddAgencyModal(
        bdUser: widget.currentUser,
        agencyService: _agencyService,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        title: const Text(
          'BD Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('agencies')
            .where('createdByBdId', isEqualTo: widget.currentUser.userId)
            .snapshots(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];
          final allAgencies = docs.map((doc) => Agency.fromMap(doc.data() as Map<String, dynamic>)).toList();

          // Aggregate stats
          final totalAgencies = allAgencies.length;
          final activeAgencies = allAgencies.where((a) => a.isActive).length;
          final totalHosts = allAgencies.fold<int>(0, (acc, a) => acc + a.totalHosts);
          final totalCommission = allAgencies.fold<double>(0.0, (acc, a) => acc + a.totalCommissionEarned);

          // Filter agencies by search and status
          final filteredAgencies = allAgencies.where((a) {
            final matchesSearch = _searchFilter.isEmpty ||
                a.agencyName.toLowerCase().contains(_searchFilter) ||
                a.agencyIdNumber.toLowerCase().contains(_searchFilter) ||
                a.owner.name.toLowerCase().contains(_searchFilter);

            final matchesStatus = _statusFilter == 'all' ||
                (_statusFilter == 'active' && a.isActive) ||
                (_statusFilter == 'terminated' && !a.isActive);

            return matchesSearch && matchesStatus;
          }).toList();

          return CustomScrollView(
            slivers: [
              // Header Card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildHeaderCard(),
                      const SizedBox(height: 16),
                      _buildStatsGrid(totalAgencies, activeAgencies, totalHosts, totalCommission),
                      const SizedBox(height: 20),
                      // Add Agency Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _showAddAgencyDialog,
                          icon: const Icon(Icons.add_business_rounded, color: Colors.white),
                          label: const Text(
                            '+ ADD NEW AGENCY',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade700,
                            elevation: 4,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Search and Filter row
                      _buildSearchAndFilters(),
                    ],
                  ),
                ),
              ),

              // Agencies List
              if (snapshot.connectionState == ConnectionState.waiting)
                const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(color: Colors.orangeAccent),
                    ),
                  ),
                )
              else if (filteredAgencies.isEmpty)
                SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.business_outlined, size: 64, color: Colors.white.withValues(alpha: 0.2)),
                          const SizedBox(height: 12),
                          Text(
                            _searchFilter.isNotEmpty || _statusFilter != 'all'
                                ? 'No agencies match your filter.'
                                : 'No agencies under your BD account yet.',
                            style: const TextStyle(color: Colors.white54, fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                          if (_searchFilter.isEmpty && _statusFilter == 'all') ...[
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _showAddAgencyDialog,
                              icon: const Icon(Icons.add),
                              label: const Text('Add First Agency'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final agency = filteredAgencies[index];
                        return _buildAgencyCard(agency);
                      },
                      childCount: filteredAgencies.length,
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeaderCard() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('Users').doc(widget.currentUser.userId).snapshots(),
      builder: (context, userSnap) {
        final userData = userSnap.data?.data() as Map<String, dynamic>?;

        final liveName = (userData?['fullname'] != null && userData!['fullname'].toString().trim().isNotEmpty)
            ? userData['fullname'].toString().trim()
            : (userData?['name'] != null && userData!['name'].toString().trim().isNotEmpty)
                ? userData['name'].toString().trim()
                : (widget.currentUser.fullname.isNotEmpty ? widget.currentUser.fullname : 'BD Manager');

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
              colors: [Color(0xFF2E1A47), Color(0xFF1E142B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.3)),
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
                            color: Colors.orangeAccent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.orangeAccent, width: 1),
                          ),
                          child: const Text(
                            'BD',
                            style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Search ID: $liveSearchId',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    Text(
                      'Role: Business Development',
                      style: TextStyle(color: Colors.purpleAccent.shade100, fontSize: 11),
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

  Widget _buildStatsGrid(int totalAgencies, int activeAgencies, int totalHosts, double totalCommission) {
    return Row(
      children: [
        Expanded(
          child: _buildStatTile('Agencies', '$totalAgencies', 'Active: $activeAgencies', Icons.business, Colors.blueAccent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatTile('Total Hosts', '$totalHosts', 'Registered', Icons.groups_rounded, Colors.purpleAccent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatTile(
            'Commission',
            totalCommission.toStringAsFixed(0),
            'Total Earned',
            Icons.monetization_on_rounded,
            Colors.amber,
          ),
        ),
      ],
    );
  }

  Widget _buildStatTile(String title, String mainValue, String subValue, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E142B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: Colors.white60, fontSize: 11)),
              Icon(icon, color: color, size: 16),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            mainValue,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 2),
          Text(subValue, style: TextStyle(color: color, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Column(
      children: [
        TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          onChanged: (val) => setState(() => _searchFilter = val.trim().toLowerCase()),
          decoration: InputDecoration(
            hintText: 'Search agencies by name, ID, or owner...',
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
            prefixIcon: const Icon(Icons.search, color: Colors.purpleAccent, size: 20),
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
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildFilterChip('All', 'all'),
            const SizedBox(width: 8),
            _buildFilterChip('Active', 'active'),
            const SizedBox(width: 8),
            _buildFilterChip('Terminated', 'terminated'),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _statusFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _statusFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.purpleAccent.withValues(alpha: 0.3) : const Color(0xFF1E142B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.purpleAccent : Colors.white12,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white60,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildAgencyCard(Agency agency) {
    final ownerUserId = agency.owner.userId;

    return StreamBuilder<DocumentSnapshot>(
      stream: ownerUserId.isNotEmpty
          ? FirebaseFirestore.instance.collection('Users').doc(ownerUserId).snapshots()
          : null,
      builder: (context, userSnap) {
        final userData = userSnap.data?.data() as Map<String, dynamic>?;

        final liveOwnerName = (userData?['fullname'] != null && userData!['fullname'].toString().trim().isNotEmpty)
            ? userData['fullname'].toString().trim()
            : (userData?['name'] != null && userData!['name'].toString().trim().isNotEmpty)
                ? userData['name'].toString().trim()
                : (agency.owner.name.isNotEmpty ? agency.owner.name : 'Owner');

        final liveOwnerPhotoUrl = (userData?['photoUrl'] != null && userData!['photoUrl'].toString().trim().isNotEmpty)
            ? userData['photoUrl'].toString().trim()
            : (userData?['photo_url'] != null && userData!['photo_url'].toString().trim().isNotEmpty)
                ? userData['photo_url'].toString().trim()
                : agency.owner.profileImageUrl;

        final liveOwnerSearchId = (userData?['searchId'] != null && userData!['searchId'].toString().trim().isNotEmpty)
            ? userData['searchId'].toString().trim()
            : 'N/A';

        final displayLogo = agency.logoUrl.isNotEmpty ? agency.logoUrl : liveOwnerPhotoUrl;

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E142B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: agency.isActive
                  ? Colors.purpleAccent.withValues(alpha: 0.25)
                  : Colors.redAccent.withValues(alpha: 0.3),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Logo, Name, ID, Status
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.purpleAccent.withValues(alpha: 0.2),
                      backgroundImage: displayLogo.isNotEmpty ? NetworkImage(displayLogo) : null,
                      onBackgroundImageError: displayLogo.isNotEmpty ? (_, __) {} : null,
                      child: displayLogo.isEmpty ? const Icon(Icons.business, color: Colors.white) : null,
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
                                  agency.agencyName,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: agency.isActive
                                      ? Colors.green.withValues(alpha: 0.2)
                                      : Colors.red.withValues(alpha: 0.2),
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
                          const SizedBox(height: 3),
                          GestureDetector(
                            onTap: () => _copyToClipboard(agency.agencyIdNumber, 'Agency ID'),
                            child: Row(
                              children: [
                                Text(
                                  'Agency ID: ${agency.agencyIdNumber}',
                                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.copy, color: Colors.white38, size: 12),
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

                // Owner & Host Count info
                Row(
                  children: [
                    const Icon(Icons.person_pin_rounded, color: Colors.blueAccent, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Owner: $liveOwnerName (Search ID: $liveOwnerSearchId)',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.groups_rounded, color: Colors.purpleAccent, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${agency.totalHosts} Hosts',
                      style: const TextStyle(color: Colors.purpleAccent, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),

            const SizedBox(height: 14),

            // Action Buttons
            Row(
              children: [
                // View Portal Button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openAgencyPortal(agency),
                    icon: const Icon(Icons.remove_red_eye_rounded, size: 16, color: Colors.white),
                    label: const Text(
                      'OPEN PORTAL',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E1A47),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: Colors.purpleAccent, width: 1),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Terminate Agency Button (if active)
                if (agency.isActive)
                  ElevatedButton.icon(
                    onPressed: () => _confirmTerminateAgency(agency),
                    icon: const Icon(Icons.cancel_outlined, size: 16, color: Colors.redAccent),
                    label: const Text(
                      'TERMINATE',
                      style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.withValues(alpha: 0.1),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5), width: 1),
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

/// Bottom sheet modal to search a user and assign them as an Agency under this BD
class _AddAgencyModal extends StatefulWidget {
  final User bdUser;
  final AgencyService agencyService;

  const _AddAgencyModal({
    required this.bdUser,
    required this.agencyService,
  });

  @override
  State<_AddAgencyModal> createState() => _AddAgencyModalState();
}

class _AddAgencyModalState extends State<_AddAgencyModal> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _agencyNameController = TextEditingController();
  final TextEditingController _agencyIdNumController = TextEditingController();

  bool _isSearching = false;
  bool _isSubmitting = false;
  Map<String, dynamic>? _foundUser;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Pre-generate a 6-digit agency ID number
    _agencyIdNumController.text = (100000 + (DateTime.now().millisecondsSinceEpoch % 900000)).toString();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _agencyNameController.dispose();
    _agencyIdNumController.dispose();
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
      // 1. Search by userId
      final doc = await FirebaseFirestore.instance.collection('Users').doc(query).get();
      if (doc.exists && doc.data() != null) {
        await _processFoundUser({'id': doc.id, ...doc.data()!});
        return;
      }

      // 2. Search by searchId
      final snapSearch = await FirebaseFirestore.instance
          .collection('Users')
          .where('searchId', isEqualTo: query)
          .limit(1)
          .get();
      if (snapSearch.docs.isNotEmpty) {
        await _processFoundUser({'id': snapSearch.docs.first.id, ...snapSearch.docs.first.data()});
        return;
      }

      // 3. Search by fullname
      final snapName = await FirebaseFirestore.instance
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

  Future<void> _processFoundUser(Map<String, dynamic> userMap) async {
    final targetUserId = userMap['id'] as String;

    // Check if user is currently an active / running agency owner
    // 1. Check agencies collection for active docs
    final agencySnap1 = await FirebaseFirestore.instance
        .collection('agencies')
        .where('ownerUserId', isEqualTo: targetUserId)
        .get();

    bool hasActiveAgencyDoc = false;
    String? activeAgencyName;
    for (final doc in agencySnap1.docs) {
      final data = doc.data();
      final bool isActive = data['isActive'] == true || (data['isActive'] == null && data['status'] != 'terminated');
      if (isActive) {
        hasActiveAgencyDoc = true;
        activeAgencyName = data['agencyName'] ?? 'Agency';
        break;
      }
    }

    if (!hasActiveAgencyDoc) {
      final agencySnap2 = await FirebaseFirestore.instance
          .collection('agencies')
          .where('owner.userId', isEqualTo: targetUserId)
          .get();
      for (final doc in agencySnap2.docs) {
        final data = doc.data();
        final bool isActive = data['isActive'] == true || (data['isActive'] == null && data['status'] != 'terminated');
        if (isActive) {
          hasActiveAgencyDoc = true;
          activeAgencyName = data['agencyName'] ?? 'Agency';
          break;
        }
      }
    }

    // 2. Check user doc flags
    final bool isUserAgencyFlag = (userMap['isAgency'] == true) ||
        (userMap['userType'] == 'agency_owner') ||
        (userMap['roles'] is List && (userMap['roles'] as List).contains(AppRoles.agency));

    final bool isRunningAgency = hasActiveAgencyDoc || isUserAgencyFlag;

    setState(() {
      _foundUser = {
        ...userMap,
        'isRunningAgency': isRunningAgency,
        'activeAgencyName': activeAgencyName ?? userMap['agencyName'],
      };
      _isSearching = false;
      _agencyNameController.text = '${userMap['fullname'] ?? "Star"}\'s Agency';
    });
  }

  Future<void> _createAgency() async {
    if (_foundUser == null) return;

    if (_foundUser!['isRunningAgency'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot assign: User already has an active running Agency.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final agencyName = _agencyNameController.text.trim();
    final agencyIdNum = _agencyIdNumController.text.trim();

    if (agencyName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an agency name.'), backgroundColor: Colors.red),
      );
      return;
    }

    if (agencyIdNum.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an agency ID number.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final targetUserId = _foundUser!['id'] as String;

      await widget.agencyService.createAgencyByBd(
        targetUserId: targetUserId,
        agencyName: agencyName,
        agencyIdNumber: agencyIdNum,
        bdUserId: widget.bdUser.userId,
        bdUserName: widget.bdUser.fullname,
      );

      if (!mounted) return;
      Navigator.pop(context); // Close modal

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 Agency "$agencyName" created and assigned successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create agency: $e'), backgroundColor: Colors.red),
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

    final bool isRunningAgency = _foundUser != null && _foundUser!['isRunningAgency'] == true;

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
                // Modal Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                Row(
                  children: const [
                    Icon(Icons.add_business_rounded, color: Colors.orangeAccent),
                    SizedBox(width: 8),
                    Text(
                      'Add Agency under BD',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Search a user to make them an Agency Owner under your BD account.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 16),

                // Search Bar
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

                // Found User Card
                if (_foundUser != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF221636),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isRunningAgency
                            ? Colors.redAccent.withValues(alpha: 0.5)
                            : Colors.purpleAccent.withValues(alpha: 0.4),
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
                                  if (isRunningAgency)
                                    const Text(
                                      '⚠️ Running Active Agency Owner',
                                      style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Warning banner if user already has an active running agency
                        if (isRunningAgency) ...[
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
                                        'Already an Active Agency Owner',
                                        style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'This user currently has an active Agency (${_foundUser!['activeAgencyName'] ?? "Active Agency"}). A BD cannot assign them. If their running agency is terminated or removed, they can be assigned again.',
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
                          const Text('Agency Name', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _agencyNameController,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFF2E1A47),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                            ),
                          ),

                          const SizedBox(height: 12),
                          const Text('Agency ID Number', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _agencyIdNumController,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFF2E1A47),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                            ),
                          ),
                        ],

                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: (_isSubmitting || isRunningAgency) ? null : _createAgency,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isRunningAgency ? Colors.grey.shade800 : Colors.orange.shade700,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _isSubmitting
                                ? const CircularProgressIndicator(color: Colors.white)
                                : Text(
                                    isRunningAgency
                                        ? 'ALREADY AN ACTIVE AGENCY'
                                        : 'ASSIGN AS AGENCY OWNER',
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

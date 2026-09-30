import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:chat_messenger/components/cached_circle_avatar.dart';
import 'package:chat_messenger/services/agency_service.dart';

/// Admin Panel screen to review, approve, and reject agency transfer requests
class AdminAgencyTransfersScreen extends StatefulWidget {
  const AdminAgencyTransfersScreen({super.key});

  @override
  State<AdminAgencyTransfersScreen> createState() => _AdminAgencyTransfersScreenState();
}

class _AdminAgencyTransfersScreenState extends State<AdminAgencyTransfersScreen>
    with SingleTickerProviderStateMixin {
  final AgencyService _agencyService = AgencyService();
  late TabController _tabController;

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

  Future<void> _approveTransfer(Map<String, dynamic> request) async {
    final currentAdminId = FirebaseAuth.instance.currentUser?.uid ?? 'admin';
    final String requestId = request['requestId'] ?? request['id'] ?? '';
    final String userName = request['userName'] ?? 'Host';
    final String userSearchId = request['userSearchId'] ?? '';
    final String currentAgency = request['currentAgencyName'] ?? 'None';
    final String targetAgency = request['targetAgencyName'] ?? 'New Agency';
    final String targetAgencyIdNum = request['targetAgencyIdNumber'] ?? '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E142B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Approve Agency Transfer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to approve this agency transfer?', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            Text('• Host: $userName (UID: $userSearchId)', style: const TextStyle(color: Colors.white)),
            Text('• From Agency: $currentAgency', style: const TextStyle(color: Colors.redAccent)),
            Text('• To Agency: $targetAgency ($targetAgencyIdNum)', style: const TextStyle(color: Color(0xFF00B074), fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text(
              '⚠️ This will transfer the host record, update user agency, and notify the user.',
              style: TextStyle(color: Colors.amber, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00B074)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('APPROVE TRANSFER'),
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
        builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.purpleAccent)),
      );

      await _agencyService.approveTransferRequest(
        requestId: requestId,
        adminId: currentAdminId,
      );

      if (mounted) Navigator.pop(context); // Close loading dialog

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Agency transfer approved successfully!'),
            backgroundColor: Color(0xFF00B074),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close loading dialog
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error approving transfer: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _rejectTransfer(Map<String, dynamic> request) async {
    final currentAdminId = FirebaseAuth.instance.currentUser?.uid ?? 'admin';
    final String requestId = request['requestId'] ?? request['id'] ?? '';
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E142B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reject Agency Transfer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Please provide a reason for rejecting this transfer request:', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter rejection reason (optional)',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF2A1D3B),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('REJECT'),
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
        builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.purpleAccent)),
      );

      await _agencyService.rejectTransferRequest(
        requestId: requestId,
        adminId: currentAdminId,
        rejectionReason: reasonController.text.trim(),
      );

      if (mounted) Navigator.pop(context); // Close loading dialog

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Agency transfer request rejected.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close loading dialog
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error rejecting transfer: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF140D20),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E142B),
        title: const Text('Agency Transfers', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Search by host name, UID, or agency...',
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
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
              TabBar(
                controller: _tabController,
                indicatorColor: Colors.purpleAccent,
                labelColor: Colors.purpleAccent,
                unselectedLabelColor: Colors.white54,
                tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs.map((tab) => _buildRequestsList(tab.toLowerCase())).toList(),
      ),
    );
  }

  Widget _buildRequestsList(String statusFilter) {
    Query query = FirebaseFirestore.instance.collection('agency_transfer_requests');

    if (statusFilter != 'all') {
      query = query.where('status', isEqualTo: statusFilter);
    }

    query = query.orderBy('createdAt', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.purpleAccent));
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Error loading requests: ${snapshot.error}',
                style: const TextStyle(color: Colors.redAccent),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        var docs = snapshot.data?.docs ?? [];

        // Client-side search filtering
        if (_searchQuery.isNotEmpty) {
          docs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final userName = (data['userName'] ?? '').toString().toLowerCase();
            final userSearchId = (data['userSearchId'] ?? '').toString().toLowerCase();
            final currentAgencyName = (data['currentAgencyName'] ?? '').toString().toLowerCase();
            final targetAgencyName = (data['targetAgencyName'] ?? '').toString().toLowerCase();
            final targetAgencyIdNumber = (data['targetAgencyIdNumber'] ?? '').toString().toLowerCase();

            return userName.contains(_searchQuery) ||
                userSearchId.contains(_searchQuery) ||
                currentAgencyName.contains(_searchQuery) ||
                targetAgencyName.contains(_searchQuery) ||
                targetAgencyIdNumber.contains(_searchQuery);
          }).toList();
        }

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.swap_horiz_rounded, size: 56, color: Colors.white.withOpacity(0.2)),
                const SizedBox(height: 12),
                Text(
                  statusFilter == 'all'
                      ? 'No agency transfer requests found'
                      : 'No $statusFilter agency transfer requests',
                  style: const TextStyle(color: Colors.white54, fontSize: 14),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            data['id'] = docs[index].id;
            return _buildRequestCard(data);
          },
        );
      },
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final String userName = request['userName'] ?? 'Host';
    final String userSearchId = request['userSearchId'] ?? '';
    final String userPhotoUrl = request['userPhotoUrl'] ?? '';
    final String currentAgencyName = request['currentAgencyName'] ?? 'Current Agency';
    final String currentAgencyIdNumber = request['currentAgencyIdNumber'] ?? '';
    final String targetAgencyName = request['targetAgencyName'] ?? 'Target Agency';
    final String targetAgencyIdNumber = request['targetAgencyIdNumber'] ?? '';
    final String targetLogoUrl = request['targetLogoUrl'] ?? '';
    final String reason = request['reason'] ?? '';
    final String status = request['status'] ?? 'pending';
    final Timestamp? createdAt = request['createdAt'] as Timestamp?;
    final String dateStr = createdAt != null
        ? '${createdAt.toDate().day}/${createdAt.toDate().month}/${createdAt.toDate().year} ${createdAt.toDate().hour.toString().padLeft(2, '0')}:${createdAt.toDate().minute.toString().padLeft(2, '0')}'
        : '';

    Color statusColor;
    String statusLabel;
    switch (status) {
      case 'approved':
        statusColor = const Color(0xFF00B074);
        statusLabel = 'APPROVED';
        break;
      case 'rejected':
        statusColor = Colors.redAccent;
        statusLabel = 'REJECTED';
        break;
      case 'cancelled':
        statusColor = Colors.grey;
        statusLabel = 'CANCELLED';
        break;
      default:
        statusColor = Colors.amber;
        statusLabel = 'PENDING';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E142B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: User Info + Status Badge
          Row(
            children: [
              CachedCircleAvatar(
                imageUrl: userPhotoUrl,
                radius: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        Text(
                          'UID: $userSearchId',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => _copyToClipboard(userSearchId, 'Host UID'),
                          child: const Icon(Icons.copy, size: 12, color: Colors.purpleAccent),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withOpacity(0.5)),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 12),

          // Transfer Route: Current Agency -> Target Agency
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2A1D3B),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                // From
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('FROM', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(
                        currentAgencyName,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (currentAgencyIdNumber.isNotEmpty)
                        Text('ID: $currentAgencyIdNumber', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward_rounded, color: Colors.purpleAccent, size: 20),
                ),
                // To
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('TO (TARGET)', style: TextStyle(color: Color(0xFF00B074), fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(
                        targetAgencyName,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (targetAgencyIdNumber.isNotEmpty)
                        Text('ID: $targetAgencyIdNumber', style: const TextStyle(color: Color(0xFF00B074), fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (reason.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Reason: $reason',
              style: const TextStyle(color: Colors.white70, fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],

          if (request['rejectionReason'] != null && request['rejectionReason'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Rejection Reason: ${request['rejectionReason']}',
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ],

          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dateStr,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
              if (status == 'pending') ...[
                Row(
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _rejectTransfer(request),
                      child: const Text('Reject', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00B074),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _approveTransfer(request),
                      child: const Text('Approve', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

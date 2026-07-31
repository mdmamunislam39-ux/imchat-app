import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chat_messenger/components/cached_circle_avatar.dart';
import 'package:chat_messenger/config/theme_config.dart';
import 'package:chat_messenger/helpers/ranking_helper.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:chat_messenger/screens/room/agency_application_screen.dart';
import 'package:chat_messenger/services/agency_service.dart';
import 'package:flutter/material.dart';

enum _AgencyRole { owner, host, invited, none }

class AgencyScreen extends StatefulWidget {
  final User currentUser;

  const AgencyScreen({super.key, required this.currentUser});

  @override
  State<AgencyScreen> createState() => _AgencyScreenState();
}

class _AgencyScreenState extends State<AgencyScreen> {
  final AgencyService _agencyService = AgencyService();

  _AgencyRole _role = _AgencyRole.none;
  bool _isLoading = true;

  // Owner state
  Agency? _agency;
  List<Host> _hosts = [];
  List<User> _agencyUsers = [];
  List<Map<String, dynamic>> _pendingInvitations = [];

  // Host state
  Host? _hostRecord;
  Agency? _hostAgency;

  // Invited state
  List<Map<String, dynamic>> _userInvitations = [];

  // Invite search state
  final _searchIdController = TextEditingController();
  Map<String, dynamic>? _searchedUser;
  bool _isSearching = false;
  bool _isSendingInvite = false;

  // Invitation action loading state
  String? _processingInvitationId;

  // Realtime listeners
  StreamSubscription<DocumentSnapshot>? _userSub;
  StreamSubscription<QuerySnapshot>? _userHostSub;
  StreamSubscription<QuerySnapshot>? _userInvitesSub;
  
  StreamSubscription<DocumentSnapshot>? _ownerAgencySub;
  StreamSubscription<QuerySnapshot>? _ownerHostsSub;
  StreamSubscription<QuerySnapshot>? _ownerPendingSub;
  StreamSubscription<QuerySnapshot>? _ownerUsersSub;
  
  StreamSubscription<DocumentSnapshot>? _hostRecordSub;
  StreamSubscription<DocumentSnapshot>? _hostAgencySub;

  @override
  void initState() {
    super.initState();
    _detectRole();
    _setupBaseListeners();
  }

  @override
  void dispose() {
    _searchIdController.dispose();
    _cancelAllListeners();
    super.dispose();
  }

  void _setupBaseListeners() {
    _userSub?.cancel();
    _userSub = FirebaseFirestore.instance
        .collection('Users')
        .doc(widget.currentUser.userId)
        .snapshots()
        .listen((_) => _detectRole(silent: true));
        
    _userHostSub?.cancel();
    _userHostSub = FirebaseFirestore.instance
        .collection('hosts')
        .where('userId', isEqualTo: widget.currentUser.userId)
        .snapshots()
        .listen((_) => _detectRole(silent: true));

    _userInvitesSub?.cancel();
    _userInvitesSub = FirebaseFirestore.instance
        .collection('host_invitations')
        .where('hostUserId', isEqualTo: widget.currentUser.userId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((_) => _detectRole(silent: true));
  }

  void _setupOwnerListeners(String agencyId) {
    _ownerAgencySub?.cancel();
    _ownerAgencySub = FirebaseFirestore.instance
        .collection('agencies')
        .doc(agencyId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null && mounted) {
        setState(() {
          _agency = Agency.fromMap(snapshot.data()!);
        });
      }
    });

    _ownerHostsSub?.cancel();
    _ownerHostsSub = FirebaseFirestore.instance
        .collection('hosts')
        .where('agencyId', isEqualTo: agencyId)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        final List<Host> uniqueHosts = [];
        final Set<String> seenUserIds = {};
        for (var doc in snapshot.docs) {
          final host = Host.fromMap(doc.data());
          if (host.isActive && !seenUserIds.contains(host.userId)) {
            seenUserIds.add(host.userId);
            uniqueHosts.add(host);
          }
        }
        setState(() {
          _hosts = uniqueHosts;
        });
      }
    });

    _ownerPendingSub?.cancel();
    _ownerPendingSub = FirebaseFirestore.instance
        .collection('host_invitations')
        .where('agencyId', isEqualTo: agencyId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        final List<Map<String, dynamic>> pending = snapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  ...doc.data(),
                })
            .toList();
        setState(() {
          _pendingInvitations = pending;
        });
      }
    });

    _ownerUsersSub?.cancel();
    _ownerUsersSub = FirebaseFirestore.instance
        .collection('Users')
        .where('agencyId', isEqualTo: agencyId)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        final List<User> users = snapshot.docs
            .map((doc) => User.fromMap(doc.data()))
            .toList();
        setState(() {
          _agencyUsers = users;
        });
      }
    });
  }

  void _setupHostListeners(String hostId, String agencyId) {
    _hostRecordSub?.cancel();
    _hostRecordSub = FirebaseFirestore.instance
        .collection('hosts')
        .doc(hostId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null && mounted) {
        setState(() {
          _hostRecord = Host.fromMap(snapshot.data()!);
        });
      }
    });

    _hostAgencySub?.cancel();
    _hostAgencySub = FirebaseFirestore.instance
        .collection('agencies')
        .doc(agencyId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null && mounted) {
        setState(() {
          _hostAgency = Agency.fromMap(snapshot.data()!);
        });
      }
    });
  }

  void _cancelOwnerHostListeners() {
    _ownerAgencySub?.cancel();
    _ownerHostsSub?.cancel();
    _ownerPendingSub?.cancel();
    _ownerUsersSub?.cancel();
    _hostRecordSub?.cancel();
    _hostAgencySub?.cancel();
  }

  void _cancelAllListeners() {
    _userSub?.cancel();
    _userHostSub?.cancel();
    _userInvitesSub?.cancel();
    _ownerUsersSub?.cancel();
    _cancelOwnerHostListeners();
  }

  Future<void> _detectRole({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) {
      setState(() => _isLoading = true);
    }

    try {
      // 1. Check if user is agency owner
      if (widget.currentUser.isAgency) {
        String? agencyId = widget.currentUser.agencyId;
        if (agencyId == null || agencyId.isEmpty) {
          final agency = await _agencyService.getAgencyByOwner(widget.currentUser.userId);
          if (agency != null) {
            agencyId = agency.agencyId;
            if (!mounted) return;
            await FirebaseFirestore.instance
                .collection('Users')
                .doc(widget.currentUser.userId)
                .update({
              'agencyId': agencyId,
              'agencyName': agency.agencyName,
            });
          }
        }

        if (!mounted) return;
        if (agencyId != null && agencyId.isNotEmpty) {
          final agency = await _agencyService.getAgency(agencyId);
          if (agency != null) {
            _setupOwnerListeners(agency.agencyId);
            final hosts = await _agencyService.getAgencyHosts(agency.agencyId);
            final pendingInv =
                await _agencyService.getAgencyPendingInvitations(agency.agencyId);
            if (mounted) {
              setState(() {
                _role = _AgencyRole.owner;
                _agency = agency;
                _hosts = hosts;
                _pendingInvitations = pendingInv;
                _isLoading = false;
              });
            }
            return;
          }
        }
      }

      // 2. Check if user is a host
      if (!mounted) return;
      final hostRecord =
          await _agencyService.getUserHostRecord(widget.currentUser.userId);
      if (hostRecord != null) {
        _setupHostListeners(hostRecord.hostId, hostRecord.agencyId);
        final agency = await _agencyService.getAgency(hostRecord.agencyId);
        if (mounted) {
          setState(() {
            _role = _AgencyRole.host;
            _hostRecord = hostRecord;
            _hostAgency = agency;
            _isLoading = false;
          });
        }
        return;
      }

      // If not owner/host, cancel sub-listeners
      _cancelOwnerHostListeners();

      // 3. Check if user has pending invitations
      if (!mounted) return;
      final invitations = await _agencyService
          .getUserPendingInvitations(widget.currentUser.userId);
      if (invitations.isNotEmpty) {
        if (mounted) {
          setState(() {
            _role = _AgencyRole.invited;
            _userInvitations = invitations;
            _isLoading = false;
          });
        }
        return;
      }

      // 4. No agency relationship
      if (mounted) {
        setState(() {
          _role = _AgencyRole.none;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error detecting agency role: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Agency'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        titleTextStyle: const TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _detectRole,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: _buildRoleView(),
              ),
            ),
    );
  }

  Widget _buildRoleView() {
    switch (_role) {
      case _AgencyRole.owner:
        return _buildOwnerView();
      case _AgencyRole.host:
        return _buildHostView();
      case _AgencyRole.invited:
        return _buildInvitedView();
      case _AgencyRole.none:
        return _buildNoAgencyView();
    }
  }

  // ==================== OWNER VIEW ====================

  int _getUserWeeklyPoints(User user) {
    return user.activityStats?.weeklyDiamondsReceived ?? 0;
  }

  Widget _buildOwnerView() {
    int weeklyPointsSum = 0;
    for (var user in _agencyUsers) {
      weeklyPointsSum += _getUserWeeklyPoints(user);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAgencyInfoCard(),
        const SizedBox(height: 20),
        _buildDashboardStatsGrid(weeklyPointsSum),
        const SizedBox(height: 20),
        _buildWeeklyRewardCard(weeklyPointsSum),
        const SizedBox(height: 20),
        _buildInviteSection(),
        const SizedBox(height: 20),
        if (_pendingInvitations.isNotEmpty) ...[
          _buildPendingInvitationsSection(),
          const SizedBox(height: 20),
        ],
        _buildHostsSection(),
      ],
    );
  }

  Widget _buildWeeklyRewardCard(int totalWeeklyPoints) {
    final tiers = [
      {'target': 10000, 'reward': 500, 'label': 'Tier 1'},
      {'target': 50000, 'reward': 3000, 'label': 'Tier 2'},
      {'target': 100000, 'reward': 7000, 'label': 'Tier 3'},
      {'target': 500000, 'reward': 40000, 'label': 'Tier 4'},
      {'target': 1000000, 'reward': 100000, 'label': 'Tier 5'},
    ];

    int currentTierIndex = 0;
    for (int i = 0; i < tiers.length; i++) {
      if (totalWeeklyPoints >= (tiers[i]['target'] as int)) {
        currentTierIndex = i + 1;
      }
    }

    final nextTier = currentTierIndex < tiers.length ? tiers[currentTierIndex] : tiers.last;
    final int nextTarget = nextTier['target'] as int;
    final double progress = (totalWeeklyPoints / nextTarget).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.shade100.withValues(alpha: 0.5),
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
              const Row(
                children: [
                  Icon(Icons.stars_rounded, color: Colors.amber, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Monday - Monday Rewards',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Text(
                  currentTierIndex > 0 ? 'Tier $currentTierIndex Unlocked' : 'Tier 0',
                  style: TextStyle(
                    color: Colors.amber.shade900,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Cycle: ${RankingHelper.mondayToMondayRangeString}',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Weekly Points: $totalWeeklyPoints / $nextTarget pts',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Next Reward: +${nextTier['reward']} 💎',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              color: Colors.amber,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgencyInfoCard() {
    final agency = _agency!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, primaryColor.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: agency.logoUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(agency.logoUrl, fit: BoxFit.cover),
                      )
                    : const Icon(Icons.business, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      agency.agencyName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: ${agency.agencyIdNumber}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildStatChip(Icons.people, '${_hosts.length}', 'Hosts'),
              const SizedBox(width: 16),
              _buildStatChip(
                  Icons.monetization_on,
                  agency.totalCommissionEarned.toStringAsFixed(0),
                  'Commission'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            '$value $label',
            style: const TextStyle(
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardStatsGrid(int weeklyDiamonds) {
    double weeklyLiveHours = 0.0;
    
    for (var host in _hosts) {
      weeklyLiveHours += host.performance.weeklyLiveHours;
    }

    final double commissionEarned = _agency?.totalCommissionEarned ?? 0.0;

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      children: [
        _buildDashboardStatCard(
            'Total Hosts', '${_hosts.length}', Icons.people, Colors.blue),
        _buildDashboardStatCard(
            'Weekly Points',
            '$weeklyDiamonds pts',
            Icons.star,
            Colors.amber),
        _buildDashboardStatCard(
            'Weekly Commission',
            commissionEarned.toStringAsFixed(0),
            Icons.monetization_on,
            Colors.green),
        _buildDashboardStatCard('Weekly Hours',
            '${weeklyLiveHours.toStringAsFixed(1)}h', Icons.timer, Colors.purple),
      ],
    );
  }

  Widget _buildDashboardStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInviteSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Invite Host',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchIdController,
                  decoration: InputDecoration(
                    hintText: 'Enter user Search ID',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _isSearching ? null : _searchUser,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                child: _isSearching
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Search',
                        style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
          if (_searchedUser != null) ...[
            const SizedBox(height: 12),
            _buildSearchedUserCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchedUserCard() {
    final user = _searchedUser!;
    final name = user['fullname'] ?? 'Unknown';
    final photo = user['photoUrl'] ?? '';
    final userId = user['userId'] ?? '';
    final bool isAlreadyHost = user['userType'] == 'host' || 
                               (user['agencyId'] != null && user['agencyId'].toString().isNotEmpty);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CachedCircleAvatar(
            imageUrl: photo,
            radius: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
                Text('ID: ${user['searchId'] ?? ''}',
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              ],
            ),
          ),
          if (isAlreadyHost)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                'Already a Host',
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else
            ElevatedButton(
              onPressed: _isSendingInvite
                  ? null
                  : () => _sendInvitation(
                      userId, name, user['email'] ?? '', user['number'] ?? ''),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              child: _isSendingInvite
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Invite',
                      style: TextStyle(color: Colors.white, fontSize: 13)),
            ),
        ],
      ),
    );
  }

  Future<void> _searchUser() async {
    final searchId = _searchIdController.text.trim();
    if (searchId.isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchedUser = null;
    });

    try {
      final result = await _agencyService.searchUserBySearchId(searchId);
      setState(() {
        _searchedUser = result;
        _isSearching = false;
      });

      if (result == null && mounted) {
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
                content: Text('No user found with that Search ID'),
                backgroundColor: Colors.orange),
          );
      }
    } catch (e) {
      setState(() => _isSearching = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(SnackBar(
              content: Text('Search failed: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _sendInvitation(
      String userId, String name, String email, String phone) async {
    setState(() => _isSendingInvite = true);

    try {
      await _agencyService.sendHostInvitation(
        agencyId: _agency!.agencyId,
        agencyName: _agency!.agencyName,
        hostUserId: userId,
        hostName: name,
        hostEmail: email,
        hostPhone: phone,
        message: 'You have been invited to join ${_agency!.agencyName}',
      );

      setState(() {
        _isSendingInvite = false;
        _searchedUser = null;
        _searchIdController.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
                content: Text('Invitation sent successfully!'),
                backgroundColor: Colors.green),
          );
      }

      // Refresh pending invitations
      final pendingInv =
          await _agencyService.getAgencyPendingInvitations(_agency!.agencyId);
      setState(() => _pendingInvitations = pendingInv);
    } catch (e) {
      setState(() => _isSendingInvite = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(SnackBar(
              content: Text('Failed to send invitation: $e'),
              backgroundColor: Colors.red));
      }
    }
  }

  Widget _buildPendingInvitationsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pending Invitations (${_pendingInvitations.length})',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ..._pendingInvitations.map((inv) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.pending_actions,
                        color: Colors.orange, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        inv['hostName'] ?? 'Unknown',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    Text('Pending',
                        style: TextStyle(
                            color: Colors.orange.shade700, fontSize: 13)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildHostsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hosts (${_hosts.length})',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (_hosts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('No hosts yet. Invite users to join your agency!',
                    style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ..._hosts.map((host) => _buildHostTile(host)),
        ],
      ),
    );
  }

  Widget _buildHostTile(Host host) {
    User? matchingUser;
    for (var u in _agencyUsers) {
      if (u.userId == host.userId) {
        matchingUser = u;
        break;
      }
    }

    String name = matchingUser?.fullname ?? host.hostName;
    String photo = matchingUser?.photoUrl ?? host.profileImageUrl;
    String searchId = matchingUser?.searchId ?? '';
    int weeklyDiamonds = matchingUser != null ? _getUserWeeklyPoints(matchingUser) : 0;
    int gifts = host.performance.totalGiftsReceived;
    double liveHours = host.performance.weeklyLiveHours;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          CachedCircleAvatar(
            imageUrl: photo,
            radius: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
                if (searchId.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text('ID: $searchId',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                ],
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    _buildMiniStat(Icons.diamond, '$weeklyDiamonds pts', color: Colors.amber.shade700),
                    _buildMiniStat(Icons.card_giftcard, '$gifts', color: Colors.pink.shade400),
                    _buildMiniStat(Icons.access_time, '${liveHours.toStringAsFixed(1)}h', color: Colors.purple.shade400),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.grey, size: 22),
            color: Colors.white,
            onSelected: (value) {
              if (value == 'history') {
                _showHostHistoryBottomSheet(host, name);
              } else if (value == 'remove') {
                _confirmRemoveHost(host);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'history',
                child: Row(
                  children: [
                    Icon(Icons.history, color: Colors.blue, size: 18),
                    SizedBox(width: 8),
                    Text('User History', style: TextStyle(fontSize: 13, color: Colors.black)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'remove',
                child: Row(
                  children: [
                    Icon(Icons.remove_circle_outline, color: Colors.red, size: 18),
                    SizedBox(width: 8),
                    Text('Remove Host', style: TextStyle(fontSize: 13, color: Colors.black)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showHostHistoryBottomSheet(Host host, String name) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      "$name - History & Stats",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 10),
              // Stats
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(Icons.diamond, '${host.performance.totalDiamonds}', 'Diamonds'),
                  _buildStatItem(Icons.star, '${host.performance.totalDiamonds}', 'Points'),
                  _buildStatItem(Icons.access_time, '${host.performance.totalLiveHours.toStringAsFixed(1)}h', 'Hours'),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                "Recent Earnings Logs",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('host_earnings')
                      .where('hostId', isEqualTo: host.hostId)
                      .orderBy('earningDate', descending: true)
                      .limit(20)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text(
                          "No earning history logs found",
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      );
                    }

                    final docs = snapshot.data!.docs;
                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final diamonds = (data['diamondsEarned'] ?? 0).toString();
                        final commission = (data['commissionAmount'] ?? 0).toString();
                        final date = (data['earningDate'] as Timestamp?)?.toDate() ?? DateTime.now();
                        final dateString = "${date.day}/${date.month}/${date.year}";

                        return Card(
                          elevation: 0,
                          color: Colors.grey.shade50,
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.amber.shade50,
                              radius: 18,
                              child: const Icon(Icons.star, color: Colors.amber, size: 18),
                            ),
                            title: Text(
                              "Received $diamonds Diamonds ($diamonds Points)",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black),
                            ),
                            subtitle: Text("Date: $dateString", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            trailing: Text(
                              "+$commission Comm.",
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
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
      },
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 22, color: primaryColor),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black)),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildMiniStat(IconData icon, String value, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color ?? Colors.grey.shade600),
        const SizedBox(width: 3),
        Text(value,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Future<void> _confirmRemoveHost(Host host) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Host'),
        content: Text(
            'Are you sure you want to remove ${host.hostName} from the agency?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _agencyService.removeHostFromAgency(
            _agency!.agencyId, host.hostId);
        // Clear agency fields on user doc
        await _agencyService.leaveAgency(host.userId);
        _detectRole(); // Refresh
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..removeCurrentSnackBar()
            ..showSnackBar(SnackBar(
                content: Text('Failed to remove host: $e'),
                backgroundColor: Colors.red));
        }
      }
    }
  }

  // ==================== HOST VIEW ====================

  Widget _buildHostView() {
    final host = _hostRecord!;
    final int hostWeeklyPoints = host.performance.totalDiamonds;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Agency info
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                primaryColor.withValues(alpha: 0.1),
                primaryColor.withValues(alpha: 0.05)
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.business, color: primaryColor, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    _hostAgency?.agencyName ?? 'Agency',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Member since ${host.joinedDate.day}/${host.joinedDate.month}/${host.joinedDate.year}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildWeeklyRewardCard(hostWeeklyPoints),
        const SizedBox(height: 20),

        // Performance stats
        const Text(
          'Your Performance',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildPerformanceGrid(host.performance),
        const SizedBox(height: 30),

        // Leave button (disabled per client request)
        // SizedBox(
        //   width: double.infinity,
        //   child: OutlinedButton(
        //     onPressed: _confirmLeaveAgency,
        //     style: OutlinedButton.styleFrom(
        //       side: const BorderSide(color: Colors.red),
        //       shape: RoundedRectangleBorder(
        //           borderRadius: BorderRadius.circular(12)),
        //       padding: const EdgeInsets.symmetric(vertical: 14),
        //     ),
        //     child: const Text('Leave Agency',
        //         style: TextStyle(color: Colors.red, fontSize: 16)),
        //   ),
        // ),
      ],
    );
  }

  Widget _buildPerformanceGrid(HostPerformance perf) {
    final stats = [
      {
        'icon': Icons.attach_money,
        'label': 'Earnings',
        'value': perf.totalEarnings.toStringAsFixed(0)
      },
      {
        'icon': Icons.diamond,
        'label': 'Diamonds',
        'value': '${perf.totalDiamonds}'
      },
      {
        'icon': Icons.card_giftcard,
        'label': 'Gifts',
        'value': '${perf.totalGiftsReceived}'
      },
      {
        'icon': Icons.access_time,
        'label': 'Live Hours',
        'value': perf.totalLiveHours.toStringAsFixed(1)
      },
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.8,
      children: stats.map((stat) {
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.1),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(stat['icon'] as IconData, color: primaryColor, size: 20),
              const SizedBox(height: 6),
              Text(
                stat['value'] as String,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                stat['label'] as String,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ==================== INVITED VIEW ====================

  Widget _buildInvitedView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.orange.withValues(alpha: 0.1),
                  Colors.orange.withValues(alpha: 0.05)
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.mail, color: Colors.orange, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pending Invitations',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'You have ${_userInvitations.length} invitation${_userInvitations.length == 1 ? '' : 's'}',
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ..._userInvitations.map((inv) => _buildInvitationCard(inv)),
      ],
    );
  }

  Widget _buildInvitationCard(Map<String, dynamic> invitation) {
    final agencyName = invitation['agencyName'] ?? 'Unknown Agency';
    final message = invitation['message'] ?? '';
    final invitationId = invitation['invitationId'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.business, color: primaryColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  agencyName,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(message,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          ],
          const SizedBox(height: 14),
          _processingInvitationId == invitationId
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  ),
                )
              : Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _processingInvitationId != null
                            ? null
                            : () => _handleRejectInvitation(invitationId),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Reject',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _processingInvitationId != null
                            ? null
                            : () => _handleAcceptInvitation(invitationId),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Accept',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Future<void> _handleAcceptInvitation(String invitationId) async {
    setState(() => _processingInvitationId = invitationId);
    try {
      await _agencyService.acceptInvitation(
          invitationId, widget.currentUser.userId);
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
                content: Text('Invitation accepted! You are now a host.'),
                backgroundColor: Colors.green),
          );
      }
      _detectRole(); // Refresh to host view
    } catch (e) {
      if (mounted) {
        setState(() => _processingInvitationId = null);
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(SnackBar(
              content: Text('Failed to accept invitation: $e'),
              backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _handleRejectInvitation(String invitationId) async {
    setState(() => _processingInvitationId = invitationId);
    try {
      await _agencyService.rejectInvitation(invitationId);
      setState(() {
        _processingInvitationId = null;
        _userInvitations
            .removeWhere((inv) => inv['invitationId'] == invitationId);
      });
      if (_userInvitations.isEmpty) {
        _detectRole(); // Refresh to no-agency view
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
                content: Text('Invitation rejected'),
                backgroundColor: Colors.orange),
          );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _processingInvitationId = null);
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(SnackBar(
              content: Text('Failed to reject invitation: $e'),
              backgroundColor: Colors.red));
      }
    }
  }

  // ==================== NO AGENCY VIEW ====================

  Widget _buildNoAgencyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
                decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.business, color: primaryColor, size: 40),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Agency Yet',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Create your own agency to manage hosts and earn commissions, or wait for an invitation from an existing agency.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.grey.shade600, fontSize: 15, height: 1.4),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: _navigateToApplication,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Apply to Create Agency',
                  style: TextStyle(color: Colors.white, fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _navigateToApplication() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AgencyApplicationScreen(currentUser: widget.currentUser),
      ),
    );

    if (result == true) {
      _detectRole(); // Refresh after successful application
    }
  }
}

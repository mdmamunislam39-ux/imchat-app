import 'package:chat_messenger/screens/room/wallet_screen.dart';
import 'package:chat_messenger/widgets/user_id_badge_widget.dart';
import 'package:chat_messenger/components/dynamic_diamond_icon.dart';
import 'package:chat_messenger/components/dynamic_bean_icon.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chat_messenger/components/cached_circle_avatar.dart';
import 'package:chat_messenger/config/theme_config.dart';
import 'package:chat_messenger/helpers/ranking_helper.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:chat_messenger/screens/room/agency_application_screen.dart';
import 'package:chat_messenger/services/agency_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

enum _AgencyRole { owner, host, invited, none }

class AgencyScreen extends StatefulWidget {
  final User currentUser;
  final bool isHostCentre;

  const AgencyScreen({
    super.key, 
    required this.currentUser,
    this.isHostCentre = false,
  });

  @override
  State<AgencyScreen> createState() => _AgencyScreenState();
}

class _AgencyScreenState extends State<AgencyScreen> {
  final AgencyService _agencyService = AgencyService();

  _AgencyRole _role = _AgencyRole.none;
  bool _isLoading = true;
  late User _liveCurrentUser;
  Map<String, dynamic> _currentUserRawMap = {};

  // Filter state for hosts list
  String _hostFilter = 'all'; // 'all', 'active', 'inactive'

  // Owner state
  Agency? _agency;
  List<Host> _hosts = [];
  List<User> _agencyUsers = [];
  List<Map<String, dynamic>> _pendingInvitations = [];
  bool _checkedAutoClaim = false;

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
    _liveCurrentUser = widget.currentUser;
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
        .listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null && mounted) {
        setState(() {
          _currentUserRawMap = snapshot.data()!;
          _liveCurrentUser = User.fromMap(snapshot.data()!);
        });
      }
      _detectRole(silent: true);
    });
        
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

        if (!_checkedAutoClaim) {
          _checkedAutoClaim = true;
          _checkAndAutoClaimPreviousWeek(agencyId, snapshot.docs);
        }
      }
    });
  }

  Future<void> _checkAndAutoClaimPreviousWeek(
    String agencyId, [
    List<QueryDocumentSnapshot<Map<String, dynamic>>>? userDocs,
  ]) async {
    try {
      if (_agency == null || _agency!.owner.userId != widget.currentUser.userId) return;

      final tiersSnap = await FirebaseFirestore.instance
          .collection('settings')
          .doc('global')
          .collection('agency_commission_tiers')
          .get();

      List<Map<String, dynamic>> tiers = [];
      if (tiersSnap.docs.isNotEmpty) {
        final activeDocs = tiersSnap.docs.where((d) => d.data()['isActive'] != false).toList();
        if (activeDocs.isNotEmpty) {
          tiers = activeDocs.map((d) {
            final data = d.data();
            return {
              'target': (data['minTargetDiamonds'] as num?)?.toInt() ?? 10000,
              'reward': (data['bonusRewardDiamonds'] as num?)?.toInt() ?? 0,
              'label': data['tierName'] ?? 'Tier ${(data['tierLevel'] ?? 1)}',
            };
          }).toList();
          tiers.sort((a, b) => (a['target'] as int).compareTo(b['target'] as int));
        }
      }

      if (tiers.isEmpty) {
        tiers = [
          {'target': 10000, 'reward': 500, 'label': 'Tier 1'},
          {'target': 50000, 'reward': 3000, 'label': 'Tier 2'},
          {'target': 100000, 'reward': 7000, 'label': 'Tier 3'},
          {'target': 500000, 'reward': 40000, 'label': 'Tier 4'},
          {'target': 1000000, 'reward': 100000, 'label': 'Tier 5'},
        ];
      }

      int prevWeekPoints = 0;
      final prevKey = 'weeklyDiamondsReceived_${RankingHelper.previousMondayWeeklySuffix}';

      if (userDocs != null) {
        for (var doc in userDocs) {
          final p = (doc.data()[prevKey] as num?)?.toInt() ?? 0;
          prevWeekPoints += p;
        }
      } else {
        final usersSnap = await FirebaseFirestore.instance
            .collection('Users')
            .where('agencyId', isEqualTo: agencyId)
            .get();
        for (var doc in usersSnap.docs) {
          final p = (doc.data()[prevKey] as num?)?.toInt() ?? 0;
          prevWeekPoints += p;
        }
      }

      if (prevWeekPoints <= 0) return;

      final claimedBeans = await _agencyService.autoClaimPreviousWeekRewards(
        agencyId: agencyId,
        ownerUserId: widget.currentUser.userId,
        previousWeekPoints: prevWeekPoints,
        tiers: tiers,
      );

      if (claimedBeans > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.amberAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('🎉 Auto-claimed $claimedBeans Beans from previous week\'s reward growth track!'),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1E293B),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      debugPrint('⚠️ Error checking auto-claim: $e');
    }
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
      if (widget.isHostCentre) {
        // Priority to Host role when opening as Host Centre
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

        // Check if user has pending invitations
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

        if (mounted) {
          setState(() {
            _role = _AgencyRole.none;
            _isLoading = false;
          });
        }
        return;
      }

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
    final bool isStreamer = widget.isHostCentre || _role == _AgencyRole.host;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(isStreamer ? 'Host Centre'.tr : 'Agency Manager'.tr),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.black87),
        titleTextStyle: const TextStyle(
          color: Colors.black87,
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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

  int _getUserDailyPoints(User user) {
    return user.activityStats?.dailyDiamondsReceived ?? 0;
  }

  int _getUserWeeklyPoints(User user) {
    return user.activityStats?.weeklyDiamondsReceived ?? 0;
  }

  bool _isHostActive(Host host) {
    if (!host.isActive) return false;
    User? matchingUser;
    for (var u in _agencyUsers) {
      if (u.userId == host.userId) {
        matchingUser = u;
        break;
      }
    }
    final weeklyDiamonds = matchingUser != null
        ? (matchingUser.activityStats?.weeklyDiamondsReceived ?? 0)
        : 0;
    return weeklyDiamonds >= 1;
  }

  Widget _buildOwnerView() {
    int dailyPointsSum = 0;
    int weeklyPointsSum = 0;
    
    // Only calculate from currently active registered hosts of this agency
    final activeHostsList = _hosts.where((h) => h.isActive).toList();

    for (var host in activeHostsList) {
      User? matchingUser;
      for (var u in _agencyUsers) {
        if (u.userId == host.userId) {
          matchingUser = u;
          break;
        }
      }
      if (matchingUser != null) {
        dailyPointsSum += _getUserDailyPoints(matchingUser);
        weeklyPointsSum += _getUserWeeklyPoints(matchingUser);
      }
    }

    final activeHostsCount = activeHostsList.where(_isHostActive).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAgencyInfoCard(activeHostsCount, weeklyPointsSum),
        const SizedBox(height: 16),
        _buildDashboardStatsGrid(dailyPointsSum, weeklyPointsSum),
        const SizedBox(height: 16),
        _buildActiveHostsBanner(activeHostsCount, _hosts.length),
        const SizedBox(height: 16),
        _buildWeeklyRewardCard(weeklyPointsSum),
        const SizedBox(height: 16),
        _buildInviteSection(),
        const SizedBox(height: 16),
        if (_pendingInvitations.isNotEmpty) ...[
          _buildPendingInvitationsSection(),
          const SizedBox(height: 16),
        ],
        _buildHostsSection(activeHostsCount),
      ],
    );
  }

  Widget _buildWeeklyRewardCard(int totalWeeklyPoints) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('settings')
          .doc('global')
          .collection('agency_commission_tiers')
          .snapshots(),
      builder: (context, snapshot) {
        List<Map<String, dynamic>> tiers = [];

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final activeDocs = snapshot.data!.docs.where((doc) {
            final d = doc.data() as Map<String, dynamic>?;
            return d?['isActive'] != false;
          }).toList();

          if (activeDocs.isNotEmpty) {
            tiers = activeDocs.map((doc) {
              final d = doc.data() as Map<String, dynamic>;
              return {
                'target': (d['minTargetDiamonds'] as num?)?.toInt() ?? 10000,
                'reward': (d['bonusRewardDiamonds'] as num?)?.toInt() ?? 0,
                'label': d['tierName'] ?? 'Tier ${(d['tierLevel'] ?? 1)}',
                'rate': (d['commissionPercentage'] as num?)?.toDouble() ?? 10.0,
                'color': d['badgeColorHex'] ?? '#FFB300',
              };
            }).toList();

            tiers.sort((a, b) => (a['target'] as int).compareTo(b['target'] as int));
          }
        }

        // Fallback default tiers
        if (tiers.isEmpty) {
          tiers = [
            {'target': 10000, 'reward': 500, 'label': 'Tier 1', 'rate': 5.0, 'color': '#4CAF50'},
            {'target': 50000, 'reward': 3000, 'label': 'Tier 2', 'rate': 8.0, 'color': '#2196F3'},
            {'target': 100000, 'reward': 7000, 'label': 'Tier 3', 'rate': 10.0, 'color': '#FFB300'},
            {'target': 500000, 'reward': 40000, 'label': 'Tier 4', 'rate': 15.0, 'color': '#9C27B0'},
            {'target': 1000000, 'reward': 100000, 'label': 'Tier 5', 'rate': 20.0, 'color': '#E91E63'},
          ];
        }

        int currentTierIndex = 0;
        for (int i = 0; i < tiers.length; i++) {
          if (totalWeeklyPoints >= (tiers[i]['target'] as int)) {
            currentTierIndex = i + 1;
          }
        }

        final nextTier = currentTierIndex < tiers.length ? tiers[currentTierIndex] : tiers.last;
        final int nextTarget = nextTier['target'] as int;
        final double progress = (totalWeeklyPoints / nextTarget).clamp(0.0, 1.0);
        final String currentTierLabel = currentTierIndex > 0
            ? '${tiers[currentTierIndex - 1]['label']} Unlocked'
            : 'Tier 0';

        return GestureDetector(
          onTap: () => _showRewardGrowthTrackModal(context, totalWeeklyPoints, tiers, currentTierIndex),
          child: Container(
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
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87),
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
                        currentTierLabel,
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Cycle: ${RankingHelper.mondayToMondayRangeString}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                    Row(
                      children: [
                        Text(
                          'Reward Growth Track',
                          style: TextStyle(
                              color: Colors.amber.shade800,
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            size: 16, color: Colors.amber.shade800),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const DynamicDiamondIcon(width: 14, height: 14),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              'Weekly Points: $totalWeeklyPoints / $nextTarget pts',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Next Reward: +${nextTier['reward']} ',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade900),
                        ),
                        const DynamicDiamondIcon(width: 14, height: 14),
                      ],
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
          ),
        );
      },
    );
  }

  void _showRewardGrowthTrackModal(
    BuildContext context,
    int totalWeeklyPoints,
    List<Map<String, dynamic>> tiers,
    int currentTierIndex,
  ) {
    final bool isOwner = _role == _AgencyRole.owner ||
        (_agency != null && _agency!.owner.userId == widget.currentUser.userId);
    final String currentCycleSuffix = RankingHelper.mondayWeeklySuffix;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final Set<int> claimingIndices = {};
        bool isClaimingAll = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _agency != null
                  ? _agencyService.streamTierClaims(
                      agencyId: _agency!.agencyId,
                      cycleSuffix: currentCycleSuffix,
                    )
                  : const Stream.empty(),
              builder: (context, claimSnap) {
                final claimData = claimSnap.data?.data();
                final List<int> claimedTiers =
                    List<int>.from(claimData?['claimedTiers'] ?? []);
                final int totalClaimedSoFar =
                    (claimData?['totalClaimed'] as num?)?.toInt() ?? 0;

                // Find highest reached milestone and calculate eligible unclaimed tiers
                int highestReachedMilestone = 0;
                final eligibleUnclaimed = <Map<String, dynamic>>[];
                for (int i = 0; i < tiers.length; i++) {
                  final int target = tiers[i]['target'] as int;
                  final int reward = tiers[i]['reward'] as int;
                  if (totalWeeklyPoints >= target) {
                    if (reward > highestReachedMilestone) {
                      highestReachedMilestone = reward;
                    }
                    if (!claimedTiers.contains(i)) {
                      eligibleUnclaimed.add({
                        'index': i,
                        'reward': reward,
                        'label': tiers[i]['label'] as String,
                      });
                    }
                  }
                }

                // Total remaining net beans to claim = highest reached milestone - already claimed
                final int totalNetEligibleBonus =
                    (highestReachedMilestone - totalClaimedSoFar).clamp(0, highestReachedMilestone);

                return Container(
                  height: MediaQuery.of(context).size.height * 0.85,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 8),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.stars_rounded, color: Colors.amber, size: 28),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Reward Growth Track',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    'Cycle: ${RankingHelper.mondayToMondayRangeString}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Current Weekly Points',
                                        style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const DynamicDiamondIcon(width: 20, height: 20),
                                          const SizedBox(width: 6),
                                          Text(
                                            '$totalWeeklyPoints',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.amber),
                                  ),
                                  child: Text(
                                    currentTierIndex > 0
                                        ? '${tiers[currentTierIndex - 1]['label']} Unlocked'
                                        : 'Tier 0 Active',
                                    style: const TextStyle(
                                      color: Colors.amber,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            // Multi-claim all button if 2 or more eligible unclaimed tiers with net beans > 0
                            if (isOwner && eligibleUnclaimed.length >= 2 && totalNetEligibleBonus > 0) ...[
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: isClaimingAll
                                      ? null
                                      : () async {
                                          if (_agency == null) return;
                                          setModalState(() => isClaimingAll = true);
                                          try {
                                            final totalClaimed =
                                                await _agencyService.claimAllEligibleTiers(
                                              agencyId: _agency!.agencyId,
                                              ownerUserId: widget.currentUser.userId,
                                              cycleSuffix: currentCycleSuffix,
                                              eligibleTiers: eligibleUnclaimed,
                                            );
                                            if (totalClaimed > 0 && context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Row(
                                                    children: [
                                                      const Icon(Icons.celebration_rounded,
                                                          color: Colors.amberAccent),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Text(
                                                          '🎉 Claimed $totalClaimed Beans net for ${eligibleUnclaimed.length} tiers!',
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  backgroundColor: const Color(0xFF1E293B),
                                                  duration: const Duration(seconds: 3),
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Failed to claim: $e'),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                          } finally {
                                            if (context.mounted) {
                                              setModalState(() => isClaimingAll = false);
                                            }
                                          }
                                        },
                                  icon: isClaimingAll
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.card_giftcard_rounded,
                                          color: Colors.white, size: 18),
                                  label: Text(
                                    isClaimingAll
                                        ? 'Claiming...'
                                        : 'Claim Remaining ($totalNetEligibleBonus Beans) 🎁',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.amber.shade700,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                          itemCount: tiers.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final tier = tiers[index];
                            final int target = tier['target'] as int;
                            final int milestoneReward = tier['reward'] as int;
                            final double rate = (tier['rate'] as num).toDouble();
                            final String label = tier['label'] as String;

                            final bool isCompleted = totalWeeklyPoints >= target;
                            final bool isClaimed = claimedTiers.contains(index);
                            final bool isClaimingThis = claimingIndices.contains(index);
                            final int remaining = (target - totalWeeklyPoints).clamp(0, target);
                            final double progress = (totalWeeklyPoints / target).clamp(0.0, 1.0);

                            // Net payout for this tier deducting what has already been claimed
                            final int netPayoutForThisTier =
                                (milestoneReward - totalClaimedSoFar).clamp(0, milestoneReward);

                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isClaimed
                                      ? Colors.green.shade300
                                      : (isCompleted
                                          ? Colors.amber.shade400
                                          : (remaining > 0 &&
                                                  (index == 0 ||
                                                      totalWeeklyPoints >=
                                                          (tiers[index - 1]['target'] as int))
                                              ? Colors.amber.shade300
                                              : Colors.grey.shade200)),
                                  width: isClaimed || isCompleted ? 1.5 : 1.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 6,
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
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isClaimed
                                              ? Colors.green.shade50
                                              : (isCompleted
                                                  ? Colors.amber.shade50
                                                  : Colors.grey.shade100),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: isClaimed
                                                ? Colors.green.shade300
                                                : (isCompleted
                                                    ? Colors.amber.shade300
                                                    : Colors.grey.shade300),
                                          ),
                                        ),
                                        child: Text(
                                          label,
                                          style: TextStyle(
                                            color: isClaimed
                                                ? Colors.green.shade800
                                                : (isCompleted
                                                    ? Colors.amber.shade900
                                                    : Colors.grey.shade700),
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Target: $target 💎',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const Spacer(),
                                      // Right action button: Claimed / Claim / Locked
                                      if (isClaimed)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.green.shade300),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.check_circle_rounded,
                                                  color: Colors.green.shade700, size: 13),
                                              const SizedBox(width: 4),
                                              Text(
                                                'CLAIMED',
                                                style: TextStyle(
                                                  color: Colors.green.shade800,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      else if (isCompleted && isOwner)
                                        Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: isClaimingThis
                                                ? null
                                                : () async {
                                                    if (_agency == null) return;
                                                    setModalState(() => claimingIndices.add(index));
                                                    try {
                                                      final netClaimed =
                                                          await _agencyService.claimTierReward(
                                                        agencyId: _agency!.agencyId,
                                                        ownerUserId: widget.currentUser.userId,
                                                        cycleSuffix: currentCycleSuffix,
                                                        tierIndex: index,
                                                        milestoneReward: milestoneReward,
                                                        tierLabel: label,
                                                      );
                                                      if (netClaimed > 0 && context.mounted) {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(
                                                            content: Row(
                                                              children: [
                                                                const Icon(
                                                                    Icons.celebration_rounded,
                                                                    color: Colors.amberAccent),
                                                                const SizedBox(width: 8),
                                                                Expanded(
                                                                  child: Text(
                                                                    '🎉 Claimed $netClaimed Beans net for $label! (Milestone: $milestoneReward)',
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                            backgroundColor:
                                                                const Color(0xFF1E293B),
                                                            duration: const Duration(seconds: 3),
                                                          ),
                                                        );
                                                      }
                                                    } catch (e) {
                                                      if (context.mounted) {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(
                                                            content: Text('Failed to claim: $e'),
                                                            backgroundColor: Colors.red,
                                                          ),
                                                        );
                                                      }
                                                    } finally {
                                                      if (context.mounted) {
                                                        setModalState(
                                                            () => claimingIndices.remove(index));
                                                      }
                                                    }
                                                  },
                                            borderRadius: BorderRadius.circular(8),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 12, vertical: 5),
                                              decoration: BoxDecoration(
                                                gradient: const LinearGradient(
                                                  colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                                                ),
                                                borderRadius: BorderRadius.circular(8),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.amber.withValues(alpha: 0.4),
                                                    blurRadius: 6,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  if (isClaimingThis)
                                                    const SizedBox(
                                                      width: 12,
                                                      height: 12,
                                                      child: CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: Colors.white,
                                                      ),
                                                    )
                                                  else ...[
                                                    const Icon(Icons.card_giftcard_rounded,
                                                        color: Colors.white, size: 14),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      netPayoutForThisTier > 0
                                                          ? 'CLAIM'
                                                          : 'CLAIM',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w900,
                                                        letterSpacing: 0.5,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ),
                                        )
                                      else
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade200,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            isCompleted ? 'UNLOCKED ✅' : 'LOCKED 🔒',
                                            style: TextStyle(
                                              color: isCompleted
                                                  ? Colors.green.shade800
                                                  : Colors.grey.shade700,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    padding:
                                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            const Text('Reward: ',
                                                style: TextStyle(
                                                    fontSize: 12, color: Colors.black54)),
                                            Text(
                                              '+$milestoneReward 💎 Milestone',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.amber.shade900,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            const Text('Commission: ',
                                                style: TextStyle(
                                                    fontSize: 12, color: Colors.black54)),
                                            Text(
                                              '${rate.toStringAsFixed(1)}%',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.purple,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      minHeight: 6,
                                      backgroundColor: Colors.grey.shade200,
                                      color: isClaimed
                                          ? Colors.green
                                          : (isCompleted ? Colors.green : Colors.amber),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        isClaimed
                                            ? 'Reward Credited to Wallet'
                                            : (isCompleted
                                                ? 'Target Reached! Ready to claim'
                                                : 'Progress: ${(progress * 100).toStringAsFixed(1)}%'),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isClaimed
                                              ? Colors.green.shade700
                                              : (isCompleted
                                                  ? Colors.amber.shade900
                                                  : Colors.grey.shade600),
                                          fontWeight: isCompleted
                                              ? FontWeight.w600
                                              : FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        isClaimed
                                            ? 'Claimed 🏆'
                                            : (isCompleted
                                                ? (netPayoutForThisTier > 0
                                                    ? 'Claim +$netPayoutForThisTier Beans 🎁'
                                                    : 'Claimed 🏆')
                                                : 'Remaining: $remaining 💎 needed'),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isClaimed
                                              ? Colors.green.shade700
                                              : (isCompleted
                                                  ? Colors.amber.shade900
                                                  : Colors.orange.shade800),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildAgencyInfoCard(int activeHostsCount, [int weeklyPoints = 0]) {
    final agency = _agency!;
    final agencyIdText = agency.agencyIdNumber.isNotEmpty
        ? agency.agencyIdNumber
        : agency.agencyId;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1E293B), // Slate 800
            Color(0xFF0F172A), // Slate 900
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Profile Picture / Logo
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.shade300, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: agency.logoUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(
                          agency.logoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.white12,
                            child: const Icon(Icons.business_rounded,
                                color: Colors.amber, size: 32),
                          ),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.business_rounded,
                            color: Colors.amber, size: 32),
                      ),
              ),
              const SizedBox(width: 16),
              // Agency Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            agency.agencyName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: Colors.amber.withValues(alpha: 0.6)),
                          ),
                          child: const Text(
                            'AGENCY',
                            style: TextStyle(
                              color: Colors.amber,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Agency ID with copy button
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: agencyIdText));
                        ScaffoldMessenger.of(context)
                          ..removeCurrentSnackBar()
                          ..showSnackBar(
                            SnackBar(
                              content: Text('Agency ID copied: $agencyIdText'),
                              backgroundColor: Colors.green.shade700,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'ID: $agencyIdText',
                              style: TextStyle(
                                color: Colors.grey.shade300,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.copy_rounded,
                              size: 13,
                              color: Colors.amber.shade200,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 14),
          // Quick Stat Chips
          Row(
            children: [
              Expanded(
                child: _buildHeaderChip(
                  icon: Icons.people_alt_rounded,
                  value: '${_hosts.length}',
                  label: 'Total Hosts',
                  color: Colors.blue.shade300,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildHeaderChip(
                  icon: Icons.check_circle_rounded,
                  value: '$activeHostsCount',
                  label: 'Active Hosts',
                  color: Colors.greenAccent.shade400,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('settings')
                      .doc('global')
                      .collection('agency_commission_tiers')
                      .snapshots(),
                  builder: (context, snapshot) {
                    final agencyRate = _agency?.commissionRate;
                    double currentRate = (agencyRate != null && agencyRate > 0)
                        ? (agencyRate * 100)
                        : 10.0;

                    if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                      final docs = snapshot.data!.docs.where((doc) {
                        final d = doc.data() as Map<String, dynamic>?;
                        return d?['isActive'] != false;
                      }).toList();

                      final tiers = docs.map((d) => d.data() as Map<String, dynamic>).toList();
                      tiers.sort((a, b) => ((a['minTargetDiamonds'] as num?) ?? 0).compareTo((b['minTargetDiamonds'] as num?) ?? 0));

                      if (tiers.isNotEmpty) {
                        currentRate = ((tiers.first['commissionPercentage'] as num?) ?? 10.0).toDouble();
                        for (var t in tiers) {
                          final target = (t['minTargetDiamonds'] as num?)?.toInt() ?? 0;
                          if (weeklyPoints >= target) {
                            currentRate = ((t['commissionPercentage'] as num?) ?? currentRate).toDouble();
                          }
                        }
                      }
                    }

                    return _buildHeaderChip(
                      iconWidget: const DynamicBeanIcon(width: 16, height: 16),
                      value: '${currentRate.toStringAsFixed(0)}%',
                      label: 'Commission',
                      color: Colors.amber.shade300,
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderChip({
    IconData? icon,
    Widget? iconWidget,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (iconWidget != null)
            iconWidget
          else if (icon != null)
            Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 10,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardStatsGrid(int dailyDiamonds, int weeklyDiamonds) {
    double weeklyLiveHours = 0.0;
    for (var host in _hosts.where((h) => h.isActive)) {
      weeklyLiveHours += host.performance.weeklyLiveHours;
    }

    final double commissionEarned = _agency?.totalCommissionEarned ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Text(
            'Performance Dashboard',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.35,
          children: [
            _buildModernStatCard(
              title: 'Daily Earning',
              value: '$dailyDiamonds',
              unitWidget: const DynamicDiamondIcon(width: 15, height: 15),
              subtitle: "Today's revenue",
              icon: Icons.today_rounded,
              gradientColors: [const Color(0xFFFFF7ED), const Color(0xFFFFEDD5)],
              accentColor: const Color(0xFFEA580C),
            ),
            _buildModernStatCard(
              title: 'Weekly Earning',
              value: '$weeklyDiamonds',
              unitWidget: const DynamicDiamondIcon(width: 15, height: 15),
              subtitle: 'Current cycle',
              icon: Icons.stars_rounded,
              gradientColors: [const Color(0xFFFEFCE8), const Color(0xFFFEF08A)],
              accentColor: const Color(0xFFCA8A04),
            ),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('settings')
                  .doc('global')
                  .collection('agency_commission_tiers')
                  .snapshots(),
              builder: (context, snapshot) {
                final agencyRate = _agency?.commissionRate;
                double currentRate = (agencyRate != null && agencyRate > 0)
                    ? (agencyRate * 100)
                    : 10.0;

                if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                  final docs = snapshot.data!.docs.where((doc) {
                    final d = doc.data() as Map<String, dynamic>?;
                    return d?['isActive'] != false;
                  }).toList();

                  final tiers = docs.map((d) => d.data() as Map<String, dynamic>).toList();
                  tiers.sort((a, b) => ((a['minTargetDiamonds'] as num?) ?? 0).compareTo((b['minTargetDiamonds'] as num?) ?? 0));

                  if (tiers.isNotEmpty) {
                    currentRate = ((tiers.first['commissionPercentage'] as num?) ?? 10.0).toDouble();
                    for (var t in tiers) {
                      final target = (t['minTargetDiamonds'] as num?)?.toInt() ?? 0;
                      if (weeklyDiamonds >= target) {
                        currentRate = ((t['commissionPercentage'] as num?) ?? currentRate).toDouble();
                      }
                    }
                  }
                }

                // Total Commission based on achieved tier rate
                final double totalCommission = weeklyDiamonds * (currentRate / 100);

                return _buildModernStatCard(
                  title: 'Total Commission',
                  value: totalCommission.toStringAsFixed(0),
                  unitWidget: const DynamicBeanIcon(width: 15, height: 15),
                  subtitle: '${currentRate.toStringAsFixed(0)}% earnings',
                  icon: Icons.account_balance_wallet_rounded,
                  gradientColors: [const Color(0xFFF0FDF4), const Color(0xFFDCFCE7)],
                  accentColor: const Color(0xFF16A34A),
                );
              },
            ),
            _buildModernStatCard(
              title: 'Weekly Hours',
              value: weeklyLiveHours.toStringAsFixed(1),
              unit: 'h',
              subtitle: 'Stream time',
              icon: Icons.timer_rounded,
              gradientColors: [const Color(0xFFFAF5FF), const Color(0xFFF3E8FF)],
              accentColor: const Color(0xFF9333EA),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModernStatCard({
    required String title,
    required String value,
    String? unit,
    Widget? unitWidget,
    required String subtitle,
    required IconData icon,
    required List<Color> gradientColors,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey.shade800,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accentColor, size: 16),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              if (unitWidget != null)
                unitWidget
              else if (unit != null)
                Text(
                  unit,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
            ],
          ),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveHostsBanner(int activeCount, int totalCount) {
    final double ratio =
        totalCount > 0 ? (activeCount / totalCount).clamp(0.0, 1.0) : 0.0;
    final int percentage = (ratio * 100).round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.teal.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.shade50.withValues(alpha: 0.5),
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
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.verified_rounded,
                        color: Colors.teal, size: 20),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Active Hosts',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.teal.shade300),
                ),
                child: Text(
                  '$activeCount / $totalCount Active ($percentage%)',
                  style: TextStyle(
                    color: Colors.teal.shade800,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Active Criteria: Received ≥ 1 ',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const DynamicDiamondIcon(width: 13, height: 13),
              Expanded(
                child: Text(
                  ' during weekly cycle (Sunday 10:00 PM – Sunday 10:00 PM)',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 7,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                percentage > 50 ? Colors.teal : Colors.orange,
              ),
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
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Invite New Host',
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
    final String? userAgencyId = user['agencyId'] as String?;
    final bool isSelf = userId == widget.currentUser.userId;
    final bool isHostAlready = _hosts.any((h) => h.userId == userId && h.isActive) ||
        (user['isHost'] == true && userAgencyId == _agency?.agencyId);
    final bool isOtherAgencyHost = userAgencyId != null && userAgencyId.isNotEmpty && userAgencyId != _agency?.agencyId;

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
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isSelf) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.purple.shade200),
                        ),
                        child: Text(
                          'You',
                          style: TextStyle(
                            color: Colors.purple.shade800,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                UserIdBadgeWidget(
                    searchId: (user['searchId'] ?? '').toString(),
                    badgeHeight: 14,
                    textStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              ],
            ),
          ),
          if (isHostAlready)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Text(
                isSelf ? 'Active Host' : 'Already a Host',
                style: TextStyle(
                  color: Colors.green.shade800,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else if (isOtherAgencyHost)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                'In Another Agency',
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
                  : Text(
                      isSelf ? 'Invite Yourself' : 'Invite',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
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
              Text(
                'Pending Invitations (${_pendingInvitations.length})',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Text(
                  'Awaiting acceptance',
                  style: TextStyle(
                      color: Colors.orange.shade800,
                      fontSize: 11,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._pendingInvitations.map((inv) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.pending_actions_rounded,
                        color: Colors.orange, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            inv['hostName'] ?? 'Unknown User',
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87),
                          ),
                          if (inv['hostEmail'] != null &&
                              inv['hostEmail'].toString().isNotEmpty)
                            Text(
                              inv['hostEmail'].toString(),
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade600),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Pending',
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.red, size: 20),
                      tooltip: 'Cancel Invitation',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _cancelPendingInvitation(
                        inv['id'] ?? inv['invitationId'] ?? '',
                        inv['hostName'] ?? 'User',
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Future<void> _cancelPendingInvitation(
      String invitationId, String hostName) async {
    if (invitationId.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Invitation'),
        content: Text(
            'Are you sure you want to cancel the invitation sent to $hostName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Cancel Invite', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await FirebaseFirestore.instance
            .collection('host_invitations')
            .doc(invitationId)
            .delete();
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..removeCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text('Invitation cancelled successfully'),
                backgroundColor: Colors.orange,
              ),
            );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..removeCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text('Failed to cancel invitation: $e'),
                backgroundColor: Colors.red,
              ),
            );
        }
      }
    }
  }

  Widget _buildHostsSection(int activeHostsCount) {
    List<Host> filteredHosts = _hosts;
    if (_hostFilter == 'active') {
      filteredHosts = _hosts.where(_isHostActive).toList();
    } else if (_hostFilter == 'inactive') {
      filteredHosts = _hosts.where((h) => !_isHostActive(h)).toList();
    }

    final int inactiveCount = _hosts.length - activeHostsCount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
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
              Text(
                'All Hosts (${_hosts.length})',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Filter Tabs
          Row(
            children: [
              _buildHostFilterTab('all', 'All (${_hosts.length})'),
              const SizedBox(width: 8),
              _buildHostFilterTab('active', 'Active ($activeHostsCount)'),
              const SizedBox(width: 8),
              _buildHostFilterTab('inactive', 'Inactive ($inactiveCount)'),
            ],
          ),
          const SizedBox(height: 14),
          if (filteredHosts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  _hostFilter == 'active'
                      ? 'No active hosts yet in this weekly cycle'
                      : (_hostFilter == 'inactive'
                          ? 'No inactive hosts'
                          : 'No hosts yet. Invite users to join your agency!'),
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                ),
              ),
            )
          else
            ...filteredHosts.map((host) => _buildHostTile(host)),
        ],
      ),
    );
  }

  Widget _buildHostFilterTab(String filterKey, String label) {
    final isSelected = _hostFilter == filterKey;
    return GestureDetector(
      onTap: () {
        setState(() {
          _hostFilter = filterKey;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
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

    final bool isActive = _isHostActive(host);
    final String name = matchingUser?.fullname ?? host.hostName;
    final String photo = matchingUser?.photoUrl ?? host.profileImageUrl;
    final String searchId = matchingUser?.searchId ?? '';
    final int weeklyDiamonds = matchingUser != null
        ? _getUserWeeklyPoints(matchingUser)
        : 0;
    final int gifts = host.performance.totalGiftsReceived;
    final double liveHours = host.performance.weeklyLiveHours;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive ? Colors.teal.shade200 : Colors.grey.shade200,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Host Avatar with active indicator
          Stack(
            children: [
              CachedCircleAvatar(
                imageUrl: photo,
                radius: 24,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: isActive ? Colors.green : Colors.grey,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          // Host Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isActive
                            ? Colors.green.shade50
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isActive
                              ? Colors.green.shade300
                              : Colors.grey.shade400,
                        ),
                      ),
                      child: Text(
                        isActive ? 'Active' : 'Inactive',
                        style: TextStyle(
                          color: isActive
                              ? Colors.green.shade800
                              : Colors.grey.shade700,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                if (searchId.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  UserIdBadgeWidget(
                    searchId: searchId,
                    badgeHeight: 14,
                    textStyle:
                        TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 6),
                Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    _buildMiniStat(null, '$weeklyDiamonds pts',
                        leadingWidget: const DynamicDiamondIcon(width: 13, height: 13)),
                    _buildMiniStat(Icons.access_time_rounded,
                        '${liveHours.toStringAsFixed(1)}h',
                        color: Colors.purple.shade500),
                    _buildMiniStat(Icons.card_giftcard_rounded, '$gifts gifts',
                        color: Colors.pink.shade400),
                  ],
                ),
              ],
            ),
          ),
          // Three-dots menu to cancel / remove host or view history
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded,
                color: Colors.grey, size: 22),
            color: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                    Icon(Icons.history_rounded, color: Colors.blue, size: 18),
                    SizedBox(width: 10),
                    Text('View History',
                        style: TextStyle(fontSize: 13, color: Colors.black87)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'remove',
                child: Row(
                  children: [
                    Icon(Icons.cancel_outlined, color: Colors.red, size: 18),
                    SizedBox(width: 10),
                    Text('Remove Host',
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.red,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showHostHistoryBottomSheet(Host? host, String name, [String? fallbackUserId]) {
    final String targetUserId = (host?.userId != null && host!.userId.isNotEmpty)
        ? host.userId
        : (fallbackUserId ?? _liveCurrentUser.userId);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: MediaQuery.of(context).size.height * 0.68,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      "$name - Live History & Stats",
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
              // Real-time User Stats Stream
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('Users')
                    .doc(targetUserId)
                    .snapshots(),
                builder: (context, userSnap) {
                  final userData = userSnap.data?.data() as Map<String, dynamic>?;
                  final userObj = userData != null ? User.fromMap(userData) : null;
                  
                  final int totalDiamonds = userObj?.activityStats?.weeklyDiamondsReceived ??
                      userObj?.diamonds ??
                      (host?.performance.totalDiamonds ?? 0);
                  
                  final double liveHours = ((userObj?.activityStats?.weeklyVoiceRoomMinutes ?? 0) / 60.0) > 0
                      ? ((userObj?.activityStats?.weeklyVoiceRoomMinutes ?? 0) / 60.0)
                      : (host?.performance.totalLiveHours ?? 0.0);

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(
                        null,
                        _formatNumber(totalDiamonds),
                        'Diamonds',
                        customWidget: const DynamicDiamondIcon(width: 22, height: 22),
                      ),
                      _buildStatItem(
                        null,
                        _formatNumber(totalDiamonds),
                        'Points',
                        customWidget: const DynamicDiamondIcon(width: 22, height: 22),
                      ),
                      _buildStatItem(
                        Icons.access_time_rounded,
                        '${liveHours.toStringAsFixed(1)}h',
                        'Live Hours',
                        iconColor: Colors.purple.shade500,
                      ),
                    ],
                  );
                },
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
                      .where('hostId', isEqualTo: targetUserId)
                      .orderBy('earningDate', descending: true)
                      .limit(30)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text(
                          "No live earning history logs found",
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
                        final beansEarned = (data['beansEarned'] ?? 0).toString();
                        final giftName = (data['giftName'] ?? '').toString();
                        final date = (data['earningDate'] as Timestamp?)?.toDate() ?? DateTime.now();
                        final dateString = "${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";

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
                              child: const DynamicDiamondIcon(width: 18, height: 18),
                            ),
                            title: Row(
                              children: [
                                Text(
                                  giftName.isNotEmpty ? "Gift: $giftName (+$diamonds) " : "Received $diamonds ",
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black),
                                ),
                                const DynamicDiamondIcon(width: 12, height: 12),
                              ],
                            ),
                            subtitle: Text("Date: $dateString", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "+$beansEarned ",
                                  style: TextStyle(
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                const DynamicBeanIcon(width: 14, height: 14),
                              ],
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

  Widget _buildStatItem(IconData? icon, String value, String label, {Widget? customWidget, Color? iconColor}) {
    return Column(
      children: [
        if (customWidget != null)
          customWidget
        else if (icon != null)
          Icon(icon, size: 22, color: iconColor ?? primaryColor),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black)),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildMiniStat(IconData? icon, String value, {Color? color, Widget? leadingWidget}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leadingWidget != null)
          leadingWidget
        else if (icon != null)
          Icon(icon, size: 14, color: color ?? Colors.grey.shade600),
        const SizedBox(width: 4),
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

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  // ==================== STREAMER / HOST VIEW ====================

  Widget _buildHostView() {
    final hostUser = _liveCurrentUser;
    final int dailyDiamonds = hostUser.activityStats?.dailyDiamondsReceived ?? 0;
    final int weeklyDiamonds = hostUser.activityStats?.weeklyDiamondsReceived ??
        (_hostRecord?.performance.totalDiamonds ?? 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStreamerHeaderCard(hostUser, dailyDiamonds, weeklyDiamonds),
        const SizedBox(height: 24),
        _buildLiveOverviewCard(weeklyDiamonds),
        const SizedBox(height: 24),
        _buildMyToolSection(hostUser),
      ],
    );
  }

  Widget _buildStreamerHeaderCard(User hostUser, int dailyEarned, int weeklyEarned) {
    final photo = hostUser.photoUrl;
    final name = hostUser.fullname.isNotEmpty ? hostUser.fullname : (_hostRecord?.hostName ?? 'Streamer');
    final searchId = hostUser.searchId.isNotEmpty ? hostUser.searchId : hostUser.userId;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF8B5CF6), // Purple 500
            Color(0xFF6D28D9), // Purple 700
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.amber.shade300, width: 2),
                ),
                child: CachedCircleAvatar(
                  imageUrl: photo,
                  radius: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'UID:$searchId',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  _showHostHistoryBottomSheet(_hostRecord, name, hostUser.userId);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: const Text(
                    'Earning details',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _formatNumber(dailyEarned),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const DynamicDiamondIcon(width: 20, height: 20),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Earnings today',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _formatNumber(weeklyEarned),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const DynamicDiamondIcon(width: 20, height: 20),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Earnings this week',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLiveOverviewCard(int weeklyEarned) {
    // Read previous week's actual received diamonds from Firestore user doc
    final int lastWeekTotal = (_currentUserRawMap['weeklyDiamondsReceived_${RankingHelper.previousMondayWeeklySuffix}'] as num?)?.toInt() ??
        (_currentUserRawMap['weeklyDiamondsReceived_${RankingHelper.weeklySuffix}'] as num?)?.toInt() ??
        0;

    final double? lastWeekDiff = lastWeekTotal > 0
        ? ((weeklyEarned - lastWeekTotal) / lastWeekTotal) * 100
        : (weeklyEarned > 0 ? 100.0 : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Live Overview',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Column(
            children: [
              _buildOverviewRow(
                title: 'Diamonds earned this week',
                value: _formatNumber(weeklyEarned),
              ),
              Divider(height: 28, color: Colors.grey.shade100),
              _buildOverviewRow(
                title: 'Diamonds earned last week',
                value: _formatNumber(lastWeekTotal),
                diffPercent: lastWeekDiff,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewRow({
    required String title,
    required String value,
    double? diffPercent,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
              height: 1.3,
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(width: 4),
                const DynamicDiamondIcon(width: 14, height: 14),
              ],
            ),
            if (diffPercent != null) ...[
              const SizedBox(height: 2),
              Text(
                '(${diffPercent >= 0 ? '+' : ''}${diffPercent.toStringAsFixed(2)}%)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: diffPercent < 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildMyToolSection(User hostUser) {
    final tools = [
      {
        'title': 'My agency',
        'icon': Icons.groups_rounded,
        'onTap': () => _showMyAgencyModal(),
      },
      {
        'title': 'Live Records',
        'icon': Icons.insert_chart_rounded,
        'onTap': () {
          _showHostHistoryBottomSheet(_hostRecord, hostUser.fullname, hostUser.userId);
        },
      },
      {
        'title': 'My Wallet',
        'icon': Icons.account_balance_wallet_rounded,
        'onTap': () {
          Get.to(() => UserWalletScreen(currentUser: hostUser));
        },
      },
      {
        'title': 'Agency\nchange',
        'icon': Icons.edit_note_rounded,
        'onTap': () => _showAgencyChangeModal(),
      },
      {
        'title': 'my\nsupporter',
        'icon': Icons.format_list_bulleted_rounded,
        'onTap': () => _showMySupportersModal(hostUser),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'My Tool',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: tools.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            childAspectRatio: 0.82,
            crossAxisSpacing: 12,
            mainAxisSpacing: 16,
          ),
          itemBuilder: (context, index) {
            final tool = tools[index];
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: tool['onTap'] as VoidCallback,
              child: Column(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Icon(
                      tool['icon'] as IconData,
                      color: const Color(0xFF1E293B),
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tool['title'] as String,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF475569),
                      height: 1.15,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  void _showMyAgencyModal() {
    final String targetAgencyId = _hostAgency?.agencyId ?? _liveCurrentUser.agencyId ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StreamBuilder<DocumentSnapshot>(
          stream: targetAgencyId.isNotEmpty
              ? FirebaseFirestore.instance.collection('agencies').doc(targetAgencyId).snapshots()
              : const Stream.empty(),
          builder: (context, snapshot) {
            Agency? liveAgency;
            if (snapshot.hasData && snapshot.data!.exists && snapshot.data!.data() != null) {
              liveAgency = Agency.fromMap(snapshot.data!.data() as Map<String, dynamic>);
            } else {
              liveAgency = _hostAgency;
            }

            final String agencyName = liveAgency?.agencyName.isNotEmpty == true 
                ? liveAgency!.agencyName 
                : (_liveCurrentUser.agencyName ?? 'Agency');

            final String agencyLogo = liveAgency?.logoUrl.isNotEmpty == true
                ? liveAgency!.logoUrl
                : (liveAgency?.owner.profileImageUrl ?? '');

            final String agencyIdNumber = (liveAgency?.agencyIdNumber.isNotEmpty == true)
                ? liveAgency!.agencyIdNumber
                : (liveAgency?.agencyId ?? 'N/A');

            final String ownerName = liveAgency?.owner.name.isNotEmpty == true 
                ? liveAgency!.owner.name 
                : '';

            final String joinedDateStr = _hostRecord != null
                ? '${_hostRecord!.joinedDate.day}/${_hostRecord!.joinedDate.month}/${_hostRecord!.joinedDate.year}'
                : 'Active';

            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'My Agency',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.black54),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            if (agencyLogo.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                                  ),
                                ),
                                child: CachedCircleAvatar(
                                  imageUrl: agencyLogo,
                                  radius: 26,
                                ),
                              )
                            else
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(Icons.business_rounded, color: Colors.white, size: 30),
                              ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    agencyName,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Agency ID: $agencyIdNumber',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(height: 1),
                        const SizedBox(height: 14),
                        _buildAgencyDetailRow('Agency ID', agencyIdNumber),
                        if (ownerName.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _buildAgencyDetailRow('Agency Owner', ownerName),
                        ],
                        const SizedBox(height: 10),
                        _buildAgencyDetailRow('Joined Date', joinedDateStr),
                        const SizedBox(height: 10),
                        _buildAgencyDetailRow('Contract Status', 'Active', isBadge: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAgencyDetailRow(String label, String value, {bool isBadge = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        if (isBadge)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Text(
              value,
              style: TextStyle(color: Colors.green.shade800, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          )
        else
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87)),
      ],
    );
  }

  void _showAgencyChangeModal() {
    final searchAgencyIdController = TextEditingController();
    final reasonController = TextEditingController();

    Agency? targetAgency;
    bool isSearchingAgency = false;
    String? searchError;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('agency_transfer_requests')
                  .where('userId', isEqualTo: _liveCurrentUser.userId)
                  .where('status', isEqualTo: 'pending')
                  .snapshots(),
              builder: (context, pendingSnap) {
                final pendingDocs = pendingSnap.data?.docs ?? [];
                final bool hasPending = pendingDocs.isNotEmpty;
                final Map<String, dynamic>? pendingData = hasPending
                    ? (pendingDocs.first.data() as Map<String, dynamic>)
                    : null;
                final String pendingDocId = hasPending ? pendingDocs.first.id : '';

                return Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Agency Change',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, color: Colors.black54),
                                onPressed: () => Navigator.pop(ctx),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          if (hasPending && pendingData != null) ...[
                            // View Active Pending Request
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.amber.shade300),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.hourglass_top_rounded, color: Colors.amber.shade800, size: 24),
                                      const SizedBox(width: 8),
                                      const Expanded(
                                        child: Text(
                                          'Transfer Request Pending',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.shade200,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'Waiting Admin Approval',
                                          style: TextStyle(
                                            color: Colors.amber.shade900,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  _buildAgencyDetailRow('Current Agency', pendingData['currentAgencyName'] ?? 'Agency'),
                                  const SizedBox(height: 8),
                                  _buildAgencyDetailRow(
                                    'Target Agency',
                                    '${pendingData['targetAgencyName'] ?? 'New Agency'} (${pendingData['targetAgencyIdNumber'] ?? ''})',
                                  ),
                                  if (pendingData['reason'] != null && pendingData['reason'].toString().isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    _buildAgencyDetailRow('Reason', pendingData['reason'].toString()),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (c) => AlertDialog(
                                      title: const Text('Cancel Transfer Request?'),
                                      content: const Text('Are you sure you want to cancel your pending agency transfer request?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(c, false),
                                          child: const Text('No'),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                          onPressed: () => Navigator.pop(c, true),
                                          child: const Text('Cancel Request', style: TextStyle(color: Colors.white)),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirmed == true) {
                                    await _agencyService.cancelTransferRequest(pendingDocId);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Transfer request cancelled.'),
                                          backgroundColor: Colors.grey,
                                        ),
                                      );
                                    }
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.redAccent,
                                  side: const BorderSide(color: Colors.redAccent),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Cancel Transfer Request', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ] else ...[
                            // New Transfer Request Form
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.info_outline_rounded, color: Colors.blue.shade700, size: 22),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Enter the Agency ID Number of the new agency you want to join. Once submitted, it will be reviewed and approved by the admin.',
                                      style: TextStyle(
                                        color: Colors.blue.shade900,
                                        fontSize: 12,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Current Agency: ${_hostAgency?.agencyName ?? _liveCurrentUser.agencyName ?? 'Agency'}',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                            ),
                            const SizedBox(height: 16),

                            // Target Agency Search Input
                            const Text(
                              'Target Agency ID / Search ID',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: searchAgencyIdController,
                                    keyboardType: TextInputType.text,
                                    decoration: InputDecoration(
                                      hintText: 'e.g. 112233 or Agency ID',
                                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                                      filled: true,
                                      fillColor: const Color(0xFFF8FAFC),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: isSearchingAgency
                                      ? null
                                      : () async {
                                          final query = searchAgencyIdController.text.trim();
                                          if (query.isEmpty) return;

                                          setModalState(() {
                                            isSearchingAgency = true;
                                            searchError = null;
                                            targetAgency = null;
                                          });

                                          final found = await _agencyService.findAgencyByIdOrNumber(query);

                                          setModalState(() {
                                            isSearchingAgency = false;
                                            if (found == null) {
                                              searchError = 'No agency found with ID "$query"';
                                            } else if (found.agencyId == _hostAgency?.agencyId) {
                                              searchError = 'You are already in this agency.';
                                            } else {
                                              targetAgency = found;
                                            }
                                          });
                                        },
                                  child: isSearchingAgency
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : const Text('Find Agency', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),

                            if (searchError != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                searchError!,
                                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                              ),
                            ],

                            // Target Agency Preview Card
                            if (targetAgency != null) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.green.shade300),
                                ),
                                child: Row(
                                  children: [
                                    if (targetAgency!.logoUrl.isNotEmpty)
                                      CachedCircleAvatar(imageUrl: targetAgency!.logoUrl, radius: 22)
                                    else
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: Colors.purple.shade600,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(Icons.business_rounded, color: Colors.white, size: 24),
                                      ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            targetAgency!.agencyName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Agency ID: ${targetAgency!.agencyIdNumber.isNotEmpty ? targetAgency!.agencyIdNumber : targetAgency!.agencyId}',
                                            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                                          ),
                                          if (targetAgency!.owner.name.isNotEmpty)
                                            Text(
                                              'Owner: ${targetAgency!.owner.name}',
                                              style: TextStyle(color: Colors.grey.shade700, fontSize: 11),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.check_circle_rounded, color: Colors.green, size: 24),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 16),
                            const Text(
                              'Reason for Transfer (Optional)',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: reasonController,
                              maxLines: 2,
                              decoration: InputDecoration(
                                hintText: 'Explain why you wish to transfer...',
                                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.all(12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: (targetAgency == null || isSubmitting)
                                    ? null
                                    : () async {
                                        setModalState(() => isSubmitting = true);
                                        try {
                                          await _agencyService.submitTransferRequest(
                                            userId: _liveCurrentUser.userId,
                                            userName: _liveCurrentUser.fullname,
                                            userSearchId: _liveCurrentUser.searchId,
                                            userPhotoUrl: _liveCurrentUser.photoUrl,
                                            currentAgencyId: _hostAgency?.agencyId ?? _liveCurrentUser.agencyId ?? '',
                                            currentAgencyName: _hostAgency?.agencyName ?? _liveCurrentUser.agencyName ?? 'Current Agency',
                                            currentAgencyIdNumber: _hostAgency?.agencyIdNumber ?? '',
                                            targetAgency: targetAgency!,
                                            reason: reasonController.text.trim(),
                                          );

                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('✅ Agency transfer request submitted to admin!'),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('❌ Error: $e'),
                                                backgroundColor: Colors.redAccent,
                                              ),
                                            );
                                          }
                                        } finally {
                                          setModalState(() => isSubmitting = false);
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: isSubmitting
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Text(
                                        'Submit Transfer Request',
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showMySupportersModal(User hostUser) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: MediaQuery.of(context).size.height * 0.65,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'My Supporters',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.black54),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('host_earnings')
                      .where('hostId', isEqualTo: _hostRecord?.hostId ?? hostUser.userId)
                      .orderBy('earningDate', descending: true)
                      .limit(30)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.favorite_border_rounded, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 10),
                            Text(
                              'No supporter data recorded yet',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            ),
                          ],
                        ),
                      );
                    }

                    final docs = snapshot.data!.docs;
                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final diamonds = (data['diamondsEarned'] ?? 0).toString();
                        final date = (data['earningDate'] as Timestamp?)?.toDate() ?? DateTime.now();

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.purple.shade50,
                                radius: 20,
                                child: Text(
                                  '#${index + 1}',
                                  style: TextStyle(
                                    color: Colors.purple.shade700,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data['senderName'] ?? 'Fan Supporter',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    Text(
                                      '${date.day}/${date.month}/${date.year}',
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  const DynamicDiamondIcon(width: 14, height: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    diamonds,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
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
      },
    );
  }

  void _showNewUsersModal(User hostUser) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'New User & Growth',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.black54),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.stars_rounded, color: Colors.white, size: 36),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'New Streamer Missions',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Host rooms and interact with new listeners to unlock bonus perks!',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.shade50,
                  child: const Icon(Icons.person_add_alt_1_rounded, color: Colors.blue),
                ),
                title: const Text('Live Room Engagement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Gain 10 new followers during audio sessions', style: TextStyle(fontSize: 12)),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('Active', style: TextStyle(color: Colors.blue.shade800, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
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

// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../models/video_pk_models.dart';
import '../services/video_pk_service.dart';

/// Bottom sheet opened by host to initiate a Live Room PK Battle
class VideoPkSheet extends StatefulWidget {
  final String currentRoomId;
  final String currentHostId;
  final String currentHostName;
  final String? currentHostPhotoUrl;

  const VideoPkSheet({
    super.key,
    required this.currentRoomId,
    required this.currentHostId,
    required this.currentHostName,
    this.currentHostPhotoUrl,
  });

  @override
  State<VideoPkSheet> createState() => _VideoPkSheetState();
}

class _VideoPkSheetState extends State<VideoPkSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final VideoPkService _pkService = VideoPkService();

  int _selectedDuration = 300; // 5 mins
  int _selectedPunishment = 60; // 60s
  bool _isSearchingRandom = false;
  String? _searchingStatus;
  Timer? _searchTimeoutTimer;

  // Inviting state for individual hosts
  final Set<String> _invitingHostIds = {};

  final List<int> _durations = [180, 300, 420, 600];
  final List<int> _punishments = [30, 60, 90, 120];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _searchTimeoutTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  String _formatDuration(int sec) {
    final m = sec ~/ 60;
    return '$m Min${m > 1 ? 's' : ''}';
  }

  Future<void> _handleRandomMatch() async {
    setState(() {
      _isSearchingRandom = true;
      _searchingStatus = 'Searching for an active live host...';
    });

    _searchTimeoutTimer?.cancel();
    _searchTimeoutTimer = Timer(const Duration(seconds: 15), () {
      if (mounted && _isSearchingRandom) {
        setState(() {
          _isSearchingRandom = false;
          _searchingStatus = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No opponent matched. Try inviting from the Live Hosts list!'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    });

    try {
      final target = await _pkService.findRandomVideoHost(widget.currentRoomId);

      if (!mounted) return;

      if (target == null) {
        _searchTimeoutTimer?.cancel();
        setState(() {
          _isSearchingRandom = false;
          _searchingStatus = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No active live video rooms found for quick match.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      setState(() {
        _searchingStatus = 'Matched with ${target.hostName}! Sending invitation...';
      });

      await _pkService.sendInvitation(
        fromRoomId: widget.currentRoomId,
        fromHostId: widget.currentHostId,
        fromHostName: widget.currentHostName,
        fromHostPhoto: widget.currentHostPhotoUrl,
        toRoomId: target.roomId,
        toHostId: target.hostId,
        toHostName: target.hostName,
        toHostPhoto: target.hostPhotoUrl,
        durationSeconds: _selectedDuration,
      );

      if (!mounted) return;
      _searchTimeoutTimer?.cancel();
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PK Challenge sent to ${target.hostName}!'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } catch (e) {
      if (mounted) {
        _searchTimeoutTimer?.cancel();
        setState(() {
          _isSearchingRandom = false;
          _searchingStatus = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send challenge: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _sendDirectInvite(OnlineVideoHost host) async {
    setState(() {
      _invitingHostIds.add(host.hostId);
    });

    try {
      await _pkService.sendInvitation(
        fromRoomId: widget.currentRoomId,
        fromHostId: widget.currentHostId,
        fromHostName: widget.currentHostName,
        fromHostPhoto: widget.currentHostPhotoUrl,
        toRoomId: host.roomId,
        toHostId: host.hostId,
        toHostName: host.hostName,
        toHostPhoto: host.hostPhotoUrl,
        durationSeconds: _selectedDuration,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PK Invitation sent to ${host.hostName}!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to invite ${host.hostName}: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _invitingHostIds.remove(host.hostId);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      margin: EdgeInsets.only(bottom: bottomPadding),
      decoration: const BoxDecoration(
        color: Color(0xFF161129),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: Color(0xFFD946EF), width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x33D946EF),
            blurRadius: 20,
            spreadRadius: 2,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD946EF), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.sports_kabaddi_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Live Video PK Battle',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'Challenge other live streamers to a split-screen battle',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white54, size: 22),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Match Config Selectors
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Duration Pills
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined,
                          color: Color(0xFF00E5FF), size: 16),
                      const SizedBox(width: 6),
                      const Text(
                        'PK Duration:',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      ..._durations.map((sec) {
                        final isSel = _selectedDuration == sec;
                        return Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: InkWell(
                            onTap: () => setState(() => _selectedDuration = sec),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isSel
                                    ? const Color(0xFFD946EF)
                                    : Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSel
                                      ? Colors.white
                                      : Colors.transparent,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                _formatDuration(sec),
                                style: TextStyle(
                                  color: isSel ? Colors.white : Colors.white70,
                                  fontSize: 11,
                                  fontWeight: isSel
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Punishment Pills
                  Row(
                    children: [
                      const Icon(Icons.sentiment_very_dissatisfied_rounded,
                          color: Color(0xFFFF5252), size: 16),
                      const SizedBox(width: 6),
                      const Text(
                        'Punish Duration:',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      ..._punishments.map((sec) {
                        final isSel = _selectedPunishment == sec;
                        return Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: InkWell(
                            onTap: () =>
                                setState(() => _selectedPunishment = sec),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isSel
                                    ? const Color(0xFFFF5252)
                                    : Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSel
                                      ? Colors.white
                                      : Colors.transparent,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                '${sec}s',
                                style: TextStyle(
                                  color: isSel ? Colors.white : Colors.white70,
                                  fontSize: 11,
                                  fontWeight: isSel
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Tabs
          TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFFD946EF),
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            tabs: const [
              Tab(
                icon: Icon(Icons.flash_on_rounded, size: 20),
                text: 'Quick Match',
              ),
              Tab(
                icon: Icon(Icons.people_alt_rounded, size: 20),
                text: 'Live Hosts',
              ),
            ],
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildQuickMatchTab(),
                _buildOnlineHostsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickMatchTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_isSearchingRandom) ...[
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFD946EF).withOpacity(0.4),
                    Colors.transparent,
                  ],
                ),
              ),
              child: const Center(
                child: SizedBox(
                  width: 50,
                  height: 50,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFFD946EF)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _searchingStatus ?? 'Finding opponent...',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Scanning online live streamers with matching criteria',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () {
                _searchTimeoutTimer?.cancel();
                setState(() {
                  _isSearchingRandom = false;
                  _searchingStatus = null;
                });
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Colors.white24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text('Cancel Search'),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF00E5FF).withOpacity(0.2),
                    const Color(0xFFD946EF).withOpacity(0.2),
                  ],
                ),
                border: Border.all(
                  color: const Color(0xFFD946EF).withOpacity(0.4),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.bolt_rounded,
                size: 54,
                color: Color(0xFF00E5FF),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Instant Matchmaking',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'We will match you with a random live streamer currently streaming in video mode.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _handleRandomMatch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00E5FF), Color(0xFFD946EF)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x66D946EF),
                        blurRadius: 14,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Container(
                    alignment: Alignment.center,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.play_arrow_rounded, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Start Quick Match',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOnlineHostsTab() {
    return FutureBuilder<List<OnlineVideoHost>>(
      future: _pkService.getOnlineVideoHosts(widget.currentRoomId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFFD946EF),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
                const SizedBox(height: 8),
                Text(
                  'Error loading hosts: ${snapshot.error}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final hosts = snapshot.data ?? [];
        if (hosts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.videocam_off_rounded,
                  color: Colors.white.withOpacity(0.25),
                  size: 52,
                ),
                const SizedBox(height: 12),
                const Text(
                  'No Other Live Video Hosts Online',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'When other creators go live with video,\nthey will appear here for challenge.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () => setState(() {}),
                  icon: const Icon(Icons.refresh, color: Color(0xFF00E5FF)),
                  label: const Text(
                    'Refresh List',
                    style: TextStyle(color: Color(0xFF00E5FF)),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          itemCount: hosts.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final host = hosts[index];
            final isInviting = _invitingHostIds.contains(host.hostId);

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
              child: Row(
                children: [
                  // Host Avatar
                  Stack(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFD946EF),
                            width: 1.5,
                          ),
                        ),
                        child: ClipOval(
                          child: host.hostPhotoUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: host.hostPhotoUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(
                                    color: Colors.white10,
                                  ),
                                  errorWidget: (_, __, ___) => const Icon(
                                    Icons.person,
                                    color: Colors.white54,
                                  ),
                                )
                              : const Icon(Icons.person, color: Colors.white54),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF161129),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  // Host Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          host.hostName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD946EF).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.videocam,
                                      size: 11, color: Color(0xFFD946EF)),
                                  SizedBox(width: 4),
                                  Text(
                                    'Live',
                                    style: TextStyle(
                                      color: Color(0xFFD946EF),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.people,
                                size: 12, color: Colors.white.withOpacity(0.5)),
                            const SizedBox(width: 3),
                            Text(
                              '${host.viewerCount}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Invite / Challenge Button
                  SizedBox(
                    height: 34,
                    child: ElevatedButton(
                      onPressed: isInviting ? null : () => _sendDirectInvite(host),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD946EF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(17),
                        ),
                      ),
                      child: isInviting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Challenge',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Dialog shown to the challenger recipient with a 15s countdown
class VideoPkInvitationDialog extends StatefulWidget {
  final VideoPkInvitationModel invitation;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const VideoPkInvitationDialog({
    super.key,
    required this.invitation,
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<VideoPkInvitationDialog> createState() =>
      _VideoPkInvitationDialogState();
}

class _VideoPkInvitationDialogState extends State<VideoPkInvitationDialog>
    with SingleTickerProviderStateMixin {
  late int _remainingSeconds;
  Timer? _timer;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.invitation.remainingSeconds.clamp(1, 15);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _startCountdown();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_remainingSeconds <= 1) {
        t.cancel();
        widget.onReject();
      } else {
        setState(() {
          _remainingSeconds--;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final invite = widget.invitation;
    final durationMinutes = invite.durationSeconds ~/ 60;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1431),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFD946EF),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD946EF).withOpacity(0.35),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header tag
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00E5FF), Color(0xFFD946EF)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bolt, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'PK BATTLE CHALLENGE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Challenger Avatar with Pulsing Halo
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  width: 84,
                  height: 84,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD946EF).withOpacity(
                            0.4 + (_pulseController.value * 0.4)),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD946EF), Color(0xFF00E5FF)],
                    ),
                  ),
                  child: ClipOval(
                    child: (invite.fromHostPhoto != null &&
                            invite.fromHostPhoto!.isNotEmpty)
                        ? CachedNetworkImage(
                            imageUrl: invite.fromHostPhoto!,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: Colors.white10,
                            ),
                            errorWidget: (_, __, ___) => const Icon(
                              Icons.person,
                              size: 40,
                              color: Colors.white54,
                            ),
                          )
                        : const Icon(
                            Icons.person,
                            size: 40,
                            color: Colors.white54,
                          ),
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            // Challenger Name
            Text(
              invite.fromHostName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 6),

            Text(
              'Has challenged you to a $durationMinutes-minute Live Video PK Battle!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 14),

            // Timer Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer_outlined,
                      color: Color(0xFFFF5252), size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'Auto rejects in ${_remainingSeconds}s',
                    style: const TextStyle(
                      color: Color(0xFFFF5252),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            // Action Buttons (Reject & Accept)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Decline',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: ElevatedButton(
                    onPressed: widget.onAccept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFD946EF), Color(0xFF00E5FF)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x66D946EF),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Container(
                        height: 44,
                        alignment: Alignment.center,
                        child: const Text(
                          'Accept PK',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

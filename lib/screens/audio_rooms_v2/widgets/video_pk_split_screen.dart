// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svga/flutter_svga.dart';
import '../../../components/cached_circle_avatar.dart';
import '../../../models/video_pk_models.dart';
import '../services/video_pk_service.dart';

/// Side-by-Side Dual Video PK Battle Screen matching Khan_Live
class VideoPkSplitScreen extends StatefulWidget {
  final VideoPkBattleModel pkBattle;
  final bool isCurrentRoomHost1;
  final Widget leftVideoView;
  final Widget rightVideoView;
  final bool isHost;
  final bool isAnimationActive;
  final PkEffectsConfig? effectsConfig;
  final String? progressSvgaUrl;
  final VoidCallback? onEndPk;
  final VoidCallback? onRematch;
  final ValueChanged<bool>? onToggleMuteOpponent;
  final VoidCallback? onBattleTimeExpired;
  final VoidCallback? onPunishmentTimeExpired;

  const VideoPkSplitScreen({
    super.key,
    required this.pkBattle,
    this.isCurrentRoomHost1 = true,
    required this.leftVideoView,
    required this.rightVideoView,
    required this.isHost,
    this.isAnimationActive = false,
    this.effectsConfig,
    this.progressSvgaUrl,
    this.onEndPk,
    this.onRematch,
    this.onToggleMuteOpponent,
    this.onBattleTimeExpired,
    this.onPunishmentTimeExpired,
  });

  @override
  State<VideoPkSplitScreen> createState() => _VideoPkSplitScreenState();
}

class _VideoPkSplitScreenState extends State<VideoPkSplitScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  Timer? _countdownTimer;
  int _secondsLeft = 0;
  bool _isOpponentAudioMuted = false;

  bool _hasNotifiedBattleExpired = false;
  bool _hasNotifiedPunishmentExpired = false;

  // Real-Time PK Progress Bar SVGA Animation
  SVGAAnimationController? _progressSvgaController;
  String? _loadedProgressSvgaUrl;
  bool _isLoadingProgressSvga = false;
  StreamSubscription? _pkEffectsSub;

  String? get _effectiveProgressSvgaUrl {
    return widget.progressSvgaUrl ??
        widget.effectsConfig?.progressSvgaUrl ??
        widget.effectsConfig?.drawSvgaUrl;
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _setupProgressEffects();
    _updateSecondsLeft();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _updateSecondsLeft();
        });
        if (_secondsLeft <= 0 && !widget.isAnimationActive) {
          if (widget.pkBattle.isActive && !_hasNotifiedBattleExpired) {
            _hasNotifiedBattleExpired = true;
            widget.onBattleTimeExpired?.call();
          } else if (widget.pkBattle.isPunishment &&
              !_hasNotifiedPunishmentExpired) {
            _hasNotifiedPunishmentExpired = true;
            widget.onPunishmentTimeExpired?.call();
          }
        }
      }
    });
  }

  void _setupProgressEffects() {
    final initialUrl = _effectiveProgressSvgaUrl;
    if (initialUrl != null && initialUrl.isNotEmpty) {
      _loadProgressSvga(initialUrl);
    }

    _pkEffectsSub?.cancel();
    _pkEffectsSub = VideoPkService().streamEffectsConfig().listen((config) {
      final url = widget.progressSvgaUrl ??
          config.progressSvgaUrl ??
          config.drawSvgaUrl;
      if (url != null && url.isNotEmpty && url != _loadedProgressSvgaUrl) {
        _loadProgressSvga(url);
      } else if ((url == null || url.isEmpty) &&
          _loadedProgressSvgaUrl != null) {
        _disposeProgressSvga();
        if (mounted) {
          setState(() {
            _loadedProgressSvgaUrl = null;
          });
        }
      }
    });
  }

  Future<void> _loadProgressSvga(String url) async {
    if (_isLoadingProgressSvga && _loadedProgressSvgaUrl == url) return;
    _loadedProgressSvgaUrl = url;
    _isLoadingProgressSvga = true;

    try {
      final movieEntity = await SVGAParser().decodeFromURL(url);
      if (!mounted || _loadedProgressSvgaUrl != url) return;

      _disposeProgressSvga();
      final controller = SVGAAnimationController(vsync: this);
      controller.videoItem = movieEntity;
      controller.repeat();

      if (mounted) {
        setState(() {
          _progressSvgaController = controller;
          _isLoadingProgressSvga = false;
        });
      }
    } catch (e) {
      debugPrint('⚠️ [VideoPkSplitScreen] Error loading PK progress SVGA: $e');
      if (mounted) {
        setState(() {
          _isLoadingProgressSvga = false;
        });
      }
    }
  }

  void _disposeProgressSvga() {
    try {
      _progressSvgaController?.stop();
      _progressSvgaController?.dispose();
    } catch (_) {}
    _progressSvgaController = null;
  }

  void _updateSecondsLeft() {
    if (widget.isAnimationActive) {
      _secondsLeft = widget.pkBattle.durationSeconds;
    } else {
      _secondsLeft = widget.pkBattle.remainingSeconds;
    }
  }

  @override
  void didUpdateWidget(covariant VideoPkSplitScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pkBattle.status != widget.pkBattle.status) {
      if (widget.pkBattle.isPunishment) {
        _hasNotifiedBattleExpired = false;
      }
    }
    if (oldWidget.isAnimationActive != widget.isAnimationActive ||
        oldWidget.pkBattle.endsAt != widget.pkBattle.endsAt) {
      _updateSecondsLeft();
    }

    final oldUrl = oldWidget.progressSvgaUrl ??
        oldWidget.effectsConfig?.progressSvgaUrl ??
        oldWidget.effectsConfig?.drawSvgaUrl;
    final newUrl = _effectiveProgressSvgaUrl;
    if (oldUrl != newUrl &&
        newUrl != null &&
        newUrl.isNotEmpty &&
        newUrl != _loadedProgressSvgaUrl) {
      _loadProgressSvga(newUrl);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _countdownTimer?.cancel();
    _pkEffectsSub?.cancel();
    _disposeProgressSvga();
    super.dispose();
  }

  String _formatTimer(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final battle = widget.pkBattle;
    final winnerId = battle.winnerId;
    final isConcluded = battle.isPunishment || battle.isEnded;
    final isDraw = winnerId == 'draw';

    // The host of the current broadcast room is ALWAYS on the LEFT side (Cyan / Home team)
    final bool isLeftHost1 = widget.isCurrentRoomHost1;

    final leftScore = isLeftHost1 ? battle.host1Score : battle.host2Score;
    final rightScore = isLeftHost1 ? battle.host2Score : battle.host1Score;

    final leftName = isLeftHost1 ? battle.host1Name : battle.host2Name;
    final rightName = isLeftHost1 ? battle.host2Name : battle.host1Name;

    final leftStreak = isLeftHost1 ? battle.host1Streak : battle.host2Streak;
    final rightStreak = isLeftHost1 ? battle.host2Streak : battle.host1Streak;

    final leftContributors =
        isLeftHost1 ? battle.host1Contributors : battle.host2Contributors;
    final rightContributors =
        isLeftHost1 ? battle.host2Contributors : battle.host1Contributors;

    final isLeftWinner = isLeftHost1
        ? (winnerId == battle.host1Id)
        : (winnerId == battle.host2Id);
    final isRightWinner = isLeftHost1
        ? (winnerId == battle.host2Id)
        : (winnerId == battle.host1Id);

    final total = leftScore + rightScore;
    double ratio = 0.5;
    if (total > 0) {
      ratio = (leftScore / total).clamp(0.12, 0.88);
    }

    final c1List = leftContributors.values.toList()
      ..sort((a, b) => b.points.compareTo(a.points));
    final c2List = rightContributors.values.toList()
      ..sort((a, b) => b.points.compareTo(a.points));

    final videoHeight = MediaQuery.of(context).size.width * 0.72;

    return Container(
      width: double.infinity,
      color: const Color(0xFF0D0E15),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. TOP PK SCORE BAR + VIDEOS + HANGING TAB (SEAMLESS EDGE-TO-EDGE)
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              // Column: Edge-to-edge Top Score Bar + Side-by-side Videos
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Progress Bar Track
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final totalWidth = constraints.maxWidth;
                      final leftWidth = totalWidth * ratio;
                      final rightWidth = totalWidth - leftWidth;

                      return SizedBox(
                        height: 26,
                        child: ClipRect(
                          child: Stack(
                            children: [
                              // 1. Base Colored Progress Tracks (Cyan & Orange)
                              Row(
                                children: [
                                  // Cyan Side (Host 1 - Left)
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeOutCubic,
                                    width: leftWidth,
                                    height: 26,
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                        colors: [
                                          Color(0xFF0091EA),
                                          Color(0xFF00B0FF),
                                          Color(0xFF00D2FF),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // Orange/Red Side (Host 2 - Right)
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeOutCubic,
                                    width: rightWidth,
                                    height: 26,
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                        colors: [
                                          Color(0xFFFF9100),
                                          Color(0xFFFF5722),
                                          Color(0xFFFF1744),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              // 2. Real-time SVGA / Collision Seam
                              _buildCollisionSeam(leftWidth, totalWidth),

                              // 3. Foreground Score Labels
                              Row(
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeOutCubic,
                                    width: leftWidth,
                                    height: 26,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10),
                                    alignment: Alignment.centerLeft,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.diamond_rounded,
                                          color: Colors.amberAccent,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$leftScore',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w900,
                                            shadows: [
                                              Shadow(
                                                color: Colors.black54,
                                                blurRadius: 4,
                                                offset: Offset(0, 1),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeOutCubic,
                                    width: rightWidth,
                                    height: 26,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10),
                                    alignment: Alignment.centerRight,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '$rightScore',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w900,
                                            shadows: [
                                              Shadow(
                                                color: Colors.black54,
                                                blurRadius: 4,
                                                offset: Offset(0, 1),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(
                                          Icons.diamond_rounded,
                                          color: Colors.amberAccent,
                                          size: 14,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  // Side-by-side Dual Live Video Views (0px gap between them)
                  SizedBox(
                    height: videoHeight,
                    child: Row(
                      children: [
                        // Left Stream (Home Team)
                        Expanded(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              widget.leftVideoView,
                              _buildVideoInfoOverlay(
                                name: leftName,
                                streak: leftStreak,
                                isWinner: isConcluded && isLeftWinner,
                                isLoser: isConcluded && !isLeftWinner && !isDraw,
                                isDraw: isConcluded && isDraw,
                                isPunishment: battle.isPunishment,
                                isLeft: true,
                              ),
                            ],
                          ),
                        ),

                        // Vertical Seam divider
                        Container(
                          width: 1.5,
                          height: videoHeight,
                          color: Colors.black54,
                        ),

                        // Right Stream (Away Team)
                        Expanded(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              widget.rightVideoView,
                              _buildVideoInfoOverlay(
                                name: rightName,
                                streak: rightStreak,
                                isWinner: isConcluded && isRightWinner,
                                isLoser:
                                    isConcluded && !isRightWinner && !isDraw,
                                isDraw: isConcluded && isDraw,
                                isPunishment: battle.isPunishment,
                                isLeft: false,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Hanging Central Timer Pill ("PK 04:32" or "PUNISHMENT 00:59")
              Positioned(
                top: 26,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: battle.isPunishment
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF131722).withOpacity(0.92),
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(12),
                    ),
                    border: Border.all(
                      color: battle.isPunishment
                          ? Colors.amberAccent
                          : Colors.white24,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.6),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        battle.isPunishment
                            ? Icons.warning_amber_rounded
                            : Icons.timer_outlined,
                        color: battle.isPunishment
                            ? Colors.white
                            : const Color(0xFFD946EF),
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        battle.isPunishment
                            ? 'PUNISHMENT ${_formatTimer(_secondsLeft)}'
                            : 'PK ${_formatTimer(_secondsLeft)}',
                        style: TextStyle(
                          color: battle.isPunishment
                              ? Colors.white
                              : Colors.amberAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // 2. BOTTOM CONTRIBUTOR AVATARS & HOST ACTION BAR
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF131722).withOpacity(0.85),
              border: Border(
                bottom: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
            ),
            child: Row(
              children: [
                // Left Team MVP gifters
                Expanded(
                  child: Row(
                    children: [
                      for (int i = 0; i < c1List.length && i < 3; i++) ...[
                        _buildContributorAvatar(c1List[i], i + 1),
                        const SizedBox(width: 4),
                      ],
                      if (c1List.isEmpty)
                        Text(
                          'No points yet',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.35),
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),
                ),

                // Host Quick Controls
                if (widget.isHost) ...[
                  IconButton(
                    icon: Icon(
                      _isOpponentAudioMuted
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                      color: _isOpponentAudioMuted
                          ? const Color(0xFFEF4444)
                          : Colors.white70,
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      setState(() {
                        _isOpponentAudioMuted = !_isOpponentAudioMuted;
                      });
                      widget.onToggleMuteOpponent?.call(_isOpponentAudioMuted);
                    },
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => _confirmEndPk(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: const Color(0xFFEF4444).withOpacity(0.5)),
                      ),
                      child: const Text(
                        'End PK',
                        style: TextStyle(
                          color: Color(0xFFEF4444),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],

                // Right Team MVP gifters
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (c2List.isEmpty)
                        Text(
                          'No points yet',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.35),
                            fontSize: 10,
                          ),
                        ),
                      for (int i = 0; i < c2List.length && i < 3; i++) ...[
                        _buildContributorAvatar(c2List[i], i + 1),
                        const SizedBox(width: 4),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollisionSeam(double leftWidth, double totalWidth) {
    if (_progressSvgaController != null) {
      return Positioned(
        left: (leftWidth - 30).clamp(0.0, totalWidth - 60),
        top: -15,
        width: 60,
        height: 56,
        child: SVGAImage(_progressSvgaController!),
      );
    }

    return Positioned(
      left: (leftWidth - 14).clamp(0.0, totalWidth - 28),
      top: 0,
      bottom: 0,
      width: 28,
      child: Center(
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: const Color(0xFF131722),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.amberAccent, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.amberAccent.withOpacity(0.5),
                blurRadius: 6,
              ),
            ],
          ),
          child: const Center(
            child: Text(
              'VS',
              style: TextStyle(
                color: Colors.amberAccent,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoInfoOverlay({
    required String name,
    required int streak,
    required bool isWinner,
    required bool isLoser,
    required bool isDraw,
    required bool isPunishment,
    required bool isLeft,
  }) {
    return Positioned.fill(
      child: Stack(
        children: [
          // Bottom Host Name & Win Streak pill
          Positioned(
            left: isLeft ? 8 : null,
            right: !isLeft ? 8 : null,
            bottom: 8,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (streak > 0) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF9800), Color(0xFFFF5722)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.local_fire_department,
                            color: Colors.white, size: 10),
                        Text(
                          '$streak',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Big Result Banner Overlay on conclusion
          if (isWinner)
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.6),
                      blurRadius: 14,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.emoji_events, color: Colors.white, size: 20),
                    SizedBox(width: 4),
                    Text(
                      'WINNER',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (isLoser)
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFEF4444), width: 1.5),
                ),
                child: Text(
                  isPunishment ? 'PUNISHMENT' : 'DEFEAT',
                  style: const TextStyle(
                    color: Color(0xFFEF4444),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),

          if (isDraw)
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amberAccent, width: 1.5),
                ),
                child: const Text(
                  'DRAW',
                  style: TextStyle(
                    color: Colors.amberAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContributorAvatar(VideoPkContributor contributor, int rank) {
    Color rankColor = const Color(0xFFFFD700);
    if (rank == 2) rankColor = const Color(0xFFC0C0C0);
    if (rank == 3) rankColor = const Color(0xFFCD7F32);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        CachedCircleAvatar(
          imageUrl: contributor.userPhoto ?? '',
          radius: 12,
          borderColor: rankColor,
          borderWidth: 1.5,
        ),
        Positioned(
          bottom: -2,
          right: -2,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: rankColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$rank',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 7,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _confirmEndPk(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131722),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('End PK Battle?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
            'Are you sure you want to end this PK battle early?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              widget.onEndPk?.call();
            },
            child: const Text('End PK',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

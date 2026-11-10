// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svga/flutter_svga.dart';
import '../../../models/video_pk_models.dart';
import '../services/video_pk_service.dart';

enum VideoPkAnimationPhase {
  none,
  countdown,
  opening,
  winner,
}

class VideoPkAnimationOverlay extends StatefulWidget {
  final VideoPkAnimationPhase phase;
  final String? winnerName;
  final String? winnerPhotoUrl;
  final PkEffectsConfig? config;
  final VoidCallback onCountdownComplete;
  final VoidCallback onOpeningComplete;
  final VoidCallback onWinnerComplete;

  const VideoPkAnimationOverlay({
    super.key,
    required this.phase,
    this.winnerName,
    this.winnerPhotoUrl,
    this.config,
    required this.onCountdownComplete,
    required this.onOpeningComplete,
    required this.onWinnerComplete,
  });

  @override
  State<VideoPkAnimationOverlay> createState() =>
      _VideoPkAnimationOverlayState();
}

class _VideoPkAnimationOverlayState extends State<VideoPkAnimationOverlay>
    with TickerProviderStateMixin {
  SVGAAnimationController? _svgaController;
  late PkEffectsConfig _effectsConfig;
  bool _isPlayingSvga = false;
  Timer? _phaseTimer;
  StreamSubscription? _configSub;

  // Fallback Countdown state
  int _countdownNumber = 3;
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _effectsConfig = widget.config ?? const PkEffectsConfig();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _scaleAnimation = Tween<double>(begin: 0.4, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.elasticOut),
    );

    _initSvgaController();

    if (widget.config == null) {
      _listenToRemoteConfig();
    } else {
      _handlePhaseChange();
    }
  }

  void _listenToRemoteConfig() {
    _configSub = VideoPkService().streamEffectsConfig().listen((config) {
      if (mounted) {
        setState(() {
          _effectsConfig = config;
        });
        _handlePhaseChange();
      }
    });
  }

  void _initSvgaController() {
    _svgaController?.dispose();
    _svgaController = SVGAAnimationController(vsync: this);
  }

  @override
  void didUpdateWidget(covariant VideoPkAnimationOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.phase != widget.phase) {
      _handlePhaseChange();
    }
  }

  void _handlePhaseChange() {
    _phaseTimer?.cancel();
    _svgaController?.stop();

    if (widget.phase == VideoPkAnimationPhase.none) {
      setState(() => _isPlayingSvga = false);
      return;
    }

    if (widget.phase == VideoPkAnimationPhase.countdown) {
      final url = _effectsConfig.countdownSvgaUrl;
      if (url != null && url.isNotEmpty) {
        _playSvga(url, onFinished: widget.onCountdownComplete);
      } else {
        _startFallbackCountdown();
      }
    } else if (widget.phase == VideoPkAnimationPhase.opening) {
      final url = _effectsConfig.openingSvgaUrl;
      if (url != null && url.isNotEmpty) {
        _playSvga(url, onFinished: widget.onOpeningComplete);
      } else {
        _startFallbackOpening();
      }
    } else if (widget.phase == VideoPkAnimationPhase.winner) {
      final url = _effectsConfig.winnerSvgaUrl;
      if (url != null && url.isNotEmpty) {
        _playSvga(url, onFinished: widget.onWinnerComplete);
      } else {
        _startFallbackWinner();
      }
    }
  }

  Future<void> _playSvga(String url, {required VoidCallback onFinished}) async {
    try {
      final movieEntity = await SVGAParser().decodeFromURL(url);
      if (!mounted) return;

      _svgaController?.videoItem = movieEntity;
      _svgaController?.reset();
      setState(() => _isPlayingSvga = true);

      _svgaController?.forward().whenComplete(() {
        if (mounted) {
          setState(() => _isPlayingSvga = false);
          onFinished();
        }
      });
    } catch (e) {
      debugPrint('⚠️ [VideoPkAnimationOverlay] Error playing SVGA: $e');
      if (mounted) {
        setState(() => _isPlayingSvga = false);
        // Fallback on error
        if (widget.phase == VideoPkAnimationPhase.countdown) {
          _startFallbackCountdown();
        } else if (widget.phase == VideoPkAnimationPhase.opening) {
          _startFallbackOpening();
        } else {
          _startFallbackWinner();
        }
      }
    }
  }

  void _startFallbackCountdown() {
    _countdownNumber = _effectsConfig.countdownSeconds;
    _pulseController.reset();
    _pulseController.forward();

    _phaseTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdownNumber > 1) {
        setState(() => _countdownNumber--);
        _pulseController.reset();
        _pulseController.forward();
      } else {
        timer.cancel();
        widget.onCountdownComplete();
      }
    });
  }

  void _startFallbackOpening() {
    _pulseController.reset();
    _pulseController.forward();
    _phaseTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) widget.onOpeningComplete();
    });
  }

  void _startFallbackWinner() {
    _pulseController.reset();
    _pulseController.forward();
    _phaseTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) widget.onWinnerComplete();
    });
  }

  @override
  void dispose() {
    _phaseTimer?.cancel();
    _configSub?.cancel();
    _pulseController.dispose();
    _svgaController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.phase == VideoPkAnimationPhase.none) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          color: Colors.black.withOpacity(0.4),
          child: Center(
            child: _isPlayingSvga && _svgaController != null
                ? SizedBox(
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.width * 1.2,
                    child: SVGAImage(_svgaController!),
                  )
                : _buildFallbackContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackContent() {
    if (widget.phase == VideoPkAnimationPhase.countdown) {
      return ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF416C).withOpacity(0.8),
                blurRadius: 28,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Center(
            child: Text(
              '$_countdownNumber',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 60,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      );
    }

    if (widget.phase == VideoPkAnimationPhase.opening) {
      return ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF8A2387), Color(0xFFE94057), Color(0xFFF27121)],
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE94057).withOpacity(0.8),
                blurRadius: 30,
                spreadRadius: 6,
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sports_kabaddi, color: Colors.white, size: 36),
              SizedBox(width: 10),
              Text(
                'PK BATTLE START!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (widget.phase == VideoPkAnimationPhase.winner) {
      return ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFD700), Color(0xFFFF8C00), Color(0xFFFF4500)],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withOpacity(0.8),
                blurRadius: 35,
                spreadRadius: 8,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.emoji_events, color: Colors.white, size: 54),
              const SizedBox(height: 8),
              if (widget.winnerPhotoUrl != null &&
                  widget.winnerPhotoUrl!.isNotEmpty) ...[
                CircleAvatar(
                  radius: 36,
                  backgroundImage:
                      CachedNetworkImageProvider(widget.winnerPhotoUrl!),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                widget.winnerName != null
                    ? '${widget.winnerName} WINS!'
                    : 'VICTORY!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  shadows: [
                    Shadow(
                      color: Colors.black45,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

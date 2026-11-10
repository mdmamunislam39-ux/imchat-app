import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/helpers/mic_refill_helper.dart';
import 'package:chat_messenger/components/universal_asset_widget.dart';
import 'dart:async';

/// A widget that shows a vibrant ripple/glow animation when [isSpeaking] is true
/// or driven by [volumeNotifier] for volume-reactive intensity.
/// If a user has equipped a 'micRefill' SVGA file, it previews and scales that refill
/// smoothly according to the speaker's voice volume.
class SpeakingRippleAnimation extends StatefulWidget {
  final bool isSpeaking;
  final ValueListenable<double>? volumeNotifier;
  final Widget child;
  final double minRadius;
  final double maxRadius;
  final Color rippleColor;
  final String? userId;

  const SpeakingRippleAnimation({
    super.key,
    required this.isSpeaking,
    this.volumeNotifier,
    required this.child,
    this.minRadius = 30,
    this.maxRadius = 40,
    this.rippleColor = const Color(0x66FFFFFF),
    this.userId,
  });

  @override
  State<SpeakingRippleAnimation> createState() =>
      _SpeakingRippleAnimationState();
}

class _SpeakingRippleAnimationState extends State<SpeakingRippleAnimation>
    with TickerProviderStateMixin {
  late AnimationController _ripple1;
  late AnimationController _ripple2;
  late AnimationController _glowController;

  double _currentVolume = 0.0;
  bool _isActive = false;

  Timer? _silenceTimer;
  StreamSubscription? _userSub;
  String? _micRefillUrl;
  String? _loadedUserId;

  bool get _shouldBeActive {
    final vol = widget.volumeNotifier?.value ?? 0.0;
    if (widget.volumeNotifier != null) {
      return vol > 0.02;
    }
    return widget.isSpeaking;
  }

  @override
  void initState() {
    super.initState();

    _ripple1 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _ripple2 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    if (widget.volumeNotifier != null) {
      widget.volumeNotifier!.addListener(_onVolumeChanged);
    }
    if (_shouldBeActive) {
      _startAnimations();
    }

    _listenToUserCustomization();
  }

  void _listenToUserCustomization() {
    final targetId = widget.userId;
    if (targetId == null || targetId.isEmpty) {
      _userSub?.cancel();
      _userSub = null;
      _loadedUserId = null;
      if (_micRefillUrl != null && mounted) {
        setState(() => _micRefillUrl = null);
      }
      return;
    }

    if (_loadedUserId == targetId && (_userSub != null || _micRefillUrl != null)) {
      return;
    }
    _loadedUserId = targetId;

    _userSub?.cancel();
    _userSub = null;

    // 1. Instant check synchronous in-memory cache for zero UI delay
    final initialCached = MicRefillHelper.getCachedUserMicRefill(targetId);
    if (initialCached != null && initialCached.isNotEmpty) {
      if (_micRefillUrl != initialCached && mounted) {
        setState(() => _micRefillUrl = initialCached);
      }
    } else if (initialCached == null && _micRefillUrl != null && mounted) {
      setState(() => _micRefillUrl = null);
    }

    // 2. If current user, observe reactive RxString (zero firestore queries)
    if (Get.isRegistered<AuthController>() && targetId == AuthController.instance.currentUser.userId) {
      _userSub = MicRefillHelper.currentMicRefillUrl.listen((newUrl) {
        if (mounted && _micRefillUrl != newUrl) {
          setState(() {
            _micRefillUrl = newUrl.isNotEmpty ? newUrl : null;
          });
        }
      });
      return;
    }

    // 3. For other users, single cached one-time fetch instead of continuous snapshot stream
    MicRefillHelper.getUserMicRefill(targetId).then((newUrl) {
      if (mounted && _loadedUserId == targetId && _micRefillUrl != newUrl) {
        setState(() {
          _micRefillUrl = newUrl;
        });
      }
    }).catchError((e) {
      debugPrint('Error loading user mic refill: $e');
    });
  }

  void _startAnimations() {
    _silenceTimer?.cancel();
    _silenceTimer = null;

    if (_isActive) return;
    _isActive = true;
    _ripple1.repeat();
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted && _isActive) _ripple2.repeat();
    });
    _glowController.repeat(reverse: true);
    if (mounted) setState(() {});
  }

  void _stopAnimations() {
    _silenceTimer?.cancel();
    _silenceTimer = null;

    if (!_isActive) return;
    _isActive = false;
    _ripple1.stop();
    _ripple1.reset();
    _ripple2.stop();
    _ripple2.reset();
    _glowController.stop();
    _glowController.reset();
    if (mounted) setState(() => _currentVolume = 0.0);
  }

  @override
  void didUpdateWidget(SpeakingRippleAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.volumeNotifier != oldWidget.volumeNotifier) {
      oldWidget.volumeNotifier?.removeListener(_onVolumeChanged);
      widget.volumeNotifier?.addListener(_onVolumeChanged);
    }

    if (widget.userId != oldWidget.userId) {
      _listenToUserCustomization();
    }

    if (widget.volumeNotifier == null) {
      if (widget.isSpeaking != oldWidget.isSpeaking) {
        if (widget.isSpeaking) {
          _currentVolume = 0.5;
          _startAnimations();
        } else {
          _stopAnimations();
        }
      }
    } else {
      if (_shouldBeActive) {
        if (!_isActive) _startAnimations();
      }
    }
  }

  void _onVolumeChanged() {
    final volume = widget.volumeNotifier?.value ?? 0.0;
    final bool isLoudEnough = volume > 0.02;

    if (isLoudEnough) {
      _silenceTimer?.cancel();
      _silenceTimer = null;

      if (!_isActive) {
        _startAnimations();
      }
      if (mounted) {
        setState(() {
          _currentVolume = volume.clamp(0.0, 1.0);
        });
      }
    } else {
      // Natural speech pauses: hold speaking active for 350ms so mic refill and ripples
      // do not stutter or destroy/reload between syllables
      if (_isActive && _silenceTimer == null) {
        _silenceTimer = Timer(const Duration(milliseconds: 350), () {
          if (mounted) {
            _stopAnimations();
          }
        });
      }
      // Smooth decay of current volume
      if (mounted && _currentVolume > 0.0) {
        setState(() {
          _currentVolume = (_currentVolume * 0.5).clamp(0.0, 1.0);
          if (_currentVolume < 0.05) _currentVolume = 0.0;
        });
      }
    }
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    widget.volumeNotifier?.removeListener(_onVolumeChanged);
    _userSub?.cancel();
    _ripple1.dispose();
    _ripple2.dispose();
    _glowController.dispose();
    super.dispose();
  }

  // Scale ripple based on volume — louder voice = bigger ripples
  double _volumeScale() {
    return 1.0 + (_currentVolume * 0.5).clamp(0.0, 0.5);
  }

  @override
  Widget build(BuildContext context) {
    final diameter = widget.minRadius * 2;
    final bool hasMicRefill = _micRefillUrl != null && _micRefillUrl!.isNotEmpty;
    // Sized right around the avatar and frame (up to 100)
    final double refillSize = (widget.minRadius * 4.0).clamp(88.0, 100.0);
    // Subtle volume dynamics so it stays clean and contained
    final double refillVolumeScale = 1.0 + (_currentVolume * 0.10).clamp(0.0, 0.12);

    return RepaintBoundary(
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // 1. Custom Mic Refill SVGA/Alpha Video animation if equipped from store
          // Rendered in the background (behind avatar and frame)
          if (hasMicRefill)
            AnimatedOpacity(
              opacity: _isActive ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: AnimatedScale(
                scale: _isActive ? refillVolumeScale : 0.94,
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOutCubic,
                child: OverflowBox(
                  minWidth: refillSize,
                  maxWidth: refillSize,
                  minHeight: refillSize,
                  maxHeight: refillSize,
                  child: IgnorePointer(
                    child: UniversalAssetWidget(
                      key: ValueKey(_micRefillUrl!),
                      url: _micRefillUrl!,
                      fit: BoxFit.contain,
                      isAlphaVideo: true,
                    ),
                  ),
                ),
              ),
            ),

          // 2. Default Ripple / Glow wave layer (only when user has no custom mic refill)
          if (_isActive && !hasMicRefill) ...[
            AnimatedBuilder(
              animation: _glowController,
              builder: (context, child) {
                final glowIntensity =
                    0.15 + (_currentVolume * 0.25) + (_glowController.value * 0.10);
                return Container(
                  width: diameter + 6,
                  height: diameter + 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: widget.rippleColor
                            .withValues(alpha: glowIntensity.clamp(0.0, 1.0)),
                        blurRadius: 8 + (_currentVolume * 8),
                        spreadRadius: 1 + (_currentVolume * 2),
                      ),
                    ],
                  ),
                );
              },
            ),

            // Subtle ripple rings
            _buildRippleRing(_ripple2, diameter, 0.35),
            _buildRippleRing(_ripple1, diameter, 0.55),
          ],

          // 3. Main Child (Avatar with optional Frame on top)
          widget.child,
        ],
      ),
    );
  }

  Widget _buildRippleRing(
    AnimationController controller,
    double diameter,
    double baseOpacity,
  ) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        if (!controller.isAnimating && controller.value == 0) {
          return const SizedBox.shrink();
        }

        // Scale grows from 1.0 to volume-boosted max
        final scale = 1.0 + (controller.value * 0.35 * _volumeScale());
        // Opacity fades out as ripple expands
        final opacity =
            (baseOpacity * (1.0 - controller.value) * _volumeScale())
                .clamp(0.0, 1.0);

        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: diameter,
              height: diameter,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.rippleColor,
                  width: 2.5 + (_currentVolume * 2),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

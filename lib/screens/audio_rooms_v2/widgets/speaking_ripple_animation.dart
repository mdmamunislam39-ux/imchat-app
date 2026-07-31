import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chat_messenger/helpers/mic_refill_helper.dart';
import 'package:chat_messenger/components/universal_asset_widget.dart';
import 'dart:async';

/// A widget that shows a vibrant ripple/glow animation when [isSpeaking] is true
/// or driven by [volumeNotifier] for volume-reactive intensity.
/// If a user has equipped a 'micRefill' SVGA file, it plays that SVGA behind the avatar instead.
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
  late AnimationController _ripple3;
  late AnimationController _glowController;

  double _currentVolume = 0.0;
  bool _isActive = false;

  StreamSubscription? _userSub;
  String? _micRefillUrl;

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
    _ripple3 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    if (widget.volumeNotifier != null) {
      widget.volumeNotifier!.addListener(_onVolumeChanged);
    } else if (widget.isSpeaking) {
      _startAnimations();
    }

    _listenToUserCustomization();
  }

  void _listenToUserCustomization() {
    _userSub?.cancel();
    if (widget.userId != null && widget.userId!.isNotEmpty) {
      _userSub = FirebaseFirestore.instance
          .collection('Users')
          .doc(widget.userId)
          .snapshots()
          .listen((snapshot) async {
        if (snapshot.exists && mounted) {
          final data = snapshot.data();
          final customization = data?['customization'] as Map<String, dynamic>?;
          final selectedMicRefillId = customization?['selectedMicRefillId'] as String?;
          
          if (selectedMicRefillId != null && selectedMicRefillId.isNotEmpty) {
            final url = await MicRefillHelper.getMicRefillUrl(selectedMicRefillId);
            if (mounted) {
              setState(() {
                _micRefillUrl = url;
              });
            }
          } else {
            if (mounted) {
              setState(() {
                _micRefillUrl = null;
              });
            }
          }
        }
      }, onError: (e) {
        debugPrint('Error listening to user document in SpeakingRippleAnimation: $e');
      });
    }
  }

  void _startAnimations() {
    if (_isActive) return;
    _isActive = true;
    _ripple1.repeat();
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted && _isActive) _ripple2.repeat();
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && _isActive) _ripple3.repeat();
    });
    _glowController.repeat(reverse: true);
  }

  void _stopAnimations() {
    if (!_isActive) return;
    _isActive = false;
    _ripple1.stop();
    _ripple1.reset();
    _ripple2.stop();
    _ripple2.reset();
    _ripple3.stop();
    _ripple3.reset();
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
          _startAnimations();
        } else {
          _stopAnimations();
        }
      }
    }
  }

  void _onVolumeChanged() {
    final volume = widget.volumeNotifier?.value ?? 0.0;

    if (volume > 0.02) {
      if (!_isActive) _startAnimations();
      if (mounted) setState(() => _currentVolume = volume.clamp(0.0, 1.0));
    } else {
      if (_isActive) _stopAnimations();
    }
  }

  @override
  void dispose() {
    widget.volumeNotifier?.removeListener(_onVolumeChanged);
    _userSub?.cancel();
    _ripple1.dispose();
    _ripple2.dispose();
    _ripple3.dispose();
    _glowController.dispose();
    super.dispose();
  }

  // Scale ripple based on volume — louder voice = bigger ripples
  double _volumeScale() {
    // Base scale boost + volume-driven boost (range: 1.0 to 1.5)
    return 1.0 + (_currentVolume * 0.5).clamp(0.0, 0.5);
  }

  @override
  Widget build(BuildContext context) {
    final diameter = widget.minRadius * 2;
    final bool hasMicRefill = _micRefillUrl != null && _micRefillUrl!.isNotEmpty;

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // Glow / Ripple animation OR Mic Refill SVGA background layer
        if (_isActive) ...[
          if (hasMicRefill)
            Positioned(
              top: -widget.minRadius * 0.45,
              bottom: -widget.minRadius * 0.45,
              left: -widget.minRadius * 0.45,
              right: -widget.minRadius * 0.45,
              child: IgnorePointer(
                child: UniversalAssetWidget(
                  url: _micRefillUrl!,
                  fit: BoxFit.cover,
                  isAlphaVideo: true,
                ),
              ),
            )
          else ...[
            // Glow layer behind everything
            AnimatedBuilder(
              animation: _glowController,
              builder: (context, child) {
                final glowIntensity =
                    0.15 + (_currentVolume * 0.35) + (_glowController.value * 0.1);
                return Container(
                  width: diameter + 16,
                  height: diameter + 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: widget.rippleColor.withValues(alpha: glowIntensity.clamp(0.0, 1.0)),
                        blurRadius: 18 + (_currentVolume * 20),
                        spreadRadius: 4 + (_currentVolume * 8),
                      ),
                    ],
                  ),
                );
              },
            ),

            // Ripple ring 3 (outermost, faintest)
            _buildRippleRing(_ripple3, diameter, 0.25),

            // Ripple ring 2 (middle)
            _buildRippleRing(_ripple2, diameter, 0.4),

            // Ripple ring 1 (innermost, brightest)
            _buildRippleRing(_ripple1, diameter, 0.6),
          ],
        ],

        // Main Child (Avatar)
        widget.child,
      ],
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

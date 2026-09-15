import 'dart:async';
import 'package:flutter/material.dart';
import 'package:chat_messenger/models/lucky_bag_model.dart';
import 'package:chat_messenger/services/lucky_bag_service.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/lucky_bag_big_packet_dialog.dart';

/// Minimized Floating Red Envelope Icon (Solid, Non-Flickering, Draggable, Auto-Vanish)
class LuckyBagFloatingWidget extends StatefulWidget {
  final String roomId;
  final String currentUserId;
  final String currentUserName;
  final String? currentUserAvatar;

  const LuckyBagFloatingWidget({
    super.key,
    required this.roomId,
    required this.currentUserId,
    required this.currentUserName,
    this.currentUserAvatar,
  });

  @override
  State<LuckyBagFloatingWidget> createState() => _LuckyBagFloatingWidgetState();
}

class _LuckyBagFloatingWidgetState extends State<LuckyBagFloatingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  Stream<LuckyBagModel?>? _bagStream;

  Stream<LuckyBagModel?> get bagStream =>
      _bagStream ??= LuckyBagService.streamActiveLuckyBag(widget.roomId);

  Timer? _ticker;
  Offset? _dragPosition;
  bool _isDragging = false;
  bool _isOpeningDialog = false;

  @override
  void initState() {
    super.initState();
    // Cache stream instance to prevent re-subscribing & flickering on parent rebuilds
    _bagStream = LuckyBagService.streamActiveLuckyBag(widget.roomId);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.96, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Periodic 1-second ticker to update countdown smoothly without starting timers inside build
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void didUpdateWidget(LuckyBagFloatingWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roomId != widget.roomId) {
      _bagStream = LuckyBagService.streamActiveLuckyBag(widget.roomId);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dragPosition == null) {
      final size = MediaQuery.of(context).size;
      // Default position: bottom-right above room event banner
      _dragPosition = Offset(size.width - 70, size.height - 240);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _ticker?.cancel();
    super.dispose();
  }

  void _openBigPacket(LuckyBagModel bag) {
    if (_isOpeningDialog) return;
    _isOpeningDialog = true;
    LuckyBagBigPacketDialog.show(
      context,
      roomId: widget.roomId,
      bag: bag,
      currentUserId: widget.currentUserId,
      currentUserName: widget.currentUserName,
      currentUserAvatar: widget.currentUserAvatar,
    );
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        _isOpeningDialog = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<LuckyBagModel?>(
      stream: bagStream, // Use safe lazy cached stream accessor
      builder: (context, snapshot) {
        final bag = snapshot.data;
        if (bag == null || !bag.isActive) {
          return const SizedBox.shrink();
        }

        final secondsLeft = bag.secondsUntilUnlock;
        final secondsSinceUnlock =
            DateTime.now().difference(bag.unlocksAt).inSeconds;

        // Auto-vanish 15 seconds after unlock countdown finishes
        if (secondsLeft <= 0 && secondsSinceUnlock > 15) {
          return const SizedBox.shrink();
        }

        final position =
            _dragPosition ?? Offset(MediaQuery.of(context).size.width - 70, 450);

        return Positioned(
          top: position.dy,
          left: position.dx,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (_) {
                _isDragging = false;
              },
              onPanUpdate: (details) {
                if (details.delta.dx.abs() > 1.5 || details.delta.dy.abs() > 1.5) {
                  _isDragging = true;
                }
                setState(() {
                  _dragPosition = Offset(
                    (position.dx + details.delta.dx)
                        .clamp(0.0, MediaQuery.of(context).size.width - 60),
                    (position.dy + details.delta.dy)
                        .clamp(40.0, MediaQuery.of(context).size.height - 100),
                  );
                });
              },
              onPanEnd: (_) {
                if (!_isDragging) {
                  _openBigPacket(bag);
                }
              },
              onTap: () => _openBigPacket(bag),
              child: Container(
                width: 56,
                height: 66,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF3B6B), Color(0xFFFF1744)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFFFFD54F),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF1744).withValues(alpha: 0.5),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Envelope Gold Ring / Icon
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFFFD54F),
                        border: Border.all(color: Colors.white, width: 1.0),
                      ),
                      child: const Center(
                        child: Icon(Icons.card_giftcard,
                            size: 11, color: Color(0xFFC62828)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Live Countdown Text Pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        secondsLeft > 0 ? '${secondsLeft}s' : 'Open',
                        style: TextStyle(
                          color: secondsLeft > 0
                              ? Colors.amberAccent
                              : Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

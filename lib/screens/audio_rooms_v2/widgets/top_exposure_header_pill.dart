import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chat_messenger/services/top_exposure_service.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/grab_the_top_bottom_sheet.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/bloc/audio_rooms_bloc.dart';

/// Top Exposure Header Pill displayed in the Voice Room header bar
class TopExposureHeaderPill extends StatefulWidget {
  final String? currentRoomId;
  final AudioRoomsBloc? audioRoomsBloc;
  final VoidCallback? onGrabTheTopTap;

  const TopExposureHeaderPill({
    super.key,
    this.currentRoomId,
    this.audioRoomsBloc,
    this.onGrabTheTopTap,
  });

  @override
  State<TopExposureHeaderPill> createState() => _TopExposureHeaderPillState();
}

class _TopExposureHeaderPillState extends State<TopExposureHeaderPill> {
  Timer? _countdownTimer;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _onPillTap(BuildContext context, TopExposure? exposure) {
    GrabTheTopBottomSheet.show(
      context,
      exposure: exposure,
      currentRoomId: widget.currentRoomId,
      audioRoomsBloc: widget.audioRoomsBloc,
      onGrabTheTop: widget.onGrabTheTopTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final topExposureService = TopExposureService.instance;

    return Obx(() {
      final exposure = topExposureService.activeTopExposure.value;

      if (exposure == null || exposure.isExpired) {
        // Idle State: "Grab the Top 🪑" pill button
        return GestureDetector(
          onTap: () => _onPillTap(context, null),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Grab the Top ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Inter',
                  ),
                ),
                Text(
                  '🪑',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        );
      }

      // Active State: Live Exposure Ticker Pill (Screenshot 1 yellow circle)
      _secondsLeft = exposure.remainingSeconds;

      return GestureDetector(
        onTap: () => _onPillTap(context, exposure),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFBA42FF).withValues(alpha: 0.6),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Sender Avatar
              _buildMiniAvatar(exposure.senderImageUrl, isSender: true),

              const SizedBox(width: 4),

              // Gift Icon & Count
              if (exposure.giftPngUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: exposure.giftPngUrl,
                  width: 18,
                  height: 18,
                  errorWidget: (_, __, ___) => const Text('💋', style: TextStyle(fontSize: 12)),
                )
              else
                const Text('💋', style: TextStyle(fontSize: 12)),

              const SizedBox(width: 2),

              Text(
                '×${exposure.quantity}',
                style: const TextStyle(
                  color: Color(0xFFFF4081),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Inter',
                ),
              ),

              const SizedBox(width: 2),

              const Icon(
                Icons.east_rounded,
                color: Color(0xFFBA42FF),
                size: 12,
              ),

              const SizedBox(width: 2),

              // Receiver Avatar
              _buildMiniAvatar(exposure.receiverImageUrl, isSender: false),

              const SizedBox(width: 6),

              // Countdown text (e.g. 180s)
              Text(
                '${_secondsLeft}s',
                style: const TextStyle(
                  color: Color(0xFFE088FF),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildMiniAvatar(String? url, {required bool isSender}) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFFFFD700),
          width: 1,
        ),
      ),
      child: ClipOval(
        child: url != null && url.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Icon(
                  isSender ? Icons.person : Icons.stars,
                  size: 14,
                  color: Colors.white,
                ),
              )
            : Icon(
                isSender ? Icons.person : Icons.stars,
                size: 14,
                color: Colors.amberAccent,
              ),
      ),
    );
  }
}

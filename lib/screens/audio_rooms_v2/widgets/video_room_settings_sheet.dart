// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';

/// Room Settings Sheet matching Khan_Live's sleek glassmorphic grid menu
class VideoRoomSettingsSheet extends StatelessWidget {
  final bool isHost;
  final bool isSeatedGuest;
  final bool isMuted;
  final bool isCameraOff;
  final bool isSpeakerMuted;
  final int joinRequestsCount;
  final VoidCallback onOpenBeauty;
  final VoidCallback onOpenBackground;
  final VoidCallback onFlipCamera;
  final VoidCallback onToggleMic;
  final VoidCallback onToggleCamera;
  final VoidCallback onToggleSpeaker;
  final VoidCallback onOpenManageGuests;
  final VoidCallback onEditRoomInfo;
  final VoidCallback onLeaveCall;
  final VoidCallback? onOpenPKBattle;
  final VoidCallback? onOpenLuckyBag;

  const VideoRoomSettingsSheet({
    super.key,
    required this.isHost,
    required this.isSeatedGuest,
    required this.isMuted,
    required this.isCameraOff,
    required this.isSpeakerMuted,
    required this.joinRequestsCount,
    required this.onOpenBeauty,
    required this.onOpenBackground,
    required this.onFlipCamera,
    required this.onToggleMic,
    required this.onToggleCamera,
    required this.onToggleSpeaker,
    required this.onOpenManageGuests,
    required this.onEditRoomInfo,
    required this.onLeaveCall,
    this.onOpenPKBattle,
    this.onOpenLuckyBag,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF131722).withOpacity(0.97),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle Bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white30,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Sheet Title & Close
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.widgets_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Room Tools & Settings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.white70, size: 20),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Options Grid
            Wrap(
              spacing: 16,
              runSpacing: 18,
              alignment: WrapAlignment.start,
              children: [
                // 1. Beauty Effect (Host only)
                if (isHost)
                  _buildSettingsTile(
                    icon: Icons.auto_awesome_rounded,
                    label: 'Beauty',
                    gradientColors: const [
                      Color(0xFFFF416C),
                      Color(0xFFFF4B2B)
                    ],
                    onTap: () {
                      Navigator.pop(context);
                      onOpenBeauty();
                    },
                  ),

                // 2. Flip Camera (Host only)
                if (isHost)
                  _buildSettingsTile(
                    icon: Icons.flip_camera_ios_rounded,
                    label: 'Flip Camera',
                    gradientColors: const [
                      Color(0xFFF7971E),
                      Color(0xFFFFD200)
                    ],
                    onTap: () {
                      Navigator.pop(context);
                      onFlipCamera();
                    },
                  ),

                // 3. PK Battle (Host only)
                if (isHost && onOpenPKBattle != null)
                  _buildSettingsTile(
                    icon: Icons.sports_kabaddi_rounded,
                    label: 'PK Battle',
                    gradientColors: const [
                      Color(0xFFD946EF),
                      Color(0xFF8B5CF6),
                    ],
                    onTap: () {
                      Navigator.pop(context);
                      onOpenPKBattle!();
                    },
                  ),

                // 4. Background / Virtual Background (Host only)
                if (isHost)
                  _buildSettingsTile(
                    icon: Icons.image_outlined,
                    label: 'Background',
                    gradientColors: const [
                      Color(0xFF2193b0),
                      Color(0xFF6dd5ed)
                    ],
                    onTap: () {
                      Navigator.pop(context);
                      onOpenBackground();
                    },
                  ),

                // 5. Manage Guests (Host only)
                if (isHost)
                  _buildSettingsTile(
                    icon: Icons.group_outlined,
                    label: joinRequestsCount > 0
                        ? 'Guests ($joinRequestsCount)'
                        : 'Guests',
                    gradientColors: const [
                      Color(0xFF10B981),
                      Color(0xFF059669)
                    ],
                    badgeText:
                        joinRequestsCount > 0 ? '$joinRequestsCount' : null,
                    onTap: () {
                      Navigator.pop(context);
                      onOpenManageGuests();
                    },
                  ),

                // 5. Edit Room Info (Host only)
                if (isHost)
                  _buildSettingsTile(
                    icon: Icons.edit_note_rounded,
                    label: 'Room Info',
                    gradientColors: const [
                      Color(0xFF8A2387),
                      Color(0xFFE94057)
                    ],
                    onTap: () {
                      Navigator.pop(context);
                      onEditRoomInfo();
                    },
                  ),

                // 6. Lucky Bag
                if (onOpenLuckyBag != null)
                  _buildSettingsTile(
                    icon: Icons.card_giftcard_rounded,
                    label: 'Lucky Bag',
                    gradientColors: const [
                      Color(0xFFFF9800),
                      Color(0xFFFF5722),
                    ],
                    badgeText: 'HOT',
                    onTap: () {
                      Navigator.pop(context);
                      onOpenLuckyBag!();
                    },
                  ),

                // 7. Mic Mute / Unmute (Host or seated guest)
                if (isHost || isSeatedGuest)
                  _buildSettingsTile(
                    icon: isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    label: isMuted ? 'Mic Muted' : 'Mic Live',
                    gradientColors: isMuted
                        ? const [Color(0xFFEB3349), Color(0xFFF45C43)]
                        : const [Color(0xFF00b09b), Color(0xFF96c93d)],
                    onTap: onToggleMic,
                  ),

                // 7. Camera On / Off (Host only)
                if (isHost)
                  _buildSettingsTile(
                    icon: isCameraOff
                        ? Icons.videocam_off_rounded
                        : Icons.videocam_rounded,
                    label: isCameraOff ? 'Cam Off' : 'Cam On',
                    gradientColors: isCameraOff
                        ? const [Color(0xFF757F9A), Color(0xFFD7DDE8)]
                        : const [Color(0xFF4facfe), Color(0xFF00f2fe)],
                    onTap: onToggleCamera,
                  ),

                // 8. Sound / Room Speaker
                _buildSettingsTile(
                  icon: isSpeakerMuted
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded,
                  label: isSpeakerMuted ? 'Muted' : 'Sound On',
                  gradientColors: isSpeakerMuted
                      ? const [Color(0xFF757F9A), Color(0xFFD7DDE8)]
                      : const [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  onTap: onToggleSpeaker,
                ),

                // 9. Leave Call (Seated Guest only)
                if (!isHost && isSeatedGuest)
                  _buildSettingsTile(
                    icon: Icons.call_end_rounded,
                    label: 'Leave Call',
                    gradientColors: const [
                      Color(0xFFEB3349),
                      Color(0xFFF45C43)
                    ],
                    onTap: () {
                      Navigator.pop(context);
                      onLeaveCall();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String label,
    required List<Color> gradientColors,
    required VoidCallback onTap,
    String? badgeText,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: gradientColors.first.withOpacity(0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      icon,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
                if (badgeText != null)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        badgeText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

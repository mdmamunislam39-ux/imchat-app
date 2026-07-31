import 'package:chat_messenger/screens/audio_rooms_v2/bloc/audio_rooms_event.dart';
import 'package:flutter/material.dart';
import 'package:chat_messenger/models/audio_room_v2.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/bloc/audio_rooms_bloc.dart';
import 'package:chat_messenger/models/user.dart';

/// Cool Room Mode Selector with modern UI
class RoomModeSelectorPage extends StatefulWidget {
  final AudioRoomV2 currentRoom;
  final AudioRoomsBloc audioRoomsBloc;
  final User currentUser;

  const RoomModeSelectorPage({
    super.key,
    required this.currentRoom,
    required this.audioRoomsBloc,
    required this.currentUser,
  });

  @override
  State<RoomModeSelectorPage> createState() => _RoomModeSelectorPageState();
}

class _RoomModeSelectorPageState extends State<RoomModeSelectorPage>
    with TickerProviderStateMixin {
  RoomMode? selectedMode;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    selectedMode = widget.currentRoom.settings.roomMode;

    // Initialize animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    // Start animation
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1A1A1A),
              Color(0xFF0A0A0A),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildCoolHeader(),
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: _buildModeGrid(),
                  ),
                ),
              ),
              _buildCoolConfirmButton(),
            ],
          ),
        ),
      ),
    );
  }

  /// Build cool header with glassmorphism effect
  Widget _buildCoolHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Back button with glow effect
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00BCD4).withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios,
                  color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          const SizedBox(width: 16),

          // Title with gradient text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF00BCD4), Color(0xFF00E5FF)],
                  ).createShader(bounds),
                  child: const Text(
                    'Switch Mode',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose your room layout',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build mode grid with cool animations - full screen layout
  Widget _buildModeGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // First row - Lite and Party modes
            Row(
              children: [
                Expanded(child: _buildCoolModeCard(RoomMode.lite, 0)),
                const SizedBox(width: 16),
                Expanded(child: _buildCoolModeCard(RoomMode.party, 1)),
              ],
            ),
            const SizedBox(height: 16),

            // Second row - MultiMic (centered)
            Row(
              children: [
                Expanded(flex: 1, child: const SizedBox()),
                Expanded(
                    flex: 2, child: _buildCoolModeCard(RoomMode.multiMic, 2)),
                Expanded(flex: 1, child: const SizedBox()),
              ],
            ),
            const SizedBox(height: 16),

            // Third row - 5 Seats and 10 Seats
            Row(
              children: [
                Expanded(child: _buildCoolModeCard(RoomMode.fiveSeats, 3)),
                const SizedBox(width: 16),
                Expanded(child: _buildCoolModeCard(RoomMode.tenSeats, 4)),
              ],
            ),
            const SizedBox(height: 16),

            // Fourth row - 20 Seats (centered)
            Row(
              children: [
                Expanded(flex: 1, child: const SizedBox()),
                Expanded(
                    flex: 2, child: _buildCoolModeCard(RoomMode.twentySeats, 5)),
                Expanded(flex: 1, child: const SizedBox()),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// Build individual mode card with glassmorphism and animations
  Widget _buildCoolModeCard(RoomMode mode, int index) {
    final isSelected = selectedMode == mode;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset:
              Offset(0, (1 - _animationController.value) * 50 * (index + 1)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            // height: 140,
            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF00BCD4),
                        Color(0xFF00E5FF),
                      ],
                    )
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.1),
                        Colors.white.withValues(alpha: 0.05),
                      ],
                    ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                  ? const Color(0xFF00E5FF).withValues(alpha: 0.8)
                  : Colors.white.withValues(alpha: 0.2),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                if (isSelected)
                    BoxShadow(
                    color: const Color(0xFF00BCD4).withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    selectedMode = mode;
                  });
                },
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Mode preview
                      Container(
                        width: 60,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _buildCoolModePreview(mode),
                      ),

                      const SizedBox(height: 12),

                      // Mode name
                      Text(
                        mode.displayName,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 4),

                      // Seat count
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: (isSelected
                                  ? Colors.white
                                  : const Color(0xFF00BCD4))
                              .withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${mode.seatCount} seats',
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF00BCD4),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      // Optional "LIVE" badge
                      if (mode == RoomMode.party || mode == RoomMode.multiMic)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Colors.red, Colors.redAccent],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'LIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Build cool mode preview with animated dots
  Widget _buildCoolModePreview(RoomMode mode) {
    final seatCount = mode.seatCount;

    return Center(
      child: Wrap(
        spacing: 3,
        runSpacing: 3,
        children: List.generate(
          seatCount > 6 ? 6 : seatCount, // Show max 6 seats in preview
          (index) => AnimatedContainer(
            duration: Duration(milliseconds: 200 + (index * 50)),
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: index == 0
                  ? Colors.amber // Admin seat
                  : Colors.white.withValues(alpha: 0.8),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (index == 0 ? Colors.amber : Colors.white)
                      .withValues(alpha: 0.5),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build cool confirm button with gradient and animations
  Widget _buildCoolConfirmButton() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: selectedMode != null
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF00BCD4),
                    Color(0xFF00E5FF),
                  ],
                )
                      : LinearGradient(
                      colors: [
                        Colors.grey.withValues(alpha: 0.3),
                        Colors.grey.withValues(alpha: 0.2),
                      ],
                ),
          borderRadius: BorderRadius.circular(16),
            boxShadow: selectedMode != null
              ? [
                  BoxShadow(
                    color: const Color(0xFF00BCD4).withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: selectedMode != null ? _confirmModeChange : null,
            borderRadius: BorderRadius.circular(16),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: selectedMode != null ? Colors.white : Colors.grey,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Confirm Selection',
                    style: TextStyle(
                      color: selectedMode != null ? Colors.white : Colors.grey,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Confirm mode change with haptic feedback
  void _confirmModeChange() {
    if (selectedMode != null &&
        selectedMode != widget.currentRoom.settings.roomMode) {
      // Add haptic feedback
      // HapticFeedback.mediumImpact();

      // Update room mode using BLoC
      widget.audioRoomsBloc.add(UpdateRoomMode(
        roomId: widget.currentRoom.id,
        userId: widget.currentUser.userId,
        roomMode: selectedMode!,
      ));

      // Show success animation
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Row(
      //       children: [
      //         const Icon(Icons.check_circle, color: Colors.white),
      //         const SizedBox(width: 8),
      //         Text('Switched to ${selectedMode!.displayName}'),
      //       ],
      //     ),
      //     backgroundColor: const Color(0xFF00BCD4),
      //     behavior: SnackBarBehavior.floating,
      //     shape: RoundedRectangleBorder(
      //       borderRadius: BorderRadius.circular(12),
      //     ),
      //   ),
      // );
    }

    Navigator.pop(context);
  }
}

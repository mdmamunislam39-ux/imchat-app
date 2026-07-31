// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:chat_messenger/components/cached_circle_avatar.dart';
// import 'package:chat_messenger/config/theme_config.dart';
// import 'package:chat_messenger/models/audio_room_v2.dart';
// import 'package:cached_network_image/cached_network_image.dart';
// import 'package:chat_messenger/screens/audio_rooms_v2/widgets/speaking_ripple_animation.dart';

// /// Individual participant seat in the audio room
// class ParticipantSeat extends StatelessWidget {
//   final AudioRoomParticipant? participant;
//   final bool isSpeaking;
//   final ValueListenable<double>? volumeNotifier;
//   final bool isLarge;
//   final bool isEmpty;
//   final VoidCallback? onTap;

//   const ParticipantSeat({
//     super.key,
//     this.participant,
//     this.isSpeaking = false,
//     this.volumeNotifier,
//     this.isLarge = false,
//     this.isEmpty = false,
//     this.onTap,
//   });

//   @override
//   Widget build(BuildContext context) {
//     if (isEmpty) {
//       return _buildEmptySeat();
//     }

//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         width: isLarge ? 100 : 80,
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             // Avatar with speaking indicator
//             Stack(
//               clipBehavior: Clip.none,
//               children: [
//                 // Avatar with Ripple Animation
//                 SpeakingRippleAnimation(
//                   isSpeaking: isSpeaking,
//                   volumeNotifier: volumeNotifier,
//                   minRadius: isLarge ? 40 : 32,
//                   rippleColor: Colors.white.withValues(alpha: 0.5),
//                   child: CachedCircleAvatar(
//                     imageUrl: participant?.userImageUrl ?? '',
//                     frameId: participant?.frameId,
//                     radius: isLarge ? 40 : 35,
//                     backgroundColor: primaryColor.withValues(alpha: 0.2),
//                     borderWidth: 0,
//                     padding: 0,
//                   ),
//                 ),

//                 // Host crown indicator removed as per request

//                 // Mute indicator
//                 if (participant?.isMuted == true)
//                   Positioned(
//                     bottom: 0,
//                     right: isLarge ? 5 : 8,
//                     child: Container(
//                       width: 20,
//                       height: 20,
//                       decoration: BoxDecoration(
//                         color: participant?.isMutedByAdmin == true
//                             ? Colors.white
//                             : Colors.red,
//                         shape: BoxShape.circle,
//                         border: Border.all(color: Colors.white, width: 1),
//                       ),
//                       child: Icon(
//                         Icons.mic_off,
//                         color: participant?.isMutedByAdmin == true
//                             ? Colors.black
//                             : Colors.white,
//                         size: 12,
//                       ),
//                     ),
//                   ),

//                 // Active Emoji Reaction
//                 if (participant?.activeEmojiUrl != null)
//                   Positioned.fill(
//                     child: Align(
//                       alignment: Alignment.center,
//                       child: TweenAnimationBuilder<double>(
//                         key: ValueKey(participant!.activeEmojiUrl),
//                         tween: Tween(begin: 0.0, end: 1.0),
//                         duration: const Duration(milliseconds: 600),
//                         curve: Curves.elasticOut,
//                         builder: (context, value, child) {
//                           return Transform.scale(
//                             scale: value * 1.8, // Slightly larger pop
//                             child: CachedNetworkImage(
//                               imageUrl: participant!.activeEmojiUrl!,
//                               width: isLarge ? 50 : 40,
//                               height: isLarge ? 50 : 40,
//                               fit: BoxFit.contain,
//                               placeholder: (context, url) => const SizedBox(),
//                               errorWidget: (context, url, error) {
//                                 debugPrint(
//                                     '❌ [ParticipantSeat] Emoji load error: $error for URL: ${participant?.activeEmojiUrl}');
//                                 return const Icon(Icons.error,
//                                     color: Colors.amber, size: 24);
//                               },
//                             ),
//                           );
//                         },
//                       ),
//                     ),
//                   ),
//               ],
//             ),

//             const SizedBox(height: 8),

//             // Participant name
//             Container(
//               constraints: BoxConstraints(maxWidth: isLarge ? 100 : 80),
//               child: Text(
//                 participant?.userName ?? '',
//                 style: TextStyle(
//                   color: Colors.white,
//                   fontSize: isLarge ? 14 : 12,
//                   fontWeight: FontWeight.w500,
//                 ),
//                 textAlign: TextAlign.center,
//                 maxLines: 2,
//                 overflow: TextOverflow.ellipsis,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   /// Build empty seat placeholder
//   Widget _buildEmptySeat() {
//     return Container(
//       width: isLarge ? 100 : 80,
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           // Empty seat indicator
//           Container(
//             width: isLarge ? 70 : 56,
//             height: isLarge ? 70 : 56,
//             decoration: BoxDecoration(
//               shape: BoxShape.circle,
//               color: Colors.white.withValues(alpha: 0.1),
//               border: Border.all(
//                 color: Colors.white.withValues(alpha: 0.3),
//                 width: 2,
//               ),
//             ),
//             child: Icon(
//               Icons.add,
//               color: Colors.white.withValues(alpha: 0.5),
//               size: isLarge ? 24 : 20,
//             ),
//           ),

//           const SizedBox(height: 8),

//           // Empty text
//           Text(
//             'Join as speaker',
//             style: TextStyle(
//               color: Colors.white.withValues(alpha: 0.5),
//               fontSize: isLarge ? 12 : 10,
//             ),
//             textAlign: TextAlign.center,
//           ),
//         ],
//       ),
//     );
//   }
// }

// /// Grid of participant seats
// class ParticipantsGrid extends StatelessWidget {
//   final List<AudioRoomParticipant> participants;
//   final int maxSeats;
//   final Function(AudioRoomParticipant)? onParticipantTap;
//   final VoidCallback? onEmptySeatTap;

//   const ParticipantsGrid({
//     super.key,
//     required this.participants,
//     this.maxSeats = 8,
//     this.onParticipantTap,
//     this.onEmptySeatTap,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 20),
//       child: Column(
//         children: [
//           // First row - 2 large seats
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//             children: [
//               _buildSeat(0, isLarge: true),
//               _buildSeat(1, isLarge: true),
//             ],
//           ),

//           const SizedBox(height: 20),

//           // Second row - 3 seats
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//             children: [
//               _buildSeat(2),
//               _buildSeat(3),
//               _buildSeat(4),
//             ],
//           ),

//           const SizedBox(height: 20),

//           // Third row - 3 seats
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//             children: [
//               _buildSeat(5),
//               _buildSeat(6),
//               _buildSeat(7),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   /// Build individual seat at given index
//   Widget _buildSeat(int index, {bool isLarge = false}) {
//     if (index < participants.length) {
//       final participant = participants[index];
//       return ParticipantSeat(
//         participant: participant,
//         isLarge: isLarge,
//         isSpeaking: false, // TODO: Implement real-time speaking detection
//         onTap: () => onParticipantTap?.call(participant),
//       );
//     } else {
//       return ParticipantSeat(
//         isEmpty: true,
//         isLarge: isLarge,
//         onTap: onEmptySeatTap,
//       );
//     }
//   }
// }

// /// Animated speaking indicator
// class SpeakingIndicator extends StatefulWidget {
//   final bool isSpeaking;
//   final Widget child;

//   const SpeakingIndicator({
//     super.key,
//     required this.isSpeaking,
//     required this.child,
//   });

//   @override
//   State<SpeakingIndicator> createState() => _SpeakingIndicatorState();
// }

// class _SpeakingIndicatorState extends State<SpeakingIndicator>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _animationController;
//   late Animation<double> _scaleAnimation;

//   @override
//   void initState() {
//     super.initState();
//     _animationController = AnimationController(
//       duration: const Duration(milliseconds: 500),
//       vsync: this,
//     );
//     _scaleAnimation = Tween<double>(
//       begin: 1.0,
//       end: 1.1,
//     ).animate(CurvedAnimation(
//       parent: _animationController,
//       curve: Curves.easeInOut,
//     ));

//     if (widget.isSpeaking) {
//       _animationController.repeat(reverse: true);
//     }
//   }

//   @override
//   void didUpdateWidget(SpeakingIndicator oldWidget) {
//     super.didUpdateWidget(oldWidget);
//     if (widget.isSpeaking != oldWidget.isSpeaking) {
//       if (widget.isSpeaking) {
//         _animationController.repeat(reverse: true);
//       } else {
//         _animationController.stop();
//         _animationController.reset();
//       }
//     }
//   }

//   @override
//   void dispose() {
//     _animationController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return AnimatedBuilder(
//       animation: _scaleAnimation,
//       builder: (context, child) {
//         return Transform.scale(
//           scale: widget.isSpeaking ? _scaleAnimation.value : 1.0,
//           child: widget.child,
//         );
//       },
//     );
//   }
// }

import 'dart:ui';
import 'dart:math';
import 'dart:convert';
import 'package:chat_messenger/widgets/spinning_dice_widget.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/voting/voting_models.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/voting/voting_result_sheet.dart';
import 'package:chat_messenger/components/cached_circle_avatar.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:chat_messenger/helpers/level_helper.dart';
import 'package:chat_messenger/helpers/nameplate_helper.dart';

import 'package:chat_messenger/models/emoji_models.dart';
import 'package:chat_messenger/models/audio_room_v2.dart';
import 'package:chat_messenger/services/emoji_chat_service.dart';
import 'package:chat_messenger/widgets/emoji_picker_bottom_sheet.dart';
import 'package:get/get.dart';
import 'game_wall_bottom_sheet.dart';
import 'gift_selection_bottom_sheet.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:chat_messenger/screens/room/roomprofile_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chat_messenger/components/dynamic_diamond_icon.dart';

/// Bottom control buttons for audio room with live chat
class RoomControls extends StatefulWidget {
  final bool isMuted;
  final bool isSpeakerOn;
  final bool isHost;
  final bool isSpeaker;
  final bool isSeated;
  final VoidCallback onMuteToggle;
  final VoidCallback onSpeakerToggle;
  final VoidCallback onLeave;
  final VoidCallback? onRequestToSpeak;
  final List<EmojiChatMessage> chatMessages;
  final Function(String) onSendMessage;
  final Function(bool)? onEmojiPickerVisibilityChanged;
  final String? roomId;
  final String? currentUserId;
  final String? currentUserName;
  final String? currentUserImageUrl;
  final String? currentUserLevelBadgeUrl;
  final String? selectedUserId; // Restored
  final String? selectedUserName; // Restored
  final String? selectedUserImageUrl;
  final List<AudioRoomParticipant> participants;
  final int totalSeats;
  final Function(EmojiChatMessage)? onMessageTap;
  final bool isMutedByAdmin;
  final bool isLive;
  final bool hasRequestedToJoin;
  final int joinRequestsCount;
  final VoidCallback? onLiveMicTapped;
  final VoidCallback? onJoinRequestTapped;

  const RoomControls({
    super.key,
    required this.isMuted,
    required this.isSpeakerOn,
    required this.isHost,
    required this.isSpeaker,
    required this.isSeated,
    required this.onMuteToggle,
    required this.onSpeakerToggle,
    required this.onLeave,
    this.onRequestToSpeak,
    required this.chatMessages,
    required this.participants,
    this.totalSeats = 15,
    required this.onSendMessage,
    this.onEmojiPickerVisibilityChanged,
    this.roomId,
    this.currentUserId,
    this.currentUserName,
    this.currentUserImageUrl,
    this.currentUserLevelBadgeUrl,
    this.selectedUserId,
    this.selectedUserName,
    this.selectedUserImageUrl,
    this.onMessageTap,
    this.isMutedByAdmin = false,
    this.isLive = false,
    this.hasRequestedToJoin = false,
    this.joinRequestsCount = 0,
    this.onLiveMicTapped,
    this.onJoinRequestTapped,
  });

  @override
  State<RoomControls> createState() => _RoomControlsState();
}

class _RoomControlsState extends State<RoomControls> {
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _textFieldFocusNode = FocusNode();
  bool _chatHasText = false;
  EmojiChatMessage? _replyingToMessage;

  // Realtime User data cache to fetch Verified checkmark efficiently
  final Map<String, User> _userCache = {};

  Future<User> _getUserData(String userId) async {
    if (_userCache.containsKey(userId)) {
      return _userCache[userId]!;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(userId)
          .get();
      if (doc.exists && doc.data() != null) {
        final user = User.fromMap(doc.data() as Map<String, dynamic>);
        _userCache[userId] = user;
        return user;
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
    }
    final fallback = User(userId: userId, fullname: 'User', isVerified: false);
    _userCache[userId] = fallback;
    return fallback;
  }

  Future<_ChatUserData> _fetchChatUserData(String userId) async {
    final user = await _getUserData(userId);
    final sendingUrl = await LevelHelper.getSendingLevelUrl(user.sendingLevel?.level);
    final receivingUrl = await LevelHelper.getReceivingLevelUrl(user.receivingLevel?.level);
    final nameplateUrl = await NameplateHelper.getNameplateUrlFromUserId(userId);
    return _ChatUserData(user, sendingUrl, receivingUrl, nameplateUrl);
  }

  void _handleTapToMention(String username) {
    setState(() {
      final currentText = _chatController.text;
      if (currentText.isEmpty) {
        _chatController.text = '@$username ';
      } else {
        _chatController.text = '$currentText @$username ';
      }
    });
    _textFieldFocusNode.requestFocus();
  }

  void _openUserProfile({
    required BuildContext context,
    required String userId,
    required String username,
    required String avatar,
  }) {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (context, animation, secondaryAnimation) =>
            ProfilePageForRoom(
          userID: userId,
          userName: username,
          userImage: avatar,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    // Focus listener not needed anymore as visibility depends on typing text content

    // Listen to text changes for emoji/send toggle
    _chatController.addListener(() {
      final hasText = _chatController.text.trim().isNotEmpty;
      if (hasText != _chatHasText) {
        setState(() {
          _chatHasText = hasText;
        });
      }
    });

    // Auto-scroll to bottom when room is first opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _chatController.dispose();
    _scrollController.dispose();
    _textFieldFocusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(RoomControls oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Auto-scroll to bottom when new messages arrive
    if (widget.chatMessages.length != oldWidget.chatMessages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
  }

  /// Scroll to the bottom of the chat
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent, // Scroll to bottom
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _toggleEmojiPicker() {
    _showCustomEmojiPicker();
  }

  void _showCustomEmojiPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EmojiPickerBottomSheet(
        onEmojiSelected: _onEmojiSelected,
        currentUserId: widget.currentUserId,
        onClose: () {
          widget.onEmojiPickerVisibilityChanged?.call(false);
        },
      ),
    );
  }

  void _onEmojiSelected(EmojiItem emoji) async {
    try {
      debugPrint('🎭 [RoomControls] Sending emoji: ${emoji.name}');
      if (widget.roomId != null &&
          widget.currentUserId != null &&
          widget.currentUserName != null) {
        if (emoji.id == 'local_dice_action') {
          final rolledNumber = Random().nextInt(6) + 1;
          await EmojiChatService.sendDiceMessage(
            roomId: widget.roomId!,
            userId: widget.currentUserId!,
            username: widget.currentUserName!,
            userAvatar: widget.currentUserImageUrl,
            rolledNumber: rolledNumber,
            senderLevelBadgeUrl: widget.currentUserLevelBadgeUrl,
          );
        } else {
          await EmojiChatService.sendEmojiMessage(
            roomId: widget.roomId!,
            userId: widget.currentUserId!,
            username: widget.currentUserName!,
            userAvatar: widget.currentUserImageUrl,
            emoji: emoji,
            senderLevelBadgeUrl: widget.currentUserLevelBadgeUrl,
          );
        }

        debugPrint('🎭 [RoomControls] Emoji sent successfully');

        // Auto-scroll to bottom after sending emoji
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });
      }
    } catch (e) {
      debugPrint('âŒ [RoomControls] Error sending emoji message: $e');
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send emoji: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showGiftSelection() async {
    if (widget.roomId == null ||
        widget.currentUserId == null ||
        widget.currentUserName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Unable to send gift - missing room or user information'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Force unfocus before showing bottom sheet
    FocusScope.of(context).unfocus();
    FocusManager.instance.primaryFocus?.unfocus();

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => GiftSelectionBottomSheet(
        roomId: widget.roomId!,
        senderId: widget.currentUserId!,
        senderName: widget.currentUserName!,
        senderImageUrl: widget.currentUserImageUrl,
        receiverId: widget.selectedUserId!, // Host ID
        receiverName: widget.selectedUserName!, // Host name
        receiverImageUrl: widget.selectedUserImageUrl, // Host image
        participants: widget.participants,
      ),
    );

    // Ensure focus is cleared after bottom sheet closes
    if (mounted) {
      FocusScope.of(context).unfocus();
      _textFieldFocusNode.unfocus();
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  /// Send chat message
  void _sendMessage() async {
    final message = _chatController.text.trim();
    if (message.isNotEmpty) {
      final replyId = _replyingToMessage?.id;
      final replyUser = _replyingToMessage?.username;
      final replyText = _replyingToMessage?.message;

      // Clear immediately for better UX
      _chatController.clear();
      // Keep keyboard open after sending a message
      FocusScope.of(context).requestFocus(_textFieldFocusNode);
      setState(() {
        _replyingToMessage = null;
      });

      try {
        // Use emoji chat service for sending text messages
        if (widget.roomId != null &&
            widget.currentUserId != null &&
            widget.currentUserName != null) {
          await EmojiChatService.sendTextMessage(
            roomId: widget.roomId!,
            userId: widget.currentUserId!,
            username: widget.currentUserName!,
            userAvatar: widget.currentUserImageUrl,
            message: message,
            senderLevelBadgeUrl: widget.currentUserLevelBadgeUrl,
            replyToMessageId: replyId,
            replyToUsername: replyUser,
            replyToText: replyText,
          );
        } else {
          // Fallback to old method if room/user info is missing
          widget.onSendMessage(message);
        }

        // Auto-scroll to bottom after sending message
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });
      } catch (e) {
        debugPrint('❌ [RoomControls] Error sending text message: $e');
        // Fallback to old method on error
        widget.onSendMessage(message);
      }
    }
  }

  /// Get consistent color for user based on their ID
  Color _getUserColor(String userId) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.purple,
      Colors.orange,
      Colors.pink,
      Colors.teal,
      Colors.indigo,
      Colors.cyan,
    ];

    final hash = userId.hashCode;
    return colors[hash.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    int seatCount = widget.totalSeats;
    double listMaxHeight = Get.height * 0.42; // default

    if (seatCount == 15 || seatCount == 12 || seatCount == 9) {
      listMaxHeight = Get.height * 0.35;
    } else if (seatCount == 10 || seatCount == 5) {
      listMaxHeight = Get.height * 0.47;
    } else if (seatCount == 20) {
      listMaxHeight = Get.height * 0.25;
    }

    return GestureDetector(
      onTap: () {},
      child: Column(
        children: [
          // Main controls container
          Container(
            padding: EdgeInsets.fromLTRB(20, 16, 20, _chatHasText ? 0 : 16),
            child: Column(
              children: [
                // Chat messages list (above input) - flexible height
                if (widget.chatMessages.isNotEmpty && !_chatHasText)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width:
                          Get.width * 0.75, // Restrict width to 75% of screen
                      margin: const EdgeInsets.only(bottom: 8),
                      constraints: BoxConstraints(
                        maxHeight: listMaxHeight, // Dynamic based on seat count
                        minHeight:
                            50, // Minimum height for at least one message
                      ),
                      child: ShaderMask(
                        shaderCallback: (Rect bounds) {
                          return const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black,
                            ],
                            stops: [
                              0.0,
                              0.20,
                            ],
                          ).createShader(bounds);
                        },
                        blendMode: BlendMode.dstIn,
                        child: ListView.builder(
                          controller:
                              _scrollController, // Add scroll controller
                          shrinkWrap: true, // Allow flexible height
                          reverse: false,
                          itemCount: widget.chatMessages.length,
                          itemBuilder: (context, index) {
                            final message = widget.chatMessages[index];
                            return _buildChatMessage(message);
                          },
                        ),
                      ),
                    ),
                  ),

                // Reply preview bar
                if (_replyingToMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 3,
                          height: 24,
                          color: const Color(0xFF00BCD4),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Replying to @${_replyingToMessage!.username}',
                                style: const TextStyle(
                                  color: Color(0xFF00BCD4),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _replyingToMessage!.message,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close,
                              size: 18, color: Colors.white70),
                          onPressed: () {
                            setState(() {
                              _replyingToMessage = null;
                            });
                          },
                        ),
                      ],
                    ),
                  ),

                // Bottom input area (with working chat) - Separated Modular Floating Controls
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: 16, vertical: _chatHasText ? 6 : 10),
                  color: Colors
                      .transparent, // Completely transparent container wrapper
                  child: Row(
                    children: [
                      // Mic button or Seat Join button for Live mode
                      if ((widget.isLive || widget.isSeated) &&
                          !_chatHasText &&
                          (widget.isLive ||
                              (!widget.isMutedByAdmin || widget.isHost))) ...[
                        GestureDetector(
                          onTap: () {
                            if (widget.isLive) {
                              if (widget.isHost || widget.isSeated) {
                                widget.onLiveMicTapped?.call();
                              } else {
                                widget.onJoinRequestTapped?.call();
                              }
                            } else {
                              widget.onMuteToggle();
                            }
                          },
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: BackdropFilter(
                                  filter:
                                      ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                  child: Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color:
                                          Colors.black.withValues(alpha: 0.3),
                                      border: Border.all(
                                        color: widget.isMuted
                                            ? Colors.white
                                                .withValues(alpha: 0.15)
                                            : const Color(0xFFD4AF37)
                                                .withValues(alpha: 0.6),
                                        width: 1.0,
                                      ),
                                    ),
                                    child: Icon(
                                      (widget.isLive &&
                                              !widget.isHost &&
                                              !widget.isSeated)
                                          ? (widget.hasRequestedToJoin
                                              ? Icons.hourglass_empty
                                              : Icons.chair_alt)
                                          : (widget.isMuted
                                              ? Icons.mic_off_rounded
                                              : Icons.mic_rounded),
                                      color: (widget.isLive &&
                                              !widget.isHost &&
                                              !widget.isSeated)
                                          ? (widget.hasRequestedToJoin
                                              ? Colors.orangeAccent
                                              : Colors.white70)
                                          : (widget.isMuted
                                              ? Colors.white70
                                              : const Color(0xFFD4AF37)),
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                              if (widget.isLive &&
                                  widget.isHost &&
                                  widget.joinRequestsCount > 0)
                                Positioned(
                                  top: -4,
                                  right: -4,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      widget.joinRequestsCount > 9
                                          ? '9+'
                                          : '${widget.joinRequestsCount}',
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
                        ),
                        const SizedBox(width: 8),
                      ],

                      // Message input capsule (Glassmorphism)
                      Expanded(
                        key: const ValueKey('chat_input_expanded'),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                            child: Container(
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  width: 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Text field
                                  Expanded(
                                    child: TextField(
                                      controller: _chatController,
                                      focusNode: _textFieldFocusNode,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontFamily: 'Inter',
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Say something...',
                                        hintStyle: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.5),
                                          fontSize: 13,
                                          fontFamily: 'Inter',
                                        ),
                                        filled: false,
                                        border: InputBorder.none,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 11,
                                        ),
                                      ),
                                      onSubmitted: (value) => _sendMessage(),
                                    ),
                                  ),

                                  // Send / Emoji button
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 250),
                                    transitionBuilder: (child, animation) {
                                      return ScaleTransition(
                                        scale: animation,
                                        child: FadeTransition(
                                          opacity: animation,
                                          child: child,
                                        ),
                                      );
                                    },
                                    child: _chatHasText
                                        ? GestureDetector(
                                            key: const ValueKey('send_button'),
                                            onTap: _sendMessage,
                                            child: Container(
                                              margin: const EdgeInsets.only(
                                                  right: 6),
                                              width: 32,
                                              height: 32,
                                              decoration: BoxDecoration(
                                                gradient: const LinearGradient(
                                                  colors: [
                                                    Color(
                                                        0xFF9C27B0), // Purple to match premium vibe
                                                    Color(0xFF673AB7),
                                                  ],
                                                ),
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color:
                                                        const Color(0xFF9C27B0)
                                                            .withValues(
                                                                alpha: 0.4),
                                                    blurRadius: 6,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: const Icon(
                                                Icons.send_rounded,
                                                color: Colors.white,
                                                size: 15,
                                              ),
                                            ),
                                          )
                                        : GestureDetector(
                                            key: const ValueKey('emoji_button'),
                                            onTap: _toggleEmojiPicker,
                                            child: Container(
                                              margin: const EdgeInsets.only(
                                                  right: 6),
                                              width: 32,
                                              height: 32,
                                              child: const Icon(
                                                Icons.emoji_emotions_outlined,
                                                color: Colors.white70,
                                                size: 22,
                                              ),
                                            ),
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Gift and Game buttons
                      if (!_chatHasText) ...[
                        const SizedBox(width: 8),

                        // Gift button
                        GestureDetector(
                          onTap: _showGiftSelection,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black.withValues(alpha: 0.3),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    width: 1.0,
                                  ),
                                ),
                                padding: const EdgeInsets.all(8),
                                child: Image.asset(
                                  'assets/images/gift_icon.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Premium Game Wall button
                        GestureDetector(
                          onTap: () => GameWallBottomSheet.show(context),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black.withValues(alpha: 0.3),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    width: 1.0,
                                  ),
                                ),
                                padding: const EdgeInsets.all(8),
                                child: Image.asset(
                                  'assets/images/game_icon.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ),
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

  /// Build individual chat message with premium glassmorphic bubble style
  Widget _buildChatMessage(EmojiChatMessage chatMessage) {
    final userColor = _getUserColor(chatMessage.userId);

    // Rule: Allow reply ONLY for real chat messages
    final bool isRealChat = chatMessage.messageType == EmojiMessageType.text;
    final bool isSystem = chatMessage.messageType == EmojiMessageType.join ||
        chatMessage.messageType == EmojiMessageType.leave;

    if (chatMessage.messageType == EmojiMessageType.voteResult ||
        (chatMessage.messageType == EmojiMessageType.text &&
            chatMessage.userId == 'system' &&
            chatMessage.message.startsWith('{') &&
            chatMessage.message.contains('"question"'))) {
      return GestureDetector(
        onTap: () {
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            builder: (context) =>
                VotingResultSheet(roomId: widget.roomId ?? ''),
          );
        },
        child: _buildVoteResultCard(chatMessage),
      );
    }

    if (chatMessage.messageType == EmojiMessageType.announcement) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8, top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF6C3483).withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: const Color(0xFF9B59B6).withValues(alpha: 0.5),
              width: 0.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.campaign, color: Color(0xFF3498DB), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: RichText(
                text: TextSpan(
                  children: [
                    const TextSpan(
                      text: 'Announcement: ',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        fontFamily: 'Inter',
                      ),
                    ),
                    TextSpan(
                      text: chatMessage.message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (chatMessage.messageType == EmojiMessageType.rouletteResult) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8, top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFE91E63).withValues(alpha: 0.2), // Pink tinted
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: const Color(0xFFF06292).withValues(alpha: 0.5),
              width: 1.0),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.casino, color: Colors.yellowAccent, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: RichText(
                text: TextSpan(
                  children: [
                    const TextSpan(
                      text: 'Roulette Result: ',
                      style: TextStyle(
                        color: Colors.yellowAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        fontFamily: 'Inter',
                      ),
                    ),
                    TextSpan(
                      text: chatMessage.message.replaceAll('Game Result: ', ''),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Sleek layout for compact Join/Leave notification events
    if (isSystem) {
      final isJoin = chatMessage.messageType == EmojiMessageType.join;
      return Container(
        margin: const EdgeInsets.only(bottom: 6, top: 4),
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isJoin ? Icons.login_rounded : Icons.logout_rounded,
                color: isJoin ? const Color(0xFFD4AF37) : Colors.white38,
                size: 12,
              ),
              const SizedBox(width: 6),
              Text(
                '${chatMessage.username} ${isJoin ? 'joined' : 'left'}',
                style: TextStyle(
                  color: isJoin ? const Color(0xFFFFD700) : Colors.white54,
                  fontSize: 11,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: isRealChat
          ? () {
              setState(() {
                _replyingToMessage = chatMessage;
              });
              _textFieldFocusNode.requestFocus();
              if (widget.onMessageTap != null) {
                widget.onMessageTap!(chatMessage);
              }
            }
          : null, // Disabled replies for emojis, gifts, and join/leave system logs
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Reply Preview indicator if replying to another message
            if (chatMessage.replyToMessageId != null &&
                chatMessage.replyToUsername != null)
              Container(
                margin: const EdgeInsets.only(left: 48, bottom: 4, top: 2),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(8),
                  border: const Border(
                    left: BorderSide(color: Color(0xFFD4AF37), width: 3),
                  ),
                ),
                child: Text(
                  'Replying to @${chatMessage.replyToUsername}: ${chatMessage.replyToText}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    fontFamily: 'Inter',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            // Premium Bubble & Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. User profile image (Tap to open profile, long press to mention)
                GestureDetector(
                  onTap: () {
                    if (widget.onMessageTap != null) {
                      widget.onMessageTap!(chatMessage);
                    } else {
                      _openUserProfile(
                        context: context,
                        userId: chatMessage.userId,
                        username: chatMessage.username,
                        avatar: chatMessage.userAvatar ?? '',
                      );
                    }
                  },
                  onLongPress: () => _handleTapToMention(chatMessage.username),
                  child: CachedCircleAvatar(
                    imageUrl: chatMessage.userAvatar ?? '',
                    radius: 17,
                    frameId: widget.participants
                        .firstWhereOrNull((p) => p.userId == chatMessage.userId)
                        ?.frameId,
                    userId: chatMessage.userId,
                    backgroundColor: userColor,
                    borderColor: const Color(0xFFD4AF37).withValues(alpha: 0.4),
                    borderWidth: 1.0,
                  ),
                ),
                const SizedBox(width: 10),

                // Message text / contents
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row: Username (White) + Blue Verified Badge
                      FutureBuilder<_ChatUserData>(
                        future: _fetchChatUserData(chatMessage.userId),
                        builder: (context, snapshot) {
                          final _ChatUserData? chatUserData = snapshot.data;
                          final User? user = chatUserData?.user;
                          final bool isVerified = user?.isVerified ?? false;
                          
                          // Use the senderLevelBadgeUrl from message, or fallback to the fetched one
                          final String? sendingUrl = chatMessage.senderLevelBadgeUrl?.isNotEmpty == true 
                              ? chatMessage.senderLevelBadgeUrl 
                              : chatUserData?.sendingUrl;
                          
                          final String? receivingUrl = chatUserData?.receivingUrl;
                          final String? nameplateUrl = chatUserData?.nameplateUrl;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      if (widget.onMessageTap != null) {
                                        widget.onMessageTap!(chatMessage);
                                      } else {
                                        _openUserProfile(
                                          context: context,
                                          userId: chatMessage.userId,
                                          username: chatMessage.username,
                                          avatar: chatMessage.userAvatar ?? '',
                                        );
                                      }
                                    },
                                    onLongPress: () => _handleTapToMention(
                                        chatMessage.username),
                                    child: Text(
                                      chatMessage.username,
                                      style: const TextStyle(
                                        color: Colors
                                            .white, // Strictly white usernames
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Inter',
                                      ),
                                    ),
                                  ),
                                  if (isVerified) ...[
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.verified,
                                      color: Color(
                                          0xFF1D9BF0), // Premium Blue Verified Checkmark
                                      size: 13,
                                    ),
                                  ],
                                ],
                              ),
                              // Sending/Receiving Level & Nameplate PNGs displayed below the username
                              if ((sendingUrl != null && sendingUrl.isNotEmpty) || 
                                  (receivingUrl != null && receivingUrl.isNotEmpty) ||
                                  (nameplateUrl != null && nameplateUrl.isNotEmpty)) ...[
                                const SizedBox(height: 3),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (sendingUrl != null && sendingUrl.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(right: 4),
                                        child: CachedNetworkImage(
                                          imageUrl: sendingUrl,
                                          height: 16, // User requested smaller PNG (16 instead of 22)
                                          fit: BoxFit.contain,
                                          errorWidget: (context, url, err) => const SizedBox.shrink(),
                                        ),
                                      ),
                                    if (receivingUrl != null && receivingUrl.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(right: 4),
                                        child: CachedNetworkImage(
                                          imageUrl: receivingUrl,
                                          height: 16, 
                                          fit: BoxFit.contain,
                                          errorWidget: (context, url, err) => const SizedBox.shrink(),
                                        ),
                                      ),
                                    if (nameplateUrl != null && nameplateUrl.isNotEmpty)
                                      CachedNetworkImage(
                                        imageUrl: nameplateUrl,
                                        height: 16,
                                        fit: BoxFit.contain,
                                        errorWidget: (context, url, err) => const SizedBox.shrink(),
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 5),

                      // Premium Glassmorphic Message Bubble
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(
                              alpha:
                                  0.07), // Soft lightweight transparent background
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(16),
                            bottomLeft: Radius.circular(16),
                            bottomRight: Radius.circular(16),
                          ),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.04),
                            width: 1.0,
                          ),
                        ),
                        child: _buildMessageContent(chatMessage, userColor),
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
  }

  /// Build message content based on message type
  Widget _buildMessageContent(EmojiChatMessage message, Color userColor) {
    switch (message.messageType) {
      case EmojiMessageType.emoji:
        return _buildEmojiMessage(message, userColor);
      case EmojiMessageType.text:
        return _buildTextMessage(message, userColor);
      case EmojiMessageType.mixed:
        return _buildMixedMessage(message, userColor);
      case EmojiMessageType.join:
      case EmojiMessageType.leave:
      case EmojiMessageType.announcement:
      case EmojiMessageType.rouletteResult:
        return const SizedBox
            .shrink(); // Handled separately as compact notifications
      case EmojiMessageType.gift:
        return _buildGiftMessage(message, userColor);
      case EmojiMessageType.vote:
        return _buildTextMessage(message, userColor);
      case EmojiMessageType.voteResult:
        return const SizedBox.shrink(); // Handled separately
    }
  }

  /// Build gift message content inside the bubble
  Widget _buildGiftMessage(EmojiChatMessage message, Color userColor) {
    String receiverName = '';
    String giftName = '';

    if (message.message.contains('|||')) {
      final parts = message.message.split('|||');
      giftName = parts[0];
      if (parts.length > 1) {
        receiverName = parts[1];
      }
    } else {
      // Legacy handling
      if (message.message.startsWith('Gifted to ')) {
        receiverName = message.message.substring(10);
      } else if (message.message.startsWith('Gifted ')) {
        giftName = message.message.substring(7);
      }
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text(
          'sends ',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontFamily: 'Inter',
          ),
        ),
        if (giftName.isNotEmpty)
          Text(
            '$giftName ',
            style: const TextStyle(
              color: Color(0xFFFF5252), // Red/Pinkish color for gift name
              fontSize: 13,
              fontFamily: 'Inter',
            ),
          ),
        if (message.giftImageUrl != null && message.giftImageUrl!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: CachedNetworkImage(
              imageUrl: message.giftImageUrl!,
              width: 20,
              height: 20,
            ),
          ),
        Text(
          ' x1(',
          style: const TextStyle(
            color: Color(0xFFFF5252),
            fontSize: 13,
            fontFamily: 'Inter',
          ),
        ),
        DynamicDiamondIcon(
          // The correct diamond PNG
          width: 14,
          height: 14,
          errorBuilder: (context, error, stackTrace) =>
              const Text('💎'), // Fallback
        ),
        Text(
          ' ${message.giftCredits ?? 0})',
          style: const TextStyle(
            color: Color(0xFFFF5252),
            fontSize: 13,
            fontFamily: 'Inter',
          ),
        ),
        if (receiverName.isNotEmpty && receiverName != 'null')
          Text(
            ' to $receiverName',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontFamily: 'Inter',
            ),
          ),
      ],
    );
  }

  /// Build emoji-only message inside the bubble
  Widget _buildEmojiMessage(EmojiChatMessage message, Color userColor) {
    if (message.emojiItem == null) {
      return _buildTextMessage(message, userColor);
    }

    if (message.emojiItem!.emojiUrl.startsWith('local_dice:')) {
      final number = int.parse(message.emojiItem!.emojiUrl.split(':')[1]);
      return StaticDiceWidget(number: number, size: 44.0);
    }

    return CachedNetworkImage(
      imageUrl: message.emojiItem!.emojiUrl,
      width: 44,
      height: 44,
      placeholder: (context, url) => const SizedBox(
        width: 44,
        height: 44,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
        ),
      ),
      errorWidget: (context, url, error) => const Icon(
        Icons.broken_image,
        color: Colors.white24,
      ),
    );
  }

  /// Build text message inside the bubble
  Widget _buildTextMessage(EmojiChatMessage message, Color userColor) {
    return Text(
      message.message,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 13.5,
        fontFamily: 'Inter',
        height: 1.3,
      ),
    );
  }

  /// Build mixed message (text + emoji) inside the bubble
  Widget _buildMixedMessage(EmojiChatMessage message, Color userColor) {
    if (message.emojiItem == null) {
      return _buildTextMessage(message, userColor);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message.message,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13.5,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 6),
        CachedNetworkImage(
          imageUrl: message.emojiItem!.emojiUrl,
          width: 40,
          height: 40,
        ),
      ],
    );
  }

  Widget _buildVoteResultCard(EmojiChatMessage message) {
    VotingState? state;
    try {
      if (message.message.startsWith('{')) {
        final Map<String, dynamic> data = jsonDecode(message.message);
        state = VotingState.fromJson(data);
      }
    } catch (_) {}

    if (state == null) {
      // Fallback
      return Container(
        margin: const EdgeInsets.only(bottom: 8, top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0F2046).withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.amber.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.poll, color: Colors.amber, size: 18),
            const SizedBox(width: 8),
            Text(
              message.message,
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    final safeState = state;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8, top: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.blueAccent.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.how_to_vote,
                  color: Colors.lightBlueAccent, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Vote Result',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...List.generate(safeState.options.length, (index) {
            final optionText = safeState.options[index];
            final voteCount = safeState.getVotesForOption(index);
            final percentage = safeState.getPercentageForOption(index);

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              height: 44,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Stack(
                children: [
                  FractionallySizedBox(
                    widthFactor: percentage > 0 ? percentage : 0.0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: Colors.black,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            optionText,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 15),
                          ),
                        ),
                        Text(
                          '$voteCount',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Additional control buttons for specific actions
class AdditionalControls extends StatelessWidget {
  final VoidCallback? onReaction;
  final VoidCallback? onShare;
  final VoidCallback? onSettings;

  const AdditionalControls({
    super.key,
    this.onReaction,
    this.onShare,
    this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Reaction button
          if (onReaction != null)
            _buildSmallButton(
              icon: Icons.favorite_border,
              onTap: onReaction!,
              tooltip: 'React',
            ),

          // Share button
          if (onShare != null)
            _buildSmallButton(
              icon: Icons.share,
              onTap: onShare!,
              tooltip: 'Share',
            ),

          // Settings button (host only)
          if (onSettings != null)
            _buildSmallButton(
              icon: Icons.settings,
              onTap: onSettings!,
              tooltip: 'Room settings',
            ),
        ],
      ),
    );
  }

  /// Build small control button
  Widget _buildSmallButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            color: Colors.white.withValues(alpha: 0.7),
            size: 18,
          ),
        ),
      ),
    );
  }
}

class _ChatUserData {
  final User user;
  final String? sendingUrl;
  final String? receivingUrl;
  final String? nameplateUrl;
  
  _ChatUserData(this.user, this.sendingUrl, this.receivingUrl, this.nameplateUrl);
}

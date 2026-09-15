import 'package:flutter/material.dart';
import 'package:chat_messenger/widgets/spinning_dice_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chat_messenger/models/emoji_models.dart';
import 'package:chat_messenger/helpers/app_helper.dart';
import 'dart:convert';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/voting/voting_models.dart';

/// Widget to display emoji chat messages
class EmojiChatMessageWidget extends StatelessWidget {
  final EmojiChatMessage message;
  final Color userColor;
  final bool isCurrentUser;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const EmojiChatMessageWidget({
    super.key,
    required this.message,
    required this.userColor,
    this.isCurrentUser = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User avatar
            if (!isCurrentUser) ...[
              CircleAvatar(
                radius: 16,
                backgroundColor: userColor.withValues(alpha: 0.2),
                backgroundImage: message.userAvatar != null
                    ? CachedNetworkImageProvider(message.userAvatar!)
                    : null,
                child: message.userAvatar == null
                    ? Text(
                        message.username.isNotEmpty
                            ? message.username[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: userColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
            ],

            // Message content
            Expanded(
              child: Column(
                crossAxisAlignment: isCurrentUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  // Username (only for other users)
                  if (!isCurrentUser) ...[
                    Text(
                      message.username.formattedUsername,
                      style: TextStyle(
                        color: userColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],

                  // Message bubble
                  Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.7,
                    ),
                    child: _buildMessageContent(),
                  ),
                ],
              ),
            ),

            // User avatar for current user
            if (isCurrentUser) ...[
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 16,
                backgroundColor: userColor.withValues(alpha: 0.2),
                backgroundImage: message.userAvatar != null
                    ? CachedNetworkImageProvider(message.userAvatar!)
                    : null,
                child: message.userAvatar == null
                    ? Text(
                        message.username.isNotEmpty
                            ? message.username[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: userColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      )
                    : null,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMessageContent() {
    // Safety check: if message was incorrectly saved as text but is a vote result
    if (message.messageType == EmojiMessageType.text &&
        message.userId == 'system' &&
        message.message.startsWith('{') &&
        message.message.contains('"question"')) {
      return _buildVoteResultMessage();
    }

    switch (message.messageType) {
      case EmojiMessageType.emoji:
        return _buildEmojiMessage();
      case EmojiMessageType.text:
        return _buildTextMessage();
      case EmojiMessageType.mixed:
        return _buildMixedMessage();
      case EmojiMessageType.join:
      case EmojiMessageType.leave:
        return _buildSystemMessage();
      case EmojiMessageType.gift:
        return _buildGiftMessage();
      case EmojiMessageType.announcement:
        return const SizedBox.shrink();
      case EmojiMessageType.vote:
        return _buildVoteMessage();
      case EmojiMessageType.voteResult:
        return _buildVoteResultMessage();
      case EmojiMessageType.rouletteResult:
        return const SizedBox.shrink(); // Rendered by RoomControls instead
    }
  }

  Widget _buildSystemMessage() {
    final isJoin = message.messageType == EmojiMessageType.join;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: (isJoin ? Colors.green : Colors.orange).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isJoin ? Colors.green : Colors.orange).withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Text(
        '${message.username.formattedUsername} ${isJoin ? 'joined' : 'left'} the room',
        style: TextStyle(
          color: (isJoin ? Colors.green : Colors.orange).withValues(alpha: 0.9),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// Build gift message widget
  Widget _buildGiftMessage() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF00BCD4).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF00BCD4).withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.card_giftcard,
            color: Color(0xFF00BCD4),
            size: 16,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Gifted!',
                  style: TextStyle(
                    color: const Color(0xFF00BCD4).withValues(alpha: 0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  message.message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          if (message.giftImageUrl != null &&
              message.giftImageUrl!.isNotEmpty) ...[
            const SizedBox(width: 8),
            CachedNetworkImage(
              imageUrl: message.giftImageUrl!,
              width: 32,
              height: 32,
              placeholder: (context, url) =>
                  const SizedBox(width: 32, height: 32),
              errorWidget: (context, url, error) => const SizedBox(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmojiMessage() {
    if (message.emojiItem == null) {
      return _buildTextMessage();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: userColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: userColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Emoji image
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: (message.emojiItem!.emojiUrl.startsWith('local_dice:') || message.emojiItem!.emojiUrl == 'local_dice_action')
                  ? StaticDiceWidget(
                      number: message.emojiItem!.emojiUrl.contains(':')
                          ? (int.tryParse(message.emojiItem!.emojiUrl.split(':')[1]) ?? 6)
                          : 6,
                      size: 48,
                      diceStyle: 'classic',
                    )
                  : (message.emojiItem!.emojiUrl.startsWith('local_blue_dice:') || message.emojiItem!.emojiUrl == 'local_blue_dice_action')
                      ? StaticDiceWidget(
                          number: message.emojiItem!.emojiUrl.contains(':')
                              ? (int.tryParse(message.emojiItem!.emojiUrl.split(':')[1]) ?? 6)
                              : 6,
                          size: 48,
                          diceStyle: 'blue',
                        )
                      : CachedNetworkImage(
                      imageUrl: message.emojiItem!.emojiUrl,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => Container(
                        color: Colors.grey.withValues(alpha: 0.3),
                        child: const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Color(0xFF00BCD4)),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey.withValues(alpha: 0.3),
                        child: Icon(
                          Icons.emoji_emotions,
                          color: Colors.grey.withValues(alpha: 0.7),
                          size: 24,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          // Emoji name
          Text(
            message.emojiItem!.displayName,
            style: TextStyle(
              color: userColor,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTextMessage() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: userColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: userColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        message.message,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.9),
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildMixedMessage() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: userColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: userColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Text part
          Text(
            message.message,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 13,
            ),
          ),
          // Emoji part
          if (message.emojiItem != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: (message.emojiItem!.emojiUrl.startsWith('local_dice:') || message.emojiItem!.emojiUrl == 'local_dice_action')
                        ? StaticDiceWidget(
                            number: message.emojiItem!.emojiUrl.contains(':')
                                ? (int.tryParse(message.emojiItem!.emojiUrl.split(':')[1]) ?? 6)
                                : 6,
                            size: 32,
                            diceStyle: 'classic',
                          )
                        : (message.emojiItem!.emojiUrl.startsWith('local_blue_dice:') || message.emojiItem!.emojiUrl == 'local_blue_dice_action')
                            ? StaticDiceWidget(
                                number: message.emojiItem!.emojiUrl.contains(':')
                                    ? (int.tryParse(message.emojiItem!.emojiUrl.split(':')[1]) ?? 6)
                                    : 6,
                                size: 32,
                                diceStyle: 'blue',
                              )
                            : CachedNetworkImage(
                            imageUrl: message.emojiItem!.emojiUrl,
                            fit: BoxFit.contain,
                            placeholder: (context, url) => Container(
                              color: Colors.grey.withValues(alpha: 0.3),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 1,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFF00BCD4)),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey.withValues(alpha: 0.3),
                              child: Icon(
                                Icons.emoji_emotions,
                                color: Colors.grey.withValues(alpha: 0.7),
                                size: 16,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  message.emojiItem!.displayName,
                  style: TextStyle(
                    color: userColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVoteMessage() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2A52).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.blueAccent.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        message.message,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildVoteResultMessage() {
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
            const SizedBox(width: 4),
            const Icon(Icons.arrow_forward_ios, color: Colors.amber, size: 12),
          ],
        ),
      );
    }

    final safeState = state;

    return Container(
      width: 280,
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
              const Icon(Icons.how_to_vote, color: Colors.lightBlueAccent, size: 20),
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
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            optionText,
                            style: const TextStyle(color: Colors.white, fontSize: 15),
                          ),
                        ),
                        Text(
                          '$voteCount',
                          style: const TextStyle(color: Colors.white, fontSize: 15),
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

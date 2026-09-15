import 'dart:async';
import 'dart:io';

import 'package:chat_messenger/components/cached_circle_avatar.dart';
import 'package:chat_messenger/components/svg_icon.dart';
import 'package:chat_messenger/config/theme_config.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/helpers/dialog_helper.dart';
import 'package:chat_messenger/models/group.dart';
import 'package:chat_messenger/models/location.dart';
import 'package:chat_messenger/models/message.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:chat_messenger/screens/messages/components/emoji_media.dart';
import 'package:chat_messenger/screens/messages/components/reply_message.dart';
import 'package:chat_messenger/screens/messages/controllers/message_controller.dart';
import 'package:chat_messenger/media/helpers/media_helper.dart';
import 'package:flutter/material.dart';
import 'package:chat_messenger/theme/app_theme.dart';
import 'package:get/get.dart';
import '../controllers/block_controller.dart';
import 'attachment/attachment_menu.dart';

class ChatInputField extends StatefulWidget {
  final MessageController controller;
  const ChatInputField({
    super.key,
    required this.controller,
    this.user,
    this.group,
  });

  final User? user;
  final Group? group;

  @override
  ChatInputFieldState createState() => ChatInputFieldState();
}

class ChatInputFieldState extends State<ChatInputField> {
  // Get Controllers
  MessageController get controller => widget.controller;
  late final BlockController blockCrl = Get.find(tag: widget.group?.groupId ?? widget.user?.userId ?? '');

  // Mentions State
  bool _showMentions = false;
  String _mentionQuery = '';
  int _mentionStartIndex = -1;
  List<User> _filteredMentionMembers = [];

  void _checkMentionQuery(String text) {
    if (widget.group == null) return;

    final selection = controller.textController.selection;
    final cursorPosition = selection.baseOffset;

    if (cursorPosition > 0 && cursorPosition <= text.length) {
      final textUntilCursor = text.substring(0, cursorPosition);
      final lastAtIndex = textUntilCursor.lastIndexOf('@');

      if (lastAtIndex != -1) {
        final charBefore = lastAtIndex > 0 ? textUntilCursor[lastAtIndex - 1] : ' ';
        if (charBefore == ' ' || charBefore == '\n') {
          final query = textUntilCursor.substring(lastAtIndex + 1);
          if (!query.contains('\n')) {
            _mentionStartIndex = lastAtIndex;
            _mentionQuery = query.toLowerCase();
            _filterMentionMembers();
            if (!_showMentions) {
              setState(() {
                _showMentions = true;
              });
            }
            return;
          }
        }
      }
    }

    if (_showMentions) {
      setState(() {
        _showMentions = false;
      });
    }
  }

  void _filterMentionMembers() {
    if (widget.group == null) return;
    final currentUserId = AuthController.instance.currentUser.userId;
    final allMembers = widget.group!.participants.where((m) => m.userId != currentUserId).toList();

    if (_mentionQuery.isEmpty) {
      _filteredMentionMembers = allMembers;
    } else {
      _filteredMentionMembers = allMembers.where((m) {
        final nameMatch = m.fullname.toLowerCase().contains(_mentionQuery);
        final idMatch = m.searchId.toLowerCase().contains(_mentionQuery);
        return nameMatch || idMatch;
      }).toList();
    }
    setState(() {});
  }

  void _onSelectMentionMember(User member) {
    final text = controller.textController.text;
    if (_mentionStartIndex == -1 || _mentionStartIndex > text.length) return;

    final textBefore = text.substring(0, _mentionStartIndex);
    final selection = controller.textController.selection;
    final cursorPosition = selection.baseOffset;
    final textAfter = (cursorPosition <= text.length && cursorPosition >= _mentionStartIndex)
        ? text.substring(cursorPosition)
        : text.substring(_mentionStartIndex);

    final String mentionText = "@${member.fullname} ";
    final newText = "$textBefore$mentionText$textAfter";

    controller.textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: (textBefore + mentionText).length,
      ),
    );

    setState(() {
      _showMentions = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = AppTheme.of(context).isDarkMode;

    final bool isIOS = Platform.isIOS;
    final String currentUserId = AuthController.instance.currentUser.userId;

    // Check if official channel or team and return immediately without wrapping in Obx to prevent GetX improper usage exception
    if (widget.user != null && (widget.user!.userId == 'official_team' || widget.user!.userId.startsWith('official_channel_'))) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[900] : Colors.grey[100],
          border: Border(
            top: BorderSide(color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.campaign, color: primaryColor, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'This is a one-way broadcast channel. You cannot reply.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Obx(
      () {
        String senderName = '';
        if (widget.group != null) {
          final Message? message = controller.replyMessage.value;
          if (message != null) {
            final member = widget.group!.getMemberProfile(message.senderId);
            senderName = member.fullname;
          }
        } else {
          senderName = widget.user!.fullname;
        }

        final bool isGroup = widget.group != null;
        final TextStyle style =
            Theme.of(context).textTheme.bodyLarge!.copyWith(color: errorColor);
        final Radius replyBorderRadius = controller.isReplying
            ? const Radius.circular(16)
            : const Radius.circular(30);

        final bool isUserBlocked = blockCrl.isUserBlocked.value;
        final bool isCurrentUserBlocked = blockCrl.isCurrentUserBlocked.value;

        // Check 1-to-1 blocked status
        if (!isGroup && isUserBlocked || isCurrentUserBlocked) {
          return _blockedMessage(
              isUserBlocked: isUserBlocked,
              isCurrentUserBlocked: isCurrentUserBlocked);
        }

        // Check removed member status
        if (isGroup && widget.group!.isRemoved(currentUserId)) {
          return Container(
            padding: const EdgeInsets.all(defaultPadding / 2),
            child: Text('not_participant_message'.tr,
                textAlign: TextAlign.center, style: style),
          );
        }

        // Check Admin messages
        if (isGroup && !widget.group!.sendMessages) {
          return Container(
            padding: const EdgeInsets.all(defaultPadding / 2),
            child: Text('only_admins_can_send_messages'.tr,
                textAlign: TextAlign.center, style: style),
          );
        }

        return PopScope(
          canPop: !controller.showEmoji.value,
          onPopInvokedWithResult: (bool didPop, Object? result) {
            if (didPop) return;
            
            // Check emoji picker
            if (controller.showEmoji.value) {
              controller.showEmoji.value = false;
            }
          },
          child: SafeArea(
            bottom: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // <-- Mentions Autocomplete list -->
                if (isGroup && _showMentions && _filteredMentionMembers.isNotEmpty)
                  Container(
                    constraints: const BoxConstraints(maxHeight: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey[900] : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 8,
                          offset: const Offset(0, -2),
                        ),
                      ],
                      border: Border.all(
                        color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
                      ),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: _filteredMentionMembers.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final member = _filteredMentionMembers[index];
                        return ListTile(
                          dense: true,
                          leading: CachedCircleAvatar(
                            radius: 16,
                            imageUrl: member.photoUrl,
                          ),
                          title: Text(
                            member.fullname,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          subtitle: Text(
                            member.searchId.isNotEmpty ? '@${member.searchId}' : 'ID: ${member.userId}',
                            style: const TextStyle(fontSize: 11, color: greyColor),
                          ),
                          onTap: () => _onSelectMentionMember(member),
                        );
                      },
                    ),
                  ),

                // <--- Chat Input --->
                Padding(
                  padding: EdgeInsets.only(
                      left: 8, top: 8, right: 8, bottom: isIOS ? 8 : 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                    Expanded(
                      child: Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: isDarkMode ? null : greyLight,
                          borderRadius: BorderRadius.only(
                            topLeft: replyBorderRadius,
                            topRight: replyBorderRadius,
                            bottomLeft: const Radius.circular(30),
                            bottomRight: const Radius.circular(30),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            //
                            // <-- Show reply message box -->
                            //
                            if (controller.replyMessage.value != null)
                              ReplyMessage(
                                cancelReply: () => controller.cancelReply(),
                                message: controller.replyMessage.value!,
                                senderName: senderName,
                              ),
                            //
                            // <-- Text input -->
                            //
                            TextFormField(
                              focusNode: controller.chatFocusNode,
                              controller: controller.textController,
                              minLines: 1,
                              maxLines: 4,
                              onTap: () => controller.showEmoji.value = false,
                              onChanged: (String text) {
                                // Update Text Msg
                                controller.isTextMsg.value =
                                    text.trim().isNotEmpty;
                                _checkMentionQuery(text);
                              },
                              decoration: InputDecoration(
                                hintText: 'message'.tr,
                                hintMaxLines: 1,
                                filled: true,
                                fillColor: isDarkMode ? null : greyLight,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                border: const OutlineInputBorder(
                                  borderSide: BorderSide(
                                    style: BorderStyle.none,
                                    width: 0,
                                  ),
                                ),
                                // <--- Emoji Picker button --->
                                prefixIcon: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: GestureDetector(
                                    onTap: () => controller.handleEmojiPicker(),
                                    child: SvgIcon(
                                      controller.showEmoji.value
                                          ? 'assets/icons/keyboard.svg'
                                          : 'assets/icons/emoji_very_happy.svg',
                                      color: isDarkMode
                                          ? Colors.white
                                          : Colors.black87,
                                      width: 26,
                                      height: 26,
                                    ),
                                  ),
                                ),

                                suffixIcon: Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // <--- Gallery Icon --->
                                      GestureDetector(
                                        onTap: () async {
                                          controller.scrollToBottom();
                                          controller.chatFocusNode.unfocus();
                                          controller.showEmoji.value = false;
                                          final List<File>? files = await MediaHelper.pickMultipleMediaFromGallery();
                                          if (files != null && files.isNotEmpty) {
                                            List<Future> futures = [];
                                            for (File file in files) {
                                              final String path = file.path;
                                              if (MediaHelper.isImage(path)) {
                                                futures.add(controller.sendMessage(MessageType.image, file: file));
                                              } else if (MediaHelper.isVideo(path)) {
                                                futures.add(controller.sendMessage(MessageType.video, file: file));
                                              } else {
                                                futures.add(controller.sendMessage(MessageType.doc, file: file));
                                              }
                                            }
                                            await Future.wait(futures);
                                          }
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                          child: Icon(
                                            Icons.image_outlined,
                                            size: 26,
                                            color: isDarkMode ? Colors.white : Colors.black87,
                                          ),
                                        ),
                                      ),
                                      // <--- Plus Icon (Attachment Menu) --->
                                      GestureDetector(
                                        onTap: () {
                                          _showAttachmentMenu();
                                          controller.scrollToBottom();
                                          controller.chatFocusNode.unfocus();
                                          controller.showEmoji.value = false;
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                          child: Icon(
                                            Icons.add_circle_outline,
                                            size: 26,
                                            color: isDarkMode ? Colors.white : Colors.black87,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),

                    ///
                    /// <--- Send message button --->
                    ///
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () async {
                        // Check action
                        if (controller.isTextMsg.value) {
                          // <-- Send Text Message -->

                          // Get text input
                          final String text = controller.textController.text;
                          // Check text msg
                          if (text.trim().isEmpty) return;

                          // Send text message
                          controller.sendMessage(MessageType.text, text: text);
                        } else {
                          //
                          // <-- Send Audio Message -->
                          //
                          final File? audio =
                              await DialogHelper.showAudioRecorderModal(
                            widget.user?.userId,
                          );

                          // Send Audio Message
                          if (audio != null) {
                            controller.sendMessage(
                              MessageType.audio,
                              file: audio,
                              isRecAudio: true,
                            );
                          }
                        }
                      },
                      icon: Container(
                        width: 54,
                        height: 54,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: SvgIcon(
                          controller.isTextMsg.value
                              ? 'assets/icons/send.svg'
                              : 'assets/icons/mic.svg',
                          color: Colors.white,
                          width: 26,
                          height: 26,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // <--- Show Emoji Picker --->
              Offstage(
                offstage: !controller.showEmoji.value,
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.35,
                  child: EmojiMedia(
                    textController: controller.textController,
                    onSelected: (category, emoji) {
                      // Update text msg
                      controller.isTextMsg.value = true;
                    },
                  ),
                ),
              ),
              ], // End children
            ), // End Column
          ), // End SafeArea
        ); // End PopScope
      },
    );
  }

  // Handle Attachment Menu
  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => AttachmentMenu(
        controller: controller,
        sendDocs: (List<File>? files) async {
          if (files == null) return;
          // Hold futures
          List<Future> futures = [];

          // Handle docs...
          for (File file in files) {
            // Get file path
            final String path = file.path;

            // Check comomn file types
            if (MediaHelper.isImage(path)) {
              // Send image file
              futures.add(
                controller.sendMessage(MessageType.image, file: file),
              );
              //
            } else if (MediaHelper.isAudio(path)) {
              // Send audio file
              futures.add(
                controller.sendMessage(MessageType.audio, file: file),
              );
            } else if (MediaHelper.isVideo(path)) {
              // Send video file
              futures.add(
                controller.sendMessage(MessageType.video, file: file),
              );
              //
            } else {
              // Send this file as document
              futures.add(controller.sendMessage(MessageType.doc, file: file));
            }
          }

          // Send all the files once
          await Future.wait(futures);
        },
        sendImage: (File? file) {
          if (file == null) return;
          // Send image message
          controller.sendMessage(MessageType.image, file: file);
        },
        sendVideo: (File? file) {
          // Send video message
          controller.sendMessage(MessageType.video, file: file);
        },
        sendLocation: (Location? location) {
          // Send location message
          controller.sendMessage(MessageType.location, location: location);
        },
      ),
    );
  }


  Widget _blockedMessage({
    required bool isUserBlocked,
    required bool isCurrentUserBlocked,
  }) {
    String message = '';

    if (isUserBlocked) {
      message = 'you_have_blocked_use_tap_the_top_corner_options_to_unblock';
    } else if (isCurrentUserBlocked) {
      message = 'user_has_blocked_you_it_s_not_possible_to_send_messages';
    }

    return Container(
      padding: const EdgeInsets.all(defaultPadding / 2),
      child: Text(
        message.trParams({'firstName': widget.user?.fullname ?? ''}),
        textAlign: TextAlign.center,
        style:
            Theme.of(context).textTheme.bodyLarge!.copyWith(color: errorColor),
      ),
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/api/official_team_api.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/helpers/app_helper.dart';
import 'package:chat_messenger/media/helpers/media_helper.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:chat_messenger/screens/messages/controllers/message_controller.dart';

class OfficialTeamBroadcastInputBar extends StatefulWidget {
  final MessageController controller;
  final Map<String, dynamic> permissionData;

  const OfficialTeamBroadcastInputBar({
    super.key,
    required this.controller,
    required this.permissionData,
  });

  @override
  State<OfficialTeamBroadcastInputBar> createState() =>
      _OfficialTeamBroadcastInputBarState();
}

class _OfficialTeamBroadcastInputBarState
    extends State<OfficialTeamBroadcastInputBar> {
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _customRecipientController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  String _selectedTarget = 'all';
  File? _selectedImage;
  String? _linkUrl;
  bool _isBroadcasting = false;

  @override
  void initState() {
    super.initState();
    final allowed = _getAllowedTargetGroups();
    if (!allowed.contains('all') && allowed.isNotEmpty) {
      _selectedTarget = allowed.first;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _customRecipientController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<String> _getAllowedTargetGroups() {
    final canSendToAll = widget.permissionData['canSendToAll'] == true;
    final dynamic rawList = widget.permissionData['allowedTargetGroups'];
    List<String> list = [];
    if (rawList is List) {
      list = List<String>.from(rawList);
    }
    if (canSendToAll && !list.contains('all')) {
      list.insert(0, 'all');
    }
    if (list.isEmpty) {
      list = ['all'];
    }
    return list;
  }

  String _getTargetLabel(String target) {
    switch (target) {
      case 'all':
        return '🌐 All Users';
      case 'host':
        return '🎤 Only Hosts';
      case 'agency':
        return '🏢 Only Agencies';
      case 'seller':
        return '🛒 Only Sellers';
      case 'new_user':
        return '🌟 New Users';
      case 'custom':
        return '🎯 Custom Selection';
      default:
        return target;
    }
  }

  Future<void> _pickImage() async {
    try {
      final file = await MediaHelper.pickMediaFromGallery();
      if (file != null) {
        setState(() {
          _selectedImage = file;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  void _showSnackbar(String title, String message, {bool isError = false, Color? bgColor}) {
    if (!mounted) return;
    try {
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger != null) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  isError ? Icons.error_outline : Icons.check_circle_outline,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        message,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: bgColor ?? (isError ? Colors.redAccent.shade700 : Colors.green.shade700),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(12),
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }
    } catch (_) {}

    // Fallback safely only if overlay is present
    try {
      if (Get.overlayContext != null) {
        Get.rawSnackbar(
          title: title,
          message: message,
          backgroundColor: isError ? Colors.redAccent.shade700 : Colors.green.shade700,
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 3),
        );
      }
    } catch (_) {}
  }

  Future<void> _sendBroadcast() async {
    final text = _textController.text.trim();
    if (text.isEmpty && _selectedImage == null) {
      _showSnackbar(
        'Empty Message',
        'Please enter a message or pick an image to broadcast.',
        isError: true,
      );
      return;
    }

    // Custom Target Audience Validation
    List<String>? customRecipients;
    if (_selectedTarget == 'custom') {
      final rawInput = _customRecipientController.text.trim();
      final ids = rawInput
          .split(RegExp(r'[,;\s]+'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      if (ids.isEmpty) {
        _showSnackbar(
          'Target Required',
          'Please enter a target User ID or Search ID to send custom notification.',
          isError: true,
        );
        return;
      }
      customRecipients = ids;
    }

    setState(() => _isBroadcasting = true);

    try {
      final User currentUser = AuthController.instance.currentUser;
      String? uploadedImageUrl;

      if (_selectedImage != null) {
        uploadedImageUrl = await AppHelper.uploadFile(
          file: _selectedImage!,
          userId: currentUser.userId,
        );
      }

      final count = await OfficialTeamApi.broadcastByPermittedUser(
        senderUserId: currentUser.userId,
        senderName: currentUser.fullname,
        messageText: text,
        targetGroup: _selectedTarget,
        customRecipients: customRecipients,
        imageUrl: uploadedImageUrl,
        linkUrl: _linkUrl,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw 'Broadcast timed out. Please check your network connection.',
      );

      if (_selectedTarget == 'custom' && count == 0) {
        _showSnackbar(
          'User Not Found',
          'No user found with the provided ID. Please check the User ID / Search ID and try again.',
          isError: true,
          bgColor: Colors.orangeAccent.shade700,
        );
        return;
      }

      _textController.clear();
      setState(() {
        _selectedImage = null;
        _linkUrl = null;
      });

      widget.controller.scrollToBottom();

      _showSnackbar(
        '📢 Broadcast Dispatched',
        'Successfully broadcasted to $count users in real-time!',
      );
    } catch (e) {
      debugPrint('Failed to broadcast: $e');
      _showSnackbar(
        'Broadcast Failed',
        'Error: $e',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isBroadcasting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final allowedGroups = _getAllowedTargetGroups();
    final bool canUploadImages = widget.permissionData['canUploadImages'] != false;

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E24) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            offset: const Offset(0, -2),
            blurRadius: 8,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Control Bar: Title & Target Audience Selector
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.campaign, color: Colors.amber, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'imChat Team Broadcaster',
                        style: TextStyle(
                          color: Colors.amber,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Target Audience Menu
                PopupMenuButton<String>(
                  initialValue: _selectedTarget,
                  tooltip: 'Change Target Audience',
                  onSelected: (val) => setState(() => _selectedTarget = val),
                  itemBuilder: (ctx) {
                    return allowedGroups.map((group) {
                      return PopupMenuItem<String>(
                        value: group,
                        child: Text(
                          _getTargetLabel(group),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: _selectedTarget == group
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: _selectedTarget == group
                                ? Colors.blueAccent
                                : null,
                          ),
                        ),
                      );
                    }).toList();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.people_alt, size: 13, color: Colors.blueAccent),
                        const SizedBox(width: 4),
                        Text(
                          _getTargetLabel(_selectedTarget).split('(')[0].trim(),
                          style: const TextStyle(
                            color: Colors.blueAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down, size: 16, color: Colors.blueAccent),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Custom Recipient Input Bar (for specific user broadcast)
            if (_selectedTarget == 'custom') ...[
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF282438) : const Color(0xFFF1EEF8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.purpleAccent.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person_pin_rounded, size: 16, color: Colors.purpleAccent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _customRecipientController,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter Target User ID or Search ID (e.g. 10908908)',
                          hintStyle: TextStyle(
                            fontSize: 12,
                            color: isDarkMode ? Colors.white38 : Colors.black38,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 6),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    if (_customRecipientController.text.isNotEmpty)
                      GestureDetector(
                        onTap: () => setState(() => _customRecipientController.clear()),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(Icons.cancel, size: 16, color: Colors.grey),
                        ),
                      ),
                  ],
                ),
              ),
            ],

            // Image Preview Thumbnail (if selected)
            if (_selectedImage != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                alignment: Alignment.centerLeft,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        _selectedImage!,
                        width: 70,
                        height: 70,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: InkWell(
                        onTap: () => setState(() => _selectedImage = null),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black87,
                          ),
                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Input Row: Attachment Buttons, Text Field & Send Button
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Image Picker Button
                if (canUploadImages)
                  IconButton(
                    icon: Icon(
                      Icons.photo_library_outlined,
                      color: _selectedImage != null
                          ? Colors.blueAccent
                          : (isDarkMode ? Colors.white60 : Colors.black54),
                    ),
                    tooltip: 'Attach Image',
                    onPressed: _isBroadcasting ? null : _pickImage,
                  ),

                // Text Field
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isDarkMode ? const Color(0xFF2C2C34) : const Color(0xFFF1F1F4),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      minLines: 1,
                      maxLines: 4,
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black87,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Broadcast to imChat Team...',
                        hintStyle: TextStyle(
                          color: isDarkMode ? Colors.white38 : Colors.black38,
                          fontSize: 13.5,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Send Button
                Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blueAccent,
                  ),
                  child: IconButton(
                    icon: _isBroadcasting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    onPressed: _isBroadcasting ? null : _sendBroadcast,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:chat_messenger/helpers/app_helper.dart';
import 'package:chat_messenger/helpers/dialog_helper.dart';
import 'package:chat_messenger/media/helpers/media_helper.dart';
import 'package:flutter/material.dart';
import 'package:chat_messenger/models/location.dart';
import 'package:chat_messenger/screens/messages/controllers/message_controller.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/audio_rooms_v2_integration.dart';
import 'package:get/get.dart';
import 'widgets/attachment_button.dart';
import 'widgets/preview_attachment.dart';

class AttachmentMenu extends StatefulWidget {
  final MessageController controller;
  const AttachmentMenu({
    super.key,
    required this.controller,
    required this.sendDocs,
    required this.sendImage,
    required this.sendVideo,
    required this.sendLocation,
  });

  final Function(List<File>?) sendDocs;
  final Function(File?) sendImage, sendVideo;
  final Function(Location?) sendLocation;

  @override
  State<AttachmentMenu> createState() => _AttachmentMenuState();
}

class _AttachmentMenuState extends State<AttachmentMenu> {
  // Variables
  MessageController get messageController => widget.controller;
  final ScrollController _scrollController = ScrollController();

  // Handle the list scroll
  void _autoScrollList() {
    // Check before scrolling
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 100,
        curve: Curves.easeOut,
        duration: const Duration(milliseconds: 500),
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BottomSheet(
      onClosing: () {},
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(10),
        ),
      ),
      builder: (context) {
        return Obx(
          () => Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              _buidHeader(context),

              const Divider(height: 0),

              // <--- Show the List of Attachments --->
              if (messageController.documents.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  height: 120,
                  width: double.maxFinite,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.grey[350],
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    scrollDirection: Axis.horizontal,
                    itemCount: messageController.documents.length,
                    itemBuilder: (context, index) {
                      // Get file
                      final File file = messageController.documents[index];

                      // Show attachment
                      return PreviewAttachment(
                        file: file,
                        onDelete: () {
                          // Update UI
                          messageController.documents.removeAt(index);
                        },
                      );
                    },
                  ),
                ),
              if (messageController.documents.isNotEmpty)
                const Divider(height: 0),

              // Attachment options
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // <--- Attach File --->
                            AttachmentButton(
                              icon: IconlyBold.document,
                              title: 'Document',
                              color: Colors.indigo,
                              onPress: () async {
                                // Pick docs/files
                                final List<File>? files =
                                    await MediaHelper.pickDocFiles(
                                  isMultiple: true,
                                );

                                // Check files
                                if (files != null) {
                                  // Add docs to the list
                                  messageController.documents.addAll(files);
                                  // Update the list
                                  _autoScrollList();
                                }
                              },
                            ),

                            // <--- Camera --->
                            AttachmentButton(
                              icon: IconlyBold.camera,
                              title: 'Camera',
                              color: Colors.pink,
                              onPress: () async {
                                Get.back();
                                final File? file = await MediaHelper.openCameraScreen(context);
                                if (file != null) {
                                  widget.sendImage(file);
                                }
                              },
                            ),

                            // <--- Gallery (Image/Video) --->
                            AttachmentButton(
                              icon: Icons.photo,
                              title: 'Gallery',
                              color: Colors.purpleAccent,
                              onPress: () async {
                                Get.back();
                                final List<File>? files = await MediaHelper.pickMultipleMediaFromGallery();
                                if (files != null && files.isNotEmpty) {
                                  widget.sendDocs(files);
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // <--- Send Audio --->
                            AttachmentButton(
                              icon: IconlyBold.voice,
                              title: 'Audio',
                              color: Colors.orange,
                              onPress: () async {
                                Get.back();
                                final List<File>? files = await MediaHelper.pickDocFiles(
                                  isMultiple: true,
                                  type: FileType.audio,
                                );
                                if (files != null && files.isNotEmpty) {
                                  widget.sendDocs(files);
                                }
                              },
                            ),

                            // <--- Share Location --->
                            AttachmentButton(
                              icon: IconlyBold.location,
                              title: 'Location',
                              color: Colors.green,
                              onPress: () async {
                                // Close this modal
                                Get.back();

                                final Location? position =
                                    await AppHelper.getUserCurrentLocation();

                                if (position == null) return;

                                // Send location
                                widget.sendLocation(position);
                              },
                            ),

                            // <--- Share Contact --->
                            AttachmentButton(
                              icon: IconlyBold.profile,
                              title: 'Contact',
                              color: Colors.blue,
                              onPress: () {
                                Get.back();
                                DialogHelper.showSnackbarMessage(SnackMsgType.info, "Contact sharing coming soon.");
                              },
                            ),
                          ],
                        ),
                        if (messageController.selectedGroup != null) ...[
                          const SizedBox(height: 15),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // <--- Group Audio Room --->
                              AttachmentButton(
                                icon: Icons.event_seat,
                                title: 'AudioRoom',
                                color: Colors.deepPurple,
                                onPress: () {
                                  Get.back();
                                  AudioRoomsV2Integration.openGroupAudioRoom(
                                    messageController.selectedGroup!,
                                  );
                                },
                              ),
                              // Invisible placeholders for 3-column alignment
                              const Opacity(
                                opacity: 0,
                                child: IgnorePointer(
                                  child: AttachmentButton(
                                    icon: Icons.event_seat,
                                    title: 'AudioRoom',
                                  ),
                                ),
                              ),
                              const Opacity(
                                opacity: 0,
                                child: IgnorePointer(
                                  child: AttachmentButton(
                                    icon: Icons.event_seat,
                                    title: 'AudioRoom',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  // Build modal header
  Widget _buidHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          // Check document files
          child: messageController.documents.isNotEmpty
              ? TextButton.icon(
                  onPressed: () {
                    // Close this modal
                    Get.back();

                    // Pass documents to callback
                    widget.sendDocs(messageController.documents);

                    // Clear the documents list
                    messageController.documents.clear();
                  },
                  icon: const Icon(Icons.upload),
                  label: Text(
                    'Upload  (${messageController.documents.length})',
                    style: const TextStyle(
                      fontSize: 18,
                    ),
                  ),
                )
              : const Text(
                  'Choose attachment',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
        ),
        // Close button
        IconButton(
          onPressed: () => Get.back(),
          icon: const Icon(Icons.close, color: Colors.grey),
        )
      ],
    );
  }
}

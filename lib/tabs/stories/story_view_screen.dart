import 'package:chat_messenger/components/app_loading.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:chat_messenger/api/report_api.dart';
import 'package:chat_messenger/components/cached_circle_avatar.dart';
import 'package:chat_messenger/components/circle_button.dart';
import 'package:chat_messenger/config/theme_config.dart';
import 'package:chat_messenger/controllers/report_controller.dart';
import 'package:chat_messenger/helpers/date_helper.dart';
import 'package:chat_messenger/helpers/dialog_helper.dart';
import 'package:chat_messenger/helpers/routes_helper.dart';
import 'package:chat_messenger/models/story/story.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:chat_messenger/tabs/stories/controller/story_view_controller.dart';
import 'package:get/get.dart';
import 'package:story_view/story_view.dart';

class StoryViewScreen extends StatelessWidget {
  StoryViewScreen({super.key, required this.story});

  final Story story;

  Future<void> updateSeenBy(
      {required String documentId,
      required String userId,
      required String fullname,
      required String photoUrl,
      required String imoji,
      required String comment,
      required int storyIndex}) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final DocumentReference docRef =
        firestore.collection('Stories').doc(documentId);

    try {
      // Run a Firestore transaction to ensure consistency
      await firestore.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(docRef);
        if (!snapshot.exists) {
          throw Exception('Document does not exist!');
        }
        // Fetch the document data
        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
        List<dynamic> images = data['images'];
        List<dynamic> seenBy = images[storyIndex]['seenBy'] ?? [];

        // Check if the current user already exists in the seenBy array
        final existingUserIndex =
            seenBy.indexWhere((element) => element['userId'] == userId);
        if (existingUserIndex >= 0) {
          Map<String, dynamic> currentUserData = seenBy[existingUserIndex];
          // Update the user's existing record
          seenBy[existingUserIndex] = {
            'fullname': fullname,
            'photoUrl': photoUrl,
            'time': DateTime.now().millisecondsSinceEpoch,
            'userId': userId,
            'imoji': currentUserData['imoji'] ?? '',
            'comment': comment
          };
        } else {
          // Add a new entry for the user if it doesn't exist
          seenBy.add({
            'fullname': fullname,
            'photoUrl': photoUrl,
            'time': DateTime.now().millisecondsSinceEpoch,
            'userId': userId,
            'imoji': '',
            'comment': comment,
          });
        }
        images[storyIndex]['seenBy'] = seenBy;

        transaction.update(docRef, {'images': images});
      });
    } catch (e) {
      debugPrint('Failed to update seenBy: $e');
    }
  }

  Future<void> updateSeenByForImoji(
      {required String documentId,
      required String userId,
      required String fullname,
      required String photoUrl,
      required String imoji,
      required int storyIndex}) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final DocumentReference docRef =
        firestore.collection('Stories').doc(documentId);

    try {
      // Run a Firestore transaction to ensure consistency
      await firestore.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(docRef);
        if (!snapshot.exists) {
          throw Exception('Document does not exist!');
        }
        // Fetch the document data
        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
        List<dynamic> images = data['images'];
        List<dynamic> seenBy = images[storyIndex]['seenBy'] ?? [];

        // Check if the current user already exists in the seenBy array
        final existingUserIndex =
            seenBy.indexWhere((element) => element['userId'] == userId);
        if (existingUserIndex >= 0) {
          Map<String, dynamic> currentUserData = seenBy[existingUserIndex];
          // Update the user's existing record
          seenBy[existingUserIndex] = {
            'fullname': currentUserData['fullname'],
            'photoUrl': currentUserData['photoUrl'],
            'time': DateTime.now().millisecondsSinceEpoch,
            'userId': currentUserData['userId'],
            'imoji': imoji,
            'comment': currentUserData['comment']
          };
        } else {
          // Add a new entry for the user if it doesn't exist
          seenBy.add({
            'fullname': fullname,
            'photoUrl': photoUrl,
            'time': DateTime.now().millisecondsSinceEpoch,
            'userId': userId,
            'imoji': imoji,
            'comment': '',
          });
        }
        images[storyIndex]['seenBy'] = seenBy;

        transaction.update(docRef, {'images': images});
      });
    } catch (e) {
      debugPrint('Failed to update seenBy: $e');
    }
  }

  // Future<void> updateSeenBy({
  //   required String documentId, // The ID of the document you want to update
  //   required String userId, // The current user's userId
  //   required String fullname, // The user's fullname
  //   required String photoUrl, // The user's profile picture URL
  //   required String imoji, // The imoji value you want to add/update
  //   required String comment,
  //   required int storyIndex // The comment value you want to add/update
  // }) async {
  //   final FirebaseFirestore firestore = FirebaseFirestore.instance;
  //   final DocumentReference docRef =
  //       firestore.collection('Stories').doc(documentId);

  //   try {
  //     // Run a Firestore transaction to ensure consistency
  //      // Adding logs to help debug
  //   debugPrint("Starting Firestore transaction for documentId: $documentId");
  //     await firestore.runTransaction((transaction) async {
  //       DocumentSnapshot snapshot = await transaction.get(docRef);
  //       if (!snapshot.exists) {
  //         throw Exception('Document does not exist!');
  //       }
  //       debugPrint('1111111111');
  //       // Fetch the document data
  //       Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
  //       List<dynamic> images = data['images'];
  //        debugPrint('222222222');
  //       // Loop through all images in the document
  //      // for (var image in images) {
  //         List<dynamic> seenBy = images[storyIndex]['seenBy'] ?? [];

  //         // Check if the current user already exists in the seenBy array
  //         final existingUserIndex =
  //             seenBy.indexWhere((element) => element['userId'] == userId);
  //          debugPrint('33333333333');
  //         if (existingUserIndex >= 0) {
  //            debugPrint('4444444444');
  //           Map<String, dynamic> currentUserData = seenBy[existingUserIndex];
  //           // Update the user's existing record
  //           seenBy[existingUserIndex] = {
  //             'fullname': fullname,
  //             'photoUrl': photoUrl,
  //             'time': DateTime.now().millisecondsSinceEpoch,
  //             'userId': userId,
  //             'imoji': '',
  //             'comment': comment
  //           };
  //         } else {
  //            debugPrint('55555555555');
  //           // Add a new entry for the user if it doesn't exist
  //           seenBy.add({
  //             'fullname': fullname,
  //             'photoUrl': photoUrl,
  //             'time': FieldValue.serverTimestamp(),
  //             'userId': userId,
  //             'imoji': imoji, // New imoji
  //             'comment': comment, // New comment
  //           });
  //         }

  //         // Update the image's seenBy field
  //         images[storyIndex]['seenBy'] = seenBy;
  //         // debugPrint(image['seenBy']);
  //      // }
  //       debugPrint('6666666666666');
  //       // Update the Firestore document with the modified data
  //       transaction.update(docRef, {'images': images});
  //       debugPrint(images);
  //       debugPrint("Transaction update complete.");
  //       debugPrint('777777777777');
  //     });

  //     debugPrint('seenBy updated successfully');
  //   } catch (e) {
  //     debugPrint('Failed to update seenBy: $e');
  //      // Log Firestore error details
  //   if (e is FirebaseException) {
  //     debugPrint('FirebaseException Code: ${e.code}');
  //     debugPrint('FirebaseException Message: ${e.message}');
  //   }
  //   }
  // }

  final storyReplyController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    final controller = Get.put(StoryViewController(story: story));
    final ReportController reportController = Get.find();
    final User user = story.user!;
    final User currentUser = AuthController.instance.currentUser;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // <-- Story View -->
          StoryView(
            storyItems: controller.storyItems,
            controller: controller.storyController,
            onComplete: () => Get.back(),
            onStoryShow: (StoryItem item, index) {
              controller.getStoryItemIndex(index);
              controller.markSeen();
            },
          ),
          // Other info
          Container(
            margin: const EdgeInsets.only(top: 60),
            child: GestureDetector(
              onTap: () {
                RoutesHelper.toProfileView(user, false).then(
                  (value) => Get.back(),
                );
              },
              child: Row(
                children: [
                  // Back button
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(
                      IconlyLight.arrowLeft2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Profile avatar
                  CachedCircleAvatar(
                    radius: 20,
                    borderColor: primaryColor,
                    imageUrl: user.photoUrl,
                  ),
                  const SizedBox(width: 12),
                  // Other info
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Profile name
                        Text(
                          user.fullname,
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge!
                              .copyWith(color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        // Created at time
                        Obx(
                          () => Text(
                            controller.createdAt.formatDateTime,
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge!
                                .copyWith(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Send message
                  // if (!story.isOwner)
                  //   Padding(
                  //     padding: const EdgeInsets.only(right: 8.0),
                  //     child: IconButton(
                  //       onPressed: () => RoutesHelper.toMessages(user: user),
                  //       icon: const Icon(
                  //         IconlyLight.chat,
                  //         color: Colors.white,
                  //         size: 32,
                  //       ),
                  //     ),
                  //   ),
                  // <-- More options -->
                  PopupMenuButton(
                    // color: Colors.white,
                    onOpened: () => controller.storyController.pause(),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        onTap: () => reportController.reportDialog(
                          type: ReportType.story,
                          story: controller.reportStoryItemData,
                        ),
                        child: Text('report_this_story'.tr),
                      ),
                      if (story.isOwner)
                        PopupMenuItem(
                          onTap: () => _deleteStoryItem(controller),
                          child: Text('delete_this_story'.tr),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Show seen by modal
          if (story.isOwner)
            Obx(() {
              return Container(
                alignment: Alignment.bottomCenter,
                padding: const EdgeInsets.only(bottom: 16),
                child: CircleButton(
                  color: Colors.transparent,
                  onPress: () {
                    // Pause story
                    controller.storyController.pause();

                    // Show bottom modal
                    DialogHelper.showStorySeenByModal(
                      seenByList: controller.seenByList,
                      onDelete: () {
                        // Close modal
                        Get.back();
                        // Delete story item
                        _deleteStoryItem(controller);
                      },
                    );
                  },
                  icon: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(IconlyBold.show, color: primaryColor),
                      const SizedBox(width: 4),
                      Text(
                        '${controller.seenByList.length}',
                        style: const TextStyle(color: primaryColor),
                      ),
                    ],
                  ),
                ),
              );
            }),
          if (!story.isOwner)
            Container(
              alignment: Alignment.bottomCenter,
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                      child: TextField(
                    controller: storyReplyController,
                    onTap: () {
                      controller.storyController.pause();
                      //  debugPrint(controller.index);
                      //  debugPrint(controller.createdAt);
                      //  debugPrint(controller.items);
                      //  debugPrint(controller.seenByList);
                      //  debugPrint(controller.story);
                      //  debugPrint(controller.storyItems);
                      //  debugPrint(controller.story.userId);
                    },
                  )),
                  InkWell(
                      onTap: () async {
                        await updateSeenByForImoji(
                            documentId: controller.story.userId,
                            userId: currentUser.userId,
                            fullname: currentUser.fullname,
                            photoUrl: currentUser.photoUrl,
                            imoji: '❤️',
                            storyIndex: controller.index.value);
                      },
                      child: Text(
                        '❤️',
                        style: TextStyle(fontSize: 30, color: Colors.red),
                      )),
                  InkWell(
                      onTap: () async {
                        await updateSeenByForImoji(
                            documentId: controller.story.userId,
                            userId: currentUser.userId,
                            fullname: currentUser.fullname,
                            photoUrl: currentUser.photoUrl,
                            imoji: '👍',
                            storyIndex: controller.index.value);
                      },
                      child: Text(
                        '👍',
                        style: TextStyle(fontSize: 25),
                      )),
                  InkWell(
                      onTap: () async {
                        await updateSeenByForImoji(
                            documentId: controller.story.userId,
                            userId: currentUser.userId,
                            fullname: currentUser.fullname,
                            photoUrl: currentUser.photoUrl,
                            imoji: '😭',
                            storyIndex: controller.index.value);
                      },
                      child: Text(
                        '😭',
                        style: TextStyle(fontSize: 25),
                      )),
                  InkWell(
                      onTap: () async {
                        await updateSeenByForImoji(
                            documentId: controller.story.userId,
                            userId: currentUser.userId,
                            fullname: currentUser.fullname,
                            photoUrl: currentUser.photoUrl,
                            imoji: '😂',
                            storyIndex: controller.index.value);
                      },
                      child: Text(
                        '😂',
                        style: TextStyle(fontSize: 25),
                      )),
                  InkWell(
                      onTap: () async {
                        await updateSeenByForImoji(
                            documentId: controller.story.userId,
                            userId: currentUser.userId,
                            fullname: currentUser.fullname,
                            photoUrl: currentUser.photoUrl,
                            imoji: '🔥',
                            storyIndex: controller.index.value);
                      },
                      child: Text(
                        '🔥',
                        style: TextStyle(fontSize: 25),
                      )),
                  IconButton(
                      onPressed: () async {
                        await updateSeenBy(
                            documentId: controller.story.userId,
                            userId: currentUser.userId,
                            fullname: currentUser.fullname,
                            photoUrl: currentUser.photoUrl,
                            imoji: '',
                            comment: storyReplyController.text.toString(),
                            storyIndex: controller.index.value);
                        AppStyle().successSnackBar(message: 'done');
                      },
                      icon: Icon(Icons.send))
                ],
              ),
            )
        ],
      ),
    );
  }

  void _deleteStoryItem(StoryViewController controller) {
    // Confirm delete story item
    DialogHelper.showAlertDialog(
      titleColor: errorColor,
      title: Text('delete_this_story'.tr),
      content: Text('this_action_cannot_be_reversed'.tr),
      actionText: 'DELETE'.tr.toUpperCase(),
      action: () {
        Get.back(); // Close confirm dialog
        Get.back(); // Close story view page
        controller.deleteStoryItem();
      },
    );
  }
}

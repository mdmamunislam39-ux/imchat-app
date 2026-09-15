import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/material.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/helpers/app_helper.dart';
import 'package:chat_messenger/helpers/dialog_helper.dart';
import 'package:chat_messenger/media/helpers/media_helper.dart';
import 'package:chat_messenger/models/story/story.dart';
import 'package:chat_messenger/models/story/submodels/seen_by.dart';
import 'package:chat_messenger/models/story/submodels/story_image.dart';
import 'package:chat_messenger/models/story/submodels/story_text.dart';
import 'package:chat_messenger/models/story/submodels/story_video.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:get/get.dart';
import 'package:rxdart/rxdart.dart';

abstract class StoryApi {
  //
  // StoryApi - CRUD Operations
  //

  // Stories collection reference
  static final CollectionReference<Map<String, dynamic>> storiesRef =
      FirebaseFirestore.instance.collection('Stories');
  
  // Get contacts story
  static Stream<List<Story>> getStories(List<User> contacts) {
    final List<Stream<List<Story>>> stories = [];
    final currentUser = AuthController.instance.currentUser;
    stories.add(_getUserStory(currentUser));
    
    final Set<String> addedUserIds = {currentUser.userId};
    for (final contact in contacts) {
      if (!addedUserIds.contains(contact.userId)) {
        addedUserIds.add(contact.userId);
        stories.add(_getUserStory(contact));
      }
    }
    
    return CombineLatestStream(stories, (values) {
      final List<Story> allStories = values.expand((list) => list).toList();
      final Map<String, Story> uniqueStories = {};
      for (final story in allStories) {
        final existing = uniqueStories[story.userId];
        if (existing == null || (story.updatedAt != null && (existing.updatedAt == null || story.updatedAt!.isAfter(existing.updatedAt!)))) {
          uniqueStories[story.userId] = story;
        }
      }
      return uniqueStories.values.toList()
        ..sort((a, b) => (b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
    });
  }

  static Stream<List<Story>> _getUserStory(User user) {
    return storiesRef
        .where('userId', isEqualTo: user.userId)
        .snapshots()
        .map((event) {
      final List<Story> list = [];
      for (final doc in event.docs) {
        try {
          list.add(Story.fromMap(user: user, data: doc.data()));
        } catch (e) {
          debugPrint('_getUserStory error for user ${user.userId}: $e');
        }
      }
      return list;
    });
  }

  // Create text story
  static Future<void> uploadTextStory({
    required String text,
    required Color bgColor,
  }) async {
    try {
      final User currentUser = AuthController.instance.currentUser;

      // Check story doc
      final storyDoc = await storiesRef.doc(currentUser.userId).get();

      // New Story Text
      final StoryText storyText = StoryText(
        text: text,
        bgColor: bgColor,
        createdAt: DateTime.now(),
      );

      // Check result
      if (storyDoc.exists) {
        final data = storyDoc.data() ?? {};
        final oldTexts = data['texts'] is List
            ? List<Map<String, dynamic>>.from(data['texts'])
            : <Map<String, dynamic>>[];

        // Update existing story
        await storyDoc.reference.set({
          'id': currentUser.userId,
          'userId': currentUser.userId,
          'texts': [...oldTexts, storyText.toMap()],
          'type': StoryType.text.name,
          'viewers': [],
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        // Create new story
        final Story story = Story(
          type: StoryType.text,
          texts: [storyText],
          updatedAt: DateTime.now(),
        );
        await storyDoc.reference.set(story.toMap());
      }
      // Close the page
      Get.back();
      // Show message
      DialogHelper.showSnackbarMessage(
          SnackMsgType.success, 'story_created_successfully'.tr);
    } catch (e) {
      DialogHelper.showSnackbarMessage(SnackMsgType.error, e.toString());
    }
  }

  // Create image story
  static Future<bool> uploadImageStory(File imageFile, {bool showDialog = true}) async {
    try {
      final User currentUser = AuthController.instance.currentUser;
      final String userId = currentUser.userId.isNotEmpty
          ? currentUser.userId
          : (fb_auth.FirebaseAuth.instance.currentUser?.uid ?? '');

      if (userId.isEmpty) {
        throw Exception('User is not logged in.');
      }

      if (showDialog) {
        DialogHelper.showProcessingDialog(
            title: 'uploading'.tr, barrierDismissible: false);
      }

      final String imageUrl =
          await AppHelper.uploadFile(file: imageFile, userId: userId);

      // New Story Image
      final StoryImage storyImage =
          StoryImage(imageUrl: imageUrl, createdAt: DateTime.now());

      // Save/merge story in Firestore atomically with arrayUnion
      await storiesRef.doc(userId).set({
        'id': userId,
        'userId': userId,
        'type': StoryType.image.name,
        'images': FieldValue.arrayUnion([storyImage.toMap()]),
        'viewers': [],
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (showDialog) {
        DialogHelper.closeDialog();
      }
      DialogHelper.showSnackbarMessage(
          SnackMsgType.success, 'story_created_successfully'.tr);
      return true;
    } catch (e) {
      debugPrint('uploadImageStory error: $e');
      if (showDialog) {
        DialogHelper.closeDialog();
      }
      DialogHelper.showSnackbarMessage(SnackMsgType.error, e.toString());
      return false;
    }
  }

  // Create video story
  static Future<void> uploadVideoStory(File videoFile) async {
    try {
      final User currentUser = AuthController.instance.currentUser;

      DialogHelper.showProcessingDialog(
          title: 'uploading'.tr, barrierDismissible: false);

      // Check story doc
      final storyDoc = await storiesRef.doc(currentUser.userId).get();

      // <-- Upload video & thumbnail -->
      final String videoUrl =
          await AppHelper.uploadFile(file: videoFile, userId: currentUser.userId);
      final File thumbFile =
          await MediaHelper.getVideoThumbnail(videoFile.path);
      final String thumbnailUrl =
          await AppHelper.uploadFile(file: thumbFile, userId: currentUser.userId);

      // New Story video
      final StoryVideo storyVideo = StoryVideo(
        videoUrl: videoUrl,
        thumbnailUrl: thumbnailUrl,
        createdAt: DateTime.now(),
      );

      // Check result
      if (storyDoc.exists) {
        final data = storyDoc.data() ?? {};
        final oldVideos = data['videos'] is List
            ? List<Map<String, dynamic>>.from(data['videos'])
            : <Map<String, dynamic>>[];

        // Update existing story
        await storyDoc.reference.set({
          'id': currentUser.userId,
          'userId': currentUser.userId,
          'videos': [...oldVideos, storyVideo.toMap()],
          'type': StoryType.video.name,
          'viewers': [],
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        // Create new story
        final Story story = Story(
          type: StoryType.video,
          videos: [storyVideo],
          updatedAt: DateTime.now(),
        );
        await storyDoc.reference.set(story.toMap());
      }
      DialogHelper.closeDialog();
      DialogHelper.showSnackbarMessage(
          SnackMsgType.success, 'story_created_successfully'.tr);
    } catch (e) {
      DialogHelper.closeDialog();
      DialogHelper.showSnackbarMessage(SnackMsgType.error, e.toString());
    }
  }

  static Future<void> markSeen({
    required Story story,
    required dynamic storyItem,
    required List<SeenBy> seenByList,
  }) async {
    try {
      final User currentUser = AuthController.instance.currentUser;

      // New seen by
      final SeenBy newSeenBy = SeenBy(
        userId: currentUser.userId,
        fullname: currentUser.fullname,
        photoUrl: currentUser.photoUrl,
        time: DateTime.now(),
        emoji: '',
        comment: ''
      );

      // New seen by list
      final List<SeenBy> newSeenByList = [...seenByList, newSeenBy];

      switch (storyItem) {
        case StoryText _:
          // Update story item
          final List<StoryText> texts = story.texts.map((e) {
            if (e == storyItem) {
              e.seenBy = newSeenByList;
            }
            return e;
          }).toList();

          await storiesRef.doc(story.id).update({
            'texts': texts.map((e) => e.toMap()).toList(),
          });
          break;
        case StoryImage _:
          // Update story item
          final List<StoryImage> images = story.images.map((e) {
            if (e == storyItem) {
              e.seenBy = newSeenByList;
            }
            return e;
          }).toList();

          await storiesRef.doc(story.id).update({
            'images': images.map((e) => e.toMap()).toList(),
          });
          break;
        case StoryVideo _:
          // Update story item
          final List<StoryVideo> videos = story.videos.map((e) {
            if (e == storyItem) {
              e.seenBy = newSeenByList;
            }
            return e;
          }).toList();

          await storiesRef.doc(story.id).update({
            'videos': videos.map((e) => e.toMap()).toList(),
          });
          break;
      }
      debugPrint('markSeen() -> success');
    } catch (e) {
      debugPrint('markSeen() -> error: $e');
    }
  }

  static Future<void> _updateStoryData({
    required Story story,
    required Map<Object, Object?> data,
  }) async {
    final int totalItems =
        (story.texts.length + story.images.length + story.videos.length);

    if (totalItems == 0) {
      await storiesRef.doc(story.id).delete();
    } else {
      await storiesRef.doc(story.id).update(data);
    }
  }

  static Future<void> deleteStoryItem({
    required Story story,
    required dynamic storyItem,
  }) async {
    try {
      void success() {
        DialogHelper.showSnackbarMessage(
            SnackMsgType.success, 'story_deleted_successfully'.tr);
      }

      switch (storyItem) {
        case StoryText _:
          final List<StoryText> texts = story.texts;
          texts.remove(storyItem);

          await _updateStoryData(story: story, data: {
            'texts': texts.map((e) => e.toMap()).toList(),
          });

          success();
          debugPrint('deleteStoryItem -> text: deleted');
          break;

        case StoryImage _:
          final List<StoryImage> images = story.images;

          // Delete image file
          AppHelper.deleteFile(storyItem.imageUrl);

          images.remove(storyItem);

          // Update story data
          await _updateStoryData(story: story, data: {
            'images': images.map((e) => e.toMap()).toList(),
          });

          success();
          debugPrint('deleteStoryItem -> image: deleted');
          break;

        case StoryVideo _:
          final List<StoryVideo> videos = story.videos;

          // Delete video & thumbnail files
          Future.wait([
            AppHelper.deleteFile(storyItem.videoUrl),
            AppHelper.deleteFile(storyItem.thumbnailUrl),
          ]);

          videos.remove(storyItem);

          // Update story data
          await _updateStoryData(story: story, data: {
            'videos': videos.map((e) => e.toMap()).toList(),
          });

          success();
          debugPrint('deleteStoryItem -> video: deleted');
          break;
      }
    } catch (e) {
      debugPrint('deleteStoryItem() -> error: $e');
      DialogHelper.showSnackbarMessage(SnackMsgType.error, e.toString());
    }
  }

  static Future<void> viewStories(List<Story> stories) async {
    try {
      final User currentUser = AuthController.instance.currentUser;
      
      final List<Future<void>> futures = stories.map((story) {
        return storiesRef.doc(story.id).update({
          'viewers': FieldValue.arrayUnion([currentUser.userId]),
        });
      }).toList();
      await Future.wait(futures);
      debugPrint('viewStories() -> success');
    } catch (e) {
      debugPrint('viewStories() -> error: $e');
    }
  }
}

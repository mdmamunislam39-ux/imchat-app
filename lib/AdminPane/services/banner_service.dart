import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import '../models/banner.dart';

class BannerService {
  final CollectionReference _bannerCollection =
      FirebaseFirestore.instance.collection('audio_room_banners');

  /// Get all banners ordered by createdAt descending
  Future<List<AudioRoomBanner>> getAllBanners() async {
    try {
      final banners = <AudioRoomBanner>[];

      // 1. Fetch from audio_room_banners
      try {
        final querySnapshot = await _bannerCollection.get();
        for (final doc in querySnapshot.docs) {
          try {
            if (doc.exists) {
              banners.add(AudioRoomBanner.fromFirestore(doc));
            }
          } catch (docError) {
            debugPrint('Error parsing doc ${doc.id} from audio_room_banners: $docError');
          }
        }
      } catch (e) {
        debugPrint('Warning: Failed to fetch from audio_room_banners: $e');
      }

      // 2. Fetch from banners collection as a robust fallback/variant
      try {
        final backupSnapshot = await FirebaseFirestore.instance.collection('banners').get();
        for (final doc in backupSnapshot.docs) {
          try {
            if (doc.exists) {
              final banner = AudioRoomBanner.fromFirestore(doc);
              // Avoid duplicate doc IDs if any exists in both collections
              if (!banners.any((b) => b.id == doc.id)) {
                banners.add(banner);
              }
            }
          } catch (docError) {
            debugPrint('Error parsing doc ${doc.id} from banners: $docError');
          }
        }
      } catch (e) {
        debugPrint('Warning: Failed to fetch from banners: $e');
      }

      // 3. Fetch from explore_banners collection as another robust fallback/variant
      try {
        final exploreSnapshot = await FirebaseFirestore.instance.collection('explore_banners').get();
        for (final doc in exploreSnapshot.docs) {
          try {
            if (doc.exists) {
              final banner = AudioRoomBanner.fromFirestore(doc);
              // Avoid duplicate doc IDs if any exists in other collections
              if (!banners.any((b) => b.id == doc.id)) {
                banners.add(banner);
              }
            }
          } catch (docError) {
            debugPrint('Error parsing doc ${doc.id} from explore_banners: $docError');
          }
        }
      } catch (e) {
        debugPrint('Warning: Failed to fetch from explore_banners: $e');
      }

      // Sort in memory by createdAt descending
      banners.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return banners;
    } catch (e) {
      debugPrint('❌ Error fetching banners: $e');
      throw Exception('Failed to fetch banners: $e');
    }
  }

  /// Add a banner
  Future<String> addBanner({
    required String imageUrl,
    String? clickUrl,
    String? eventId,
    File? imageFile,
  }) async {
    try {
      String finalImageUrl = imageUrl;

      // If a local image file is provided, upload it to Firebase Storage first
      if (imageFile != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('banners/${DateTime.now().millisecondsSinceEpoch}.jpg');

        final uploadTask = await storageRef.putFile(imageFile);
        finalImageUrl = await uploadTask.ref.getDownloadURL();
      }

      if (finalImageUrl.isEmpty) {
        throw Exception('Banner image URL cannot be empty');
      }

      final docRef = await _bannerCollection.add({
        'imageUrl': finalImageUrl,
        'clickUrl': clickUrl,
        if (eventId != null && eventId.isNotEmpty) 'eventId': eventId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Sync the exact same document ID to explore_banners and banners collections for complete safety!
      try {
        await FirebaseFirestore.instance.collection('explore_banners').doc(docRef.id).set({
          'imageUrl': finalImageUrl,
          'clickUrl': clickUrl,
          'redirectUrl': clickUrl,
          if (eventId != null && eventId.isNotEmpty) 'eventId': eventId,
          'createdAt': FieldValue.serverTimestamp(),
        });
        await FirebaseFirestore.instance.collection('banners').doc(docRef.id).set({
          'imageUrl': finalImageUrl,
          'clickUrl': clickUrl,
          if (eventId != null && eventId.isNotEmpty) 'eventId': eventId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('Warning: Failed to sync new banner to other collections: $e');
      }

      return docRef.id;
    } catch (e) {
      debugPrint('❌ Error adding banner: $e');
      throw Exception('Failed to add banner: $e');
    }
  }

  /// Delete a banner
  Future<void> deleteBanner(String bannerId, String imageUrl) async {
    try {
      // Handle collection-prefixed IDs from the merged frontend safely
      String actualDocId = bannerId;
      String collectionName = 'audio_room_banners';

      if (bannerId.startsWith('audio_room_banners_')) {
        actualDocId = bannerId.replaceFirst('audio_room_banners_', '');
        collectionName = 'audio_room_banners';
      } else if (bannerId.startsWith('banners_')) {
        actualDocId = bannerId.replaceFirst('banners_', '');
        collectionName = 'banners';
      } else if (bannerId.startsWith('explore_banners_')) {
        actualDocId = bannerId.replaceFirst('explore_banners_', '');
        collectionName = 'explore_banners';
      }

      // 1. Delete from Firestore in the correct collection
      await FirebaseFirestore.instance.collection(collectionName).doc(actualDocId).delete();
      
      // Also try to delete from all other possible collections as clean-up if the ID exists there
      final otherCollections = ['audio_room_banners', 'banners', 'explore_banners', 'audio_room_banner', 'room_banners'];
      for (final col in otherCollections) {
        if (col != collectionName) {
          try {
            await FirebaseFirestore.instance.collection(col).doc(actualDocId).delete();
          } catch (_) {}
        }
      }

      // 2. If it was a Firebase Storage URL, attempt to delete the file
      if (imageUrl.contains('firebasestorage.googleapis.com')) {
        try {
          final storageRef = FirebaseStorage.instance.refFromURL(imageUrl);
          await storageRef.delete();
        } catch (storageError) {
          debugPrint('⚠️ Warning: Failed to delete banner image file from Storage: $storageError');
        }
      }
    } catch (e) {
      debugPrint('❌ Error deleting banner: $e');
      throw Exception('Failed to delete banner: $e');
    }
  }
}

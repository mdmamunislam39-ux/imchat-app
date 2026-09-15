import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

/// Redesigned unified admin service for managing Gifts, Entry Effects, Frames, Badges, and Profile Skins.
class AdminAssetsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();

  static const String _giftsCollection = 'gift';
  static const String _marketItemsCollection = 'market_items';

  /// Fetch all assets by type.
  /// Supported types: 'gift', 'badge', 'avatarFrame', 'entryEffect', 'backgroundTheme'
  Future<List<Map<String, dynamic>>> getAssetsByType(String type) async {
    try {
      debugPrint('📦 AdminAssetsService: Fetching assets of type "$type"');
      if (type == 'gift') {
        final snapshot = await _firestore
            .collection(_giftsCollection)
            .get();

        var assetsList = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['name'] ?? '',
            'type': 'gift',
            'category': data['category'] ?? '',
            'price': data['credits'] ?? 0,
            'thumbnailUrl': data['pngUrl'] ?? '',
            'fileUrl': data['svgaUrl'] ?? '',
            'isActive': data['isActive'] ?? true,
            'createdAt': data['createdAt'],
            'updatedAt': data['updatedAt'],
            'starRating': data['starRating'] ?? 1,
          };
        }).toList();

        assetsList.sort((a, b) {
          final aDate = a['createdAt'] as Timestamp?;
          final bDate = b['createdAt'] as Timestamp?;
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return bDate.compareTo(aDate);
        });

        return assetsList;
      } else {
        final snapshot = await _firestore
            .collection(_marketItemsCollection)
            .where('type', isEqualTo: type)
            .get();

        var assetsList = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['name'] ?? '',
            'type': data['type'] ?? '',
            'description': data['description'] ?? '',
            'category': data['category'] ?? 'general',
            'price': data['coinPrice'] ?? data['diamondPrice'] ?? 0,
            'thumbnailUrl': data['thumbnailUrl'] ?? data['imageUrl'] ?? '',
            'fileUrl': data['fileUrl'] ?? '',
            'isActive': data['isActive'] ?? true,
            'createdAt': data['createdAt'],
            'updatedAt': data['updatedAt'],
            'starRating': data['starRating'] ?? 1,
            'verifyLevel': data['verifyLevel'] ?? data['verificationLevel'] ?? 0,
          };
        }).toList();

        assetsList.sort((a, b) {
          final aDate = a['createdAt'] as Timestamp?;
          final bDate = b['createdAt'] as Timestamp?;
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return bDate.compareTo(aDate);
        });

        return assetsList;
      }
    } catch (e, stackTrace) {
      debugPrint('❌ AdminAssetsService: Error fetching assets: $e');
      debugPrint('❌ AdminAssetsService: Stack trace: $stackTrace');
      throw Exception('Failed to fetch assets: $e');
    }
  }

  /// Upload file to Firebase Storage
  Future<String> _uploadFile(File file, String path) async {
    try {
      debugPrint('📤 AdminAssetsService: Starting upload to $path...');
      final ref = _storage.ref().child(path);
      final uploadTask = ref.putFile(file);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      debugPrint('✅ AdminAssetsService: Upload successful: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('❌ AdminAssetsService: Error uploading file to $path: $e');
      throw Exception('Failed to upload file: $e');
    }
  }

  /// Add new asset
  Future<String> addAsset({
    required String name,
    required String type,
    required int price,
    required String category,
    required String description,
    File? pngFile,
    File? animationFile,
    bool skipFileUpload = false,
    int starRating = 1,
    int verifyLevel = 0,
    Map<String, dynamic>? validityPrices,
  }) async {
    try {
      final String id = _uuid.v4();
      final DateTime now = DateTime.now();

      String? thumbnailUrl;
      String? fileUrl;

      if (skipFileUpload) {
        thumbnailUrl = 'placeholder_thumbnail_url';
        fileUrl = 'placeholder_animation_url';
      } else {
        // Upload thumbnail/icon (PNG)
        if (pngFile != null) {
          final path = type == 'gift'
              ? 'gifts/$id/icon.png'
              : 'market_items/$id/icon.png';
          thumbnailUrl = await _uploadFile(pngFile, path);
        }

        // Upload main animation/asset file
        if (animationFile != null) {
          final extension = animationFile.path.split('.').last.toLowerCase();
          final path = type == 'gift'
              ? 'gifts/$id/animation.$extension'
              : 'market_items/$id/animation.$extension';
          fileUrl = await _uploadFile(animationFile, path);
        }
      }

      if (type == 'gift') {
        final giftData = {
          'id': id,
          'name': name.trim(),
          'category': category.trim(),
          'credits': price,
          'pngUrl': thumbnailUrl,
          'svgaUrl': fileUrl,
          'createdAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
          'isActive': true,
          'starRating': starRating,
          if (validityPrices != null) 'validityPrices': validityPrices,
        };
        await _firestore.collection(_giftsCollection).doc(id).set(giftData);
      } else {
        final itemData = {
          'id': id,
          'name': name.trim(),
          'description': description.trim(),
          'type': type,
          'category': category.trim().isEmpty ? 'general' : category.trim(),
          'diamondPrice': price,
          'thumbnailUrl': thumbnailUrl,
          'fileUrl': fileUrl,
          'createdAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
          'isActive': true,
          'starRating': starRating,
          'verifyLevel': verifyLevel,
          if (validityPrices != null) 'validityPrices': validityPrices,
        };
        await _firestore.collection(_marketItemsCollection).doc(id).set(itemData);
      }

      debugPrint('✅ AdminAssetsService: Asset added successfully with ID: $id');
      return id;
    } catch (e, stackTrace) {
      debugPrint('❌ AdminAssetsService: Error adding asset: $e');
      debugPrint('❌ AdminAssetsService: Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Update existing asset
  Future<void> updateAsset({
    required String id,
    required String type,
    String? name,
    int? price,
    String? category,
    String? description,
    File? pngFile,
    File? animationFile,
    bool? isActive,
    int? starRating,
    int? verifyLevel,
    Map<String, dynamic>? validityPrices,
  }) async {
    try {
      final DateTime now = DateTime.now();
      final updates = <String, dynamic>{
        'updatedAt': Timestamp.fromDate(now),
      };

      if (name != null) updates['name'] = name.trim();
      if (category != null) updates['category'] = category.trim();
      if (isActive != null) updates['isActive'] = isActive;
      if (starRating != null) updates['starRating'] = starRating;
      if (verifyLevel != null) updates['verifyLevel'] = verifyLevel;
      if (validityPrices != null) updates['validityPrices'] = validityPrices;

      if (pngFile != null) {
        final path = type == 'gift'
            ? 'gifts/$id/icon.png'
            : 'market_items/$id/icon.png';
        updates[type == 'gift' ? 'pngUrl' : 'thumbnailUrl'] =
            await _uploadFile(pngFile, path);
      }

      if (animationFile != null) {
        final extension = animationFile.path.split('.').last.toLowerCase();
        final path = type == 'gift'
            ? 'gifts/$id/animation.$extension'
            : 'market_items/$id/animation.$extension';
        updates[type == 'gift' ? 'svgaUrl' : 'fileUrl'] =
            await _uploadFile(animationFile, path);
      }

      if (type == 'gift') {
        if (price != null) updates['credits'] = price;
        await _firestore.collection(_giftsCollection).doc(id).update(updates);
      } else {
        if (price != null) {
          updates['diamondPrice'] = price;
        }
        if (description != null) updates['description'] = description.trim();
        await _firestore.collection(_marketItemsCollection).doc(id).update(updates);
      }

      debugPrint('✅ AdminAssetsService: Asset $id updated successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ AdminAssetsService: Error updating asset: $e');
      debugPrint('❌ AdminAssetsService: Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Delete asset
  Future<void> deleteAsset(String id, String type) async {
    try {
      debugPrint('🗑️ AdminAssetsService: Deleting asset $id of type $type');

      // Attempt to clean up files in storage
      if (type == 'gift') {
        final doc = await _firestore.collection(_giftsCollection).doc(id).get();
        if (doc.exists) {
          final data = doc.data()!;
          final png = data['pngUrl'] as String?;
          final svga = data['svgaUrl'] as String?;
          if (png != null && png.startsWith('http')) {
            try {
              await _storage.refFromURL(png).delete();
            } catch (_) {}
          }
          if (svga != null && svga.startsWith('http')) {
            try {
              await _storage.refFromURL(svga).delete();
            } catch (_) {}
          }
        }
        await _firestore.collection(_giftsCollection).doc(id).delete();
      } else {
        final doc = await _firestore.collection(_marketItemsCollection).doc(id).get();
        if (doc.exists) {
          final data = doc.data()!;
          final thumb = data['thumbnailUrl'] as String?;
          final file = data['fileUrl'] as String?;
          if (thumb != null && thumb.startsWith('http')) {
            try {
              await _storage.refFromURL(thumb).delete();
            } catch (_) {}
          }
          if (file != null && file.startsWith('http')) {
            try {
              await _storage.refFromURL(file).delete();
            } catch (_) {}
          }
        }
        await _firestore.collection(_marketItemsCollection).doc(id).delete();
      }
      debugPrint('✅ AdminAssetsService: Asset $id deleted successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ AdminAssetsService: Error deleting asset: $e');
      debugPrint('❌ AdminAssetsService: Stack trace: $stackTrace');
      rethrow;
    }
  }
}


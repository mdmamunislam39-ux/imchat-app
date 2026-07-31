import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:chat_messenger/models/emoji_models.dart';

/// Service for managing emoji data from Firebase
class EmojiService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get all emoji categories
  static Future<List<EmojiCategory>> getEmojiCategories() async {
    try {
      debugPrint('🎭 [EmojiService] Fetching emoji categories...');
      
      final querySnapshot = await _firestore
          .collection('emoji')
          .get();

      final categories = querySnapshot.docs
          .map((doc) {
            final data = doc.data();
            debugPrint('🎭 [EmojiService] Category data: ${doc.id} -> $data');
            return EmojiCategory.fromJson({
              'id': doc.id,
              'name': doc.id, // Use document ID as name
              'displayName': doc.id, // Use document ID as display name
              'iconUrl': '', // No icon URL in your structure
              'order': 0, // Default order
              'isActive': true, // Default to active
              ...data,
            });
          })
          .where((category) => category.isActive)
          .toList();

      debugPrint('🎭 [EmojiService] Found ${categories.length} emoji categories');
      return categories;
    } catch (e) {
      debugPrint('❌ [EmojiService] Error fetching emoji categories: $e');
      return [];
    }
  }

  /// Get emojis for a specific category
  static Future<List<EmojiItem>> getEmojisByCategory(String categoryId) async {
    try {
      debugPrint('🎭 [EmojiService] Fetching emojis for category: $categoryId');
      
      final doc = await _firestore
          .collection('emoji')
          .doc(categoryId)
          .get();

      if (!doc.exists) {
        debugPrint('🎭 [EmojiService] Category document does not exist: $categoryId');
        return [];
      }

      final data = doc.data();
      final emojisData = data?['emojis'] as List<dynamic>?;
      
      if (emojisData == null) {
        debugPrint('🎭 [EmojiService] No emojis array found in category: $categoryId');
        return [];
      }

      final emojis = emojisData
          .asMap()
          .entries
          .map((entry) {
            final index = entry.key;
            final emojiData = entry.value as Map<String, dynamic>;
            debugPrint('🎭 [EmojiService] Emoji data: $index -> $emojiData');
            return EmojiItem.fromJson({
              'id': '${categoryId}_$index', // Generate unique ID
              'categoryId': categoryId,
              'order': index,
              'isActive': true,
              ...emojiData,
            });
          })
          .where((emoji) => emoji.isActive)
          .toList();

      debugPrint('🎭 [EmojiService] Found ${emojis.length} emojis in category $categoryId');
      return emojis;
    } catch (e) {
      debugPrint('❌ [EmojiService] Error fetching emojis for category $categoryId: $e');
      return [];
    }
  }

  /// Get all emojis from all categories
  static Future<Map<String, List<EmojiItem>>> getAllEmojis() async {
    try {
      debugPrint('🎭 [EmojiService] Fetching all emojis...');
      
      final categories = await getEmojiCategories();
      final Map<String, List<EmojiItem>> emojisByCategory = {};

      for (final category in categories) {
        final emojis = await getEmojisByCategory(category.id);
        emojisByCategory[category.id] = emojis;
      }

      debugPrint('🎭 [EmojiService] Fetched emojis for ${emojisByCategory.length} categories');
      return emojisByCategory;
    } catch (e) {
      debugPrint('❌ [EmojiService] Error fetching all emojis: $e');
      return {};
    }
  }

  /// Get emoji by ID
  static Future<EmojiItem?> getEmojiById(String categoryId, String emojiId) async {
    try {
      debugPrint('🎭 [EmojiService] Fetching emoji: $emojiId from category: $categoryId');
      
      final doc = await _firestore
          .collection('emoji')
          .doc(categoryId)
          .collection('emojis')
          .doc(emojiId)
          .get();

      if (doc.exists) {
        final emoji = EmojiItem.fromJson({
          'id': doc.id,
          ...doc.data()!,
        });
        debugPrint('🎭 [EmojiService] Found emoji: ${emoji.name}');
        return emoji;
      }

      debugPrint('🎭 [EmojiService] Emoji not found: $emojiId');
      return null;
    } catch (e) {
      debugPrint('❌ [EmojiService] Error fetching emoji $emojiId: $e');
      return null;
    }
  }

  /// Search emojis by name
  static Future<List<EmojiItem>> searchEmojis(String query) async {
    try {
      debugPrint('🎭 [EmojiService] Searching emojis for: $query');
      
      if (query.isEmpty) return [];

      final allEmojis = await getAllEmojis();
      final List<EmojiItem> searchResults = [];

      for (final emojis in allEmojis.values) {
        for (final emoji in emojis) {
          if (emoji.name.toLowerCase().contains(query.toLowerCase()) ||
              emoji.displayName.toLowerCase().contains(query.toLowerCase()) ||
              (emoji.emojiUrl.toLowerCase().contains(query.toLowerCase()))) {
            searchResults.add(emoji);
          }
        }
      }

      // Sort by relevance (exact match first, then partial match)
      searchResults.sort((a, b) {
        final aExact = a.name.toLowerCase() == query.toLowerCase() ||
            a.displayName.toLowerCase() == query.toLowerCase();
        final bExact = b.name.toLowerCase() == query.toLowerCase() ||
            b.displayName.toLowerCase() == query.toLowerCase();
        
        if (aExact && !bExact) return -1;
        if (!aExact && bExact) return 1;
        return 0;
      });

      debugPrint('🎭 [EmojiService] Found ${searchResults.length} emojis matching "$query"');
      return searchResults;
    } catch (e) {
      debugPrint('❌ [EmojiService] Error searching emojis: $e');
      return [];
    }
  }

  /// Get recent emojis (last 20 used)
  static Future<List<EmojiItem>> getRecentEmojis(String userId) async {
    try {
      debugPrint('🎭 [EmojiService] Fetching recent emojis for user: $userId');
      
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('recent_emojis')
          .orderBy('lastUsed', descending: true)
          .limit(20)
          .get();

      final List<EmojiItem> recentEmojis = [];

      for (final docSnapshot in doc.docs) {
        final data = docSnapshot.data();
        final categoryId = data['categoryId'] as String?;
        final emojiId = data['emojiId'] as String?;

        if (categoryId != null && emojiId != null) {
          final emoji = await getEmojiById(categoryId, emojiId);
          if (emoji != null) {
            recentEmojis.add(emoji);
          }
        }
      }

      debugPrint('🎭 [EmojiService] Found ${recentEmojis.length} recent emojis');
      return recentEmojis;
    } catch (e) {
      debugPrint('❌ [EmojiService] Error fetching recent emojis: $e');
      return [];
    }
  }

  /// Add emoji to recent list
  static Future<void> addToRecentEmojis(String userId, EmojiItem emoji) async {
    try {
      debugPrint('🎭 [EmojiService] Adding emoji to recent: ${emoji.name}');
      
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('recent_emojis')
          .doc(emoji.id)
          .set({
        'categoryId': emoji.categoryId,
        'emojiId': emoji.id,
        'lastUsed': FieldValue.serverTimestamp(),
      });

      debugPrint('🎭 [EmojiService] Added emoji to recent list');
    } catch (e) {
      debugPrint('❌ [EmojiService] Error adding emoji to recent: $e');
    }
  }

  /// Clear recent emojis
  static Future<void> clearRecentEmojis(String userId) async {
    try {
      debugPrint('🎭 [EmojiService] Clearing recent emojis for user: $userId');
      
      final batch = _firestore.batch();
      final recentEmojis = await _firestore
          .collection('users')
          .doc(userId)
          .collection('recent_emojis')
          .get();

      for (final doc in recentEmojis.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      debugPrint('🎭 [EmojiService] Cleared recent emojis');
    } catch (e) {
      debugPrint('❌ [EmojiService] Error clearing recent emojis: $e');
    }
  }
}

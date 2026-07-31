import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user.dart';

class LevelService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Level progression requirements
  static const Map<int, int> _sendingLevelRequirements = {
    1: 0,    // Beginner
    2: 100,  // Novice
    3: 500,  // Intermediate
    4: 1000, // Advanced
    5: 2500, // Expert
    6: 5000, // Master
    7: 10000, // Grandmaster
    8: 25000, // Legend
    9: 50000, // Mythic
    10: 100000, // Transcendent
  };

  static const Map<int, int> _receivingLevelRequirements = {
    1: 0,    // Beginner
    2: 50,   // Novice
    3: 250,  // Intermediate
    4: 500,  // Advanced
    5: 1250, // Expert
    6: 2500, // Master
    7: 5000, // Grandmaster
    8: 12500, // Legend
    9: 25000, // Mythic
    10: 50000, // Transcendent
  };

  static const Map<int, String> _levelNames = {
    1: 'Beginner',
    2: 'Novice',
    3: 'Intermediate',
    4: 'Advanced',
    5: 'Expert',
    6: 'Master',
    7: 'Grandmaster',
    8: 'Legend',
    9: 'Mythic',
    10: 'Transcendent',
  };

  // Get user level data
  Future<User?> getUserLevelData(String userId) async {
    try {
      debugPrint('🎯 Fetching user level data for: $userId');
      
      final doc = await _firestore.collection('Users').doc(userId).get();
      
      if (doc.exists) {
        return User.fromMap(doc.data()!);
      } else {
        debugPrint('❌ User not found: $userId');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error fetching user level data: $e');
      rethrow;
    }
  }

  Future<UserLevel> _calculateDynamicLevel(int totalProgress, String configDocName, {int? assignedLevel}) async {
    int newLevel = 1;
    String levelName = 'Beginner';
    double requiredForNext = 100.0;
    int healedProgress = totalProgress;

    try {
      final configDoc = await _firestore.collection('level_configurations').doc(configDocName).get();
      if (configDoc.exists && configDoc.data() != null && configDoc.data()!['levels'] != null) {
        final levelsConfig = List<Map<String, dynamic>>.from(configDoc.data()!['levels']);
        levelsConfig.sort((a, b) => (a['levelNumber'] ?? 0).compareTo(b['levelNumber'] ?? 0));

        if (levelsConfig.isNotEmpty) {
          // --- Self-Healing Logic for Admin Overrides ---
          if (assignedLevel != null) {
             int naturalLevel = 1;
             for (int i = 0; i < levelsConfig.length; i++) {
                final req = (levelsConfig[i]['diamondRequirement'] as num?)?.toDouble() ?? 100.0;
                if (totalProgress >= req) {
                   naturalLevel = (levelsConfig[i]['levelNumber'] ?? (i + 1));
                } else {
                   break;
                }
             }

             if (naturalLevel != assignedLevel) {
                 for (int i = 0; i < levelsConfig.length; i++) {
                    int lvlNum = levelsConfig[i]['levelNumber'] ?? (i + 1);
                    if (lvlNum == assignedLevel) {
                        healedProgress = (levelsConfig[i]['diamondRequirement'] as num?)?.toInt() ?? totalProgress;
                        break;
                    }
                 }
             }
          }
          // --- End Self-Healing ---

          for (int i = 0; i < levelsConfig.length; i++) {
            final req = (levelsConfig[i]['diamondRequirement'] as num?)?.toDouble() ?? 100.0;
            if (healedProgress >= req) {
              newLevel = (levelsConfig[i]['levelNumber'] ?? (i + 1));
              levelName = levelsConfig[i]['levelName'] ?? 'Level $newLevel';
              
              if (i + 1 < levelsConfig.length) {
                requiredForNext = (levelsConfig[i + 1]['diamondRequirement'] as num?)?.toDouble() ?? req;
              } else {
                requiredForNext = req;
              }
            } else {
              break;
            }
          }
          
          if (totalProgress < ((levelsConfig[0]['diamondRequirement'] as num?)?.toDouble() ?? 0)) {
            newLevel = 1;
            levelName = levelsConfig[0]['levelName'] ?? 'Beginner';
            requiredForNext = (levelsConfig[0]['diamondRequirement'] as num?)?.toDouble() ?? 100.0;
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching config for dynamic level: $e');
    }

    return UserLevel(
      level: newLevel,
      currentProgress: healedProgress,
      requiredForNext: requiredForNext.toInt(),
      levelName: levelName,
      lastUpdated: DateTime.now(),
    );
  }

  // Update user level based on diamonds sent
  Future<void> updateSendingLevel(String userId, int diamondsSent) async {
    try {
      debugPrint('🎯 Updating sending level for user: $userId, diamonds: $diamondsSent');
      
      final userDoc = await _firestore.collection('Users').doc(userId).get();
      if (!userDoc.exists) {
        throw Exception('User not found');
      }
      
      final userData = User.fromMap(userDoc.data()!);
      final currentLevel = userData.sendingLevel ?? _createDefaultSendingLevel();
      
      int healedProgress = currentLevel.currentProgress;
      // Self-heal: check if admin manually updated the level without updating progress
      final tempLevel = await _calculateDynamicLevel(healedProgress, 'sending_config', assignedLevel: currentLevel.level);
      
      int newProgress = tempLevel.currentProgress + diamondsSent;
      final updatedLevel = await _calculateDynamicLevel(newProgress, 'sending_config');

      await _firestore.collection('Users').doc(userId).update({
        'sendingLevel': updatedLevel.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('✅ Sending level updated: Level ${updatedLevel.level}, Progress: $newProgress');
    } catch (e) {
      debugPrint('❌ Error updating sending level: $e');
      rethrow;
    }
  }

  // Update user level based on diamonds received
  Future<void> updateReceivingLevel(String userId, int diamondsReceived) async {
    try {
      debugPrint('🎯 Updating receiving level for user: $userId, diamonds: $diamondsReceived');
      
      final userDoc = await _firestore.collection('Users').doc(userId).get();
      if (!userDoc.exists) {
        throw Exception('User not found');
      }

      final userData = User.fromMap(userDoc.data()!);
      final currentLevel = userData.receivingLevel ?? _createDefaultReceivingLevel();
      
      int healedProgress = currentLevel.currentProgress;
      // Self-heal: check if admin manually updated the level without updating progress
      final tempLevel = await _calculateDynamicLevel(healedProgress, 'receiving_config', assignedLevel: currentLevel.level);

      int newProgress = tempLevel.currentProgress + diamondsReceived;
      final updatedLevel = await _calculateDynamicLevel(newProgress, 'receiving_config');

      await _firestore.collection('Users').doc(userId).update({
        'receivingLevel': updatedLevel.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Receiving level updated: Level ${updatedLevel.level}, Progress: $newProgress');
    } catch (e) {
      debugPrint('❌ Error updating receiving level: $e');
      rethrow;
    }
  }

  // Get level requirements for a specific level
  Map<String, dynamic> getLevelRequirements(int level, String type) {
    final requirements = type == 'sending' ? _sendingLevelRequirements : _receivingLevelRequirements;
    final nextLevel = level + 1;
    final currentRequired = requirements[level] ?? 0;
    final nextRequired = requirements[nextLevel] ?? 0;
    
    return {
      'currentLevel': level,
      'currentRequired': currentRequired,
      'nextLevel': nextLevel,
      'nextRequired': nextRequired,
      'levelName': _levelNames[level] ?? 'Unknown',
      'nextLevelName': _levelNames[nextLevel] ?? 'Max Level',
      'isMaxLevel': level >= 10,
    };
  }

  // Get all level requirements
  Map<String, dynamic> getAllLevelRequirements() {
    return {
      'sendingLevels': _sendingLevelRequirements,
      'receivingLevels': _receivingLevelRequirements,
      'levelNames': _levelNames,
    };
  }

  // Create default sending level
  UserLevel _createDefaultSendingLevel() {
    return UserLevel(
      level: 1,
      currentProgress: 0,
      requiredForNext: _sendingLevelRequirements[2] ?? 100,
      levelName: _levelNames[1] ?? 'Beginner',
      lastUpdated: DateTime.now(),
    );
  }

  // Create default receiving level
  UserLevel _createDefaultReceivingLevel() {
    return UserLevel(
      level: 1,
      currentProgress: 0,
      requiredForNext: _receivingLevelRequirements[2] ?? 50,
      levelName: _levelNames[1] ?? 'Beginner',
      lastUpdated: DateTime.now(),
    );
  }

  // Calculate level progress percentage
  double calculateLevelProgress(UserLevel level, String type) {
    if (level.requiredForNext == 0) return 1.0; // Max level
    
    final requirements = type == 'sending' ? _sendingLevelRequirements : _receivingLevelRequirements;
    final currentLevelReq = requirements[level.level] ?? 0;
    
    final progress = level.currentProgress - currentLevelReq;
    final totalNeeded = level.requiredForNext - currentLevelReq;
    
    return (progress / totalNeeded).clamp(0.0, 1.0);
  }

  // Get level rewards/benefits
  Map<String, dynamic> getLevelRewards(int level) {
    final rewards = <String, dynamic>{
      'badges': <String>[],
      'frames': <String>[],
      'effects': <String>[],
      'themes': <String>[],
      'privileges': <String>[],
    };

    // Define rewards based on level
    if (level >= 2) {
      rewards['badges'].add('Novice Badge');
      rewards['privileges'].add('Custom Status');
    }
    if (level >= 3) {
      rewards['frames'].add('Intermediate Frame');
      rewards['privileges'].add('Priority Support');
    }
    if (level >= 5) {
      rewards['effects'].add('Expert Entry Effect');
      rewards['privileges'].add('Exclusive Chat Rooms');
    }
    if (level >= 7) {
      rewards['themes'].add('Grandmaster Theme');
      rewards['privileges'].add('VIP Support');
    }
    if (level >= 10) {
      rewards['privileges'].add('All Premium Features');
      rewards['privileges'].add('Exclusive Events');
    }

    return rewards;
  }
}
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../../domain/repositories/fruit_wheel_repository.dart';
import '../models/round_state_model.dart';
import '../models/round_history_model.dart';
import '../models/user_bet_history_model.dart';

class FruitWheelRepositoryImpl implements FruitWheelRepository {
  final FirebaseDatabase _realtimeDb;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  FruitWheelRepositoryImpl({
    required FirebaseDatabase realtimeDb,
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
  })  : _realtimeDb = realtimeDb,
        _auth = auth,
        _firestore = firestore;

  @override
  Stream<RoundStateModel?> watchCurrentRound() {
    final ref = _realtimeDb.ref('fruit_wheel/current_round');
    return ref.onValue.map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return null;
      return RoundStateModel.fromRtdb(data, _auth.currentUser?.uid);
    });
  }

  @override
  Future<Map<String, dynamic>> placeBet({
    required String symbol,
    required int amount,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Must be logged in');

    // 1. Deduct diamonds from Firestore directly (avoids transaction deadlocks)
    final userRef = _firestore.collection('Users').doc(uid);
    await userRef.update({'diamonds': FieldValue.increment(-amount)});

    // 2. Add bet to Realtime Database
    final roundRef = _realtimeDb.ref('fruit_wheel/current_round');
    await roundRef.child('totalBets/$symbol').set(ServerValue.increment(amount));
    await roundRef.child('bets/$uid/$symbol').set(ServerValue.increment(amount));

    return {'success': true};
  }

  Future<String> _generateResult() async {
    try {
      final configDoc = await _firestore.collection('config').doc('fruit_wheel').get();
      int wWatermelon = 1, wPlum = 1, wSevens = 1;
      
      if (configDoc.exists) {
        final data = configDoc.data()!;
        wWatermelon = data['watermelonWeight'] ?? 1;
        wPlum = data['grapeWeight'] ?? 1; // Admin panel uses 'grapeWeight' for plum
        wSevens = data['sevensWeight'] ?? 1;
      }

      final totalWeight = wWatermelon + wPlum + wSevens;
      final rand = Random().nextDouble() * totalWeight;

      if (rand < wWatermelon) return 'watermelon';
      if (rand < wWatermelon + wPlum) return 'plum';
      return 'sevens';
    } catch (e) {
      // Fallback
      final rand = Random().nextInt(100);
      if (rand < 50) return 'watermelon';
      if (rand < 90) return 'plum';
      return 'sevens';
    }
  }

  @override
  Future<Map<String, dynamic>> tickGame() async {
    final roundRef = _realtimeDb.ref('fruit_wheel/current_round');
    final snapshot = await roundRef.get();
    
    final now = DateTime.now().millisecondsSinceEpoch;
    
    if (!snapshot.exists || snapshot.value == null) {
      await roundRef.set({
        'roundNumber': 1,
        'phase': 'betting',
        'phaseEndTime': now + 25000,
        'totalBets': {'watermelon': 0, 'plum': 0, 'sevens': 0},
        'bets': {},
        'result': null,
        'winners': {},
      });
      return {'status': 'initialized'};
    }
    
    final data = Map<String, dynamic>.from(snapshot.value as Map);
    final phaseEndTime = (data['phaseEndTime'] as num?)?.toInt() ?? 0;
    final phase = data['phase'] as String?;
    
    if (now < phaseEndTime) return {'status': 'waiting'};
    
    if (phase == 'betting') {
      final newResult = await _generateResult();
      await roundRef.update({
        'phase': 'spinning',
        'phaseEndTime': now + 6000,
        'result': newResult,
      });
    } else if (phase == 'spinning') {
      await roundRef.update({
        'phase': 'result',
        'phaseEndTime': now + 5000,
      });
      
      // Calculate payouts and history!
      final result = data['result'] as String?;
      final bets = data['bets'] as Map?;
      final currentRound = (data['roundNumber'] as num?)?.toInt() ?? 0;
      
      if (result != null && bets != null) {
        int multiplier = result == 'sevens' ? 8 : 2;
        Map<String, dynamic> winners = {};
        List<Map<String, dynamic>> winnersList = [];
        
        final String dateString = DateTime.now().toIso8601String().split('T')[0];
        
        for (var uidKey in bets.keys) {
          final String uidStr = uidKey.toString();
          final userBets = Map<String, dynamic>.from(bets[uidKey] as Map);
          
          int winAmount = 0;
          int totalBetAmount = 0;
          
          for (var sym in userBets.keys) {
            final betAmount = (userBets[sym] as num).toInt();
            totalBetAmount += betAmount;
            if (sym == result) {
              winAmount += betAmount * multiplier;
            }
          }
          
          // 1. Write to User's Bet History (Both Win and Loss)
          await _firestore.collection('Users').doc(uidStr).collection('bet_history').add({
            'roundNumber': currentRound,
            'bets': userBets,
            'result': result,
            'payout': winAmount,
            'totalBet': totalBetAmount,
            'timestamp': FieldValue.serverTimestamp(),
          });
          
          // 2. Handle Winner Logic
          if (winAmount > 0) {
            await _firestore.collection('Users').doc(uidStr).update({
              'diamonds': FieldValue.increment(winAmount)
            });
            
            // Daily Rankings Update
            await _firestore
                .collection('fruit_wheel_rankings')
                .doc(dateString)
                .collection('top_winners')
                .doc(uidStr)
                .set({
              'uid': uidStr,
              'totalWon': FieldValue.increment(winAmount),
              'lastWonAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));

            // Fetch User Details for Top 3
            try {
              final userDoc = await _firestore.collection('Users').doc(uidStr).get();
              final userData = userDoc.data();
              if (userData != null) {
                winnersList.add({
                  'uid': uidStr,
                  'payout': winAmount,
                  'name': userData['fullname'] ?? userData['name'] ?? 'Player',
                  'photo': userData['photoUrl'] ?? userData['imageUrl'] ?? userData['profileImageUrl'] ?? '',
                });
                
                // Update ranking user info
                await _firestore
                    .collection('fruit_wheel_rankings')
                    .doc(dateString)
                    .collection('top_winners')
                    .doc(uidStr)
                    .set({
                  'name': userData['fullname'] ?? userData['name'] ?? 'Player',
                  'photo': userData['photoUrl'] ?? userData['imageUrl'] ?? userData['profileImageUrl'] ?? '',
                }, SetOptions(merge: true));
              }
            } catch (e) {
              debugPrint('Error fetching user for winner: $e');
            }
          }
        }
        
        // Sort and pick Top 3
        winnersList.sort((a, b) => (b['payout'] as int).compareTo(a['payout'] as int));
        final top3 = winnersList.take(3).toList();
        
        for (var w in top3) {
          winners[w['uid']] = w;
        }
        
        if (winners.isNotEmpty) {
          await roundRef.child('winners').set(winners);
        }
      }
    } else if (phase == 'result') {
      final currentRound = (data['roundNumber'] as num?)?.toInt() ?? 0;
      
      // Save history before moving to next round
      await _realtimeDb.ref('fruit_wheel/history/$currentRound').set({
        'roundNumber': currentRound,
        'result': data['result'],
        'timestamp': ServerValue.timestamp,
      });

      await roundRef.set({
        'roundNumber': currentRound + 1,
        'phase': 'betting',
        'phaseEndTime': now + 25000,
        'totalBets': {'watermelon': 0, 'plum': 0, 'sevens': 0},
        'bets': {},
        'result': null,
        'winners': {},
      });
    }
    
    return {'status': 'transitioned'};
  }

  /// Parse RTDB history data which can come as either a Map or List
  /// (Firebase returns a List when keys are sequential integers).
  List<RoundHistoryModel> _parseHistory(Object? rawData) {
    if (rawData == null) return [];

    Map<String, dynamic> dataMap = {};

    if (rawData is Map) {
      dataMap = rawData.map(
        (key, value) => MapEntry(key.toString(), value),
      );
    } else if (rawData is List) {
      for (int i = 0; i < rawData.length; i++) {
        if (rawData[i] != null) {
          dataMap[i.toString()] = rawData[i];
        }
      }
    } else {
      return [];
    }

    final entries = dataMap.entries.toList()
      ..sort((a, b) => int.parse(b.key).compareTo(int.parse(a.key)));

    return entries
        .where((e) => e.value is Map)
        .map((e) => RoundHistoryModel.fromRtdb(e.value as Map<dynamic, dynamic>))
        .toList();
  }

  @override
  Future<List<RoundHistoryModel>> getHistory({int limit = 10}) async {
    final ref = _realtimeDb.ref('fruit_wheel/history');
    final snapshot = await ref.orderByKey().limitToLast(limit).get();
    return _parseHistory(snapshot.value);
  }

  @override
  Stream<List<RoundHistoryModel>> watchHistory({int limit = 10}) {
    final ref = _realtimeDb.ref('fruit_wheel/history');
    return ref.orderByKey().limitToLast(limit).onValue.map((event) {
      return _parseHistory(event.snapshot.value);
    });
  }


  @override
  Future<List<UserBetHistoryModel>> getUserBetHistory({int limit = 20}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];

    final snapshot = await _firestore
        .collection('Users')
        .doc(uid)
        .collection('bet_history')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => UserBetHistoryModel.fromFirestore(doc))
        .toList();
  }
}

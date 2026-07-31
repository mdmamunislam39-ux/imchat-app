import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/device_session_model.dart';
import '../api/auth_api.dart';

class DeviceSessionService {
  static const String _deviceIdKey = 'app_unique_device_id';
  static const String _deviceSessionsCollection = 'device_sessions';
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static String? _currentDeviceId;
  static StreamSubscription<DocumentSnapshot>? _sessionListener;

  /// Gets the unique persistent ID for this specific app installation on the device.
  static Future<String> getDeviceId() async {
    if (_currentDeviceId != null) return _currentDeviceId!;

    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString(_deviceIdKey);

    if (id == null) {
      id = const Uuid().v4();
      await prefs.setString(_deviceIdKey, id);
    }
    
    _currentDeviceId = id;
    return id;
  }

  /// Extracts the device name and type using device_info_plus
  static Future<Map<String, String>> getDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    String name = 'Unknown Device';
    String type = 'Unknown';

    try {
      if (kIsWeb) {
        final webInfo = await deviceInfo.webBrowserInfo;
        name = webInfo.userAgent ?? 'Web Browser';
        type = 'Web';
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        name = '${androidInfo.brand} ${androidInfo.model}';
        type = 'Android';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        name = iosInfo.name;
        type = 'iPhone';
      }
    } catch (e) {
      debugPrint('Error getting device info: $e');
    }

    return {'name': name, 'type': type};
  }

  /// Register or update the session in Firestore upon login
  static Future<void> registerSession(String userId) async {
    try {
      final deviceId = await getDeviceId();
      final info = await getDeviceInfo();

      final docRef = _firestore.collection(_deviceSessionsCollection).doc(deviceId);
      
      final doc = await docRef.get();
      if (doc.exists) {
        // Update existing
        await docRef.update({
          'userId': userId,
          'deviceName': info['name'],
          'deviceType': info['type'],
          'lastActiveTime': FieldValue.serverTimestamp(),
          'loginTime': FieldValue.serverTimestamp(),
          'isActive': true,
        });
      } else {
        // Create new
        await docRef.set({
          'userId': userId,
          'deviceName': info['name'],
          'deviceType': info['type'],
          'loginTime': FieldValue.serverTimestamp(),
          'lastActiveTime': FieldValue.serverTimestamp(),
          'isActive': true,
        });
      }

      // Start listening to the session to allow force logout
      _listenToSession(deviceId);
    } catch (e) {
      debugPrint('Error registering device session: $e');
    }
  }

  /// Listen to the current device session. If it becomes inactive, force logout.
  static void _listenToSession(String deviceId) {
    _sessionListener?.cancel();
    _sessionListener = _firestore
        .collection(_deviceSessionsCollection)
        .doc(deviceId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final isActive = snapshot.data()?['isActive'] ?? false;
        if (!isActive) {
          // Force logout because session was invalidated
          debugPrint('Device session invalidated. Logging out...');
          _sessionListener?.cancel();
          AuthApi.signOut();
        }
      }
    });
  }

  /// Mark the current session as inactive (Local logout)
  static Future<void> deactivateCurrentSession() async {
    try {
      _sessionListener?.cancel();
      final deviceId = await getDeviceId();
      await _firestore
          .collection(_deviceSessionsCollection)
          .doc(deviceId)
          .update({'isActive': false});
    } catch (e) {
      debugPrint('Error deactivating current session: $e');
    }
  }

  /// Mark another device session as inactive (Remote logout)
  static Future<bool> forceLogoutDevice(String deviceId) async {
    try {
      await _firestore
          .collection(_deviceSessionsCollection)
          .doc(deviceId)
          .update({'isActive': false});
      return true;
    } catch (e) {
      debugPrint('Error force logging out device: $e');
      return false;
    }
  }

  /// Update last active time (can be called on app resume)
  static Future<void> updateLastActiveTime() async {
    try {
      if (_currentDeviceId == null) return;
      await _firestore
          .collection(_deviceSessionsCollection)
          .doc(_currentDeviceId)
          .update({'lastActiveTime': FieldValue.serverTimestamp()});
    } catch (e) {
      debugPrint('Error updating last active time: $e');
    }
  }

  /// Get all active sessions for a user
  static Stream<List<DeviceSessionModel>> getActiveSessions(String userId) {
    return _firestore
        .collection(_deviceSessionsCollection)
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => DeviceSessionModel.fromFirestore(doc))
              .toList();
          list.sort((a, b) => b.loginTime.compareTo(a.loginTime));
          return list;
        });
  }

  /// Get login history (inactive sessions) for a user
  static Stream<List<DeviceSessionModel>> getLoginHistory(String userId) {
    return _firestore
        .collection(_deviceSessionsCollection)
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: false)
        .limit(20)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => DeviceSessionModel.fromFirestore(doc))
              .toList();
          list.sort((a, b) => b.lastActiveTime.compareTo(a.lastActiveTime));
          return list;
        });
  }
}

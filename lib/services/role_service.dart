import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

/// Role constants for the app
class AppRoles {
  static const String admin = 'admin';
  static const String bd = 'bd'; // Legacy
  static const String agency = 'agency';
  static const String seller = 'seller';
  static const String host = 'host';
  static const String regular = 'regular';

  /// Permission definitions per role
  static const Map<String, List<String>> rolePermissions = {
    admin: [
      'access_admin_panel',
      'manage_users',
      'manage_roles',
      'manage_banners',
      'manage_gifts',
      'manage_notifications',
      'manage_assets',
      'manage_diamonds',
      'ban_users',
      'view_analytics',
      'manage_voice_rooms',
      'assign_roles',
      'access_bd_tools',
    ],
    bd: [
      'access_admin_panel',
      'manage_users',
      'access_bd_tools',
      'view_analytics',
    ],
    agency: [
      'manage_hosts',
      'view_analytics',
    ],
    seller: [
      'manage_diamonds',
    ],
    host: [
      'create_voice_room',
    ],
    regular: [],
  };

  static List<String> permissionsForRole(String role) {
    return rolePermissions[role.toLowerCase()] ?? [];
  }

  static bool roleHasPermission(String role, String permission) {
    final perms = permissionsForRole(role.toLowerCase());
    return perms.contains(permission);
  }
}

/// Real-time role service — wraps Firebase listener and exposes reactive role state
class RoleService extends GetxController {
  static RoleService get instance {
    if (!Get.isRegistered<RoleService>()) {
      Get.put(RoleService(), permanent: true);
    }
    return Get.find<RoleService>();
  }

  final _firestore = FirebaseFirestore.instance;

  // Reactive role state
  final RxString userRole = AppRoles.regular.obs;
  final RxList<String> userRoles = <String>[].obs;
  final RxList<String> userPermissions = <String>[].obs;
  final RxBool isLoading = false.obs;

  // Real-time Super Admin state
  final RxBool isSuperAdmin = false.obs;
  final RxMap<String, dynamic> superAdminPermissions = <String, dynamic>{}.obs;

  // Real-time Seller state
  final RxBool isSellerActive = false.obs;

  StreamSubscription<DocumentSnapshot>? _roleSubscription;
  StreamSubscription<QuerySnapshot>? _superAdminSubscription;
  StreamSubscription<QuerySnapshot>? _sellerSubscription;
  String? _currentSuperAdminUserId;
  String? _currentSellerUserId;

  /// Start listening for real-time role updates for a user
  void listenToUserRole(String userId) {
    _roleSubscription?.cancel();

    if (userId.isEmpty) {
      userRole.value = AppRoles.regular;
      userPermissions.value = [];
      _stopSuperAdminListener();
      _stopSellerListener();
      return;
    }

    isLoading.value = true;

    // Start super admin permissions listener for the user immediately
    _listenToSuperAdminPermissions(userId);

    // Start seller active status listener for the user immediately
    _listenToSellerStatus(userId);

    _roleSubscription = _firestore
        .collection('Users')
        .doc(userId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        userRole.value = AppRoles.regular;
        userPermissions.value = [];
        isLoading.value = false;
        return;
      }

      final data = snapshot.data()!;
      final rawRole = (data['userType'] ?? data['role'] ?? AppRoles.regular) as String;
      final rawRoles = List<String>.from(data['roles'] ?? []);

      // If userType or role is admin, guarantee AppRoles.admin is in the roles list
      if (rawRole == AppRoles.admin && !rawRoles.contains(AppRoles.admin)) {
        rawRoles.add(AppRoles.admin);
      }
      if ((data['isAgency'] == true || rawRole == AppRoles.agency || rawRole == 'agency_owner') && !rawRoles.contains(AppRoles.agency)) {
        rawRoles.add(AppRoles.agency);
      }
      if ((data['isHost'] == true || rawRole == AppRoles.host || (data['agencyId'] != null && data['agencyId'].toString().isNotEmpty && rawRole != AppRoles.agency && data['isAgency'] != true)) && !rawRoles.contains(AppRoles.host)) {
        rawRoles.add(AppRoles.host);
      }
      
      // Fallback to rawRole if roles list is empty
      if (rawRoles.isEmpty) {
        rawRoles.add(rawRole);
      }

      // Sync main role for backward compatibility
      userRole.value = rawRoles.isNotEmpty ? rawRoles.first : rawRole;
      userRoles.value = rawRoles;

      // Combine permissions from all assigned roles
      final combinedPermissions = <String>{};
      for (final role in rawRoles) {
        combinedPermissions.addAll(AppRoles.permissionsForRole(role));
      }
      userPermissions.value = combinedPermissions.toList();

      isLoading.value = false;

      debugPrint('🔐 [RoleService] Role updated for $userId: $rawRoles');
      debugPrint('🔐 [RoleService] Permissions: ${userPermissions.join(', ')}');
    }, onError: (e) {
      debugPrint('❌ [RoleService] Error listening to role: $e');
      isLoading.value = false;
    });
  }

  void _listenToSuperAdminPermissions(String userId) {
    if (_currentSuperAdminUserId == userId && _superAdminSubscription != null) {
      return; // Already listening to this user's super admin doc
    }

    _currentSuperAdminUserId = userId;
    _superAdminSubscription?.cancel();
    _superAdminSubscription = _firestore
        .collection('super_admins')
        .where('userId', isEqualTo: userId)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      debugPrint('🔐 [RoleService] Super Admin snapshots count: ${snapshot.docs.length} for userId: $userId');
      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        final isActive = data['isActive'] ?? false;
        debugPrint('🔐 [RoleService] Found Super Admin document: $data, isActive: $isActive');
        if (isActive) {
          isSuperAdmin.value = true;
          superAdminPermissions.value = Map<String, dynamic>.from(data['permissions'] ?? {});
          debugPrint('🔐 [RoleService] Super Admin permissions updated: ${superAdminPermissions.keys.where((k) => superAdminPermissions[k] == true).join(', ')}');
        } else {
          _clearSuperAdminState();
        }
      } else {
        _clearSuperAdminState();
      }
    }, onError: (e) {
      debugPrint('❌ [RoleService] Error listening to super admin permissions: $e');
      _clearSuperAdminState();
    });
  }

  void _clearSuperAdminState() {
    isSuperAdmin.value = false;
    superAdminPermissions.clear();
  }

  void _stopSuperAdminListener() {
    _superAdminSubscription?.cancel();
    _superAdminSubscription = null;
    _currentSuperAdminUserId = null;
    _clearSuperAdminState();
  }

  void _listenToSellerStatus(String userId) {
    if (_currentSellerUserId == userId && _sellerSubscription != null) {
      return; // Already listening to this user's seller doc
    }

    _currentSellerUserId = userId;
    _sellerSubscription?.cancel();
    _sellerSubscription = _firestore
        .collection('sellers')
        .where('userId', isEqualTo: userId)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        final isActive = data['isActive'] ?? true;
        isSellerActive.value = (isActive == true);
        debugPrint('🛒 [RoleService] Realtime seller status updated: isActive=${isSellerActive.value} for userId: $userId');
      } else {
        isSellerActive.value = false;
      }
    }, onError: (e) {
      debugPrint('❌ [RoleService] Error listening to seller status: $e');
      isSellerActive.value = false;
    });
  }

  void _stopSellerListener() {
    _sellerSubscription?.cancel();
    _sellerSubscription = null;
    _currentSellerUserId = null;
    isSellerActive.value = false;
  }

  /// Stop listening
  void stopListening() {
    _roleSubscription?.cancel();
    _roleSubscription = null;
    _stopSuperAdminListener();
    _stopSellerListener();
  }

  @override
  void onClose() {
    stopListening();
    super.onClose();
  }

  // Permission checks (reactive)
  // Maps to Admin Pane module names in super_admins
  bool get canAccessAdminPanel => isSuperAdmin.value || hasPermission('access_admin_panel');
  bool get canManageUsers => hasSuperAdminPermission('Users Management') || hasPermission('manage_users');
  bool get canManageRoles => hasSuperAdminPermission('Users Management') || hasPermission('manage_roles');
  bool get canManageBanners => hasSuperAdminPermission('Banner Management') || hasPermission('manage_banners');
  bool get canManageGifts => hasSuperAdminPermission('Gift Economy') || hasPermission('manage_gifts');
  bool get canManageDiamonds => hasSuperAdminPermission('Gift Economy') || hasPermission('manage_diamonds');
  bool get canBanUsers => hasSuperAdminPermission('Users Management') || hasPermission('ban_users');
  bool get canAssignRoles => hasSuperAdminPermission('Users Management') || hasSuperAdminPermission('Settings') || hasPermission('assign_roles');
  bool get canAccessBdTools => hasSuperAdminPermission('Verification Requests') || hasPermission('access_bd_tools');
  bool get isAdmin => userRoles.contains(AppRoles.admin);
  bool get isBD => userRoles.contains(AppRoles.bd);
  bool get isHost => userRoles.contains(AppRoles.host);
  bool get isRegular => userRoles.contains(AppRoles.regular) && userRoles.length == 1;
  bool get isAgency => userRoles.contains(AppRoles.agency);
  bool get isSeller => isSellerActive.value || (userRoles.contains(AppRoles.seller) && isSellerActive.value);

  bool hasSuperAdminPermission(String moduleName) {
    if (!isSuperAdmin.value) return false;
    return superAdminPermissions[moduleName] == true;
  }

  bool hasPermission(String permission) {
    return userPermissions.contains(permission);
  }

  /// Assign multiple roles to a user (admin-only operation)
  Future<bool> assignRoles({
    required String targetUserId,
    required List<String> newRoles,
    required String assignedByUserId,
  }) async {
    if (!canAssignRoles && !isAdmin) {
      debugPrint('❌ [RoleService] Permission denied: cannot assign roles');
      return false;
    }

    try {
      final primaryRole = newRoles.isNotEmpty ? newRoles.first : AppRoles.regular;
      
      await _firestore.collection('Users').doc(targetUserId).update({
        'userType': primaryRole,
        'roles': newRoles,
        'roleAssignedBy': assignedByUserId,
        'roleAssignedAt': FieldValue.serverTimestamp(),
        'isAgency': newRoles.contains(AppRoles.agency),
        'isHost': newRoles.contains(AppRoles.host),
      });

      // Log role assignment
      await _firestore.collection('role_assignments').add({
        'targetUserId': targetUserId,
        'newRoles': newRoles,
        'assignedBy': assignedByUserId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ [RoleService] Roles ${newRoles.join(', ')} assigned to $targetUserId');
      return true;
    } catch (e) {
      debugPrint('❌ [RoleService] Error assigning roles: $e');
      return false;
    }
  }

  static Future<List<String>> getUserRoles(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('Users').doc(userId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data.containsKey('roles') && data['roles'] is List) {
          return List<String>.from(data['roles']);
        }
        return [(data['userType'] ?? data['role'] ?? AppRoles.regular) as String];
      }
      return [AppRoles.regular];
    } catch (e) {
      debugPrint('❌ [RoleService] Error fetching user roles: $e');
      return [AppRoles.regular];
    }
  }

  /// Fetch current role for any user once (no listener)
  static Future<String> fetchUserRole(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(userId)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        return (data['userType'] ?? data['role'] ?? AppRoles.regular) as String;
      }
    } catch (e) {
      debugPrint('❌ [RoleService] fetchUserRole error: $e');
    }
    return AppRoles.regular;
  }
}

import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/material.dart';
import 'package:chat_messenger/AdminPane/screens/admin_audio_rooms_screen.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chat_messenger/services/role_service.dart';
import 'screens/admin_assets_screen.dart';
import 'screens/admin_banners_screen.dart';
import 'screens/admin_notifications_screen.dart';
import 'screens/admin_greedy_game_screen.dart';
import 'screens/admin_ban_management.dart';


/// Main AdminPane entry point — access gated by RoleService
class AdminPane extends StatefulWidget {
  const AdminPane({super.key});

  @override
  State<AdminPane> createState() => _AdminPaneState();
}

class _AdminPaneState extends State<AdminPane> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final roleService = RoleService.instance;

      if (roleService.isLoading.value) {
        return const Scaffold(
          backgroundColor: Color(0xFF1E142B),
          body: Center(child: CircularProgressIndicator(color: Colors.purpleAccent)),
        );
      }

      if (!roleService.canAccessAdminPanel) {
        return const Scaffold(
          backgroundColor: Color(0xFF1E142B),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock, color: Colors.redAccent, size: 60),
                SizedBox(height: 16),
                Text(
                  'Access Denied',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'You do not have permission to access the Admin Panel.',
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }

      // Build available tabs based on role permissions
      final List<_AdminTab> availableTabs = _buildAvailableTabs(roleService);

      if (availableTabs.isEmpty) {
        return const Scaffold(
          backgroundColor: Color(0xFF1E142B),
          body: Center(
            child: Text(
              'No admin tools available for your role.',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ),
        );
      }

      // Clamp index
      final safeIndex = _currentIndex.clamp(0, availableTabs.length - 1);

      return Scaffold(
        body: availableTabs[safeIndex].screen,
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: safeIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: const Color(0xFF1E142B),
          selectedItemColor: Colors.purpleAccent,
          unselectedItemColor: Colors.white38,
          type: BottomNavigationBarType.fixed,
          items: availableTabs
              .map((tab) => BottomNavigationBarItem(
                    icon: Icon(tab.icon),
                    label: tab.label,
                  ))
              .toList(),
        ),
      );
    });
  }

  List<_AdminTab> _buildAvailableTabs(RoleService roleService) {
    final tabs = <_AdminTab>[];

    if (roleService.canManageBanners || roleService.canManageGifts || roleService.isAdmin) {
      tabs.add(_AdminTab(
        label: 'Assets',
        icon: Icons.layers,
        screen: const AdminAssetsScreen(),
      ));
    }

    if (roleService.canManageBanners || roleService.isAdmin) {
      tabs.add(_AdminTab(
        label: 'Banners',
        icon: Icons.photo_library,
        screen: const AdminBannersScreen(),
      ));
    }

    if (roleService.isAdmin) {
      tabs.add(_AdminTab(
        label: 'Notify',
        icon: Icons.campaign,
        screen: const AdminNotificationsScreen(),
      ));
    }

    if (roleService.canAssignRoles || roleService.isAdmin) {
      tabs.add(_AdminTab(
        label: 'Roles',
        icon: Icons.manage_accounts,
        screen: const RoleManagementScreen(),
      ));
    }

    if (roleService.isAdmin) {
      tabs.add(_AdminTab(
        label: 'Rooms',
        icon: Icons.meeting_room,
        screen: const AdminAudioRoomsScreen(),
      ));
      
      tabs.add(_AdminTab(
        label: 'Bans',
        icon: Icons.gavel,
        screen: const AdminBanManagementScreen(),
      ));
    }

    if (roleService.isAdmin) {
      tabs.add(_AdminTab(
        label: 'Games',
        icon: Icons.casino,
        screen: const AdminGreedyGameScreen(),
      ));
    }

    return tabs;
  }
}

class _AdminTab {
  final String label;
  final IconData icon;
  final Widget screen;
  const _AdminTab({required this.label, required this.icon, required this.screen});
}

/// Role Management Screen for Admin to assign roles
class RoleManagementScreen extends StatefulWidget {
  const RoleManagementScreen({super.key});

  @override
  State<RoleManagementScreen> createState() => _RoleManagementScreenState();
}

class _RoleManagementScreenState extends State<RoleManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  final fb_auth.FirebaseAuth _firebaseAuth = fb_auth.FirebaseAuth.instance;
  bool _isSearching = false;
  Map<String, dynamic>? _foundUser;
  String? _errorMessage;
  List<String> _selectedRoles = [];
  bool _isSuperAdminTarget = false;

  final List<String> _allRoles = [
    AppRoles.agency,
    AppRoles.seller,
    AppRoles.regular,
  ];

  Future<void> _searchUser() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _foundUser = null;
      _errorMessage = null;
    });

    try {
      // Search by userId directly
      final doc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(query)
          .get();

      if (doc.exists) {
        setState(() {
          _foundUser = {'id': doc.id, ...doc.data()!};
          _parseUserRoles(doc.data()!);
          _isSearching = false;
        });
        return;
      }

      // Search by searchId
      final searchIdQuery = await FirebaseFirestore.instance
          .collection('Users')
          .where('searchId', isEqualTo: query)
          .limit(1)
          .get();

      if (searchIdQuery.docs.isNotEmpty) {
        final d = searchIdQuery.docs.first;
        setState(() {
          _foundUser = {'id': d.id, ...d.data()};
          _parseUserRoles(d.data());
          _isSearching = false;
        });
        return;
      }

      // Search by fullname
      final nameQuery = await FirebaseFirestore.instance
          .collection('Users')
          .where('fullname', isEqualTo: query)
          .limit(1)
          .get();

      if (nameQuery.docs.isNotEmpty) {
        final d = nameQuery.docs.first;
        setState(() {
          _foundUser = {'id': d.id, ...d.data()};
          _parseUserRoles(d.data());
          _isSearching = false;
        });
        return;
      }

      setState(() {
        _errorMessage = 'No user found with that ID, Search ID, or name.';
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Search failed: $e';
        _isSearching = false;
      });
    }
  }

  void _parseUserRoles(Map<String, dynamic> data) {
    final rawRoles = List<String>.from(data['roles'] ?? [data['userType'] ?? AppRoles.regular]);
    _isSuperAdminTarget = rawRoles.contains(AppRoles.admin);
    
    // Filter to only allowed roles to be selected
    _selectedRoles = rawRoles.where((r) => _allRoles.contains(r) && r != AppRoles.regular).toList();
  }

  Future<void> _assignRole() async {
    if (_foundUser == null) return;

    final roleService = RoleService.instance;
    // Get current admin's UID from Firebase Auth
    final String assignedBy = _firebaseAuth.currentUser?.uid ?? '';

    final success = await roleService.assignRoles(
      targetUserId: _foundUser!['id'] as String,
      newRoles: _selectedRoles.isEmpty ? [AppRoles.regular] : _selectedRoles,
      assignedByUserId: assignedBy,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Roles updated for ${_foundUser!['fullname'] ?? _foundUser!['id']}'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {
        _foundUser!['roles'] = _selectedRoles.isEmpty ? [AppRoles.regular] : List.from(_selectedRoles);
        _foundUser!['userType'] = _selectedRoles.isEmpty ? AppRoles.regular : _selectedRoles.first;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Failed to assign role. Check permissions.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0917),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E142B),
        title: const Text(
          '🛡️ Role Management',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Role summary
            Obx(() {
              final roleService = RoleService.instance;
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A148C).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user, color: Colors.purpleAccent, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Your role: ${roleService.userRole.value.toUpperCase()}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 20),

            // Search user
            const Text('Search User (by ID, Search ID, or Name)',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'User ID, Search ID, or Full Name',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF1E142B),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.search, color: Colors.white38),
                    ),
                    onSubmitted: (_) => _searchUser(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isSearching ? null : _searchUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purpleAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSearching
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.search, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Error
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent))),
                  ],
                ),
              ),

            // Found user
            if (_foundUser != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E142B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundImage: _foundUser!['photoUrl'] != null && (_foundUser!['photoUrl'] as String).isNotEmpty
                              ? NetworkImage(_foundUser!['photoUrl'])
                              : null,
                          backgroundColor: Colors.purpleAccent.withValues(alpha: 0.3),
                          child: _foundUser!['photoUrl'] == null || (_foundUser!['photoUrl'] as String).isEmpty
                              ? const Icon(Icons.person, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _foundUser!['fullname'] ?? 'Unknown',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                'ID: ${(_foundUser!['id'] as String).substring(0, 8)}... | SearchID: ${_foundUser!['searchId'] ?? 'N/A'}',
                                style: const TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                              Text(
                                'Current Roles: ${List<String>.from(_foundUser!['roles'] ?? [_foundUser!['userType'] ?? 'regular']).join(', ').toUpperCase()}',
                                style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_isSuperAdminTarget) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.redAccent),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.shield, color: Colors.redAccent),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'This user is a Super Admin. Their roles can only be managed from the Web Admin Panel.',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      const Text('Assign New Roles (Select multiple):', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _allRoles.where((r) => r != AppRoles.regular).map((role) {
                          final isSelected = _selectedRoles.contains(role);
                          Color roleColor = Colors.grey;
                          if (role == AppRoles.agency) {
                            roleColor = Colors.blueAccent;
                          } else if (role == AppRoles.seller) {
                            roleColor = Colors.orange;
                          }

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedRoles.remove(role);
                                } else {
                                  _selectedRoles.add(role);
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? roleColor.withValues(alpha: 0.25) : const Color(0xFF2A1B3D),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected ? roleColor : Colors.white12,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Text(
                                role.toUpperCase(),
                                style: TextStyle(
                                  color: isSelected ? roleColor : Colors.white54,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _assignRole,
                          icon: const Icon(Icons.save),
                          label: Text('Update Roles for ${_foundUser!['fullname'] ?? 'user'}'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purpleAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Quick access to admin screens
class AdminPaneRoutes {
  static const String assets = '/admin/assets';
  static const String banners = '/admin/banners';
  static const String notifications = '/admin/notifications';
  static const String roles = '/admin/roles';

  static Map<String, WidgetBuilder> get routes => {
    assets: (context) => const AdminAssetsScreen(),
    banners: (context) => const AdminBannersScreen(),
    notifications: (context) => const AdminNotificationsScreen(),
    roles: (context) => const RoleManagementScreen(),
  };
}

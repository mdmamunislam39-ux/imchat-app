import 'package:flutter/material.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/services/role_service.dart';
import 'package:chat_messenger/AdminPane/admin_pane.dart';
import 'package:chat_messenger/AdminPane/screens/admin_banners_screen.dart';
import 'package:chat_messenger/AdminPane/screens/admin_assets_screen.dart';
import 'package:chat_messenger/AdminPane/screens/admin_notifications_screen.dart';
import 'package:chat_messenger/AdminPane/screens/admin_official_channels_screen.dart';
import 'package:chat_messenger/AdminPane/screens/admin_reports_analytics.dart';
import 'package:chat_messenger/AdminPane/screens/admin_settings_screen.dart';
import 'package:chat_messenger/AdminPane/screens/admin_game_management_screen.dart';
import 'package:chat_messenger/AdminPane/screens/admin_room_id_customization_screen.dart';
import 'package:chat_messenger/AdminPane/screens/admin_greedy_game_screen.dart';
import 'package:chat_messenger/AdminPane/screens/admin_audio_rooms_screen.dart';
import 'package:chat_messenger/AdminPane/screens/admin_invitation_reward_screen.dart';
import 'package:chat_messenger/AdminPane/screens/admin_payment_management_screen.dart';
import 'package:chat_messenger/AdminPane/screens/admin_recharge_requests_screen.dart';
import 'package:chat_messenger/AdminPane/screens/admin_agora_settings_screen.dart';

class RoleDashboardScreen extends StatefulWidget {
  final User currentUser;
  const RoleDashboardScreen({super.key, required this.currentUser});

  @override
  State<RoleDashboardScreen> createState() => _RoleDashboardScreenState();
}

class _RoleDashboardScreenState extends State<RoleDashboardScreen> {
  Worker? _roleWorker;
  Worker? _superAdminWorker;

  @override
  void initState() {
    super.initState();
    
    // Listen to changes and pop if permissions are revoked
    _roleWorker = ever(RoleService.instance.userRole, (role) {
      _checkAccess();
    });
    
    // Also listen to Super Admin state
    _superAdminWorker = ever(RoleService.instance.isSuperAdmin, (isSuperAdmin) {
      _checkAccess();
    });
    
    // Check initially after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAccess();
    });
  }

  void _checkAccess() {
    if (!mounted) return;
    final roleService = RoleService.instance;
    if (roleService.userRole.value != AppRoles.admin && !roleService.isSuperAdmin.value && !roleService.isBD) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Access Revoked'),
        backgroundColor: Colors.red,
      ));
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    _roleWorker?.dispose();
    _superAdminWorker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final roleService = RoleService.instance;
      
      if (roleService.isLoading.value) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }

      if (roleService.userRole.value != AppRoles.admin && !roleService.isSuperAdmin.value && !roleService.isBD) {
        return const Scaffold(
          body: Center(child: Text('Access Denied. You do not have permission to view this dashboard.')),
        );
      }

      final isSuperAdmin = roleService.userRole.value == AppRoles.admin || roleService.isSuperAdmin.value;

      return Scaffold(
        backgroundColor: const Color(0xFF0F0F1A),
        appBar: AppBar(
          title: Text(isSuperAdmin ? 'Admin Dashboard' : 'BD Dashboard', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          backgroundColor: const Color(0xFF1A1A2E),
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1A1A2E), Color(0xFF0F0F1A)],
            )
          ),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (!isSuperAdmin) ...[
                _buildDashboardCard('Agency Management', Icons.business, Colors.orange),
                _buildDashboardCard('Diamond Seller Management', Icons.monetization_on, Colors.orangeAccent),
              ] else ...[
                _buildAdminPaneCard('Full Management Features (Admin Pane)', Icons.admin_panel_settings, Colors.purpleAccent),
                _buildCardBase('Invitation Reward Setting', Icons.card_giftcard, Colors.pinkAccent, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminInvitationRewardScreen()));
                }),
                _buildCardBase('Payment Management', Icons.payments_rounded, const Color(0xFF00B074), () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPaymentManagementScreen()));
                }),
                _buildCardBase('Recharge Requests', Icons.receipt_long_rounded, Colors.tealAccent, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminRechargeRequestsScreen()));
                }),
                _buildCardBase('Agora RTC Settings', Icons.cell_tower_rounded, Colors.purpleAccent, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminAgoraSettingsScreen()));
                }),
                ...roleService.superAdminPermissions.entries
                    .where((entry) => entry.value == true)
                    .map((entry) => _buildModuleCard(entry.key)),
              ],
            ],
          ),
        ),
      );
    });
  }

  Widget _buildAdminPaneCard(String title, IconData icon, Color color) {
    return _buildCardBase(title, icon, color, () {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPane()));
    });
  }

  Widget _buildModuleCard(String moduleName) {
    IconData icon;
    Color color;

    switch (moduleName) {
      case 'Users Management':
        icon = Icons.people;
        color = Colors.blue;
        break;
      case 'Verification Requests':
        icon = Icons.verified;
        color = Colors.green;
        break;
      case 'System Stats':
        icon = Icons.analytics;
        color = Colors.teal;
        break;
      case 'Settings':
        icon = Icons.settings;
        color = Colors.grey;
        break;
      case 'Banner Management':
        icon = Icons.photo_library;
        color = Colors.deepOrange;
        break;
      case 'Official Channels':
        icon = Icons.campaign;
        color = Colors.pink;
        break;
      case 'Official Items':
        icon = Icons.store;
        color = Colors.purple;
        break;
      case 'Game Management':
        icon = Icons.sports_esports;
        color = Colors.amber;
        break;
      case 'Greedy Game Settings':
        icon = Icons.casino;
        color = Colors.orangeAccent;
        break;
      case 'Custom Room IDs':
        icon = Icons.star;
        color = Colors.indigoAccent;
        break;
      case 'Gift Economy':
        icon = Icons.card_giftcard;
        color = Colors.redAccent;
        break;
      default:
        icon = Icons.extension;
        color = Colors.blueGrey;
    }

    return _buildCardBase(moduleName, icon, color, () {
      Widget? destination;
      
      switch (moduleName) {
        case 'Users Management':
          destination = const RoleManagementScreen();
          break;
        case 'Banner Management':
          destination = const AdminBannersScreen();
          break;
        case 'Gift Economy':
        case 'Official Items':
          destination = const AdminAssetsScreen();
          break;
        case 'Official Channels':
          destination = const AdminOfficialChannelsScreen();
          break;
        case 'Verification Requests':
          destination = const AdminNotificationsScreen();
          break;
        case 'System Stats':
          destination = const AdminReportsAnalytics();
          break;
        case 'Settings':
          destination = const AdminSettingsScreen();
          break;
        case 'Voice Rooms':
          destination = const AdminAudioRoomsScreen();
          break;
        case 'Game Management':
          destination = const AdminGameManagementScreen();
          break;
        case 'Greedy Game Settings':
          destination = const AdminGreedyGameScreen();
          break;
        case 'Custom Room IDs':
          destination = const AdminRoomIdCustomizationScreen();
          break;
      }

      if (destination != null) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => destination!));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$moduleName is coming soon!'),
          backgroundColor: color,
        ));
      }
    });
  }

  Widget _buildDashboardCard(String title, IconData icon, Color color) {
    return _buildCardBase(title, icon, color, () {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$title opening...'),
        backgroundColor: color,
      ));
    });
  }

  Widget _buildCardBase(String title, IconData icon, Color color, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF22223B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 10, spreadRadius: 2)
        ],
      ),
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
          trailing: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.chevron_right, color: Colors.white54, size: 20),
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}

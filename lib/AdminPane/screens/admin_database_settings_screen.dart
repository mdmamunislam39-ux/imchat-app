import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/services/global_settings_service.dart';
import 'package:chat_messenger/services/vps_api_service.dart';

/// Admin screen to dynamically configure Dual-Engine Database & VPS Backend:
/// 1. Master Engine Switch (Firebase Cloud vs. VPS PostgreSQL Server)
/// 2. VPS Backend Endpoints (Base REST URL, WebSocket URL, Connection Health Test)
/// 3. Firebase Auth & FCM Notification status
/// Stored in Firestore: global_settings/app_settings & global_settings/server_config
class AdminDatabaseSettingsScreen extends StatefulWidget {
  const AdminDatabaseSettingsScreen({super.key});

  @override
  State<AdminDatabaseSettingsScreen> createState() => _AdminDatabaseSettingsScreenState();
}

class _AdminDatabaseSettingsScreenState extends State<AdminDatabaseSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;

  // Active Database/Backend Engine ('FIREBASE' or 'VPS')
  String _activeEngine = 'FIREBASE';
  bool _autoFailoverToFirebase = true;

  // VPS Server Controllers
  final TextEditingController _vpsBaseUrlController = TextEditingController();
  final TextEditingController _vpsSocketUrlController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isTestingConnection = false;
  String? _testResultStatus;
  String? _testResultMessage;
  bool _testSuccess = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  @override
  void dispose() {
    _vpsBaseUrlController.dispose();
    _vpsSocketUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentSettings() async {
    setState(() => _isLoading = true);
    try {
      final appDoc = await _firestore.collection('global_settings').doc('app_settings').get();
      if (appDoc.exists && appDoc.data() != null) {
        final data = appDoc.data()!;
        if (data.containsKey('activeBackendEngine') && data['activeBackendEngine'] != null) {
          _activeEngine = data['activeBackendEngine'].toString().trim().toUpperCase();
        }
        if (data.containsKey('vpsBaseUrl') && data['vpsBaseUrl'] != null) {
          _vpsBaseUrlController.text = data['vpsBaseUrl'].toString().trim();
        }
        if (data.containsKey('vpsSocketUrl') && data['vpsSocketUrl'] != null) {
          _vpsSocketUrlController.text = data['vpsSocketUrl'].toString().trim();
        }
        if (data.containsKey('autoFailoverBackendToFirebase') && data['autoFailoverBackendToFirebase'] != null) {
          _autoFailoverToFirebase = data['autoFailoverBackendToFirebase'] == true;
        }
      } else {
        if (Get.isRegistered<GlobalSettingsService>()) {
          final settings = Get.find<GlobalSettingsService>();
          _activeEngine = settings.activeBackendEngine.value;
          _vpsBaseUrlController.text = settings.vpsBaseUrl.value;
          _vpsSocketUrlController.text = settings.vpsSocketUrl.value;
          _autoFailoverToFirebase = settings.autoFailoverBackendToFirebase.value;
        } else {
          _activeEngine = 'FIREBASE';
        }
      }
    } catch (e) {
      debugPrint('[AdminDatabaseSettings] Error loading settings: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _testVpsConnection() async {
    final url = _vpsBaseUrlController.text.trim();
    if (url.isEmpty) {
      setState(() {
        _testResultStatus = 'Missing URL';
        _testResultMessage = 'Please enter a VPS Base URL to test.';
        _testSuccess = false;
      });
      return;
    }

    setState(() {
      _isTestingConnection = true;
      _testResultStatus = null;
      _testResultMessage = null;
    });

    try {
      final apiService = Get.isRegistered<VpsApiService>() ? Get.find<VpsApiService>() : Get.put(VpsApiService());
      final result = await apiService.checkHealth(url);

      if (result['status'] == 'ok') {
        setState(() {
          _testSuccess = true;
          _testResultStatus = 'Connected Successfully';
          _testResultMessage = 'PostgreSQL Database: Active\nSocket.io Server: Active\nLatency: Online';
        });
      } else {
        setState(() {
          _testSuccess = false;
          _testResultStatus = 'Connection Failed';
          _testResultMessage = result['message'] ?? result['error'] ?? 'Unable to connect to $url/health';
        });
      }
    } catch (e) {
      setState(() {
        _testSuccess = false;
        _testResultStatus = 'Connection Error';
        _testResultMessage = e.toString();
      });
    } finally {
      if (mounted) setState(() => _isTestingConnection = false);
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    final trimmedBaseUrl = _vpsBaseUrlController.text.trim();
    final trimmedSocketUrl = _vpsSocketUrlController.text.trim();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E142B),
        title: const Text('Update Database & Backend Settings?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Active Backend Engine will be set to: ${_activeEngine == 'VPS' ? 'VPS PostgreSQL Server' : 'Firebase Cloud (Default)'}\n\n'
          'This will take effect across all mobile client apps in real-time.',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm & Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);
    try {
      final payload = {
        'activeBackendEngine': _activeEngine,
        'vpsBaseUrl': trimmedBaseUrl,
        'vpsSocketUrl': trimmedSocketUrl,
        'vpsApiEndpoint': trimmedBaseUrl,
        'vpsWsEndpoint': trimmedSocketUrl,
        'autoFailoverBackendToFirebase': _autoFailoverToFirebase,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('global_settings').doc('app_settings').set(payload, SetOptions(merge: true));
      await _firestore.collection('global_settings').doc('server_config').set(payload, SetOptions(merge: true));

      if (Get.isRegistered<GlobalSettingsService>()) {
        final settings = Get.find<GlobalSettingsService>();
        settings.activeBackendEngine.value = _activeEngine;
        settings.vpsBaseUrl.value = trimmedBaseUrl;
        settings.vpsSocketUrl.value = trimmedSocketUrl;
        settings.autoFailoverBackendToFirebase.value = _autoFailoverToFirebase;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Database & Backend settings saved! Live sync updated.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Database & VPS Server Settings',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: 'Reload',
            onPressed: _isLoading || _isSaving ? null : _loadCurrentSettings,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.purpleAccent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoCard(),
                    const SizedBox(height: 24),

                    // MASTER DATABASE ENGINE SELECTOR
                    _buildSectionHeader('Active Database & Backend Engine', Icons.storage_rounded),
                    const SizedBox(height: 8),
                    const Text(
                      'Choose whether to route 1v1 chat, voice rooms, gifts, assets, and database operations through Firebase Cloud or self-hosted VPS PostgreSQL.',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(height: 14),
                    _buildEngineSwitch(),
                    const SizedBox(height: 28),

                    // FIREBASE PERMANENT SERVICES CARD
                    _buildSectionHeader('Permanent Firebase Cloud Core', Icons.verified_user_rounded),
                    const SizedBox(height: 8),
                    _buildFirebaseCoreInfoCard(),
                    const SizedBox(height: 28),

                    // VPS CONFIGURATION SECTION
                    _buildSectionHeader('VPS PostgreSQL Server Configuration', Icons.dns_rounded),
                    const SizedBox(height: 8),
                    const Text(
                      'Configure your self-hosted VPS REST API and Socket.io endpoints for zero-database cost operation.',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _vpsBaseUrlController,
                      style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
                      decoration: _inputDecoration(
                        hintText: 'https://api.yourdomain.com',
                        labelText: 'VPS Base REST API URL',
                        suffixIcon: const Icon(Icons.http_rounded, color: Colors.white54, size: 20),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _vpsSocketUrlController,
                      style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
                      decoration: _inputDecoration(
                        hintText: 'wss://api.yourdomain.com',
                        labelText: 'VPS WebSocket / Socket.io URL',
                        suffixIcon: const Icon(Icons.electrical_services_rounded, color: Colors.white54, size: 20),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Test Connection Button
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.tealAccent,
                        side: const BorderSide(color: Colors.tealAccent),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onPressed: _isTestingConnection ? null : _testVpsConnection,
                      icon: _isTestingConnection
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.tealAccent, strokeWidth: 2))
                          : const Icon(Icons.network_check_rounded, size: 18),
                      label: Text(_isTestingConnection ? 'Testing Connection...' : 'Test VPS Server Health'),
                    ),

                    // Test Result Display
                    if (_testResultStatus != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _testSuccess ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _testSuccess ? Colors.green : Colors.redAccent),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(_testSuccess ? Icons.check_circle : Icons.error_outline, color: _testSuccess ? Colors.green : Colors.redAccent, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_testResultStatus!, style: TextStyle(color: _testSuccess ? Colors.green : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                                  if (_testResultMessage != null) ...[
                                    const SizedBox(height: 4),
                                    Text(_testResultMessage!, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Failover switch
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: Colors.purpleAccent,
                      title: const Text(
                        'Auto-Failover to Firebase if VPS is offline',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text(
                        'Automatically falls back to Firebase Cloud if the VPS server experiences downtime.',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      value: _autoFailoverToFirebase,
                      onChanged: (val) => setState(() => _autoFailoverToFirebase = val),
                    ),

                    const SizedBox(height: 32),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purpleAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 4,
                        ),
                        onPressed: _isSaving ? null : _saveSettings,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.save_rounded),
                        label: Text(
                          _isSaving ? 'Saving Changes...' : 'Save & Sync Backend Settings',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildEngineSwitch() {
    final isFirebase = _activeEngine == 'FIREBASE';
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _activeEngine = 'FIREBASE'),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isFirebase ? Colors.purpleAccent : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_done_rounded, color: isFirebase ? Colors.white : Colors.white54, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Firebase Cloud',
                      style: TextStyle(
                        color: isFirebase ? Colors.white : Colors.white54,
                        fontWeight: isFirebase ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _activeEngine = 'VPS'),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: !isFirebase ? Colors.purpleAccent : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.dns_rounded, color: !isFirebase ? Colors.white : Colors.white54, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'VPS PostgreSQL',
                      style: TextStyle(
                        color: !isFirebase ? Colors.white : Colors.white54,
                        fontWeight: !isFirebase ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFirebaseCoreInfoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161626),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock_clock_rounded, color: Colors.blueAccent, size: 18),
              SizedBox(width: 8),
              Text(
                'Always Secured by Firebase Core',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            '• Firebase Authentication & UID remain active in all modes.\n'
            '• Firebase Cloud Messaging (FCM) handles push notifications.\n'
            '• Switching to VPS eliminates Firestore read/write costs for chats, rooms, gifts, and wallets.',
            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E142B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.purpleAccent.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.sync_alt_rounded, color: Colors.purpleAccent, size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dual-Backend Dynamic Architecture',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                SizedBox(height: 4),
                Text(
                  'Easily switch between Firebase Cloud and self-hosted VPS PostgreSQL server at any time. Existing Firebase operations remain 100% intact with zero breaking changes.',
                  style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.purpleAccent, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({required String hintText, String? labelText, Widget? suffixIcon}) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
      hintText: hintText,
      hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
      filled: true,
      fillColor: const Color(0xFF1A1A2E),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.purpleAccent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }
}

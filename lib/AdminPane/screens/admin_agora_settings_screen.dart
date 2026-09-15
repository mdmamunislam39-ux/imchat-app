import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/services/global_settings_service.dart';

/// Admin screen to dynamically configure Agora RTC App ID & App Certificate
/// Stored in Firestore: global_settings/app_settings
class AdminAgoraSettingsScreen extends StatefulWidget {
  const AdminAgoraSettingsScreen({super.key});

  @override
  State<AdminAgoraSettingsScreen> createState() => _AdminAgoraSettingsScreenState();
}

class _AdminAgoraSettingsScreenState extends State<AdminAgoraSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;

  // Default hardcoded fallbacks
  static const String _defaultAppId = 'c74eafbb98784225bae6be9b7e7f6225';
  static const String _defaultCertificate = 'eb4c5875fba74804b9d348882d7365f0';

  final TextEditingController _appIdController = TextEditingController();
  final TextEditingController _certificateController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _obscureCert = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  @override
  void dispose() {
    _appIdController.dispose();
    _certificateController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentSettings() async {
    setState(() => _isLoading = true);
    try {
      final doc = await _firestore.collection('global_settings').doc('app_settings').get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _appIdController.text = (data['agoraAppId'] ?? _defaultAppId).toString().trim();
        final cert = data['agoraAppCertificate'] ?? data['agoraCertificate'] ?? _defaultCertificate;
        _certificateController.text = cert.toString().trim();
      } else {
        if (Get.isRegistered<GlobalSettingsService>()) {
          final settings = Get.find<GlobalSettingsService>();
          _appIdController.text = settings.agoraAppId.value;
          _certificateController.text = settings.agoraCertificate.value;
        } else {
          _appIdController.text = _defaultAppId;
          _certificateController.text = _defaultCertificate;
        }
      }
    } catch (e) {
      debugPrint('[AdminAgoraSettings] Error loading credentials: $e');
      _appIdController.text = _defaultAppId;
      _certificateController.text = _defaultCertificate;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    final trimmedAppId = _appIdController.text.trim();
    final trimmedCert = _certificateController.text.trim();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E142B),
        title: const Text('Update Agora Credentials?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'Changing Agora App ID or Certificate affects all active voice rooms, audio calls, and video calls in real-time.\n\nMake sure the credentials are correct from your Agora Console.',
          style: TextStyle(color: Colors.white70, fontSize: 14),
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
      await _firestore.collection('global_settings').doc('app_settings').set({
        'agoraAppId': trimmedAppId,
        'agoraAppCertificate': trimmedCert,
        'agoraCertificate': trimmedCert,
        'agoraUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Update in-memory reactive values
      if (Get.isRegistered<GlobalSettingsService>()) {
        final settings = Get.find<GlobalSettingsService>();
        settings.agoraAppId.value = trimmedAppId;
        settings.agoraCertificate.value = trimmedCert;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Agora credentials saved! Live sync updated.'),
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

  Future<void> _resetToDefaults() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E142B),
        title: const Text('Reset to Defaults?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'This will restore the original default Agora App ID and Certificate.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _appIdController.text = _defaultAppId;
      _certificateController.text = _defaultCertificate;
      await _saveSettings();
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
          'Agora RTC Settings',
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
                    // Status & Architecture info banner
                    _buildInfoCard(),
                    const SizedBox(height: 24),

                    // App ID Section
                    _buildSectionHeader('Agora App ID', Icons.vpn_key_rounded),
                    const SizedBox(height: 8),
                    const Text(
                      'Unique project identifier from Agora.io Console. Required for both client and server connection.',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _appIdController,
                      style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
                      decoration: _inputDecoration(
                        hintText: 'e.g. c74eafbb98784225bae6be9b7e7f6225',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.copy, color: Colors.white54, size: 20),
                          tooltip: 'Copy App ID',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _appIdController.text.trim()));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('App ID copied to clipboard')),
                            );
                          },
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Agora App ID cannot be empty';
                        }
                        if (val.trim().length < 16) {
                          return 'App ID seems too short (usually 32 hex characters)';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 28),

                    // App Certificate Section
                    _buildSectionHeader('Agora App Certificate', Icons.security_rounded),
                    const SizedBox(height: 8),
                    const Text(
                      'Secret primary certificate from Agora.io Console. Used by Firebase Cloud Functions to sign secure RTC tokens.',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _certificateController,
                      obscureText: _obscureCert,
                      style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
                      decoration: _inputDecoration(
                        hintText: 'e.g. eb4c5875fba74804b9d348882d7365f0',
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                _obscureCert ? Icons.visibility_off : Icons.visibility,
                                color: Colors.white54,
                                size: 20,
                              ),
                              tooltip: _obscureCert ? 'Show Certificate' : 'Hide Certificate',
                              onPressed: () => setState(() => _obscureCert = !_obscureCert),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy, color: Colors.white54, size: 20),
                              tooltip: 'Copy Certificate',
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: _certificateController.text.trim()));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Certificate copied to clipboard')),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Agora App Certificate cannot be empty';
                        }
                        if (val.trim().length < 16) {
                          return 'Certificate seems too short (usually 32 hex characters)';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 36),

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
                          _isSaving ? 'Saving Changes...' : 'Save & Sync Agora Settings',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Reset to Defaults Button
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white54,
                          side: const BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isSaving ? null : _resetToDefaults,
                        icon: const Icon(Icons.restore, size: 18),
                        label: const Text('Reset to Default Project Credentials'),
                      ),
                    ),
                  ],
                ),
              ),
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
                  'Real-Time Live Sync Active',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                SizedBox(height: 4),
                Text(
                  'Changes made here update Firestore immediately. Firebase Cloud Functions dynamically signs RTC tokens with these credentials with 0ms audio latency.',
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

  InputDecoration _inputDecoration({required String hintText, Widget? suffixIcon}) {
    return InputDecoration(
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

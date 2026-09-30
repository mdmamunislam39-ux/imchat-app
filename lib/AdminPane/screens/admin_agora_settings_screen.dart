import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/services/global_settings_service.dart';

/// Admin screen to dynamically configure Dual-Engine RTC:
/// 1. Master Engine Switch (Agora vs. LiveKit VPS)
/// 2. LiveKit VPS Server (URL, API Key, API Secret, Auto Failover)
/// 3. Agora RTC (App ID & App Certificate)
/// Stored in Firestore: global_settings/app_settings & global_settings/server_config
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

  // Engine Switch State ('AGORA' or 'LIVEKIT')
  String _activeEngine = 'AGORA';
  bool _autoFailoverToAgora = true;

  // Agora Controllers
  final TextEditingController _appIdController = TextEditingController();
  final TextEditingController _certificateController = TextEditingController();

  // LiveKit Controllers
  final TextEditingController _livekitUrlController = TextEditingController();
  final TextEditingController _livekitKeyController = TextEditingController();
  final TextEditingController _livekitSecretController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _obscureAgoraCert = true;
  bool _obscureLivekitSecret = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  @override
  void dispose() {
    _appIdController.dispose();
    _certificateController.dispose();
    _livekitUrlController.dispose();
    _livekitKeyController.dispose();
    _livekitSecretController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentSettings() async {
    setState(() => _isLoading = true);
    try {
      // 1. Load app_settings
      final appDoc = await _firestore.collection('global_settings').doc('app_settings').get();
      if (appDoc.exists && appDoc.data() != null) {
        final data = appDoc.data()!;
        _appIdController.text = (data['agoraAppId'] ?? _defaultAppId).toString().trim();
        final cert = data['agoraAppCertificate'] ?? data['agoraCertificate'] ?? _defaultCertificate;
        _certificateController.text = cert.toString().trim();

        if (data.containsKey('activeRtcEngine') && data['activeRtcEngine'] != null) {
          _activeEngine = data['activeRtcEngine'].toString().trim().toUpperCase();
        }
        if (data.containsKey('livekitServerUrl') && data['livekitServerUrl'] != null) {
          _livekitUrlController.text = data['livekitServerUrl'].toString().trim();
        }
        if (data.containsKey('livekitApiKey') && data['livekitApiKey'] != null) {
          _livekitKeyController.text = data['livekitApiKey'].toString().trim();
        }
        if (data.containsKey('livekitApiSecret') && data['livekitApiSecret'] != null) {
          _livekitSecretController.text = data['livekitApiSecret'].toString().trim();
        }
        if (data.containsKey('autoFailoverRtcToAgora') && data['autoFailoverRtcToAgora'] != null) {
          _autoFailoverToAgora = data['autoFailoverRtcToAgora'] == true;
        }
      } else {
        if (Get.isRegistered<GlobalSettingsService>()) {
          final settings = Get.find<GlobalSettingsService>();
          _appIdController.text = settings.agoraAppId.value;
          _certificateController.text = settings.agoraCertificate.value;
          _activeEngine = settings.activeRtcEngine.value;
          _livekitUrlController.text = settings.livekitServerUrl.value;
          _livekitKeyController.text = settings.livekitApiKey.value;
          _livekitSecretController.text = settings.livekitApiSecret.value;
          _autoFailoverToAgora = settings.autoFailoverRtcToAgora.value;
        } else {
          _appIdController.text = _defaultAppId;
          _certificateController.text = _defaultCertificate;
          _activeEngine = 'AGORA';
        }
      }

      // 2. Load server_config (if exists, fallback / cross-check)
      final serverDoc = await _firestore.collection('global_settings').doc('server_config').get();
      if (serverDoc.exists && serverDoc.data() != null) {
        final sData = serverDoc.data()!;
        if (_livekitUrlController.text.isEmpty && sData['vpsRtcEndpoint'] != null) {
          _livekitUrlController.text = sData['vpsRtcEndpoint'].toString().trim();
        }
        if (_livekitKeyController.text.isEmpty && sData['vpsRtcAuthToken'] != null) {
          _livekitKeyController.text = sData['vpsRtcAuthToken'].toString().trim();
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
    final trimmedLivekitUrl = _livekitUrlController.text.trim();
    final trimmedLivekitKey = _livekitKeyController.text.trim();
    final trimmedLivekitSecret = _livekitSecretController.text.trim();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E142B),
        title: const Text('Update RTC Streaming Settings?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Active Engine will be set to: ${_activeEngine == 'LIVEKIT' ? 'LiveKit (VPS WebRTC)' : 'Agora RTC Cloud'}\n\n'
          'This will instantly take effect across all mobile client apps in real-time.',
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
        'activeRtcEngine': _activeEngine,
        'agoraAppId': trimmedAppId,
        'agoraAppCertificate': trimmedCert,
        'agoraCertificate': trimmedCert,
        'livekitServerUrl': trimmedLivekitUrl,
        'livekitApiKey': trimmedLivekitKey,
        'livekitApiSecret': trimmedLivekitSecret,
        'autoFailoverRtcToAgora': _autoFailoverToAgora,
        'vpsRtcEndpoint': trimmedLivekitUrl,
        'vpsRtcAuthToken': trimmedLivekitKey,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Write to all documents for unified sync across App and Backend VPS
      await _firestore.collection('global_settings').doc('app_settings').set(payload, SetOptions(merge: true));
      await _firestore.collection('global_settings').doc('server_config').set(payload, SetOptions(merge: true));
      await _firestore.collection('system_configs').doc('rtc_engine_settings').set(payload, SetOptions(merge: true));

      // Update in-memory reactive values
      if (Get.isRegistered<GlobalSettingsService>()) {
        final settings = Get.find<GlobalSettingsService>();
        settings.activeRtcEngine.value = _activeEngine;
        settings.agoraAppId.value = trimmedAppId;
        settings.agoraCertificate.value = trimmedCert;
        settings.livekitServerUrl.value = trimmedLivekitUrl;
        settings.livekitApiKey.value = trimmedLivekitKey;
        settings.livekitApiSecret.value = trimmedLivekitSecret;
        settings.autoFailoverRtcToAgora.value = _autoFailoverToAgora;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('RTC Engine settings saved! Live sync updated.'),
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
          'This will restore default Agora settings and set Active Engine to Agora Cloud.',
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
      _activeEngine = 'AGORA';
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
          'RTC Engine & Streaming Settings',
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

                    // MASTER RTC ENGINE SELECTOR
                    _buildSectionHeader('Active RTC Streaming Engine', Icons.tune_rounded),
                    const SizedBox(height: 8),
                    const Text(
                      'Choose which WebRTC engine powers all live audio rooms, video rooms, and 1-on-1 calls.',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(height: 14),
                    _buildEngineSwitch(),
                    const SizedBox(height: 28),

                    // LIVEKIT / VPS CONFIGURATION SECTION
                    _buildSectionHeader('LiveKit / VPS WebRTC Server', Icons.dns_rounded),
                    const SizedBox(height: 8),
                    const Text(
                      'Configure your self-hosted LiveKit instance on VPS for zero-cost per-minute unlimited streaming.',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _livekitUrlController,
                      style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
                      decoration: _inputDecoration(
                        hintText: 'wss://livekit.yourdomain.com',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.link, color: Colors.white54, size: 20),
                          tooltip: 'Server WebSocket URL',
                          onPressed: () {},
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // LiveKit API Key & Secret
                    TextFormField(
                      controller: _livekitKeyController,
                      style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
                      decoration: _inputDecoration(
                        hintText: 'LiveKit API Key (e.g. devkey / APIName)',
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _livekitSecretController,
                      obscureText: _obscureLivekitSecret,
                      style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
                      decoration: _inputDecoration(
                        hintText: 'LiveKit API Secret',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureLivekitSecret ? Icons.visibility_off : Icons.visibility,
                            color: Colors.white54,
                            size: 20,
                          ),
                          onPressed: () => setState(() => _obscureLivekitSecret = !_obscureLivekitSecret),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Failover switch
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: Colors.purpleAccent,
                      title: const Text(
                        'Auto-Failover to Agora if VPS is offline',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text(
                        'Automatically routes calls to Agora if VPS LiveKit connection fails.',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      value: _autoFailoverToAgora,
                      onChanged: (val) => setState(() => _autoFailoverToAgora = val),
                    ),

                    const SizedBox(height: 28),

                    // AGORA CONFIGURATION SECTION
                    _buildSectionHeader('Agora RTC Cloud Engine', Icons.cloud_done_rounded),
                    const SizedBox(height: 8),
                    const Text(
                      'Primary cloud RTC engine and instant backup fallback. Configured from Agora.io Console.',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _appIdController,
                      style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
                      decoration: _inputDecoration(
                        hintText: 'Agora App ID (32 hex characters)',
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
                        return null;
                      },
                    ),

                    const SizedBox(height: 14),

                    // Agora App Certificate
                    TextFormField(
                      controller: _certificateController,
                      obscureText: _obscureAgoraCert,
                      style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
                      decoration: _inputDecoration(
                        hintText: 'Agora App Certificate',
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                _obscureAgoraCert ? Icons.visibility_off : Icons.visibility,
                                color: Colors.white54,
                                size: 20,
                              ),
                              onPressed: () => setState(() => _obscureAgoraCert = !_obscureAgoraCert),
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
                          _isSaving ? 'Saving Changes...' : 'Save & Sync RTC Settings',
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
                        label: const Text('Reset to Default Agora Settings'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildEngineSwitch() {
    final isAgora = _activeEngine == 'AGORA';
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
              onTap: () => setState(() => _activeEngine = 'AGORA'),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isAgora ? Colors.purpleAccent : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_done_rounded, color: isAgora ? Colors.white : Colors.white54, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Agora Cloud',
                      style: TextStyle(
                        color: isAgora ? Colors.white : Colors.white54,
                        fontWeight: isAgora ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _activeEngine = 'LIVEKIT'),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: !isAgora ? Colors.purpleAccent : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.dns_rounded, color: !isAgora ? Colors.white : Colors.white54, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'LiveKit (VPS)',
                      style: TextStyle(
                        color: !isAgora ? Colors.white : Colors.white54,
                        fontWeight: !isAgora ? FontWeight.bold : FontWeight.normal,
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
                  'Dual-Engine Real-Time Sync Active',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                SizedBox(height: 4),
                Text(
                  'Easily switch between Agora Cloud and self-hosted VPS LiveKit at any time. Changes sync instantly across all user devices.',
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

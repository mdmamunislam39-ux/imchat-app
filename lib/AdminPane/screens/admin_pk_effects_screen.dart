// ignore_for_file: deprecated_member_use
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svga/flutter_svga.dart';
import '../../models/video_pk_models.dart';

/// Admin Screen to configure PK Battle visual animations & effects
class AdminPkEffectsScreen extends StatefulWidget {
  const AdminPkEffectsScreen({super.key});

  @override
  State<AdminPkEffectsScreen> createState() => _AdminPkEffectsScreenState();
}

class _AdminPkEffectsScreenState extends State<AdminPkEffectsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEnabled = true;
  int _countdownSeconds = 3;

  final TextEditingController _countdownCtrl = TextEditingController();
  final TextEditingController _openingCtrl = TextEditingController();
  final TextEditingController _progressCtrl = TextEditingController();
  final TextEditingController _winnerCtrl = TextEditingController();
  final TextEditingController _drawCtrl = TextEditingController();

  final Map<String, bool> _uploadingState = {};

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _countdownCtrl.dispose();
    _openingCtrl.dispose();
    _progressCtrl.dispose();
    _winnerCtrl.dispose();
    _drawCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    setState(() => _isLoading = true);
    try {
      final doc = await _firestore.collection('app_config').doc('pk_effects').get();
      if (doc.exists && doc.data() != null) {
        final config = PkEffectsConfig.fromMap(doc.data()!);
        _countdownCtrl.text = config.countdownSvgaUrl ?? '';
        _openingCtrl.text = config.openingSvgaUrl ?? '';
        _progressCtrl.text = config.progressSvgaUrl ?? '';
        _winnerCtrl.text = config.winnerSvgaUrl ?? '';
        _drawCtrl.text = config.drawSvgaUrl ?? '';
        _countdownSeconds = config.countdownSeconds;
        _isEnabled = config.isEnabled;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load PK effects configuration: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveConfig() async {
    setState(() => _isSaving = true);
    try {
      final config = PkEffectsConfig(
        countdownSvgaUrl: _countdownCtrl.text.trim(),
        openingSvgaUrl: _openingCtrl.text.trim(),
        progressSvgaUrl: _progressCtrl.text.trim(),
        winnerSvgaUrl: _winnerCtrl.text.trim(),
        drawSvgaUrl: _drawCtrl.text.trim(),
        countdownSeconds: _countdownSeconds,
        isEnabled: _isEnabled,
      );

      await _firestore
          .collection('app_config')
          .doc('pk_effects')
          .set(config.toMap(), SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ PK Battle Effects successfully saved!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to save PK effects: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickAndUpload(String key, TextEditingController controller) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['svga', 'gif', 'webp', 'png', 'mp4'],
      );

      if (result == null || result.files.single.path == null) return;

      setState(() => _uploadingState[key] = true);

      final file = File(result.files.single.path!);
      final fileName = result.files.single.name;
      final extension = fileName.split('.').last;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storagePath = 'pk_effects/${key}_$timestamp.$extension';

      final ref = _storage.ref().child(storagePath);
      final uploadTask = ref.putFile(file);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      if (mounted) {
        setState(() {
          controller.text = downloadUrl;
          _uploadingState[key] = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Uploaded $fileName successfully!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingState[key] = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _previewEffect(String title, String url) {
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter or upload a URL first to preview.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final isSvga = url.toLowerCase().contains('.svga');

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF161129),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFD946EF), width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                height: 240,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Center(
                  child: isSvga
                      ? _SvgaPreviewWidget(url: url)
                      : CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.contain,
                          placeholder: (_, __) => const CircularProgressIndicator(
                            color: Color(0xFFD946EF),
                          ),
                          errorWidget: (_, __, error) => Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.broken_image,
                                  color: Colors.redAccent, size: 40),
                              const SizedBox(height: 8),
                              Text(
                                'Error loading preview: $error',
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 12),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Source: ${url.length > 40 ? '${url.substring(0, 40)}...' : url}',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0B1E),
      appBar: AppBar(
        title: const Text(
          'PK Battle Effects & SVGA Settings',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: const Color(0xFF1B1431),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _loadConfig,
            tooltip: 'Reload',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFD946EF)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFD946EF).withOpacity(0.15),
                          const Color(0xFF8B5CF6).withOpacity(0.15),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFD946EF).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD946EF).withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.sports_kabaddi_rounded,
                            color: Color(0xFFD946EF),
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Live Video Room PK Effects',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Manage SVGA animation assets for countdown, VS opening, score seam, victory, and draw.',
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _isEnabled,
                          activeColor: const Color(0xFFD946EF),
                          onChanged: (val) => setState(() => _isEnabled = val),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Countdown Duration Slider
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B1431),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Countdown Timer Before Battle',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD946EF).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$_countdownSeconds Seconds',
                                style: const TextStyle(
                                  color: Color(0xFFD946EF),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: _countdownSeconds.toDouble(),
                          min: 1,
                          max: 5,
                          divisions: 4,
                          activeColor: const Color(0xFFD946EF),
                          inactiveColor: Colors.white12,
                          onChanged: (val) =>
                              setState(() => _countdownSeconds = val.round()),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    'SVGA & Animation Assets',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 1. Countdown SVGA
                  _buildAssetCard(
                    title: '1. Countdown Effect (3-2-1)',
                    subtitle:
                        'Plays right before the battle starts. Default: built-in animated 3-2-1.',
                    key: 'countdownSvgaUrl',
                    controller: _countdownCtrl,
                    icon: Icons.timer,
                  ),

                  const SizedBox(height: 12),

                  // 2. VS Opening SVGA
                  _buildAssetCard(
                    title: '2. Battle Start / VS Opening Effect',
                    subtitle:
                        'Full-screen VS explosion animation when PK begins.',
                    key: 'openingSvgaUrl',
                    controller: _openingCtrl,
                    icon: Icons.flash_on_rounded,
                  ),

                  const SizedBox(height: 12),

                  // 3. Progress Collision Seam SVGA
                  _buildAssetCard(
                    title: '3. Score Progress Collision Seam',
                    subtitle:
                        'Moving lightning/flame animation positioned between the score bars.',
                    key: 'progressSvgaUrl',
                    controller: _progressCtrl,
                    icon: Icons.compare_arrows_rounded,
                  ),

                  const SizedBox(height: 12),

                  // 4. Winner Celebration SVGA
                  _buildAssetCard(
                    title: '4. Victory Celebration Effect',
                    subtitle:
                        'Crown, fireworks, or trophy animation celebrating the winning host.',
                    key: 'winnerSvgaUrl',
                    controller: _winnerCtrl,
                    icon: Icons.emoji_events_rounded,
                  ),

                  const SizedBox(height: 12),

                  // 5. Draw SVGA
                  _buildAssetCard(
                    title: '5. Draw / Tie Match Effect',
                    subtitle:
                        'Animation played when both hosts score equal points.',
                    key: 'drawSvgaUrl',
                    controller: _drawCtrl,
                    icon: Icons.handshake_rounded,
                  ),

                  const SizedBox(height: 28),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveConfig,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFD946EF), Color(0xFF8B5CF6)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x66D946EF),
                              blurRadius: 16,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Container(
                          alignment: Alignment.center,
                          child: _isSaving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.save_rounded, color: Colors.white),
                                    SizedBox(width: 8),
                                    Text(
                                      'Save PK Effects',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildAssetCard({
    required String title,
    required String subtitle,
    required String key,
    required TextEditingController controller,
    required IconData icon,
  }) {
    final isUploading = _uploadingState[key] ?? false;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1431),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF00E5FF), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'https://... or upload .svga / .gif / .webp',
              hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
              filled: true,
              fillColor: Colors.black26,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.white12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.white12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFD946EF)),
              ),
              suffixIcon: controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear,
                          size: 16, color: Colors.white54),
                      onPressed: () => setState(() => controller.clear()),
                    )
                  : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Upload Button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      isUploading ? null : () => _pickAndUpload(key, controller),
                  icon: isUploading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Color(0xFFD946EF)),
                          ),
                        )
                      : const Icon(Icons.upload_file,
                          size: 16, color: Color(0xFFD946EF)),
                  label: Text(
                    isUploading ? 'Uploading...' : 'Upload File',
                    style: const TextStyle(
                      color: Color(0xFFD946EF),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFD946EF), width: 1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Preview Button
              OutlinedButton.icon(
                onPressed: () => _previewEffect(title, controller.text.trim()),
                icon: const Icon(Icons.visibility,
                    size: 16, color: Color(0xFF00E5FF)),
                label: const Text(
                  'Preview',
                  style: TextStyle(
                    color: Color(0xFF00E5FF),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF00E5FF), width: 1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Helper to render SVGA preview in a dialog
class _SvgaPreviewWidget extends StatefulWidget {
  final String url;
  const _SvgaPreviewWidget({required this.url});

  @override
  State<_SvgaPreviewWidget> createState() => _SvgaPreviewWidgetState();
}

class _SvgaPreviewWidgetState extends State<_SvgaPreviewWidget>
    with SingleTickerProviderStateMixin {
  SVGAAnimationController? _controller;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = SVGAAnimationController(vsync: this);
    _loadSvga();
  }

  Future<void> _loadSvga() async {
    try {
      final videoItem = await SVGAParser.shared.decodeFromURL(widget.url);
      if (!mounted) return;
      _controller?.videoItem = videoItem;
      _controller?.repeat();
      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const CircularProgressIndicator(color: Color(0xFFD946EF));
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 36),
            const SizedBox(height: 6),
            Text(
              'Failed to load SVGA: $_error',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    if (_controller != null) {
      return SVGAImage(_controller!);
    }
    return const SizedBox();
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/admin_assets_service.dart';
import '../../components/universal_asset_widget.dart';

/// Redesigned premium asset dialog for creating and editing Gifts, Entry Effects, Frames, Badges, and Profile Skins.
class AssetFormDialog extends StatefulWidget {
  final AdminAssetsService assetsService;
  final Map<String, dynamic>? asset; // null for add, Map of existing asset details for edit
  final String initialType;

  const AssetFormDialog({
    super.key,
    required this.assetsService,
    this.asset,
    required this.initialType,
  });

  @override
  State<AssetFormDialog> createState() => _AssetFormDialogState();
}

class _AssetFormDialogState extends State<AssetFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();
  final _priceController = TextEditingController();
  final _price3dController = TextEditingController();
  final _price7dController = TextEditingController();
  final _price15dController = TextEditingController();
  final _price30dController = TextEditingController();

  late String _selectedType;
  File? _pngFile;
  File? _animationFile;
  bool _isLoading = false;
  bool _fastMode = false;
  int _starRating = 1;
  int _verifyLevel = 0;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;

    if (widget.asset != null) {
      _nameController.text = widget.asset!['name'] ?? '';
      _descriptionController.text = widget.asset!['description'] ?? '';
      _categoryController.text = widget.asset!['category'] ?? '';
      _priceController.text = widget.asset!['price']?.toString() ?? '0';
      _selectedType = widget.asset!['type'] ?? widget.initialType;
      _starRating = widget.asset!['starRating'] ?? 1;
      _verifyLevel = widget.asset!['verifyLevel'] ?? widget.asset!['verificationLevel'] ?? 0;
      if (widget.asset!['validityPrices'] != null && widget.asset!['validityPrices'] is Map) {
        final vp = Map<String, dynamic>.from(widget.asset!['validityPrices']);
        _price3dController.text = vp['3']?.toString() ?? '';
        _price7dController.text = vp['7']?.toString() ?? '';
        _price15dController.text = vp['15']?.toString() ?? '';
        _price30dController.text = vp['30']?.toString() ?? '';
      }
    } else {
      _categoryController.text = _selectedType == 'gift' ? 'love' : 'general';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _priceController.dispose();
    _price3dController.dispose();
    _price7dController.dispose();
    _price15dController.dispose();
    _price30dController.dispose();
    super.dispose();
  }

  Future<void> _pickFile(String type) async {
    try {
      debugPrint('📁 AssetFormDialog: Picking $type file...');
      final List<String> extensions;
      if (type == 'png') {
        extensions = ['png', 'jpg', 'jpeg', 'webp'];
      } else {
        // Animation file can be SVGA, MP4 (Alpha), VAP, VAR, PNG, WEBP, GIF
        extensions = ['svga', 'mp4', 'vap', 'var', 'png', 'webp', 'gif'];
      }

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: extensions,
      );

      if (result != null && result.files.isNotEmpty && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final file = File(filePath);

        if (await file.exists()) {
          setState(() {
            if (type == 'png') {
              _pngFile = file;
              debugPrint('✅ AssetFormDialog: Thumbnail file selected: $filePath');
            } else {
              _animationFile = file;
              debugPrint('✅ AssetFormDialog: Animation file selected: $filePath');
            }
          });
        } else {
          _showSnackBar('Selected file does not exist', isError: true);
        }
      }
    } catch (e) {
      debugPrint('❌ AssetFormDialog: Error picking file: $e');
      _showSnackBar('Failed to pick file: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.teal,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _saveAsset() async {
    if (!_formKey.currentState!.validate()) {
      _showSnackBar('Please fill in all required fields', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final name = _nameController.text.trim();
      final description = _descriptionController.text.trim();
      final category = _categoryController.text.trim();
      final price = int.tryParse(_priceController.text.trim()) ?? 0;

      final Map<String, dynamic> validityPrices = {};
      final p3 = int.tryParse(_price3dController.text.trim());
      if (p3 != null && p3 > 0) validityPrices['3'] = p3;
      final p7 = int.tryParse(_price7dController.text.trim());
      if (p7 != null && p7 > 0) validityPrices['7'] = p7;
      final p15 = int.tryParse(_price15dController.text.trim());
      if (p15 != null && p15 > 0) validityPrices['15'] = p15;
      final p30 = int.tryParse(_price30dController.text.trim());
      if (p30 != null && p30 > 0) validityPrices['30'] = p30;

      if (widget.asset == null) {
        // Create new
        await widget.assetsService.addAsset(
          name: name,
          type: _selectedType,
          price: price,
          category: category,
          description: description,
          pngFile: _fastMode ? null : _pngFile,
          animationFile: _fastMode ? null : _animationFile,
          skipFileUpload: _fastMode,
          starRating: _starRating,
          verifyLevel: _verifyLevel,
          validityPrices: validityPrices.isNotEmpty ? validityPrices : null,
        );
        _showSnackBar('Asset created successfully!');
        if (mounted) Navigator.of(context).pop(true);
      } else {
        // Edit existing
        await widget.assetsService.updateAsset(
          id: widget.asset!['id'],
          type: _selectedType,
          name: name,
          price: price,
          category: category,
          description: description,
          pngFile: _pngFile,
          animationFile: _animationFile,
          starRating: _starRating,
          verifyLevel: _verifyLevel,
          validityPrices: validityPrices.isNotEmpty ? validityPrices : null,
        );
        _showSnackBar('Asset updated successfully!');
        if (mounted) Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugPrint('❌ AssetFormDialog: Error saving asset: $e');
      _showSnackBar('Failed to save asset: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEdit = widget.asset != null;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Center(
        child: SingleChildScrollView(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.90,
            constraints: const BoxConstraints(maxWidth: 550),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2C2D35), Color(0xFF15161A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withAlpha(26), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(128),
                  blurRadius: 25,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            padding: const EdgeInsets.all(28),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dialog Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEdit ? 'Edit Custom Asset' : 'Redesigned Asset Upload',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white60),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white12, thickness: 1, height: 24),

                  // Real-time Preview Area (Interactive Card)
                  _buildPreviewArea(),
                  const SizedBox(height: 20),

                  // Fields Grid
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _nameController,
                          label: 'Asset Name',
                          hintText: 'Enter name',
                          validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTypeDropdown(disabled: isEdit),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _priceController,
                          label: 'Cost (Diamonds)',
                          hintText: 'e.g. 100',
                          keyboardType: TextInputType.number,
                          validator: (val) {
                            if (val == null || val.isEmpty) return 'Required';
                            if (int.tryParse(val) == null || int.parse(val) < 0) return 'Invalid';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField(
                          controller: _categoryController,
                          label: 'Category / Tag',
                          hintText: _selectedType == 'gift' ? 'love, active, VIP...' : 'general, classic...',
                          validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Star Rating and Verify Level
                  if (_selectedType == 'badge')
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Star Rating',
                                style: TextStyle(
                                    color: Colors.white.withAlpha(179),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(10),
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: Colors.white.withAlpha(20)),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    value: _starRating,
                                    dropdownColor: const Color(0xFF202125),
                                    icon: const Icon(Icons.star, color: Colors.amber),
                                    isExpanded: true,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 14),
                                    items: [1, 2, 3, 4, 5].map((rating) {
                                      return DropdownMenuItem<int>(
                                        value: rating,
                                        child: Row(
                                          children: [
                                            Text('$rating ★ '),
                                            Row(
                                              children: List.generate(
                                                rating,
                                                (index) => const Icon(Icons.star,
                                                    color: Colors.amber, size: 12),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() {
                                          _starRating = val;
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Verify Level (ভেরিফাই লেভেল)',
                                style: TextStyle(
                                    color: Colors.white.withAlpha(179),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(10),
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: Colors.white.withAlpha(20)),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    value: _verifyLevel,
                                    dropdownColor: const Color(0xFF202125),
                                    icon: const Icon(Icons.verified,
                                        color: Colors.tealAccent),
                                    isExpanded: true,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 14),
                                    items: [
                                      const DropdownMenuItem<int>(
                                        value: 0,
                                        child: Text('0 - Normal (নন-ভেরিফাই)'),
                                      ),
                                      ...List.generate(10, (index) {
                                        final lvl = index + 1;
                                        return DropdownMenuItem<int>(
                                          value: lvl,
                                          child: Row(
                                            children: [
                                              Text('Level $lvl '),
                                              const Icon(Icons.verified,
                                                  color: Colors.tealAccent, size: 14),
                                            ],
                                          ),
                                        );
                                      }),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() {
                                          _verifyLevel = val;
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Star Rating',
                          style: TextStyle(
                              color: Colors.white.withAlpha(179),
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(10),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withAlpha(20)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _starRating,
                              dropdownColor: const Color(0xFF202125),
                              icon: const Icon(Icons.star, color: Colors.amber),
                              isExpanded: true,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              items: [1, 2, 3, 4, 5].map((rating) {
                                return DropdownMenuItem<int>(
                                  value: rating,
                                  child: Row(
                                    children: [
                                      Text('$rating Star${rating > 1 ? 's' : ''} '),
                                      Row(
                                        children: List.generate(
                                          rating,
                                          (index) => const Icon(Icons.star,
                                              color: Colors.amber, size: 14),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _starRating = val;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),

                  if (_selectedType != 'gift') ...[
                    _buildTextField(
                      controller: _descriptionController,
                      label: 'Short Description',
                      hintText: 'Item description or unlock requirements...',
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // File Pickers
                  _buildFilePicker(
                    label: 'Static Preview/Thumbnail (PNG/JPG)',
                    file: _pngFile,
                    type: 'png',
                    existingUrl: isEdit ? (widget.asset!['thumbnailUrl']) : null,
                  ),
                  const SizedBox(height: 16),

                  _buildFilePicker(
                    label: 'Dynamic Animation File (SVGA / MP4 Alpha / VAP / VAR / GIF)',
                    file: _animationFile,
                    type: 'animation',
                    existingUrl: isEdit ? (widget.asset!['fileUrl']) : null,
                  ),
                  const SizedBox(height: 24),

                  // Fast Mode Checkbox (Only for testing / fast creation)
                  if (!isEdit)
                    Row(
                      children: [
                        Checkbox(
                          value: _fastMode,
                          onChanged: (val) => setState(() => _fastMode = val ?? false),
                          activeColor: Colors.tealAccent,
                          checkColor: Colors.black,
                        ),
                        const Text(
                          'Skip uploads (Fast Mode for testing)',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  const SizedBox(height: 20),

                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                        child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _saveAsset,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.tealAccent,
                          foregroundColor: Colors.black,
                          shadowColor: Colors.tealAccent.withAlpha(102),
                          elevation: 8,
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                              )
                            : Text(
                                isEdit ? 'Save Changes' : 'Upload Asset',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewArea() {
    final bool hasLocalAnim = _animationFile != null;
    final String? remoteUrl = widget.asset != null
        ? (widget.asset!['fileUrl'] ??
                widget.asset!['animationUrl'] ??
                widget.asset!['frameUrl'] ??
                widget.asset!['frameMediaUrl'] ??
                widget.asset!['svgaUrl'] ??
                widget.asset!['imageUrl'] ??
                widget.asset!['thumbnailUrl'] ??
                '')
            .toString()
        : null;
    final bool hasRemoteAnim = remoteUrl != null && remoteUrl.isNotEmpty;

    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(77),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(13)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Grid background to showcase transparent alpha blending
          Positioned.fill(
            child: Opacity(
              opacity: 0.15,
              child: CustomPaint(
                painter: GridPainter(),
              ),
            ),
          ),
          
          if (hasLocalAnim || hasRemoteAnim)
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: UniversalAssetWidget(
                  file: _animationFile,
                  url: _animationFile == null ? remoteUrl : null,
                  fit: BoxFit.contain,
                  isAlphaVideo: true,
                ),
              ),
            )
          else
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.video_library_outlined, color: Colors.tealAccent.withAlpha(153), size: 40),
                const SizedBox(height: 8),
                const Text(
                  'Real-time Player Preview Panel',
                  style: TextStyle(color: Colors.white38, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Upload animation file to play instantly',
                  style: TextStyle(color: Colors.white24, fontSize: 11),
                ),
              ],
            ),
          
          // Badge showing the active format
          if (hasLocalAnim || hasRemoteAnim)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.teal.withAlpha(204),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _getFileExtension().toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _getFileExtension() {
    if (_animationFile != null) {
      return _animationFile!.path.split('.').last.toLowerCase();
    }
    if (widget.asset != null && widget.asset!['fileUrl'] != null) {
      final String url = widget.asset!['fileUrl'];
      return url.split('?').first.split('.').last.toLowerCase();
    }
    return '';
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white.withAlpha(179), fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: Colors.white.withAlpha(77), fontSize: 13),
            filled: true,
            fillColor: Colors.white.withAlpha(10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withAlpha(20)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withAlpha(20)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.tealAccent, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeDropdown({bool disabled = false}) {
    final types = {
      'gift': '🎁 Virtual Gift',
      'entryEffect': '🚀 Entrance Effect',
      'avatarFrame': '🖼️ Avatar Frame',
      'roomTheme': '🎙️ Room Theme',
      'backgroundTheme': '🎨 Profile Skin',
      'roomEntry': '🚪 Room Entry Banner',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Asset Category Type',
          style: TextStyle(color: Colors.white.withAlpha(179), fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withAlpha(20)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedType,
              dropdownColor: const Color(0xFF202125),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
              isExpanded: true,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              items: types.entries.map((entry) {
                return DropdownMenuItem<String>(
                  value: entry.key,
                  child: Text(entry.value),
                );
              }).toList(),
              onChanged: disabled
                  ? null
                  : (val) {
                      if (val != null) {
                        setState(() {
                          _selectedType = val;
                          if (_categoryController.text == 'love' || _categoryController.text == 'general') {
                            _categoryController.text = val == 'gift' ? 'love' : 'general';
                          }
                        });
                      }
                    },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilePicker({
    required String label,
    required File? file,
    required String type,
    String? existingUrl,
  }) {
    final bool hasFile = file != null;
    final bool hasExisting = existingUrl != null && existingUrl.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white.withAlpha(179), fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(8),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withAlpha(15)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasFile
                          ? file.path.split(Platform.pathSeparator).last
                          : hasExisting
                              ? 'Default Server File Loaded'
                              : 'No File Chosen',
                      style: TextStyle(
                        color: hasFile || hasExisting ? Colors.tealAccent : Colors.white30,
                        fontSize: 13,
                        fontWeight: hasFile || hasExisting ? FontWeight.w600 : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (hasExisting && !hasFile)
                      const SizedBox(height: 2),
                    if (hasExisting && !hasFile)
                      const Text(
                        'Will retain existing file if none is chosen',
                        style: TextStyle(color: Colors.white24, fontSize: 10),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () => _pickFile(type),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withAlpha(20),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Colors.white.withAlpha(13)),
                  ),
                ),
                child: const Text('Browse', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Custom painter to draw a checkered chess grid to highlight transparent assets
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double squareSize = 10;
    final Paint lightPaint = Paint()..color = Colors.white.withAlpha(26);
    final Paint darkPaint = Paint()..color = Colors.transparent;

    for (double y = 0; y < size.height; y += squareSize) {
      for (double x = 0; x < size.width; x += squareSize) {
        final bool isLight = ((x / squareSize).floor() + (y / squareSize).floor()) % 2 == 0;
        canvas.drawRect(
          Rect.fromLTWH(x, y, squareSize, squareSize),
          isLight ? lightPaint : darkPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

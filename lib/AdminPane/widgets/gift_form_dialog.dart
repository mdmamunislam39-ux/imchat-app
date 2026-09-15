import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/gift.dart';
import '../services/gift_service.dart';

/// Dialog for adding/editing gifts
class GiftFormDialog extends StatefulWidget {
  final GiftService giftService;
  final Gift? gift; // null for add, existing gift for edit

  const GiftFormDialog({
    super.key,
    required this.giftService,
    this.gift,
  });

  @override
  State<GiftFormDialog> createState() => _GiftFormDialogState();
}

class _GiftFormDialogState extends State<GiftFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _creditsController = TextEditingController();
  final _categoryController = TextEditingController();
  final _showingTimeController = TextEditingController();
  
  File? _pngFile;
  File? _svgaFile;
  bool _isLoading = false;
  bool _fastMode = false; // Skip file uploads for testing

  @override
  void initState() {
    super.initState();
    if (widget.gift != null) {
      _nameController.text = widget.gift!.name;
      _creditsController.text = widget.gift!.credits.toString();
      _categoryController.text = widget.gift!.category;
      if (widget.gift!.showingTimeSeconds != null) {
        _showingTimeController.text = widget.gift!.showingTimeSeconds.toString();
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _creditsController.dispose();
    _categoryController.dispose();
    _showingTimeController.dispose();
    super.dispose();
  }

  Future<void> _pickFile(String type) async {
    try {
      debugPrint('📁 GiftFormDialog: Picking $type file...');
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: type == 'png' ? ['png'] : ['svga', 'mp4', 'vap'],
      );

      if (result != null && result.files.isNotEmpty && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final file = File(filePath);
        
        // Check if file exists
        if (await file.exists()) {
          setState(() {
            if (type == 'png') {
              _pngFile = file;
              debugPrint('✅ GiftFormDialog: PNG file selected: $filePath');
            } else {
              _svgaFile = file;
              debugPrint('✅ GiftFormDialog: Animation file selected: $filePath');
            }
          });
        } else {
          debugPrint('❌ GiftFormDialog: Selected file does not exist: $filePath');
          _showErrorSnackBar('Selected file does not exist');
        }
      } else {
        debugPrint('⚠️ GiftFormDialog: No file selected or file path is null');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ GiftFormDialog: Error picking file: $e');
      debugPrint('❌ GiftFormDialog: Stack trace: $stackTrace');
      _showErrorSnackBar('Failed to pick file: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _saveGift() async {
    try {
      debugPrint('🎁 GiftFormDialog: Starting save process...');
      debugPrint('🎁 GiftFormDialog: Form key state: ${_formKey.currentState}');
      
      if (!_formKey.currentState!.validate()) {
        debugPrint('❌ GiftFormDialog: Form validation failed');
        _showErrorSnackBar('Please fill in all required fields');
        return;
      }
      
      debugPrint('✅ GiftFormDialog: Form validation passed');

      setState(() => _isLoading = true);
      debugPrint('🔄 GiftFormDialog: Loading state set to true');

      final name = _nameController.text.trim();
      final creditsText = _creditsController.text.trim();
      
      // Validate name
      debugPrint('🎁 GiftFormDialog: Validating name: "$name"');
      if (name.isEmpty) {
        debugPrint('❌ GiftFormDialog: Gift name is empty');
        _showErrorSnackBar('Please enter a gift name');
        return;
      }
      debugPrint('✅ GiftFormDialog: Name validation passed');
      
      // Validate credits
      if (creditsText.isEmpty) {
        debugPrint('❌ GiftFormDialog: Credits is empty');
        _showErrorSnackBar('Please enter credits');
        return;
      }
      
      final credits = int.tryParse(creditsText);
      if (credits == null || credits < 0) {
        debugPrint('❌ GiftFormDialog: Invalid credits: $creditsText');
        _showErrorSnackBar('Please enter valid credits');
        return;
      }
      
      // Validate category
      final categoryName = _categoryController.text.trim();
      if (categoryName.isEmpty) {
        debugPrint('❌ GiftFormDialog: Category is empty');
        _showErrorSnackBar('Please enter a category');
        return;
      }
      
      // For testing: Allow gifts without files
      debugPrint('ℹ️ GiftFormDialog: Files are optional for testing');
      
      debugPrint('📝 GiftFormDialog: Gift details - Name: $name, Credits: $credits, Category: $categoryName');
      debugPrint('📁 GiftFormDialog: Files - PNG: ${_pngFile?.path}, SVGA: ${_svgaFile?.path}');

      // Optional showing time
      final showingTimeText = _showingTimeController.text.trim();
      final int? showingTimeSeconds = showingTimeText.isNotEmpty ? int.tryParse(showingTimeText) : null;

      if (widget.gift == null) {
        // Add new gift
        debugPrint('➕ GiftFormDialog: Adding new gift...');
        final giftId = await widget.giftService.addGift(
          name: name,
          category: categoryName,
          credits: credits,
          pngFile: _fastMode ? null : _pngFile,
          svgaFile: _fastMode ? null : _svgaFile,
          skipFileUpload: _fastMode,
          showingTimeSeconds: showingTimeSeconds,
        );
        debugPrint('✅ GiftFormDialog: New gift added with ID: $giftId');
        
        if (mounted) {
          Navigator.of(context).pop(true); // Return true to indicate success
        }
      } else {
        // Update existing gift
        debugPrint('✏️ GiftFormDialog: Updating existing gift with ID: ${widget.gift!.id}');
        await widget.giftService.updateGift(
          id: widget.gift!.id,
          name: name,
          category: categoryName,
          credits: credits,
          pngFile: _pngFile,
          svgaFile: _svgaFile,
          showingTimeSeconds: showingTimeSeconds,
        );
        debugPrint('✅ GiftFormDialog: Gift updated successfully');
        
        if (mounted) {
          Navigator.of(context).pop(widget.gift);
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ GiftFormDialog: Error saving gift: $e');
      debugPrint('❌ GiftFormDialog: Stack trace: $stackTrace');
      _showErrorSnackBar('Failed to save gift: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        debugPrint('🔄 GiftFormDialog: Loading state set to false');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                widget.gift == null ? 'Add New Gift' : 'Edit Gift',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              // Gift Name
              _buildTextField(
                controller: _nameController,
                label: 'Gift Name',
                hintText: 'Give a name to the gift',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter gift name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Category
              _buildTextField(
                controller: _categoryController,
                label: 'Category',
                hintText: 'Enter category name (e.g. Love, VIP, Classic)',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a category';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Credits
              _buildTextField(
                controller: _creditsController,
                label: 'Credits',
                hintText: 'Credits needed to send',
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter credits';
                  }
                  final credits = int.tryParse(value.trim());
                  if (credits == null || credits < 0) {
                    return 'Please enter valid credits';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Showing Time (Seconds)
              _buildTextField(
                controller: _showingTimeController,
                label: 'Showing Time in Seconds (Optional)',
                hintText: 'e.g. 10, 30, 60 (Leave blank for default setting)',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),

              // PNG file
              _buildFilePicker(
                label: 'PNG file',
                file: _pngFile,
                type: 'png',
                existingUrl: widget.gift?.pngUrl,
              ),
              const SizedBox(height: 16),

              // Animation file (SVGA/MP4)
              _buildFilePicker(
                label: 'Animation file (SVGA/MP4)',
                file: _svgaFile,
                type: 'svga',
                existingUrl: widget.gift?.svgaUrl,
              ),
              const SizedBox(height: 24),

              // Fast mode toggle
              Row(
                children: [
                  Checkbox(
                    value: _fastMode,
                    onChanged: (value) {
                      setState(() {
                        _fastMode = value ?? false;
                      });
                    },
                    activeColor: const Color(0xFF00BCD4),
                  ),
                  const Text(
                    'Fast Mode (Skip File Upload)',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveGift,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _fastMode ? Colors.orange : const Color(0xFF00BCD4),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          _fastMode ? 'Save (Fast Mode)' : 'Save',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label *',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label *',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  file != null
                      ? file.path.split('/').last
                      : existingUrl != null
                          ? 'Current file (${type == 'svga' ? 'SVGA/MP4/VAP' : 'PNG'})'
                          : 'No file chosen',
                  style: TextStyle(
                    color: file != null || existingUrl != null
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: () => _pickFile(type),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: const Text(
                  'Choose File',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

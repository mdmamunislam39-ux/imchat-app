import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:chat_messenger/config/theme_config.dart';

class PickImageModal extends StatelessWidget {
  const PickImageModal({super.key, required this.isAvatar});

  final bool isAvatar;
  static bool _isPickerActive = false;

  // Handle picked image
  Future<File?> _pickAndCropImage(BuildContext context, ImageSource source) async {
    if (_isPickerActive) return null;
    _isPickerActive = true;

    try {
      final XFile? pickedFile = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 80,
      );

      if (pickedFile == null) return null;

      try {
        // Set aspect ratio list
        final aspectRatioList = [
          isAvatar ? CropAspectRatioPreset.square : CropAspectRatioPreset.original,
          if (!isAvatar) ...[
            CropAspectRatioPreset.ratio16x9,
            CropAspectRatioPreset.ratio4x3,
          ],
        ];

        // Crop the image
        final CroppedFile? croppedFile = await ImageCropper().cropImage(
          sourcePath: pickedFile.path,
          maxWidth: 1080,
          maxHeight: 1080,
          compressQuality: 80,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'crop_image'.tr,
              toolbarColor: primaryColor,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: isAvatar ? CropAspectRatioPreset.square : CropAspectRatioPreset.original,
              lockAspectRatio: isAvatar,
              aspectRatioPresets: aspectRatioList,
            ),
            IOSUiSettings(
              title: 'crop_image'.tr,
              aspectRatioPresets: aspectRatioList,
            ),
          ],
        );

        if (croppedFile != null) {
          return File(croppedFile.path);
        }
      } catch (cropError) {
        debugPrint('ImageCropper fallback to original image: $cropError');
        return File(pickedFile.path);
      }

      // For background images, if user skips cropping, keep original image
      if (!isAvatar) {
        return File(pickedFile.path);
      }

      return null;
    } catch (e) {
      debugPrint('Error picking image: $e');
      return null;
    } finally {
      _isPickerActive = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(defaultRadius),
          topRight: Radius.circular(defaultRadius),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  margin: const EdgeInsets.only(left: 8.0),
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'photo'.tr,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: greyColor),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 0),
            ListTile(
              leading: const Icon(IconlyLight.image),
              title: Text('gallery'.tr),
              onTap: () async {
                final File? image = await _pickAndCropImage(context, ImageSource.gallery);
                if (context.mounted) {
                  Navigator.of(context).pop(image);
                }
              },
            ),
            ListTile(
              leading: const Icon(IconlyLight.camera),
              title: Text('camera'.tr),
              onTap: () async {
                final File? image = await _pickAndCropImage(context, ImageSource.camera);
                if (context.mounted) {
                  Navigator.of(context).pop(image);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

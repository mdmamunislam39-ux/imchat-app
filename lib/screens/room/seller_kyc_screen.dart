import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:chat_messenger/api/official_team_api.dart';

class SellerKycView extends StatefulWidget {
  final User currentUser;
  final Map<String, dynamic> sellerData;
  final VoidCallback? onKycSubmitted;

  const SellerKycView({
    super.key,
    required this.currentUser,
    required this.sellerData,
    this.onKycSubmitted,
  });

  @override
  State<SellerKycView> createState() => _SellerKycViewState();
}

class _SellerKycViewState extends State<SellerKycView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _realNameController = TextEditingController();

  File? _nidFrontImage;
  File? _nidBackImage;
  File? _selfieImage;

  bool _isUploading = false;
  String _uploadStatus = '';
  bool _forceShowForm = false;

  @override
  void initState() {
    super.initState();
    final existingRealName = widget.sellerData['realName'] ?? widget.currentUser.fullname;
    _realNameController.text = existingRealName;
  }

  @override
  void dispose() {
    _realNameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(int type) async {
    // 1: NID Front, 2: NID Back, 3: Selfie
    try {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF6C5CE7)),
                title: Text('Take with Camera'.tr),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF6C5CE7)),
                title: Text('Choose from Gallery'.tr),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );

      if (source == null) return;

      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );

      if (picked != null) {
        setState(() {
          if (type == 1) _nidFrontImage = File(picked.path);
          if (type == 2) _nidBackImage = File(picked.path);
          if (type == 3) _selfieImage = File(picked.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image selection failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<String> _uploadSingleFile(File file, String nameSuffix) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = 'seller_kyc/${widget.currentUser.userId}/${nameSuffix}_$timestamp.jpg';
    final ref = _storage.ref().child(path);
    final uploadTask = ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  Future<void> _submitKyc() async {
    final realName = _realNameController.text.trim();
    if (realName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter your real name as per NID'.tr),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_nidFrontImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please upload NID front page'.tr),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_nidBackImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please upload NID back page'.tr),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selfieImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please upload selfie holding NID card'.tr),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadStatus = 'Uploading NID front page...'.tr;
    });

    try {
      // 1. Upload NID Front
      final nidFrontUrl = await _uploadSingleFile(_nidFrontImage!, 'nid_front');

      // 2. Upload NID Back
      setState(() => _uploadStatus = 'Uploading NID back page...'.tr);
      final nidBackUrl = await _uploadSingleFile(_nidBackImage!, 'nid_back');

      // 3. Upload Selfie
      setState(() => _uploadStatus = 'Uploading selfie with NID...'.tr);
      final selfieUrl = await _uploadSingleFile(_selfieImage!, 'selfie_with_nid');

      setState(() => _uploadStatus = 'Saving application details...'.tr);

      final userId = widget.currentUser.userId;
      final dsId = (widget.sellerData['directSellerId'] ?? '').toString();
      final dsName = (widget.sellerData['directSellerName'] ?? '').toString();

      // 4. Save to seller_kyc_applications
      final appRef = _firestore.collection('seller_kyc_applications').doc(userId);
      await appRef.set({
        'id': userId,
        'userId': userId,
        'userSearchId': widget.currentUser.searchId,
        'userName': widget.currentUser.fullname,
        'userPhoto': widget.currentUser.photoUrl,
        'realName': realName,
        'nidFrontUrl': nidFrontUrl,
        'nidBackUrl': nidBackUrl,
        'selfieUrl': selfieUrl,
        'directSellerId': dsId,
        'directSellerName': dsName,
        'status': 'pending',
        'rejectionReason': '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 5. Update sellers collection document
      final sellerDocSnap = await _firestore
          .collection('sellers')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (sellerDocSnap.docs.isNotEmpty) {
        await sellerDocSnap.docs.first.reference.update({
          'kycStatus': 'pending_approval',
          'realName': realName,
          'nidFrontUrl': nidFrontUrl,
          'nidBackUrl': nidBackUrl,
          'selfieUrl': selfieUrl,
          'status': 'pending_approval',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // 6. Update Users collection document
      await _firestore.collection('Users').doc(userId).update({
        'sellerKycStatus': 'pending_approval',
        'sellerRealName': realName,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 7. Send official confirmation message
      try {
        await OfficialTeamApi.sendOfficialMessage(
          receiverId: userId,
          receiverDeviceToken: widget.currentUser.deviceToken,
          messageText: '📋 Your Seller KYC application has been submitted successfully! Your seller page will be active once approved by admin.\n\n📋 আপনার সেলার ভেরিফিকেশন (KYC) আবেদন সফলভাবে জমা হয়েছে। অ্যাডমিন প্যানেল থেকে অনুমোদনের পর পেজ সক্রিয় হবে।',
        );
      } catch (_) {}

      if (!mounted) return;

      setState(() {
        _isUploading = false;
        _forceShowForm = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Your KYC application has been submitted! It is now pending admin approval.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
        ),
      );

      widget.onKycSubmitted?.call();
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submission failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showZoomDialog(String imageUrl, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              backgroundColor: Colors.black,
              title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            Flexible(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (c, w, p) => p == null
                      ? w
                      : const Center(child: CircularProgressIndicator(color: Colors.white)),
                  errorBuilder: (c, e, s) => const Center(
                    child: Icon(Icons.broken_image, color: Colors.white54, size: 48),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('seller_kyc_applications').doc(widget.currentUser.userId).snapshots(),
      builder: (context, snapshot) {
        Map<String, dynamic>? appData;
        if (snapshot.hasData && snapshot.data!.exists) {
          appData = snapshot.data!.data() as Map<String, dynamic>?;
        }

        final kycStatus = (appData?['status'] ?? widget.sellerData['kycStatus'] ?? 'not_submitted').toString();

        if (!_forceShowForm) {
          if (kycStatus == 'pending' || kycStatus == 'pending_approval') {
            return _buildPendingView(appData);
          }
          if (kycStatus == 'rejected') {
            return _buildRejectedView(appData);
          }
        }

        return _buildFormView();
      },
    );
  }

  // 1. Pending view
  Widget _buildPendingView(Map<String, dynamic>? appData) {
    final realName = appData?['realName'] ?? widget.sellerData['realName'] ?? 'Not Provided';
    final dsName = appData?['directSellerName'] ?? widget.sellerData['directSellerName'] ?? 'Direct Seller';
    final nidFront = appData?['nidFrontUrl'] ?? widget.sellerData['nidFrontUrl'];
    final nidBack = appData?['nidBackUrl'] ?? widget.sellerData['nidBackUrl'];
    final selfie = appData?['selfieUrl'] ?? widget.sellerData['selfieUrl'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          // Hourglass badge
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.amber.shade50,
              border: Border.all(color: Colors.amber.shade300, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withOpacity(0.15),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Icon(
              Icons.hourglass_top_rounded,
              size: 64,
              color: Colors.amber.shade800,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Verification Pending'.tr,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3436),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Your seller verification is under review. Your seller dashboard will be active once approved by admin.'.tr,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),

          // Application Summary Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  _buildDetailRow(Icons.person_rounded, 'Real Name'.tr, realName),
                  const Divider(height: 20),
                  _buildDetailRow(Icons.storefront_rounded, 'Appointed By Direct Seller'.tr, dsName),
                  const Divider(height: 20),
                  _buildDetailRow(Icons.info_outline_rounded, 'Status'.tr, 'Pending Admin Approval'.tr),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Submitted Documents'.tr,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          ),
          const SizedBox(height: 12),

          // 3 Uploaded Images Row
          Row(
            children: [
              if (nidFront != null)
                Expanded(child: _buildDocumentThumb('NID Front'.tr, nidFront)),
              const SizedBox(width: 8),
              if (nidBack != null)
                Expanded(child: _buildDocumentThumb('NID Back'.tr, nidBack)),
              const SizedBox(width: 8),
              if (selfie != null)
                Expanded(child: _buildDocumentThumb('Selfie with NID'.tr, selfie)),
            ],
          ),

          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.notifications_active_outlined, color: Colors.blue.shade700, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'You will receive an official notification once approved.'.tr,
                    style: TextStyle(color: Colors.blue.shade900, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 2. Rejected view
  Widget _buildRejectedView(Map<String, dynamic>? appData) {
    final reason = appData?['rejectionReason'] ?? widget.sellerData['rejectionReason'] ?? 'Documents or details were not accepted.';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.red.shade50,
              border: Border.all(color: Colors.red.shade300, width: 2),
            ),
            child: Icon(Icons.cancel_rounded, size: 64, color: Colors.red.shade600),
          ),
          const SizedBox(height: 20),
          Text(
            'Application Rejected'.tr,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.red),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Rejection Reason:'.tr,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 15),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  reason,
                  style: TextStyle(color: Colors.red.shade900, fontSize: 14, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Please provide accurate information and clear photos to re-apply.'.tr,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C5CE7),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                setState(() {
                  _forceShowForm = true;
                  _nidFrontImage = null;
                  _nidBackImage = null;
                  _selfieImage = null;
                });
              },
              icon: const Icon(Icons.replay_rounded, color: Colors.white),
              label: Text(
                'Re-apply'.tr,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 3. Form view
  Widget _buildFormView() {
    final dsName = (widget.sellerData['directSellerName'] ?? 'Direct Seller').toString();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner guidance
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.assignment_ind_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Seller KYC Verification'.tr,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Appointed by: $dsName\nPlease provide your NID information to activate your account.',
                        style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 1. Real Name
          Text(
            '1. ${'Real Name'.tr} *',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _realNameController,
            decoration: InputDecoration(
              hintText: 'Enter real name as per NID'.tr,
              prefixIcon: const Icon(Icons.badge_rounded, color: Color(0xFF6C5CE7)),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 2. NID Front
          Text(
            '2. ${'NID Card Front Page'.tr} *',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          _buildImagePickerCard(
            file: _nidFrontImage,
            title: 'Upload NID front page'.tr,
            subtitle: 'Ensure the photo and text are clear and legible'.tr,
            icon: Icons.credit_card_rounded,
            onTap: () => _pickImage(1),
            onRemove: () => setState(() => _nidFrontImage = null),
          ),
          const SizedBox(height: 20),

          // 3. NID Back
          Text(
            '3. ${'NID Card Back Page'.tr} *',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          _buildImagePickerCard(
            file: _nidBackImage,
            title: 'Upload NID back page'.tr,
            subtitle: 'Ensure address and barcode are clearly visible'.tr,
            icon: Icons.flip_to_back_rounded,
            onTap: () => _pickImage(2),
            onRemove: () => setState(() => _nidBackImage = null),
          ),
          const SizedBox(height: 20),

          // 4. Selfie holding NID
          Text(
            '4. ${'Selfie with NID'.tr} *',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          _buildImagePickerCard(
            file: _selfieImage,
            title: 'Take selfie holding NID'.tr,
            subtitle: 'Hold your NID card next to your face with both face and card clearly visible'.tr,
            icon: Icons.camera_front_rounded,
            onTap: () => _pickImage(3),
            onRemove: () => setState(() => _selfieImage = null),
          ),
          const SizedBox(height: 28),

          // Uploading progress
          if (_isUploading) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF6C5CE7)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      _uploadStatus,
                      style: const TextStyle(
                        color: Color(0xFF6C5CE7),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C5CE7),
                disabledBackgroundColor: Colors.grey.shade400,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 3,
              ),
              onPressed: _isUploading ? null : _submitKyc,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'Submit KYC'.tr,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildImagePickerCard({
    required File? file,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    required VoidCallback onRemove,
  }) {
    if (file != null) {
      return Container(
        height: 160,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF6C5CE7), width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(file, fit: BoxFit.cover),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black54, Colors.transparent],
                  begin: Alignment.topCenter,
                  end: Alignment.center,
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    radius: 18,
                    child: IconButton(
                      icon: const Icon(Icons.edit, size: 18, color: Color(0xFF6C5CE7)),
                      onPressed: onTap,
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    radius: 18,
                    child: IconButton(
                      icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                      onPressed: onRemove,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 8,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Image Selected'.tr,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: const Color(0xFF6C5CE7).withOpacity(0.1),
              child: Icon(icon, color: const Color(0xFF6C5CE7), size: 28),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF6C5CE7)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentThumb(String label, String url) {
    return GestureDetector(
      onTap: () => _showZoomDialog(url, label),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 90,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    url,
                    fit: BoxFit.cover,
                    loadingBuilder: (c, w, p) => p == null
                        ? w
                        : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    errorBuilder: (c, e, s) => const Icon(Icons.broken_image, color: Colors.grey),
                  ),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.zoom_in, color: Colors.white, size: 14),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              color: Colors.grey.shade100,
              child: Text(
                label,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

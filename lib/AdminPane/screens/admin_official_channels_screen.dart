import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:chat_messenger/tabs/chats/controllers/channel_controller.dart';
import 'package:chat_messenger/models/channel.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AdminOfficialChannelsScreen extends StatefulWidget {
  const AdminOfficialChannelsScreen({super.key});

  @override
  State<AdminOfficialChannelsScreen> createState() => _AdminOfficialChannelsScreenState();
}

class _AdminOfficialChannelsScreenState extends State<AdminOfficialChannelsScreen> {
  final TextEditingController _textContentController = TextEditingController();
  final TextEditingController _voiceRoomIdController = TextEditingController();
  final TextEditingController _linkUrlController = TextEditingController();

  final ChannelController _channelController = Get.put(ChannelController());
  
  OfficialChannel? _selectedChannel;
  File? _selectedImage;
  bool _isPublishing = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _channelController.onInit();
  }

  @override
  void dispose() {
    _textContentController.dispose();
    _voiceRoomIdController.dispose();
    _linkUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  Future<void> _publishPost() async {
    if (_selectedChannel == null) {
      _showError('Please select an Official Channel.');
      return;
    }

    final textContent = _textContentController.text.trim();
    if (textContent.isEmpty && _selectedImage == null) {
      _showError('Please add some text or an image.');
      return;
    }

    setState(() {
      _isPublishing = true;
    });

    try {
      String? imageUrl;
      if (_selectedImage != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('channel_posts_media/${const Uuid().v4()}.jpg');
        await storageRef.putFile(_selectedImage!);
        imageUrl = await storageRef.getDownloadURL();
      }

      await FirebaseFirestore.instance.collection('channel_posts').add({
        'channelId': _selectedChannel!.id,
        'textContent': textContent,
        'imageUrl': imageUrl,
        'voiceRoomId': _voiceRoomIdController.text.trim(),
        'linkUrl': _linkUrlController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      _showSuccess('Post published successfully!');
      
      setState(() {
        _textContentController.clear();
        _voiceRoomIdController.clear();
        _linkUrlController.clear();
        _selectedImage = null;
      });
    } catch (e) {
      _showError('Failed to publish post: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isPublishing = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        title: const Text(
          'Channel Posts',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildChannelSelector(),
            const SizedBox(height: 24),
            _buildPostComposer(),
            const SizedBox(height: 24),
            _buildLivePreview(),
            const SizedBox(height: 32),
            _buildPublishButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Official Channel',
          style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Obx(() {
          if (_channelController.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_channelController.channels.isEmpty) {
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF22223B),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'No official channels available. Please create one first.',
                style: TextStyle(color: Colors.white54),
              ),
            );
          }

          // If there's only one channel, auto-select it.
          if (_selectedChannel == null && _channelController.channels.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() {
                _selectedChannel = _channelController.channels.first;
              });
            });
          }

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF22223B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.purpleAccent.withValues(alpha:0.3)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<OfficialChannel>(
                isExpanded: true,
                dropdownColor: const Color(0xFF1A1A2E),
                value: _selectedChannel,
                icon: const Icon(Icons.keyboard_arrow_down, color: Colors.purpleAccent),
                hint: const Text('Choose a channel...', style: TextStyle(color: Colors.white38)),
                items: _channelController.channels.map((channel) {
                  return DropdownMenuItem<OfficialChannel>(
                    value: channel,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.purpleAccent.withValues(alpha:0.2),
                          backgroundImage: channel.logo.isNotEmpty
                              ? CachedNetworkImageProvider(channel.logo)
                              : null,
                          child: channel.logo.isEmpty
                              ? const Icon(Icons.campaign, size: 16, color: Colors.purpleAccent)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          channel.name,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedChannel = value;
                  });
                },
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPostComposer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha:0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Compose Post',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          // Text Input
          TextField(
            controller: _textContentController,
            style: const TextStyle(color: Colors.white),
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'What\'s new with this channel?...',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: const Color(0xFF22223B),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),

          // Image Attachment
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: _selectedImage != null ? 200 : 80,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF22223B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purpleAccent.withValues(alpha:0.3)),
                image: _selectedImage != null
                    ? DecorationImage(
                        image: FileImage(_selectedImage!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: _selectedImage == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.add_photo_alternate, color: Colors.purpleAccent),
                        SizedBox(height: 8),
                        Text('Attach Image', style: TextStyle(color: Colors.purpleAccent)),
                      ],
                    )
                  : Stack(
                      children: [
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedImage = null;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),

          // Optional Links
          TextField(
            controller: _voiceRoomIdController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Optional: Voice Room ID to link',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.mic, color: Colors.orangeAccent),
              filled: true,
              fillColor: const Color(0xFF22223B),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          
          TextField(
            controller: _linkUrlController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Optional: External URL link',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.link, color: Colors.lightBlueAccent),
              filled: true,
              fillColor: const Color(0xFF22223B),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }

  Widget _buildLivePreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Live Preview',
          style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF22223B),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.purpleAccent.withValues(alpha:0.2),
                backgroundImage: _selectedChannel?.logo.isNotEmpty == true
                    ? CachedNetworkImageProvider(_selectedChannel!.logo)
                    : null,
                child: _selectedChannel?.logo.isEmpty ?? true
                    ? const Icon(Icons.campaign, color: Colors.purpleAccent)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _selectedChannel?.name ?? 'Select a channel',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.verified, color: Colors.blue, size: 14),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text('Just Now', style: TextStyle(color: Colors.white38, fontSize: 11)),
                    const SizedBox(height: 8),
                    if (_textContentController.text.isNotEmpty)
                      Text(
                        _textContentController.text,
                        style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
                      ),
                    if (_selectedImage != null) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(_selectedImage!, fit: BoxFit.cover, height: 150, width: double.infinity),
                      ),
                    ],
                    if (_voiceRoomIdController.text.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.orangeAccent.withValues(alpha:0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orangeAccent.withValues(alpha:0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.mic, color: Colors.orangeAccent, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'Join Voice Room: ${_voiceRoomIdController.text}',
                              style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    ],
                    if (_linkUrlController.text.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.link, color: Colors.lightBlueAccent, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _linkUrlController.text,
                              style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      )
                    ],
                    if (_textContentController.text.isEmpty && _selectedImage == null && _voiceRoomIdController.text.isEmpty && _linkUrlController.text.isEmpty)
                      const Text('Your post content will appear here...', style: TextStyle(color: Colors.white24, fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPublishButton() {
    return ElevatedButton(
      onPressed: _isPublishing ? null : _publishPost,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.purpleAccent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 5,
        shadowColor: Colors.purpleAccent.withValues(alpha:0.5),
      ),
      child: _isPublishing
          ? const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.send),
                SizedBox(width: 8),
                Text('Publish Post', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
    );
  }
}

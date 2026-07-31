import 'dart:io';
import 'package:chat_messenger/components/loading_indicator.dart';
import 'package:chat_messenger/config/theme_config.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:chat_messenger/services/news_feed_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:chat_messenger/components/rich_text_controller.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PostCreationScreen extends StatefulWidget {
  final bool autoPickMedia;
  const PostCreationScreen({super.key, this.autoPickMedia = false});

  @override
  State<PostCreationScreen> createState() => _PostCreationScreenState();
}

class _PostCreationScreenState extends State<PostCreationScreen> {
  final RichTextController _textController = RichTextController();
  final ImagePicker _picker = ImagePicker();
  final List<File> _mediaFiles = [];
  bool _isPosting = false;
  String _visibility = 'public';
  VideoPlayerController? _videoPlayerController;
  
  bool _showMentions = false;
  String _mentionQuery = '';
  List<Map<String, dynamic>> _mentionResults = [];
  List<Map<String, dynamic>> _allUsers = [];
  int _mentionStartIndex = -1;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
    _fetchAllUsers();
    if (widget.autoPickMedia) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pickMedia();
      });
    }
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161622) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(IconlyLight.image, color: Colors.blue),
                  title: const Text('Pick Image from Gallery'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageOrVideo(true);
                  },
                ),
                ListTile(
                  leading: const Icon(IconlyLight.video, color: Colors.green),
                  title: const Text('Pick Video from Gallery'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageOrVideo(false);
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickImageOrVideo(bool isImage) async {
    try {
      if (isImage) {
        // High quality image picker with compression (imageQuality: 80)
        final pickedFiles = await _picker.pickMultiImage(
          imageQuality: 80,
        );
        if (pickedFiles.isNotEmpty) {
          setState(() {
            for (var file in pickedFiles) {
              _mediaFiles.add(File(file.path));
            }
          });
        }
      } else {
        final pickedFile = await _picker.pickVideo(
          source: ImageSource.gallery,
          maxDuration: const Duration(minutes: 5),
        );
        if (pickedFile != null) {
          final file = File(pickedFile.path);
          _videoPlayerController?.dispose();
          _videoPlayerController = VideoPlayerController.file(file)
            ..initialize().then((_) {
              setState(() {});
            });
          setState(() {
            _mediaFiles.clear(); // Only support 1 video at a time
            _mediaFiles.add(file);
          });
        }
      }
    } catch (e) {
      debugPrint('❌ [PostCreationScreen] Media picker error: $e');
    }
  }

  void _removeMedia(int index) {
    setState(() {
      _mediaFiles.removeAt(index);
      if (_videoPlayerController != null) {
        _videoPlayerController?.dispose();
        _videoPlayerController = null;
      }
    });
  }

  void _onTextChanged() {
    final text = _textController.text;
    final selection = _textController.selection;

    if (!selection.isValid || selection.baseOffset == -1) {
      if (_showMentions) setState(() => _showMentions = false);
      return;
    }

    final cursorPosition = selection.baseOffset;
    final textBeforeCursor = text.substring(0, cursorPosition);

    final lastAtIndex = textBeforeCursor.lastIndexOf('@');
    if (lastAtIndex != -1) {
      final textAfterAt = textBeforeCursor.substring(lastAtIndex + 1);
      if (!textAfterAt.contains(' ') && !textAfterAt.contains('\n')) {
        _mentionStartIndex = lastAtIndex;
        final newQuery = textAfterAt.toLowerCase();
        
        if (newQuery != _mentionQuery || !_showMentions) {
          _mentionQuery = newQuery;
          _showMentions = true;
          _searchUsers(_mentionQuery);
          setState(() {});
        }
        return;
      }
    }

    if (_showMentions) {
      setState(() => _showMentions = false);
    }
  }

  Future<void> _fetchAllUsers() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('Users')
          .limit(500)
          .get();
      _allUsers = snapshot.docs.map((doc) => doc.data()).toList();
      if (mounted && _showMentions) {
        _searchUsers(_mentionQuery);
      }
    } catch (e) {
      debugPrint('Error fetching users for mentions: $e');
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      if (_showMentions) {
        setState(() {
          _mentionResults = _allUsers.take(10).toList();
        });
      }
      return;
    }
    
    final lowerQuery = query.toLowerCase();
    final results = _allUsers.where((user) {
      final fullname = (user['fullname'] ?? '').toString().toLowerCase();
      return fullname.contains(lowerQuery);
    }).take(10).toList();
    
    if (_showMentions && _mentionQuery == query) {
      setState(() {
        _mentionResults = results;
      });
    }
  }

  void _insertMention(String username) {
    if (_mentionStartIndex == -1) return;
    
    final text = _textController.text;
    final textBefore = text.substring(0, _mentionStartIndex);
    final textAfter = text.substring(_textController.selection.baseOffset);
    
    final formattedUsername = username.replaceAll(' ', ''); 
    final newText = '$textBefore@$formattedUsername $textAfter';
    
    _textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: _mentionStartIndex + formattedUsername.length + 2),
    );
    
    setState(() {
      _showMentions = false;
    });
  }

  Future<void> _submitPost() async {
    final caption = _textController.text.trim();
    if (caption.isEmpty && _mediaFiles.isEmpty) {
      Get.snackbar(
        'Empty Post',
        'Please enter a caption or select a photo/video.',
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
      return;
    }

    setState(() => _isPosting = true);

    final User currentUser = AuthController.instance.currentUser;
    final String? frameId = currentUser.customization?.selectedFrameId;

    final postId = await NewsFeedService.createPost(
      userId: currentUser.userId,
      userName: currentUser.fullname,
      userAvatar: currentUser.photoUrl,
      userFrameId: frameId,
      isVerified: currentUser.isVerified,
      content: caption,
      mediaFiles: _mediaFiles.isNotEmpty ? _mediaFiles : null,
      visibility: _visibility,
    );

    setState(() => _isPosting = false);

    if (postId != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your post has been published successfully.'),
            backgroundColor: Colors.green,
          ),
        );
        Get.back();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not publish your post. Please check your internet connection.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final User currentUser = AuthController.instance.currentUser;
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF0F0F1A) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDarkMode ? Colors.black : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: isDarkMode ? Colors.white : Colors.black),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Create Post',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: ElevatedButton(
              onPressed: _isPosting ? null : _submitPost,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              child: _isPosting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Post', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User Profile & Privacy Header
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundImage: currentUser.photoUrl.isNotEmpty
                          ? NetworkImage(currentUser.photoUrl)
                          : null,
                      backgroundColor: Colors.grey[300],
                      child: currentUser.photoUrl.isEmpty ? const Icon(Icons.person) : null,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentUser.fullname,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Privacy selector dropdown
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDarkMode ? const Color(0xFF1E1E2F) : Colors.grey[200],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: DropdownButton<String>(
                            value: _visibility,
                            icon: const Icon(Icons.arrow_drop_down, size: 18),
                            elevation: 16,
                            underline: const SizedBox.shrink(),
                            dropdownColor: isDarkMode ? const Color(0xFF1E1E2F) : Colors.white,
                            style: TextStyle(
                              color: isDarkMode ? Colors.white70 : Colors.black87,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            onChanged: (String? value) {
                              if (value != null) {
                                setState(() => _visibility = value);
                              }
                            },
                            items: const [
                              DropdownMenuItem(value: 'public', child: Row(children: [Icon(Icons.public, size: 14), SizedBox(width: 6), Text('Public')])),
                              DropdownMenuItem(value: 'friends', child: Row(children: [Icon(Icons.people, size: 14), SizedBox(width: 6), Text('Friends Only')])),
                              DropdownMenuItem(value: 'private', child: Row(children: [Icon(Icons.lock, size: 14), SizedBox(width: 6), Text('Only Me')])),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Text Input area
                TextField(
                  controller: _textController,
                  maxLines: 8,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    hintText: "What's on your mind?",
                    hintStyle: TextStyle(
                      color: isDarkMode ? Colors.white30 : Colors.grey[400],
                    ),
                    border: InputBorder.none,
                  ),
                ),
                
                // Mentions Autocomplete list
                if (_showMentions && _mentionResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isDarkMode ? const Color(0xFF1E1E2F) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _mentionResults.length,
                      itemBuilder: (context, index) {
                        final user = _mentionResults[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: user['photoUrl'] != null && user['photoUrl'].toString().isNotEmpty 
                                ? NetworkImage(user['photoUrl']) 
                                : null,
                            child: user['photoUrl'] == null || user['photoUrl'].toString().isEmpty 
                                ? const Icon(Icons.person) 
                                : null,
                          ),
                          title: Text(user['fullname'] ?? 'User', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
                          onTap: () => _insertMention(user['fullname'] ?? 'User'),
                        );
                      },
                    ),
                  ),
                
                const SizedBox(height: 20),

                // Selected Media Preview Area
                if (_mediaFiles.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Media Attachments:',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white60 : Colors.grey[600],
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: _mediaFiles.length,
                        itemBuilder: (context, index) {
                          final file = _mediaFiles[index];
                          final isVideo = file.path.split('.').last.toLowerCase() == 'mp4' ||
                              _videoPlayerController != null;
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                isVideo
                                    ? (_videoPlayerController?.value.isInitialized ?? false
                                        ? AspectRatio(
                                            aspectRatio: _videoPlayerController!.value.aspectRatio,
                                            child: VideoPlayer(_videoPlayerController!),
                                          )
                                        : const Center(child: LoadingIndicator()))
                                    : Image.file(file, fit: BoxFit.cover),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () => _removeMedia(index),
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      padding: const EdgeInsets.all(4),
                                      child: const Icon(Icons.close, color: Colors.white, size: 16),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
              ],
            ),
          ),
          
          // Bottom toolbar for adding media
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              color: isDarkMode ? Colors.black : Colors.grey[100],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Text(
                    'Add to your post',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white70 : Colors.grey[700],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(IconlyLight.image, color: Colors.blue),
                    onPressed: _pickMedia,
                  ),
                  IconButton(
                    icon: const Icon(IconlyLight.video, color: Colors.green),
                    onPressed: _pickMedia,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

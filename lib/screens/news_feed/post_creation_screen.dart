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

class PhotoEditData {
  int rotationQuarterTurns;
  bool isFlippedHorizontal;
  String filterName;
  String caption;
  List<String> taggedUsernames;

  PhotoEditData({
    this.rotationQuarterTurns = 0,
    this.isFlippedHorizontal = false,
    this.filterName = 'Original',
    this.caption = '',
    List<String>? taggedUsernames,
  }) : taggedUsernames = taggedUsernames ?? [];

  PhotoEditData copy() {
    return PhotoEditData(
      rotationQuarterTurns: rotationQuarterTurns,
      isFlippedHorizontal: isFlippedHorizontal,
      filterName: filterName,
      caption: caption,
      taggedUsernames: List.from(taggedUsernames),
    );
  }
}

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
  double _trimStartSeconds = 0;
  double _trimEndSeconds = 0;
  bool _isVideoMuted = false;
  bool _isPlayingVideo = false;
  String _videoCaption = '';
  List<String> _videoTaggedUsernames = [];
  final Map<int, PhotoEditData> _photoEdits = {};
  
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

  void _toggleVideoPlayPause() {
    if (_videoPlayerController == null || !_videoPlayerController!.value.isInitialized) return;
    setState(() {
      if (_videoPlayerController!.value.isPlaying) {
        _videoPlayerController?.pause();
        _isPlayingVideo = false;
      } else {
        _videoPlayerController?.play();
        _isPlayingVideo = true;
      }
    });
  }

  void _toggleVideoMute() {
    if (_videoPlayerController == null) return;
    setState(() {
      _isVideoMuted = !_isVideoMuted;
      _videoPlayerController?.setVolume(_isVideoMuted ? 0.0 : 1.0);
    });
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
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
          maxDuration: const Duration(minutes: 10),
        );
        if (pickedFile != null) {
          final file = File(pickedFile.path);
          _videoPlayerController?.dispose();
          _videoPlayerController = VideoPlayerController.file(file)
            ..initialize().then((_) {
              if (mounted) {
                setState(() {
                  _trimStartSeconds = 0;
                  _trimEndSeconds = _videoPlayerController!.value.duration.inSeconds.toDouble();
                  if (_trimEndSeconds <= 0) _trimEndSeconds = 1;
                  _isVideoMuted = false;
                  _isPlayingVideo = false;
                });
              }
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
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 80 + MediaQuery.of(context).padding.bottom,
            ),
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
                  Material(
                    color: isDarkMode ? const Color(0xFF1E1E2F) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    child: Container(
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
                      _videoPlayerController != null
                          ? _buildVideoPreviewCard(_mediaFiles.first, isDarkMode)
                          : GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                              ),
                              itemCount: _mediaFiles.length,
                              itemBuilder: (context, index) {
                                return _buildPhotoThumbnailCard(index, _mediaFiles[index], isDarkMode);
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
              color: isDarkMode ? const Color(0xFF161622) : Colors.grey[100],
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: 12 + MediaQuery.of(context).padding.bottom,
              ),
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

  Widget _buildVideoPreviewCard(File videoFile, bool isDarkMode) {
    final isInitialized = _videoPlayerController?.value.isInitialized ?? false;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Video Player Display
          if (isInitialized)
            AspectRatio(
              aspectRatio: _videoPlayerController!.value.aspectRatio.clamp(0.75, 1.78),
              child: VideoPlayer(_videoPlayerController!),
            )
          else
            Container(
              height: 220,
              color: Colors.black87,
              child: const Center(child: LoadingIndicator()),
            ),

          // Click on video body to toggle play/pause
          GestureDetector(
            onTap: _toggleVideoPlayPause,
            behavior: HitTestBehavior.translucent,
            child: Container(color: Colors.transparent),
          ),

          // Center Play / Pause Button Overlay
          if (!_isPlayingVideo)
            GestureDetector(
              onTap: _toggleVideoPlayPause,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 38,
                ),
              ),
            ),

          // Top Action Bar: Edit & Remove Buttons
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Edit Video Button (Facebook Style)
                GestureDetector(
                  onTap: _showVideoEditorModal,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white30),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.edit, color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Edit Video',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Remove Video Button
                GestureDetector(
                  onTap: () => _removeMedia(0),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),

          // Caption & Tag Overlay Badge (Facebook style)
          if (_videoCaption.isNotEmpty)
            Positioned(
              bottom: 45,
              left: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _videoCaption,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),

          // Bottom Controls Toolbar: Timestamp & Sound Mute Toggle
          if (isInitialized)
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Timestamp Badge
                  ValueListenableBuilder<VideoPlayerValue>(
                    valueListenable: _videoPlayerController!,
                    builder: (context, value, child) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_formatDuration(value.position)} / ${_formatDuration(value.duration)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ),

                  // Mute / Unmute Button
                  GestureDetector(
                    onTap: _toggleVideoMute,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isVideoMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showVideoEditorModal() {
    if (_videoPlayerController == null || !_videoPlayerController!.value.isInitialized) return;

    final totalDurationSec = _videoPlayerController!.value.duration.inSeconds.toDouble();
    final captionController = TextEditingController(text: _videoCaption);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161622) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    // Editor Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                          ),
                          const Text(
                            'Edit Video',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              setState(() {});
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                            child: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),

                    const Divider(height: 1),

                    // Video Player Preview in Editor
                    Expanded(
                      child: Container(
                        color: Colors.black,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            AspectRatio(
                              aspectRatio: _videoPlayerController!.value.aspectRatio.clamp(0.75, 1.78),
                              child: VideoPlayer(_videoPlayerController!),
                            ),
                            GestureDetector(
                              onTap: () {
                                setModalState(() {
                                  _toggleVideoPlayPause();
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _isPlayingVideo ? Icons.pause : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 36,
                                ),
                              ),
                            ),
                            if (_videoCaption.isNotEmpty)
                              Positioned(
                                bottom: 20,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.75),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white38),
                                  ),
                                  child: Text(
                                    _videoCaption,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    // Controls Area
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: isDark ? const Color(0xFF1E142B) : Colors.grey[50],
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Text & @Mention Tagging Section
                          const Text(
                            'Add Text & Tag Friends (@):',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: captionController,
                            style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Write on video or type @ to tag someone...',
                              hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey[500], fontSize: 12),
                              filled: true,
                              fillColor: isDark ? Colors.white10 : Colors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onChanged: (text) {
                              setModalState(() {
                                _videoCaption = text;
                              });
                            },
                          ),
                          if (_videoCaption.contains('@')) ...[
                            const SizedBox(height: 6),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: _allUsers.take(8).map((user) {
                                  final fullname = (user['fullname'] ?? '').toString();
                                  if (fullname.isEmpty) return const SizedBox.shrink();
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: ActionChip(
                                      avatar: const Icon(Icons.alternate_email, size: 14, color: Colors.blueAccent),
                                      label: Text(fullname, style: const TextStyle(fontSize: 12)),
                                      onPressed: () {
                                        setModalState(() {
                                          final text = captionController.text;
                                          final lastAt = text.lastIndexOf('@');
                                          final newText = (lastAt != -1 ? text.substring(0, lastAt) : text) + '@$fullname ';
                                          captionController.text = newText;
                                          _videoCaption = newText;
                                          if (!_videoTaggedUsernames.contains(fullname)) {
                                            _videoTaggedUsernames.add(fullname);
                                          }
                                        });
                                      },
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),

                          // Trim Slider Header
                          if (totalDurationSec > 1) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Trim Video (Length):',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                Text(
                                  '${_formatDuration(Duration(seconds: _trimStartSeconds.round()))} - ${_formatDuration(Duration(seconds: _trimEndSeconds.round()))}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 13),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // RangeSlider for Video Trimming
                            RangeSlider(
                              values: RangeValues(
                                _trimStartSeconds.clamp(0, totalDurationSec),
                                _trimEndSeconds.clamp(0, totalDurationSec),
                              ),
                              min: 0,
                              max: totalDurationSec > 0 ? totalDurationSec : 1,
                              divisions: totalDurationSec.round() > 0 ? totalDurationSec.round() : 1,
                              activeColor: primaryColor,
                              inactiveColor: Colors.grey[300],
                              onChanged: (RangeValues values) {
                                setModalState(() {
                                  _trimStartSeconds = values.start;
                                  _trimEndSeconds = values.end;
                                  _videoPlayerController?.seekTo(Duration(seconds: values.start.round()));
                                });
                              },
                            ),
                          ],

                          const SizedBox(height: 8),

                          // Mute Original Sound Toggle
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Mute Original Video Sound', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            subtitle: const Text('Remove audio from uploaded video', style: TextStyle(fontSize: 12)),
                            value: _isVideoMuted,
                            activeTrackColor: primaryColor,
                            onChanged: (val) {
                              setModalState(() {
                                _isVideoMuted = val;
                                _videoPlayerController?.setVolume(_isVideoMuted ? 0.0 : 1.0);
                                setState(() {});
                              });
                            },
                          ),

                          const SizedBox(height: 8),

                          // Replace Video Button
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                _pickImageOrVideo(false);
                              },
                              icon: const Icon(IconlyLight.video),
                              label: const Text('Replace Video with Another'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPhotoThumbnailCard(int index, File file, bool isDarkMode) {
    final editData = _photoEdits[index] ?? PhotoEditData();
    final filter = _getFilterMatrix(editData.filterName);

    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 6,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Photo Display with Rotation, Flip & Filter applied
          GestureDetector(
            onTap: () => _showPhotoEditorModal(index),
            child: ColorFiltered(
              colorFilter: filter,
              child: Transform.scale(
                scaleX: editData.isFlippedHorizontal ? -1 : 1,
                child: RotatedBox(
                  quarterTurns: editData.rotationQuarterTurns,
                  child: Image.file(file, fit: BoxFit.cover),
                ),
              ),
            ),
          ),

          // Caption & Tag Overlay Badge (Facebook style)
          if (editData.caption.isNotEmpty)
            Positioned(
              bottom: 6,
              left: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  editData.caption,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),

          // Top Left: Facebook Style ✏️ Edit Button
          Positioned(
            top: 6,
            left: 6,
            child: GestureDetector(
              onTap: () => _showPhotoEditorModal(index),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white30, width: 0.8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.edit, color: Colors.white, size: 12),
                    SizedBox(width: 3),
                    Text(
                      'Edit',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Top Right: Remove Button (❌)
          Positioned(
            top: 6,
            right: 6,
            child: GestureDetector(
              onTap: () => _removeMedia(index),
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  ColorFilter _getFilterMatrix(String filterName) {
    switch (filterName) {
      case 'Vivid':
        return const ColorFilter.matrix([
          1.2, 0, 0, 0, 0,
          0, 1.2, 0, 0, 0,
          0, 0, 1.2, 0, 0,
          0, 0, 0, 1, 0
        ]);
      case 'Warm':
        return const ColorFilter.matrix([
          1.1, 0, 0, 0, 12,
          0, 1.0, 0, 0, 0,
          0, 0, 0.85, 0, 0,
          0, 0, 0, 1, 0
        ]);
      case 'Cool':
        return const ColorFilter.matrix([
          0.9, 0, 0, 0, 0,
          0, 1.0, 0, 0, 0,
          0, 0, 1.2, 0, 15,
          0, 0, 0, 1, 0
        ]);
      case 'B&W':
        return const ColorFilter.matrix([
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0, 0, 0, 1, 0
        ]);
      case 'Vintage':
        return const ColorFilter.matrix([
          0.9, 0.4, 0.1, 0, 0,
          0.2, 0.8, 0.1, 0, 0,
          0.2, 0.3, 0.5, 0, 0,
          0, 0, 0, 1, 0
        ]);
      default:
        return const ColorFilter.mode(Colors.transparent, BlendMode.dst);
    }
  }

  void _showPhotoEditorModal(int index) {
    if (index >= _mediaFiles.length) return;
    final file = _mediaFiles[index];

    final currentEdit = (_photoEdits[index] ?? PhotoEditData()).copy();
    final captionController = TextEditingController(text: currentEdit.caption);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final filter = _getFilterMatrix(currentEdit.filterName);

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161622) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                          ),
                          const Text(
                            'Edit Photo',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              _photoEdits[index] = currentEdit;
                              Navigator.pop(context);
                              setState(() {});
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                            child: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),

                    const Divider(height: 1),

                    // Image Preview Display in Editor
                    Expanded(
                      child: Container(
                        color: Colors.black,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            ColorFiltered(
                              colorFilter: filter,
                              child: Transform.scale(
                                scaleX: currentEdit.isFlippedHorizontal ? -1 : 1,
                                child: RotatedBox(
                                  quarterTurns: currentEdit.rotationQuarterTurns,
                                  child: Image.file(file, fit: BoxFit.contain),
                                ),
                              ),
                            ),
                            if (currentEdit.caption.isNotEmpty)
                              Positioned(
                                bottom: 20,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.75),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white38),
                                  ),
                                  child: Text(
                                    currentEdit.caption,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    // Bottom Editing Controls (Text, Mentions, Rotate, Flip, Filters)
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: isDark ? const Color(0xFF1E142B) : Colors.grey[50],
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Text & @Mention Tagging Section
                          const Text(
                            'Add Text & Tag Friends (@):',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: captionController,
                            style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Write on photo or type @ to tag someone...',
                              hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey[500], fontSize: 12),
                              filled: true,
                              fillColor: isDark ? Colors.white10 : Colors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onChanged: (text) {
                              setModalState(() {
                                currentEdit.caption = text;
                              });
                            },
                          ),
                          if (currentEdit.caption.contains('@')) ...[
                            const SizedBox(height: 6),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: _allUsers.take(8).map((user) {
                                  final fullname = (user['fullname'] ?? '').toString();
                                  if (fullname.isEmpty) return const SizedBox.shrink();
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: ActionChip(
                                      avatar: const Icon(Icons.alternate_email, size: 14, color: Colors.blueAccent),
                                      label: Text(fullname, style: const TextStyle(fontSize: 12)),
                                      onPressed: () {
                                        setModalState(() {
                                          final text = captionController.text;
                                          final lastAt = text.lastIndexOf('@');
                                          final newText = (lastAt != -1 ? text.substring(0, lastAt) : text) + '@$fullname ';
                                          captionController.text = newText;
                                          currentEdit.caption = newText;
                                          if (!currentEdit.taggedUsernames.contains(fullname)) {
                                            currentEdit.taggedUsernames.add(fullname);
                                          }
                                        });
                                      },
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),

                          // Rotation & Flip Action Buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () {
                                  setModalState(() {
                                    currentEdit.rotationQuarterTurns =
                                        (currentEdit.rotationQuarterTurns + 1) % 4;
                                  });
                                },
                                icon: const Icon(Icons.rotate_right, size: 18),
                                label: const Text('Rotate 90°'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDark ? Colors.white12 : Colors.grey[200],
                                  foregroundColor: isDark ? Colors.white : Colors.black87,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () {
                                  setModalState(() {
                                    currentEdit.isFlippedHorizontal =
                                        !currentEdit.isFlippedHorizontal;
                                  });
                                },
                                icon: const Icon(Icons.flip, size: 18),
                                label: const Text('Flip Horizontal'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDark ? Colors.white12 : Colors.grey[200],
                                  foregroundColor: isDark ? Colors.white : Colors.black87,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          const Text(
                            'Photo Filters:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 8),

                          // Filters Chips Row
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: ['Original', 'Vivid', 'Warm', 'Cool', 'B&W', 'Vintage']
                                  .map((filterName) {
                                final isSelected = currentEdit.filterName == filterName;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(filterName),
                                    selected: isSelected,
                                    selectedColor: primaryColor,
                                    labelStyle: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : (isDark ? Colors.white70 : Colors.black87),
                                      fontWeight: FontWeight.bold,
                                    ),
                                    onSelected: (selected) {
                                      if (selected) {
                                        setModalState(() {
                                          currentEdit.filterName = filterName;
                                        });
                                      }
                                    },
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

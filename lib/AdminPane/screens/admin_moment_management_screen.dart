import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:chat_messenger/models/news_feed_post.dart';
import 'package:chat_messenger/services/news_feed_service.dart';
import 'package:chat_messenger/components/loading_indicator.dart';
import 'package:get/get.dart';

class AdminMomentManagementScreen extends StatefulWidget {
  const AdminMomentManagementScreen({super.key});

  @override
  State<AdminMomentManagementScreen> createState() =>
      _AdminMomentManagementScreenState();
}

class _AdminMomentManagementScreenState
    extends State<AdminMomentManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryBg = Color(0xFF1E142B);

    return Scaffold(
      backgroundColor: primaryBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF120B1C),
        elevation: 0,
        title: const Text(
          'imChat Moment Management',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.purpleAccent,
          labelColor: Colors.purpleAccent,
          unselectedLabelColor: Colors.white60,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.campaign), text: 'Notices'),
            Tab(icon: Icon(Icons.report_problem), text: 'Reported Posts'),
            Tab(icon: Icon(Icons.dynamic_feed), text: 'All Moments'),
            Tab(icon: Icon(Icons.ads_click), text: 'AdSense Config'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _NoticeBoardTab(),
          _ReportedPostsTab(),
          _AllMomentsTab(),
          _AdSenseConfigTab(),
        ],
      ),
    );
  }
}

// ─── 1. NOTICE BOARD TAB ───────────────────────────────────────────────────

class _NoticeBoardTab extends StatefulWidget {
  const _NoticeBoardTab();

  @override
  State<_NoticeBoardTab> createState() => _NoticeBoardTabState();
}

class _NoticeBoardTabState extends State<_NoticeBoardTab> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  File? _selectedMedia;
  bool _isPinned = true;
  bool _isSubmitting = false;

  Future<void> _pickMedia() async {
    final ImagePicker picker = ImagePicker();
    final XFile? file = await picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      setState(() => _selectedMedia = File(file.path));
    }
  }

  Future<void> _publishNotice() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty || content.isEmpty) {
      Get.snackbar(
        'Missing Fields',
        'Please enter notice title and text.',
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final result = await NewsFeedService.createNoticePost(
      title: title,
      content: content,
      mediaFile: _selectedMedia,
      isPinned: _isPinned,
    );

    setState(() => _isSubmitting = false);

    if (result != null) {
      _titleController.clear();
      _contentController.clear();
      setState(() => _selectedMedia = null);

      Get.snackbar(
        'Success',
        'Notice published on imChat Moment page!',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } else {
      Get.snackbar(
        'Error',
        'Failed to publish notice. Try again.',
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Create Notice Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2A1B3D),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.add_alert_rounded, color: Colors.amberAccent),
                    SizedBox(width: 8),
                    Text(
                      'Publish Official Notice to imChat Moment',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _titleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Notice Title',
                    labelStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: const Color(0xFF1E142B),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _contentController,
                  maxLines: 4,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Notice Details / Body Text',
                    labelStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: const Color(0xFF1E142B),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _pickMedia,
                      icon: const Icon(Icons.image, size: 18),
                      label: Text(_selectedMedia == null ? 'Attach Banner Image' : 'Change Image'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        const Text('Pin to Top', style: TextStyle(color: Colors.white70)),
                        Switch(
                          value: _isPinned,
                          onChanged: (val) => setState(() => _isPinned = val),
                          activeColor: Colors.purpleAccent,
                        ),
                      ],
                    ),
                  ],
                ),
                if (_selectedMedia != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Attached: ${_selectedMedia!.path.split('/').last}',
                      style: const TextStyle(color: Colors.greenAccent, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _publishNotice,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purpleAccent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'Publish Notice Now',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Text(
            'Active Notices',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // Published Notices List Stream
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('news_feed_posts')
                .where('isNotice', isEqualTo: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: LoadingIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Text(
                  'No active notices found.',
                  style: TextStyle(color: Colors.white54),
                );
              }

              final notices = snapshot.data!.docs
                  .map((d) => NewsFeedPost.fromFirestore(d))
                  .where((p) => !p.isDeleted)
                  .toList();

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: notices.length,
                itemBuilder: (context, index) {
                  final notice = notices[index];
                  return Card(
                    color: const Color(0xFF2A1B3D),
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.amber,
                        child: Icon(Icons.campaign, color: Colors.black),
                      ),
                      title: Text(
                        notice.noticeTitle ?? 'Official Notice',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        notice.content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () => NewsFeedService.deletePost(notice.id),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── 2. REPORTED POSTS TAB ─────────────────────────────────────────────────

class _ReportedPostsTab extends StatelessWidget {
  const _ReportedPostsTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: NewsFeedService.getReportedPostsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: LoadingIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 60),
                SizedBox(height: 12),
                Text(
                  'No reported posts pending review.',
                  style: TextStyle(color: Colors.white60, fontSize: 16),
                ),
              ],
            ),
          );
        }

        final reports = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: reports.length,
          itemBuilder: (context, index) {
            final report = reports[index].data();
            final reportId = reports[index].id;
            final postId = report['postId'] ?? '';
            final reason = report['reason'] ?? 'Unknown Reason';

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('news_feed_posts').doc(postId).get(),
              builder: (context, postSnap) {
                if (!postSnap.hasData || !postSnap.data!.exists) {
                  return const SizedBox.shrink();
                }

                final postData = postSnap.data!.data() as Map<String, dynamic>?;
                if (postData == null || (postData['isDeleted'] ?? false)) {
                  return const SizedBox.shrink();
                }

                final post = NewsFeedPost.fromFirestore(postSnap.data!);

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A1B3D),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with Report Reason Badge
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.report, color: Colors.white, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  reason,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Text(
                            post.timeAgo,
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Reported Post Info
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundImage: post.userAvatar != null ? NetworkImage(post.userAvatar!) : null,
                            child: post.userAvatar == null ? const Icon(Icons.person) : null,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            post.userName,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        post.content,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70),
                      ),

                      const SizedBox(height: 16),

                      // Action Buttons: Delete Post or Dismiss Report
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                await NewsFeedService.deleteReportedPost(postId, reportId);
                                Get.snackbar(
                                  'Post Deleted',
                                  'Reported post has been permanently removed.',
                                  backgroundColor: Colors.redAccent,
                                  colorText: Colors.white,
                                );
                              },
                              icon: const Icon(Icons.delete, color: Colors.white, size: 18),
                              label: const Text('Delete Post'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                await NewsFeedService.dismissReport(reportId);
                                Get.snackbar(
                                  'Report Dismissed',
                                  'Report marked as dismissed.',
                                  backgroundColor: Colors.grey,
                                  colorText: Colors.white,
                                );
                              },
                              icon: const Icon(Icons.check, color: Colors.greenAccent, size: 18),
                              label: const Text('Dismiss', style: TextStyle(color: Colors.greenAccent)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.greenAccent),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

// ─── 3. ALL MOMENTS MANAGEMENT TAB ─────────────────────────────────────────

class _AllMomentsTab extends StatelessWidget {
  const _AllMomentsTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('news_feed_posts')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: LoadingIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text('No moments posts found.', style: TextStyle(color: Colors.white54)),
          );
        }

        final posts = snapshot.data!.docs
            .map((d) => NewsFeedPost.fromFirestore(d))
            .where((p) => !p.isDeleted)
            .toList();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            final hasVideo = post.media.any((m) => m.type == 'video');

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF2A1B3D),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundImage: post.userAvatar != null ? NetworkImage(post.userAvatar!) : null,
                    child: post.userAvatar == null ? const Icon(Icons.person) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              post.userName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (hasVideo)
                              Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'VIDEO',
                                  style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          post.content.isEmpty ? '[Media Only]' : post.content,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Likes: ${post.likeCount} | Comments: ${post.commentCount} | Reports: ${post.reportCount}',
                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: () => NewsFeedService.deletePost(post.id),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ─── 4. ADSENSE CONFIG TAB ─────────────────────────────────────────────────

class _AdSenseConfigTab extends StatefulWidget {
  const _AdSenseConfigTab();

  @override
  State<_AdSenseConfigTab> createState() => _AdSenseConfigTabState();
}

class _AdSenseConfigTabState extends State<_AdSenseConfigTab> {
  final TextEditingController _bannerIdController = TextEditingController();
  bool _adsEnabled = true;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('app_settings').doc('moment_ads').get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _adsEnabled = data['adsEnabled'] ?? true;
        _bannerIdController.text = data['bannerUnitId'] ?? 'ca-app-pub-3940256099942544/6300978111';
      } else {
        _bannerIdController.text = 'ca-app-pub-3940256099942544/6300978111';
      }
    } catch (e) {
      debugPrint('Error loading ad settings: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveConfig() async {
    setState(() => _isSaving = true);
    await NewsFeedService.updateAdSettings({
      'adsEnabled': _adsEnabled,
      'bannerUnitId': _bannerIdController.text.trim(),
      'updatedAt': Timestamp.now(),
    });
    setState(() => _isSaving = false);

    Get.snackbar(
      'Settings Saved',
      'AdSense / AdMob settings updated successfully.',
      backgroundColor: Colors.green,
      colorText: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: LoadingIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2A1B3D),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.ads_click, color: Colors.amberAccent),
                    const SizedBox(width: 8),
                    const Text(
                      'Google AdSense / AdMob Configuration',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    Switch(
                      value: _adsEnabled,
                      onChanged: (val) => setState(() => _adsEnabled = val),
                      activeColor: Colors.purpleAccent,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _bannerIdController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Banner Ad Unit ID',
                    labelStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: const Color(0xFF1E142B),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveConfig,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purpleAccent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'Save Ad Settings',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
}

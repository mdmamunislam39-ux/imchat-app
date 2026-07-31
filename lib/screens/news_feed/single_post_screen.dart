import 'package:flutter/material.dart';
import 'package:chat_messenger/components/loading_indicator.dart';
import 'package:chat_messenger/components/custom_appbar.dart';
import 'package:chat_messenger/models/news_feed_post.dart';
import 'package:chat_messenger/services/news_feed_service.dart';
import 'package:chat_messenger/screens/news_feed/post_comments_sheet.dart';

class SinglePostScreen extends StatelessWidget {
  final String postId;

  const SinglePostScreen({super.key, required this.postId});

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF0F0F1A) : const Color(0xFFF3F4F6),
      appBar: CustomAppBar(
        title: const Text('Post'),
      ),
      body: StreamBuilder<NewsFeedPost?>(
        stream: NewsFeedService.getPostByIdStream(postId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: LoadingIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 60, color: Colors.grey[500]),
                  const SizedBox(height: 16),
                  Text(
                    'This post has been deleted or is unavailable.',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }
          return SafeArea(
            child: PostCommentsSheet(post: snapshot.data!),
          );
        },
      ),
    );
  }
}

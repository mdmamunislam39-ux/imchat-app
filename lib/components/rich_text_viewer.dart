import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:chat_messenger/api/user_api.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:chat_messenger/screens/room/roomprofile_screen.dart';

class RichTextViewer extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final Function(String)? onUrlTap;
  final Function(String)? onMentionTap;
  final Function(String)? onHashtagTap;

  const RichTextViewer({
    super.key,
    required this.text,
    this.style,
    this.maxLines,
    this.overflow,
    this.onUrlTap,
    this.onMentionTap,
    this.onHashtagTap,
  });

  @override
  State<RichTextViewer> createState() => _RichTextViewerState();
}

class _RichTextViewerState extends State<RichTextViewer> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    _clearRecognizers();
    super.dispose();
  }

  void _clearRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  Future<void> _openUrl(String rawUrl) async {
    if (widget.onUrlTap != null) {
      widget.onUrlTap!(rawUrl);
      return;
    }

    String urlStr = rawUrl.trim();
    if (urlStr.toLowerCase().startsWith('www.')) {
      urlStr = 'https://$urlStr';
    } else if (!urlStr.toLowerCase().startsWith('http://') &&
        !urlStr.toLowerCase().startsWith('https://')) {
      urlStr = 'https://$urlStr';
    }

    final Uri? uri = Uri.tryParse(urlStr);
    if (uri == null) return;

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Could not launch URL $urlStr: $e');
    }
  }

  Future<void> _openMention(String rawMention) async {
    final query = rawMention.replaceAll('@', '').trim();
    if (query.isEmpty) return;

    try {
      // 1. Direct match by userId using UserApi
      final directUser = await UserApi.getUser(query);
      if (directUser != null) {
        Get.to(() => ProfilePageForRoom(
              userID: directUser.userId,
              userName: directUser.fullname,
              userImage: directUser.photoUrl,
            ));
        return;
      }

      // 2. Query searchId from Firestore Users collection
      final usersRef = FirebaseFirestore.instance.collection('Users');
      final searchIdQuery =
          await usersRef.where('searchId', isEqualTo: query).limit(1).get();
      if (searchIdQuery.docs.isNotEmpty) {
        final user = User.fromMap(searchIdQuery.docs.first.data());
        Get.to(() => ProfilePageForRoom(
              userID: user.userId,
              userName: user.fullname,
              userImage: user.photoUrl,
            ));
        return;
      }

      // 3. Match by fullname
      final snapshot = await usersRef.limit(200).get();
      final lowerQuery = query.toLowerCase();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final fullname = (data['fullname'] ?? '').toString();
        final cleanFullname = fullname.replaceAll(' ', '').toLowerCase();
        final searchId = (data['searchId'] ?? '').toString().toLowerCase();

        if (cleanFullname == lowerQuery ||
            fullname.toLowerCase() == lowerQuery ||
            searchId == lowerQuery ||
            doc.id.toLowerCase() == lowerQuery ||
            (cleanFullname.isNotEmpty && cleanFullname.contains(lowerQuery))) {
          final user = User.fromMap(data);
          Get.to(() => ProfilePageForRoom(
                userID: user.userId,
                userName: user.fullname,
                userImage: user.photoUrl,
              ));
          return;
        }
      }

      Get.snackbar(
        'User Not Found',
        'Could not find profile for @$query',
        backgroundColor: Colors.black.withValues(alpha: 0.7),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      debugPrint('Error opening mentioned user profile: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    _clearRecognizers();

    if (widget.text.isEmpty) {
      return Text('', style: widget.style);
    }

    List<InlineSpan> children = [];
    final pattern = RegExp(
      r'(https?:\/\/[^\s]+|www\.[^\s]+)|(@[a-zA-Z0-9_\.\-\u0980-\u09FF]+)|(#\w+)',
      caseSensitive: false,
    );
    final matches = pattern.allMatches(widget.text);

    int lastMatchEnd = 0;

    final TextStyle defaultBaseStyle =
        widget.style ?? DefaultTextStyle.of(context).style;

    final TextStyle linkStyle = defaultBaseStyle.copyWith(
      color: const Color(0xFF1877F2),
      decoration: TextDecoration.underline,
      decorationColor: const Color(0xFF1877F2),
      fontWeight: FontWeight.w500,
    );

    final TextStyle mentionStyle = defaultBaseStyle.copyWith(
      color: Colors.blue,
      fontWeight: FontWeight.bold,
    );

    final TextStyle hashtagStyle = defaultBaseStyle.copyWith(
      color: Colors.blue,
      fontStyle: FontStyle.italic,
    );

    for (final match in matches) {
      if (match.start > lastMatchEnd) {
        children.add(TextSpan(
          text: widget.text.substring(lastMatchEnd, match.start),
          style: widget.style,
        ));
      }

      String matchedText = match.group(0)!;
      final lowerMatched = matchedText.toLowerCase();

      if (lowerMatched.startsWith('http://') ||
          lowerMatched.startsWith('https://') ||
          lowerMatched.startsWith('www.')) {
        // Strip trailing punctuation if present (e.g. '.', ',', ')', ']', '!', '?')
        String trailingPunct = '';
        while (matchedText.isNotEmpty &&
            (matchedText.endsWith('.') ||
                matchedText.endsWith(',') ||
                matchedText.endsWith(')') ||
                matchedText.endsWith(']') ||
                matchedText.endsWith('!') ||
                matchedText.endsWith('?'))) {
          trailingPunct = matchedText[matchedText.length - 1] + trailingPunct;
          matchedText = matchedText.substring(0, matchedText.length - 1);
        }

        if (matchedText.isNotEmpty) {
          final String urlToOpen = matchedText;
          final recognizer = TapGestureRecognizer()
            ..onTap = () => _openUrl(urlToOpen);
          _recognizers.add(recognizer);

          children.add(TextSpan(
            text: matchedText,
            style: linkStyle,
            recognizer: recognizer,
          ));
        }

        if (trailingPunct.isNotEmpty) {
          children.add(TextSpan(
            text: trailingPunct,
            style: widget.style,
          ));
        }
      } else if (matchedText.startsWith('@')) {
        final recognizer = TapGestureRecognizer()
          ..onTap = () {
            if (widget.onMentionTap != null) {
              widget.onMentionTap!(matchedText);
            } else {
              _openMention(matchedText);
            }
          };
        _recognizers.add(recognizer);

        children.add(TextSpan(
          text: matchedText,
          style: mentionStyle,
          recognizer: recognizer,
        ));
      } else if (matchedText.startsWith('#')) {
        final recognizer = widget.onHashtagTap != null
            ? (TapGestureRecognizer()
              ..onTap = () => widget.onHashtagTap!(matchedText))
            : null;
        if (recognizer != null) _recognizers.add(recognizer);

        children.add(TextSpan(
          text: matchedText,
          style: hashtagStyle,
          recognizer: recognizer,
        ));
      }

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < widget.text.length) {
      children.add(TextSpan(
        text: widget.text.substring(lastMatchEnd),
        style: widget.style,
      ));
    }

    return RichText(
      maxLines: widget.maxLines,
      overflow: widget.overflow ?? TextOverflow.clip,
      text: TextSpan(
        style: defaultBaseStyle,
        children: children,
      ),
    );
  }
}

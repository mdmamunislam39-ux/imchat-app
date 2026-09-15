import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/services/app_theme_service.dart';

class Html5GameSheet extends StatefulWidget {
  final String url;
  final String title;
  final bool isInAudioRoom;
  final String? roomId;

  const Html5GameSheet({
    super.key,
    required this.url,
    required this.title,
    this.isInAudioRoom = true,
    this.roomId,
  });

  static void show(
    BuildContext context, {
    required String url,
    required String title,
    bool isInAudioRoom = true,
    String? roomId,
  }) {
    if (!isInAudioRoom) {
      Get.to(
        () => Html5GameFullScreenPage(url: url, title: title, roomId: roomId),
        transition: Transition.rightToLeft,
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.4),
        builder: (ctx) => FractionallySizedBox(
          heightFactor: 0.85,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: Container(
              color: const Color(0xFF0D1117),
              child: Html5GameSheet(
                url: url,
                title: title,
                isInAudioRoom: true,
                roomId: roomId,
              ),
            ),
          ),
        ),
      );
    }
  }

  @override
  State<Html5GameSheet> createState() => _Html5GameSheetState();
}

class _Html5GameSheetState extends State<Html5GameSheet> {
  late final WebViewController _controller;
  bool _isLoading = true;
  double _loadingProgress = 0.0;
  String _finalUrl = '';

  @override
  void initState() {
    super.initState();
    _finalUrl = _buildAuthenticatedUrl(widget.url, widget.roomId);

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0D1117))
      ..addJavaScriptChannel(
        'FlutterBridge',
        onMessageReceived: (JavaScriptMessage message) {
          try {
            final data = jsonDecode(message.message);
            if (data['type'] == 'CLOSE_GAME' || data['type'] == 'close') {
              Navigator.pop(context);
            }
          } catch (_) {
            if (message.message.contains('close') || message.message.contains('CLOSE_GAME')) {
              Navigator.pop(context);
            }
          }
        },
      )
      ..addJavaScriptChannel(
        'FlutterApp',
        onMessageReceived: (JavaScriptMessage message) {
          if (message.message == 'close' || message.message == 'exit') {
            Navigator.pop(context);
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) {
              setState(() => _loadingProgress = progress / 100.0);
            }
          },
          onPageStarted: (url) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _loadingProgress = 1.0;
              });
            }
          },
          onWebResourceError: (error) {
            debugPrint('HTML5 Game WebView error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(_finalUrl));
  }

  static String _buildAuthenticatedUrl(String rawUrl, String? roomId) {
    String cleanUrl = rawUrl.trim();
    if (cleanUrl.isEmpty) {
      cleanUrl = 'https://ludu-room-game.web.app';
    }

    try {
      final user = AuthController.instance.currentUser;
      final currentUserId = user.userId.isNotEmpty
          ? user.userId
          : (FirebaseAuth.instance.currentUser?.uid ?? '');
      final userName = user.fullname.isNotEmpty ? user.fullname : 'Player';
      final userAvatar = user.photoUrl;
      final userDiamonds = user.diamonds;

      String diamondIconUrl = '';
      try {
        if (Get.isRegistered<AppThemeService>()) {
          diamondIconUrl = Get.find<AppThemeService>().diamondIconUrl.value;
        }
      } catch (_) {}

      final uri = Uri.parse(cleanUrl);
      final Map<String, String> queryParams = Map.from(uri.queryParameters);
      queryParams['userId'] = currentUserId;
      queryParams['uid'] = currentUserId;
      queryParams['name'] = userName;
      queryParams['avatar'] = userAvatar;
      queryParams['diamonds'] = userDiamonds.toString();
      queryParams['coins'] = userDiamonds.toString();
      if (diamondIconUrl.isNotEmpty) {
        queryParams['diamondIcon'] = diamondIconUrl;
      }
      if (roomId != null && roomId.isNotEmpty) {
        queryParams['roomId'] = roomId;
      }

      return uri.replace(queryParameters: queryParams).toString();
    } catch (_) {
      return cleanUrl;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: Color(0xFF161B22),
            border: Border(bottom: BorderSide(color: Colors.white12)),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.sports_esports_rounded, color: Colors.amber, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Refresh button
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 20),
                onPressed: () => _controller.reload(),
                tooltip: 'Reload',
              ),
              // Fullscreen button
              IconButton(
                icon: const Icon(Icons.fullscreen_rounded, color: Colors.white70, size: 22),
                onPressed: () {
                  Navigator.pop(context);
                  Get.to(
                    () => Html5GameFullScreenPage(
                      url: widget.url,
                      title: widget.title,
                      roomId: widget.roomId,
                    ),
                    transition: Transition.rightToLeft,
                  );
                },
                tooltip: 'Full Screen',
              ),
              // Close button
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                onPressed: () => Navigator.pop(context),
                tooltip: 'Close',
              ),
            ],
          ),
        ),

        // Linear Progress Bar while loading
        if (_isLoading)
          LinearProgressIndicator(
            value: _loadingProgress > 0 ? _loadingProgress : null,
            backgroundColor: const Color(0xFF161B22),
            color: Colors.amber,
            minHeight: 2.5,
          ),

        // WebView Container
        Expanded(
          child: WebViewWidget(controller: _controller),
        ),
      ],
    );
  }
}

class Html5GameFullScreenPage extends StatefulWidget {
  final String url;
  final String title;
  final String? roomId;

  const Html5GameFullScreenPage({
    super.key,
    required this.url,
    required this.title,
    this.roomId,
  });

  @override
  State<Html5GameFullScreenPage> createState() => _Html5GameFullScreenPageState();
}

class _Html5GameFullScreenPageState extends State<Html5GameFullScreenPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  double _loadingProgress = 0.0;
  String _finalUrl = '';

  @override
  void initState() {
    super.initState();
    _finalUrl = _Html5GameSheetState._buildAuthenticatedUrl(widget.url, widget.roomId);

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0A0E1A))
      ..addJavaScriptChannel(
        'FlutterBridge',
        onMessageReceived: (JavaScriptMessage message) {
          try {
            final data = jsonDecode(message.message);
            if (data['type'] == 'CLOSE_GAME' || data['type'] == 'close') {
              Get.back();
            }
          } catch (_) {
            if (message.message.contains('close') || message.message.contains('CLOSE_GAME')) {
              Get.back();
            }
          }
        },
      )
      ..addJavaScriptChannel(
        'FlutterApp',
        onMessageReceived: (JavaScriptMessage message) {
          if (message.message == 'close' || message.message == 'exit') {
            Get.back();
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) setState(() => _loadingProgress = progress / 100.0);
          },
          onPageStarted: (url) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _loadingProgress = 1.0;
              });
            }
          },
          onWebResourceError: (error) {
            debugPrint('HTML5 Fullscreen WebView error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(_finalUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: SafeArea(
        child: Stack(
          children: [
            WebViewWidget(controller: _controller),

            if (_isLoading)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(
                  value: _loadingProgress > 0 ? _loadingProgress : null,
                  backgroundColor: Colors.black26,
                  color: Colors.amber,
                  minHeight: 3,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

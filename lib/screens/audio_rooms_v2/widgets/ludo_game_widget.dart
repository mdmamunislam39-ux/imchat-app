import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/models/audio_room_v2.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/repository/audio_rooms_repository.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/services/app_theme_service.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/html5_game_sheet.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/ludo/ludo_lobby_widget.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/ludo/ludo_controller.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/ludo/ludo_models.dart';

class LudoGameWidget extends StatefulWidget {
  final AudioRoomV2 room;
  final bool isHost;
  final AudioRoomsRepository repository;
  final String currentUserId;

  const LudoGameWidget({
    super.key,
    required this.room,
    required this.isHost,
    required this.repository,
    required this.currentUserId,
  });

  @override
  State<LudoGameWidget> createState() => _LudoGameWidgetState();
}

class _LudoGameWidgetState extends State<LudoGameWidget> {
  late final LudoController _ludoController;
  late final WebViewController _controller;
  bool _isLoading = true;
  double _loadingProgress = 0.0;
  String _rawGameUrl = 'https://ludu-room-game.web.app';
  String _finalUrl = '';
  bool _hasError = false;
  StreamSubscription<DatabaseEvent>? _actionSubscription;

  @override
  void initState() {
    super.initState();
    _ludoController = Get.put(
      LudoController(widget.room.id, widget.currentUserId, isHost: widget.isHost),
      tag: widget.room.id,
    );
    _initController();
    _listenToActions();

    // Watch gameState: when isStarted becomes true, load URL
    ever(_ludoController.gameState, (state) {
      if (state.isStarted && _finalUrl.isEmpty) {
        _loadGameUrl();
      }
    });

    if (_ludoController.gameState.value.isStarted) {
      _loadGameUrl();
    }
  }

  void _initController() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF140526))
      ..addJavaScriptChannel(
        'LudoSyncChannel',
        onMessageReceived: (JavaScriptMessage message) {
          try {
            final data = jsonDecode(message.message);
            FirebaseDatabase.instance
                .ref('rooms/${widget.room.id}/ludo/action')
                .set({
                  ...data,
                  'senderId': widget.currentUserId,
                  'timestamp': DateTime.now().millisecondsSinceEpoch,
                });
          } catch (e) {
            debugPrint('Error syncing Ludo action: $e');
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) {
              setState(() {
                _loadingProgress = progress / 100.0;
              });
            }
          },
          onPageStarted: (url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _hasError = false;
              });
            }
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
            debugPrint('Ludo Room Mode WebView error: ${error.description}');
            if (mounted && _isLoading) {
              setState(() {
                _hasError = true;
                _isLoading = false;
              });
            }
          },
        ),
      );
  }

  void _listenToActions() {
    final ref = FirebaseDatabase.instance.ref('rooms/${widget.room.id}/ludo/action');
    _actionSubscription = ref.onValue.listen((event) {
      if (event.snapshot.exists && event.snapshot.value != null) {
        try {
          final data = Map<String, dynamic>.from(event.snapshot.value as Map);
          final senderId = data['senderId']?.toString();
          if (senderId != widget.currentUserId) {
            final jsonStr = jsonEncode(data);
            _controller.runJavaScript('window.onRemoteLudoAction($jsonStr);');
          }
        } catch (e) {
          debugPrint('Error handling remote Ludo action: $e');
        }
      }
    });
  }

  @override
  void dispose() {
    _actionSubscription?.cancel();
    Get.delete<LudoController>(tag: widget.room.id);
    super.dispose();
  }

  Future<void> _loadGameUrl() async {
    try {
      final configDoc = await FirebaseFirestore.instance
          .collection('config')
          .doc('html5_ludo_game')
          .get();

      if (configDoc.exists && configDoc.data() != null) {
        final url = configDoc.data()!['gameUrl']?.toString().trim();
        if (url != null && url.isNotEmpty) {
          _rawGameUrl = url;
        }
      } else {
        final roomGameDoc = await FirebaseFirestore.instance
            .collection('room_games')
            .doc('room_ludo_champion')
            .get();
        if (roomGameDoc.exists && roomGameDoc.data() != null) {
          final url = roomGameDoc.data()!['gameUrl']?.toString().trim();
          if (url != null && url.isNotEmpty) {
            _rawGameUrl = url;
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching Ludo config in Room Mode: $e');
    }

    _finalUrl = _buildAuthenticatedUrl(_rawGameUrl);

    if (mounted) {
      try {
        _controller.loadRequest(Uri.parse(_finalUrl));
      } catch (e) {
        debugPrint('Error loading Ludo URL: $e');
        if (mounted) {
          setState(() {
            _hasError = true;
            _isLoading = false;
          });
        }
      }
    }
  }

  String _buildAuthenticatedUrl(String rawUrl) {
    String cleanUrl = rawUrl.trim();
    if (cleanUrl.isEmpty) {
      cleanUrl = 'https://ludu-room-game.web.app';
    }

    try {
      final user = AuthController.instance.currentUser;
      final currentUserId = widget.currentUserId.isNotEmpty
          ? widget.currentUserId
          : (user.userId.isNotEmpty
              ? user.userId
              : (FirebaseAuth.instance.currentUser?.uid ?? ''));
      final userName = user.fullname.isNotEmpty ? user.fullname : 'Player';
      final userAvatar = user.photoUrl;
      final userDiamonds = user.diamonds;

      final state = _ludoController.gameState.value;

      final redId = state.players[LudoColor.red] ?? currentUserId;
      final redName = state.playerNames[LudoColor.red] ?? userName;
      final redAvatar = state.playerAvatars[LudoColor.red] ?? userAvatar;

      final yellowId = state.players[LudoColor.yellow] ?? '';
      final yellowName = state.playerNames[LudoColor.yellow] ?? 'Opponent';
      final yellowAvatar = state.playerAvatars[LudoColor.yellow] ?? '';

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
      queryParams['current_user_id'] = currentUserId;
      queryParams['name'] = userName;
      queryParams['avatar'] = userAvatar;
      queryParams['diamonds'] = userDiamonds.toString();
      queryParams['coins'] = userDiamonds.toString();
      if (diamondIconUrl.isNotEmpty) {
        queryParams['diamondIcon'] = diamondIconUrl;
      }
      queryParams['roomId'] = widget.room.id;
      queryParams['isHost'] = widget.isHost ? 'true' : 'false';
      queryParams['mode'] = 'room';
      queryParams['players'] = '2';

      queryParams['red_id'] = redId;
      queryParams['red_name'] = redName;
      queryParams['red_avatar'] = redAvatar;

      queryParams['yellow_id'] = yellowId;
      queryParams['yellow_name'] = yellowName;
      queryParams['yellow_avatar'] = yellowAvatar;

      return uri.replace(queryParameters: queryParams).toString();
    } catch (_) {
      return cleanUrl;
    }
  }

  void _confirmCloseLudo() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C0A33),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFFFD700), width: 1.2),
        ),
        title: const Row(
          children: [
            Icon(Icons.casino, color: Color(0xFFFFD700), size: 24),
            SizedBox(width: 8),
            Text(
              'End Ludo Game?',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: const Text(
          'Ending the game will close the Ludo arena and restore voice room seats for all participants.',
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _closeLudo();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('End Game', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _closeLudo() {
    try {
      FirebaseDatabase.instance
          .ref('rooms/${widget.room.id}/ludo/action')
          .set({
            'type': 'PLAYER_LEFT',
            'userId': widget.currentUserId,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          });
    } catch (_) {}

    widget.repository.updateLudoState(
      roomId: widget.room.id,
      isActive: false,
    );

    try {
      final user = AuthController.instance.currentUser;
      final userId = user.userId.isNotEmpty ? user.userId : 'system';
      final userName = user.fullname.isNotEmpty ? user.fullname : 'Host';
      final userAvatar = user.photoUrl;

      widget.repository.sendChatMessage(
        widget.room.id,
        userId,
        userName,
        userAvatar,
        '🏁 Host ended Ludo Game',
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isStarted = _ludoController.gameState.value.isStarted;

      if (!isStarted) {
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: LudoLobbyWidget(
            controller: _ludoController,
            currentUserId: widget.currentUserId,
            onStart: () {
              _ludoController.startGame();
              _loadGameUrl();
            },
            onClose: _confirmCloseLudo,
            isHost: widget.isHost,
          ),
        );
      }

      final screenWidth = MediaQuery.of(context).size.width;
      final double arenaWidth = screenWidth - 24;
      final double arenaHeight = arenaWidth + 44;

      return Container(
        width: arenaWidth,
        height: arenaHeight,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF2B0A4E),
              Color(0xFF160529),
              Color(0xFF0F031C),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFFFD700).withValues(alpha: 0.85),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD700).withValues(alpha: 0.25),
              blurRadius: 18,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.7),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                child: Stack(
                  children: [
                    WebViewWidget(controller: _controller),
                    if (_isLoading) _buildLoadingOverlay(),
                    if (_hasError) _buildErrorOverlay(),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildHeader() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFFFB300),
            Color(0xFFFF8F00),
            Color(0xFFFF6F00),
          ],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.casino, color: Colors.black87, size: 20),
              const SizedBox(width: 8),
              const Text(
                'LUDO CHAMPION',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'ROOM MODE',
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 8.5,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  Html5GameSheet.show(
                    context,
                    url: _rawGameUrl,
                    title: 'Ludo Champion (লুডু গেম)',
                    isInAudioRoom: true,
                    roomId: widget.room.id,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(5),
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.12),
                  ),
                  child: const Icon(Icons.fullscreen, color: Colors.black87, size: 18),
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() => _isLoading = true);
                  if (_finalUrl.isNotEmpty) {
                    _controller.reload();
                  } else {
                    _loadGameUrl();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(5),
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.12),
                  ),
                  child: const Icon(Icons.refresh, color: Colors.black87, size: 18),
                ),
              ),
              if (widget.isHost)
                GestureDetector(
                  onTap: _confirmCloseLudo,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.18),
                    ),
                    child: const Icon(Icons.close, color: Colors.black, size: 18),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: const Color(0xFF140526),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
              strokeWidth: 3,
            ),
            const SizedBox(height: 14),
            const Text(
              'Loading Ludo Arena...',
              style: TextStyle(
                color: Color(0xFFFFD700),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            if (_loadingProgress > 0) ...[
              const SizedBox(height: 8),
              Text(
                '${(_loadingProgress * 100).toInt()}%',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorOverlay() {
    return Container(
      color: const Color(0xFF140526),
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: Colors.orangeAccent, size: 40),
            const SizedBox(height: 10),
            const Text(
              'Failed to load Ludo Arena',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 6),
            const Text(
              'Please check your internet connection.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _hasError = false;
                });
                if (_finalUrl.isNotEmpty) {
                  _controller.reload();
                } else {
                  _loadGameUrl();
                }
              },
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9800),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

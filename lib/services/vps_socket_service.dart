import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:chat_messenger/screens/audio_rooms_v2/audio_rooms_v2_integration.dart';
import 'global_settings_service.dart';

/// Realtime Socket.io service for 1v1 messaging, voice rooms, seat updates & gifts
class VpsSocketService extends GetxService {
  final GlobalSettingsService _settings = Get.find<GlobalSettingsService>();

  io.Socket? _socket;
  String _currentConnectedUrl = '';
  final RxBool isConnected = false.obs;
  bool _isConnecting = false;

  @override
  void onInit() {
    super.onInit();
    // Only re-connect when the VPS base or socket URL or backend engine explicitly changes
    ever(_settings.vpsBaseUrl, (_) => _onConfigChanged());
    ever(_settings.vpsSocketUrl, (_) => _onConfigChanged());
    ever(_settings.activeBackendEngine, (_) => _onConfigChanged());

    // Re-authenticate / reconnect whenever Firebase Auth state changes
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        authenticate(user.uid);
      }
    });

    Future.delayed(const Duration(milliseconds: 500), () => connect());
  }

  void _onConfigChanged() {
    final newUrl = socketUrl;
    if (newUrl != _currentConnectedUrl) {
      disconnect();
      connect();
    }
  }

  Future<void> authenticate([String? explicitUid]) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final uid = explicitUid ?? user?.uid;
      if (uid != null && uid.isNotEmpty && uid != 'guest') {
        String token = '';
        try {
          token = await user?.getIdToken() ?? '';
        } catch (e) {
          debugPrint('[VpsSocketService] Failed to obtain ID token in authenticate: $e');
        }
        if (_socket != null && _socket!.connected) {
          _socket!.emit('authenticate', {'uid': uid, 'token': token});
          debugPrint('🔑 [VpsSocketService] Emitted authenticate for UID: $uid');
        } else {
          connect();
        }
      }
    } catch (e) {
      debugPrint('[VpsSocketService] Error during authenticate: $e');
    }
  }

  // Stream Controllers for real-time app events
  final _directMessageController = StreamController<Map<String, dynamic>>.broadcast();
  final _groupMessageController = StreamController<Map<String, dynamic>>.broadcast();
  final _roomMessageController = StreamController<Map<String, dynamic>>.broadcast();
  final _seatUpdateController = StreamController<Map<String, dynamic>>.broadcast();
  final _giftAnimationController = StreamController<Map<String, dynamic>>.broadcast();
  final _momentPostController = StreamController<Map<String, dynamic>>.broadcast();
  final _momentLikeController = StreamController<Map<String, dynamic>>.broadcast();
  final _momentCommentController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get directMessageStream => _directMessageController.stream;
  Stream<Map<String, dynamic>> get groupMessageStream => _groupMessageController.stream;
  Stream<Map<String, dynamic>> get roomMessageStream => _roomMessageController.stream;
  Stream<Map<String, dynamic>> get seatUpdateStream => _seatUpdateController.stream;
  Stream<Map<String, dynamic>> get giftAnimationStream => _giftAnimationController.stream;
  Stream<Map<String, dynamic>> get momentPostStream => _momentPostController.stream;
  Stream<Map<String, dynamic>> get momentLikeStream => _momentLikeController.stream;
  Stream<Map<String, dynamic>> get momentCommentStream => _momentCommentController.stream;

  String get socketUrl {
    String raw = _settings.vpsSocketUrl.value.trim();
    if (raw.isEmpty) {
      raw = _settings.vpsBaseUrl.value.trim();
    }
    if (raw.isEmpty) return '';
    // Normalize ws:// to http:// and wss:// to https:// because socket_io_client requires http/https
    if (raw.startsWith('ws://')) {
      raw = 'http://${raw.substring(5)}';
    } else if (raw.startsWith('wss://')) {
      raw = 'https://${raw.substring(6)}';
    } else if (!raw.startsWith('http://') && !raw.startsWith('https://')) {
      raw = 'http://$raw';
    }
    return raw.replaceAll(RegExp(r'/+$'), '');
  }

  Future<void> connect() async {
    final url = socketUrl;
    if (url.isEmpty) {
      debugPrint('[VpsSocketService] Socket URL is empty, skipping connection');
      return;
    }

    // If socket is already active for this URL, do not dispose or recreate it
    if (_socket != null && _socket!.connected && _currentConnectedUrl == url) {
      authenticate();
      return;
    }

    if (_isConnecting) {
      return;
    }

    _isConnecting = true;

    try {
      final user = FirebaseAuth.instance.currentUser;
      String token = '';
      try {
        token = await user?.getIdToken() ?? '';
      } catch (e) {
        debugPrint('[VpsSocketService] Warning: Failed to fetch ID token: $e');
      }
      final uid = user?.uid ?? 'guest';

      debugPrint('[VpsSocketService] Initiating socket connection to: $url (UID: $uid)');
      _currentConnectedUrl = url;
      _socket?.dispose();

      _socket = io.io(
        url,
        io.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .setAuth({'token': token, 'uid': uid})
            .setQuery({'token': token, 'uid': uid})
            .setExtraHeaders({'origin': '*'})
            .enableReconnection()
            .setReconnectionAttempts(100)
            .setReconnectionDelay(2000)
            .setReconnectionDelayMax(5000)
            .setTimeout(10000)
            .enableAutoConnect()
            .build(),
      );

      _socket!.onConnect((_) async {
        _isConnecting = false;
        isConnected.value = true;
        debugPrint('🚀 [VpsSocketService] Successfully Connected to VPS Realtime Server ($url)');

        // Immediately authenticate with active UID
        try {
          final currentUser = FirebaseAuth.instance.currentUser;
          final currentUid = currentUser?.uid ?? uid;
          if (currentUid.isNotEmpty && currentUid != 'guest') {
            String currentToken = token;
            try {
              final fetched = await currentUser?.getIdToken();
              if (fetched != null && fetched.isNotEmpty) {
                currentToken = fetched;
              }
            } catch (tokenErr) {
              debugPrint('⚠️ [VpsSocketService] Could not refresh token on connect: $tokenErr');
            }
            _socket!.emit('authenticate', {'uid': currentUid, 'token': currentToken});
            debugPrint('🔑 [VpsSocketService] Authenticated on connect: $currentUid');
          }
        } catch (e) {
          debugPrint('⚠️ [VpsSocketService] Error during onConnect auth: $e');
        }

        if (_activeRoomId != null && _activeRoomId!.isNotEmpty) {
          _socket!.emit('join_room', {'roomId': _activeRoomId});
          debugPrint('🎙️ [VpsSocketService] Re-joined active room: $_activeRoomId');
        }
      });

      _socket!.onDisconnect((reason) {
        _isConnecting = false;
        isConnected.value = false;
        debugPrint('⚠️ [VpsSocketService] Disconnected from VPS Realtime Server ($reason)');
      });

      _socket!.onConnectError((err) {
        _isConnecting = false;
        isConnected.value = false;
        debugPrint('❌ [VpsSocketService] Connect Error: $err');
      });

      // 1v1 Direct Message Event
      _socket!.on('direct_message_received', (data) {
        if (data is Map) {
          _directMessageController.add(Map<String, dynamic>.from(data));
        }
      });

      _socket!.on('direct_message_sent', (data) {
        if (data is Map) {
          _directMessageController.add(Map<String, dynamic>.from(data));
        }
      });

      // Group Message Event
      _socket!.on('new_group_message', (data) {
        if (data is Map) {
          _groupMessageController.add(Map<String, dynamic>.from(data));
        }
      });

      // Room Real-time Events
      _socket!.on('seat_updated', (data) {
        if (data is Map) {
          _seatUpdateController.add(Map<String, dynamic>.from(data));
        }
      });

      _socket!.on('new_room_message', (data) {
        if (data is Map) {
          _roomMessageController.add(Map<String, dynamic>.from(data));
        }
      });

      _socket!.on('room_gift_animation', (data) {
        if (data is Map) {
          _giftAnimationController.add(Map<String, dynamic>.from(data));
        }
      });

      // Moments Real-time Events
      _socket!.on('new_moment_post', (data) {
        if (data is Map) {
          _momentPostController.add(Map<String, dynamic>.from(data));
        }
      });

      _socket!.on('moment_liked', (data) {
        if (data is Map) {
          _momentLikeController.add(Map<String, dynamic>.from(data));
        }
      });

      _socket!.on('new_moment_comment', (data) {
        if (data is Map) {
          _momentCommentController.add(Map<String, dynamic>.from(data));
        }
      });

      // Follower Live Room Notification
      _socket!.on('follower_live_notification', (data) {
        if (data is Map) {
          final title = data['title']?.toString() ?? 'Live Room Alert';
          final body = data['body']?.toString() ?? "Let's have fun together!!🤘🤟";
          final roomId = data['roomId']?.toString() ?? '';

          if (roomId.isNotEmpty) {
            try {
              final context = Get.overlayContext ?? Get.context;
              if (context != null && Overlay.maybeOf(context) != null) {
                Get.snackbar(
                  title,
                  body,
                  backgroundColor: const Color(0xFF1E1E2E),
                  colorText: Colors.white,
                  snackPosition: SnackPosition.TOP,
                  margin: const EdgeInsets.all(10),
                  duration: const Duration(seconds: 8),
                  mainButton: TextButton(
                    onPressed: () {
                      if (Get.isSnackbarOpen == true) Get.back();
                      AudioRoomsV2Integration.joinRoomById(roomId);
                    },
                    child: const Text('Join Live', style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                  ),
                  onTap: (_) {
                    AudioRoomsV2Integration.joinRoomById(roomId);
                  },
                );
              }
            } catch (e) {
              debugPrint('[VpsSocketService] Follower live banner error: $e');
            }
          }
        }
      });

      _socket!.connect();
    } catch (e) {
      _isConnecting = false;
      debugPrint('[VpsSocketService] Error initiating socket: $e');
    }
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    isConnected.value = false;
  }

  // --------------------------------------------------------------------------
  // 1v1 Messaging Methods
  // --------------------------------------------------------------------------
  void sendDirectMessage({
    required String receiverId,
    required String content,
    String messageType = 'text',
    String? mediaUrl,
    int? mediaDuration,
    String? giftId,
    int giftCount = 1,
    String? msgId,
  }) {
    if (_socket == null || !_socket!.connected) {
      connect();
    }
    _socket?.emit('send_direct_message', {
      'id': msgId,
      'msgId': msgId,
      'receiverId': receiverId,
      'content': content,
      'messageType': messageType,
      'mediaUrl': mediaUrl ?? '',
      'mediaDuration': mediaDuration ?? 0,
      'giftId': giftId,
      'giftCount': giftCount,
    });
  }

  String? _activeRoomId;

  // --------------------------------------------------------------------------
  // Voice Room Methods
  // --------------------------------------------------------------------------
  void joinRoom(String roomId) {
    _activeRoomId = roomId;
    if (_socket == null || !_socket!.connected) {
      connect();
    }
    _socket?.emit('join_room', {'roomId': roomId});
    debugPrint('🎙️ [VpsSocketService] Emitted join_room for: $roomId');
  }

  void leaveRoom(String roomId) {
    if (_activeRoomId == roomId) _activeRoomId = null;
    _socket?.emit('leave_room', {'roomId': roomId});
  }

  void takeSeat({required String roomId, required int seatIndex}) {
    if (_socket == null || !_socket!.connected) connect();
    _socket?.emit('take_seat', {'roomId': roomId, 'seatIndex': seatIndex});
  }

  void leaveSeat({required String roomId, required int seatIndex}) {
    if (_socket == null || !_socket!.connected) connect();
    _socket?.emit('leave_seat', {'roomId': roomId, 'seatIndex': seatIndex});
  }

  void sendRoomMessage({
    required String roomId,
    required String content,
    String messageType = 'text',
    Map<String, dynamic>? extraData,
  }) {
    if (_socket == null || !_socket!.connected) {
      connect();
    }
    _socket?.emit('send_room_message', {
      'roomId': roomId,
      'content': content,
      'messageType': messageType,
      'extraData': extraData ?? {},
    });
    debugPrint('💬 [VpsSocketService] Emitted send_room_message for room: $roomId (content: $content)');
  }

  void sendRoomGift({
    required String roomId,
    required String receiverId,
    required String giftId,
    required String giftName,
    required String giftIcon,
    String? giftSvgaUrl,
    required int giftCoins,
    int giftCount = 1,
  }) {
    if (_socket == null || !_socket!.connected) {
      connect();
    }
    _socket?.emit('send_room_gift', {
      'roomId': roomId,
      'receiverId': receiverId,
      'giftId': giftId,
      'giftName': giftName,
      'giftIcon': giftIcon,
      'giftSvgaUrl': giftSvgaUrl ?? '',
      'giftCoins': giftCoins,
      'giftCount': giftCount,
    });
  }

  // --------------------------------------------------------------------------
  // Group Chat Methods
  // --------------------------------------------------------------------------
  void joinGroup(String groupId) {
    if (_socket == null || !_socket!.connected) connect();
    _socket?.emit('join_group', {'groupId': groupId});
  }

  void leaveGroup(String groupId) {
    _socket?.emit('leave_group', {'groupId': groupId});
  }

  void sendGroupMessage({
    required String groupId,
    required String content,
    String messageType = 'text',
    String? mediaUrl,
    int? mediaDuration,
  }) {
    if (_socket == null || !_socket!.connected) connect();
    _socket?.emit('send_group_message', {
      'groupId': groupId,
      'content': content,
      'messageType': messageType,
      'mediaUrl': mediaUrl ?? '',
      'mediaDuration': mediaDuration ?? 0,
    });
  }

  // --------------------------------------------------------------------------
  // Moments / News Feed Methods
  // --------------------------------------------------------------------------
  void publishMoment(Map<String, dynamic> postData) {
    if (_socket == null || !_socket!.connected) connect();
    _socket?.emit('publish_moment', postData);
  }

  void likeMoment({required String postId, String reactionType = 'like'}) {
    if (_socket == null || !_socket!.connected) connect();
    _socket?.emit('like_moment', {'postId': postId, 'reactionType': reactionType});
  }

  void commentMoment({
    required String postId,
    String? commentId,
    required String text,
    required String userName,
    String? userAvatar,
    String? userFrameId,
    String? imageUrl,
    String? replyToId,
    String? replyToUserName,
  }) {
    if (_socket == null || !_socket!.connected) connect();
    _socket?.emit('comment_moment', {
      'postId': postId,
      'commentId': commentId,
      'text': text,
      'userName': userName,
      'userAvatar': userAvatar,
      'userFrameId': userFrameId,
      'imageUrl': imageUrl,
      'replyToId': replyToId,
      'replyToUserName': replyToUserName,
    });
  }

  @override
  void onClose() {
    disconnect();
    _directMessageController.close();
    _groupMessageController.close();
    _roomMessageController.close();
    _seatUpdateController.close();
    _giftAnimationController.close();
    _momentPostController.close();
    _momentLikeController.close();
    _momentCommentController.close();
    super.onClose();
  }
}

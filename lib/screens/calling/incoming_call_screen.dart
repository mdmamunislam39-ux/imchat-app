import 'dart:async';

import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/screens/home/home_screen.dart';
import 'package:chat_messenger/tabs/groups/screens/group_video_call.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:chat_messenger/components/cached_circle_avatar.dart';
import 'package:chat_messenger/models/call.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:chat_messenger/routes/app_routes.dart';
import 'package:chat_messenger/config/theme_config.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'package:flutter/services.dart';
import 'package:chat_messenger/main.dart';

import 'package:chat_messenger/services/agora_token_service.dart';
import 'package:chat_messenger/services/agora_service.dart';

import '../../components/app_loading.dart';
import '../../components/circle_button.dart';

class IncommingCallScreen extends StatefulWidget {
  const IncommingCallScreen({super.key, required this.call});

  final Call call;

  @override
  State<IncommingCallScreen> createState() => _IncommingCallScreenState();
}

class _IncommingCallScreenState extends State<IncommingCallScreen>
    with SingleTickerProviderStateMixin {
  // Animation controller
  late AnimationController _controller;
  late Animation<double> _animation;
  bool isMinimized = false;
  Timer? _timeoutTimer;

  ////////////////add new///////////////
  RxString callState = ''.obs;

  // Firestore listener stream
  late StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>
      callSubscription;

  void _safeClose() {
    FlutterRingtonePlayer().stop();
    const MethodChannel('com.imchatapp/app_visibility')
        .invokeMethod('clearWakeScreen')
        .catchError((_) {});
    if (mounted) {
      final nav = navigatorKey.currentState ?? Get.key.currentState;
      if (nav != null && nav.canPop()) {
        nav.pop();
      } else {
        Get.offAllNamed(AppRoutes.home);
      }
    }
  }

  bool _documentEverExisted = false;

  void _listenToCallState() {
    // Listen to Firestore changes
    try {
      final collection = widget.call.receiverId == 'group_call' ? 'GroupCalls' : 'Calls';
      callSubscription = FirebaseFirestore.instance
          .collection(collection)
          .doc(widget.call.callerId)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists) {
          _documentEverExisted = true;
          String state = snapshot.data()?['state'] ?? '';
          if (state == 'decline' || state == 'missed' || state == 'ended' || state == 'cancel') {
            _safeClose();
          }
        } else {
          // Only close if the document previously existed and was deleted
          if (_documentEverExisted) {
            _safeClose();
          }
        }
      });
    } catch (e) {
      AppStyle().failedSnackBar(message: e.toString());
    }
  }

  @override
  void initState() {
    // Play Ringtone for incoming call
    FlutterRingtonePlayer().play(
      fromAsset: 'assets/sound.mp3',
      // android: AndroidSounds.ringtone,
      ios: IosSounds.electronic,
      //looping: true, // Android only - API >= 28
      volume: 0.5, // Android only - API >= 28
      // asAlarm: true, // Android only - all APIs
    );

    // Pre-warm Agora RTC Engine & Token in background while ringing (0ms latency upon Accept)
    try {
      final token = widget.call.agoraToken;
      if (token != null && token.isNotEmpty) {
        AgoraTokenService.instance.cachePreGeneratedToken(
          channelName: widget.call.callerId,
          token: token,
        );
      } else {
        AgoraTokenService.instance.generateToken(
          channelName: widget.call.callerId,
          uid: 0,
        ).catchError((_) => null);
      }
      AgoraService().initialize().catchError((_) => false);
    } catch (_) {}

    // Create an animation controller that loops
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true); // Loop the animation

    _animation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _listenToCallState();

    // Start 45-second timeout timer
    _timeoutTimer = Timer(const Duration(seconds: 45), _handleTimeout);

    // Turn screen on and show over lock screen only while incoming call screen is active
    const MethodChannel('com.imchatapp/app_visibility')
        .invokeMethod('wakeScreen')
        .catchError((_) {});

    super.initState();
  }

  void _handleTimeout() async {
    try {
      final docRef = widget.call.receiverId == 'group_call'
          ? FirebaseFirestore.instance
              .collection('GroupCalls')
              .doc(widget.call.callerId)
          : FirebaseFirestore.instance
              .collection('Calls')
              .doc(widget.call.callerId);

      final docSnapshot = await docRef.get();
      if (docSnapshot.exists) {
        await docRef.update({'state': 'missed'}).catchError((_) {});
        Future.delayed(const Duration(seconds: 3), () {
          docRef.delete().catchError((_) {});
          box.remove('callIsActive');
        });
      }
      _safeClose();
    } catch (e) {
      debugPrint('Timeout error: $e');
      _safeClose();
    }
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    FlutterRingtonePlayer().stop();
    _controller.dispose();
    callSubscription.cancel();
    const MethodChannel('com.imchatapp/app_visibility')
        .invokeMethod('clearWakeScreen')
        .catchError((_) {});
    super.dispose();
  }

  var box = GetStorage();
  void onPhoneBackButtonPress() {
    box.write('callIsActive', widget.call.toMap());
    Get.to(() => HomeScreen());
  }

  @override
  Widget build(BuildContext context) {
    // final CallController controller =
    //     Get.put(CallController(call: widget.call));
    final String photoUrl = widget.call.callerPhotoUrl;
    final User currentUser = AuthController.instance.currentUser;
    return PopScope(
      canPop: true,
      child: Scaffold(
          // extendBodyBehindAppBar: true,
          // appBar: const CustomAppBar(
          //   centerTitle: false,
          //   backgroundColor: Colors.transparent,
          // ),
          body: Stack(
        children: [
          // WhatsApp style dark background
          Container(
            color: const Color(0xFF1E1E1E), // Dark grey like WhatsApp
            width: double.maxFinite,
            height: double.maxFinite,
          ),
          if (photoUrl.isEmpty)
            Container(
              color: Theme.of(context).colorScheme.primaryContainer,
              width: double.maxFinite,
              height: double.maxFinite,
            ),
          Positioned(
            top: 45, // Adjust the top margin as needed
            left: 30, // Adjust the left margin as needed
            child: IconButton(
              icon:
                  const Icon(Icons.zoom_out_map, color: Colors.white, size: 30),
              onPressed: () {
                box.write('callIsActive', widget.call.toMap());
                Get.to(() => HomeScreen());
              },
            ),
          ),
          // Content container
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: defaultPadding,
                vertical: defaultPadding * 2,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  SizedBox(
                    height: 20,
                  ),
                  // Profile avatar
                  CachedCircleAvatar(
                    iconSize: 70,
                    imageUrl: photoUrl,
                    radius: 75,
                  ),
                  const SizedBox(height: 16),
                  // Profile name
                  Text(
                    widget.call.callerName,
                    style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  widget.call.receiverId == 'group_call'
                      ? Text(
                          widget.call.isVideo
                              ? 'Incoming Group Video Call'
                              : 'Incoming Group Voice Call',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium!
                              .copyWith(color: Colors.white70),
                        )
                      : Text(
                          widget.call.isVideo
                              ? 'Incoming Video Call'
                              : 'Incoming Voice Call',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium!
                              .copyWith(color: Colors.white70),
                        ),
                  const Spacer(),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // Decline call
                      Column(
                        children: [
                          CircleButton(
                            size: 70,
                            color: Colors.red,
                            icon: const Icon(
                              Icons.call_end,
                              color: Colors.white,
                              size: 35,
                            ),
                            onPress: () {
                              FlutterRingtonePlayer().stop();
                              if (widget.call.receiverId == 'group_call') {
                                _safeClose();
                              } else {
                                try {
                                  final docRef = FirebaseFirestore.instance
                                      .collection('Calls')
                                      .doc(widget.call.callerId);

                                  // Update state asynchronously without blocking UI
                                  docRef.update(
                                      {'state': 'decline'}).catchError((_) {});

                                  // Asynchronously delete document after delay to ensure update propagates
                                  Future.delayed(
                                      const Duration(seconds: 3), () {
                                    docRef.delete().catchError((_) {});
                                  });

                                  // Immediately remove from local storage and navigate back
                                  box.remove('callIsActive');
                                  _safeClose();
                                } catch (e) {
                                  debugPrint(e.toString());
                                  _safeClose();
                                }
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          const Text('Decline',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 16)),
                        ],
                      ),

                      // Accept call
                      Column(
                        children: [
                          ScaleTransition(
                            scale: _animation,
                            child: CircleButton(
                              size: 70,
                              color: Colors.green,
                              icon: const Icon(
                                Icons.call,
                                color: Colors.white,
                                size: 35,
                              ),
                              onPress: () {
                                if (widget.call.receiverId == 'group_call') {
                                  final docRef = FirebaseFirestore.instance
                                      .collection('GroupCalls')
                                      .doc(widget.call.callerId);

                                  // Async update without waiting for get()
                                  docRef.update({
                                    'receiverName': FieldValue.arrayUnion(
                                        [currentUser.fullname]),
                                    'state': 'running',
                                  }).catchError((_) {});

                                  // Instant navigation
                                  Get.off(() => GroupCallScreen(
                                      isVideo: widget.call.isVideo,
                                      call: widget.call));
                                } else {
                                  final docRef = FirebaseFirestore.instance
                                      .collection('Calls')
                                      .doc(widget.call.callerId);

                                  // Async update without waiting for get()
                                  docRef.update(
                                      {'state': 'running'}).catchError((_) {});

                                  // Instant navigation
                                  if (widget.call.isVideo) {
                                    Get.offNamed(AppRoutes.videoCall,
                                        arguments: {'call': widget.call});
                                  } else {
                                    Get.offNamed(AppRoutes.voiceCall,
                                        arguments: {'call': widget.call});
                                  }
                                }
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text('Accept',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 16)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 50),

                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      )),
    );
  }
}

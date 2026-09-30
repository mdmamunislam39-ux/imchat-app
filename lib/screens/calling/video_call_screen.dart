import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

import 'package:chat_messenger/components/cached_card_image.dart';
import 'package:chat_messenger/components/loading_indicator.dart';
import 'package:chat_messenger/screens/home/home_screen.dart';

import 'package:flutter/material.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/models/call.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:chat_messenger/screens/calling/controller/call_controller.dart';
import 'package:chat_messenger/config/theme_config.dart';
import 'package:get_storage/get_storage.dart';

import 'components/call_bacground.dart';
import 'components/call_timer.dart';
import '../../components/circle_button.dart';
import 'components/local_user_preview.dart';

class VideoCallScreen extends StatefulWidget {
  const VideoCallScreen({
    super.key,
    required this.call,
  });

  final Call call;

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  late final CallController controller;
  final GetStorage box = GetStorage();

  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<CallController>()) {
      Get.delete<CallController>(force: true);
    }
    controller = Get.put(CallController(call: widget.call));
  }

  void onPhoneBackButtonPress() {
    try {
      box.write('callIsActive', widget.call.toMap());
    } catch (_) {}
    Get.to(() => HomeScreen());
  }

  @override
  Widget build(BuildContext context) {
    // Get current user model
    final User currentUser = AuthController.instance.currentUser;

    return PopScope(
      canPop: true,
      child: Obx(() {
        // Get obx vars
        final int? remoteUid = controller.remoteUid.value;

        final String photoUrl =
            widget.call.isCaller ? widget.call.receiverPhotoUrl : widget.call.callerPhotoUrl;
        final String profileName =
            widget.call.isCaller ? widget.call.receiverName : widget.call.callerName;
        return Scaffold(
          body: CallBackground(
            remoteUid: remoteUid,
            // <-- REMOTE user video preview  -->
            preview:
             remoteUid != null
                ? Stack(
                  fit: StackFit.expand,
                  children: [
                    controller.isRemoteVideoMuted.value
                        ? Container(
                            color: Colors.black,
                            child: Center(
                              child: photoUrl.isEmpty
                                  ? const Icon(Icons.person,
                                      color: Colors.white, size: 100)
                                  : CachedCardImage(photoUrl),
                            ),
                          )
                        : (controller.isLiveKit
                            ? (controller.livekitService.remoteVideoTrack.value != null
                                ? lk.VideoTrackRenderer(
                                    controller.livekitService.remoteVideoTrack.value!,
                                  )
                                : CachedCardImage(photoUrl))
                            : AgoraVideoView(
                                controller: VideoViewController.remote(
                                  rtcEngine: controller.engine,
                                  canvas: VideoCanvas(
                                    uid: remoteUid,
                                  ),
                                  connection: RtcConnection(
                                    channelId: widget.call.callerId
                                  ),
                                ),
                              )),
                    Positioned(
                      top: 45, // Adjust the top margin as needed
                      left: 30, // Adjust the left margin as needed
                      child: IconButton(
                        icon: const Icon(Icons.zoom_out_map,
                            color: Colors.white, size: 30),
                        onPressed: () {
                            controller.isMinimized.value = true;
                            box.write('callIsActive', widget.call.toMap());
                            Get.to(()=>HomeScreen(
                              passController: controller,routeVideo: 'video',
                            ));
                        },
                      ),
                    ),
                    const Center(child: CallTimer()),
                  ],
                )
                : photoUrl.isEmpty
                    ? Container(
                        color: Theme.of(context).colorScheme.primaryContainer,
                      )
                    : CachedCardImage(photoUrl),
            // Other content
            child: Stack(
              children: [
                SafeArea(
                  child: Column(
                    children: [
                      const Spacer(),
                      // <-- LOCAL user video preview  -->
                      Obx(
                        () => LocalUserPreview(
                          child: controller.isLocalUserJoined.value
                              ? (controller.isLiveKit
                                  ? (controller.livekitService.localVideoTrack.value != null
                                      ? lk.VideoTrackRenderer(
                                          controller.livekitService.localVideoTrack.value!,
                                        )
                                      : CachedCardImage(currentUser.photoUrl))
                                  : AgoraVideoView(
                                      controller: VideoViewController(
                                        rtcEngine: controller.engine,
                                        canvas: const VideoCanvas(uid: 0),
                                      ),
                                    ))
                              : currentUser.photoUrl.isEmpty
                                  ? const Icon(IconlyBold.profile,
                                      color: Colors.white, size: 60)
                                  : CachedCardImage(currentUser.photoUrl),
                        ),
                      ),
      
                      // <-- Call actions -->
                      Padding(
                        padding: const EdgeInsets.all(defaultPadding),
                        child: Obx(() => Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Speaker
                            // CircleButton(
                            //   color: primaryColor,
                            //   icon: Icon(
                            //     controller.speaker.value
                            //         ? IconlyBold.volumeUp
                            //         : IconlyBold.volumeOff,
                            //     color: Colors.white,
                            //   ),
                            //   onPress: () => controller.onToggleSpeaker(),
                            // ),
                            //camera off/on
                            CircleButton(
                              color: Colors.black54,
                              icon: Icon(
                                controller.isCameraOn.value
                                    ? Icons.videocam
                                    : Icons.videocam_off,
                                color: Colors.white,
                              ),
                              onPress: () => controller.toggleCamera(),
                            ),
                            // Switch camera
                            CircleButton(
                              color: Colors.black54,
                              icon: Icon(
                                controller.switchCamera.value
                                    ?Icons.cameraswitch
                                    :Icons.cameraswitch,
                                color: Colors.white,
                              ),
                              onPress: () => controller.onSwitchCamera(),
                            ),
                            // Mute
                            CircleButton(
                              color: Colors.black54,
                              icon: Icon(
                                controller.mute.value
                                    ? Icons.mic_off
                                    : IconlyBold.voice,
                                color: Colors.white,
                              ),
                              onPress: () => controller.onToggleMute(),
                            ),
                            // End call
                            CircleButton(
                              color: Colors.redAccent,
                              icon: const Icon(
                                IconlyBold.callMissed,
                                color: Colors.white,
                              ),
                              onPress: () {
                                try {
                                  box.remove('callIsActive');
                                } catch (_) {}
                                controller.onEndCall();
                              },
                            ),
                          ],
                        )),
                      ),
                    ],
                  ),
                ),
                // <-- Call indicator status -->
                if (remoteUid == null)
                  Center(
                    // child: JoinCallIndicator(
                    //   call,
                    //   loadingColor:
                    //       photoUrl.isEmpty ? Colors.white : primaryColor,
                    // ),
                    child: Column(
                          children: [
                            Text(
          profileName,
          style: Theme.of(context)
              .textTheme
              .headlineSmall!
              .copyWith(color: Colors.white54),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        // Show when current user is a caller
        if (widget.call.isCaller && controller.isOnline.value==true)
        Text(
            'Ringing',
            style: Theme.of(context)
                .textTheme
                .bodyLarge!
                .copyWith(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        
        if (widget.call.isCaller && controller.isOnline.value==false)
          Text(
            'calling'.tr,
            style: Theme.of(context)
                .textTheme
                .bodyLarge!
                .copyWith(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: 3),
        // Show loading
        LoadingIndicator(color: photoUrl.isEmpty ? Colors.white : primaryColor),
                          ],
                         ),
                  ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

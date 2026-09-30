import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:chat_messenger/screens/room/controller/video_live_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

class VideoLiveScreen extends StatelessWidget {
  final String roomId;
  final String roomName;
  final bool isBroadcaster;

  const VideoLiveScreen({
    super.key,
    required this.roomId,
    required this.roomName,
    required this.isBroadcaster,
  });

  @override
  Widget build(BuildContext context) {
    final VideoLiveController controller = Get.put(
      VideoLiveController(roomId: roomId, isBroadcaster: isBroadcaster),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video Layer
          Obx(() {
            if (!controller.isJoined.value) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            }

            final bool isCameraMuted = isBroadcaster 
                ? controller.isCameraOff.value 
                : controller.remoteCameraOff.value;

            if (isCameraMuted) {
              return Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (controller.broadcasterPhotoUrl.value.isNotEmpty)
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: NetworkImage(controller.broadcasterPhotoUrl.value),
                      )
                    else
                      const CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey,
                        child: Icon(Icons.person, size: 50, color: Colors.white),
                      ),
                    if (controller.broadcasterFrameUrl.value.isNotEmpty)
                      SizedBox(
                        width: 130,
                        height: 130,
                        child: Image.network(controller.broadcasterFrameUrl.value, fit: BoxFit.cover),
                      ),
                  ],
                ),
              );
            }

            if (isBroadcaster) {
              if (controller.isLiveKit) {
                return controller.livekitService.localVideoTrack.value != null
                    ? lk.VideoTrackRenderer(
                        controller.livekitService.localVideoTrack.value!,
                      )
                    : const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      );
              }
              return AgoraVideoView(
                controller: VideoViewController(
                  rtcEngine: controller.engine,
                  canvas: const VideoCanvas(uid: 0), // Local view
                ),
              );
            } else {
              if (controller.isLiveKit) {
                if (controller.livekitService.remoteVideoTrack.value != null) {
                  return lk.VideoTrackRenderer(
                    controller.livekitService.remoteVideoTrack.value!,
                  );
                } else {
                  return const Center(
                    child: Text(
                      'Waiting for broadcaster...',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  );
                }
              } else {
                if (controller.remoteUids.isNotEmpty) {
                  // Show the first remote user (the broadcaster)
                  return AgoraVideoView(
                    controller: VideoViewController.remote(
                      rtcEngine: controller.engine,
                      canvas: VideoCanvas(uid: controller.remoteUids.first),
                      connection: RtcConnection(channelId: roomId),
                    ),
                  );
                } else {
                  return const Center(
                    child: Text(
                      'Waiting for broadcaster...',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  );
                }
              }
            }
          }),

          // UI Overlay Layer
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Bar
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Room Info
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 14,
                              backgroundColor: Colors.blueAccent,
                              child: Icon(Icons.live_tv, size: 16, color: Colors.white),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              roomName,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      // Close Button
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 30),
                        onPressed: () {
                          controller.leaveRoom();
                        },
                      ),
                    ],
                  ),
                ),
                
                const Spacer(),
                
                // Bottom Bar placeholder
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: const Text(
                            'Say hi...',
                            style: TextStyle(color: Colors.white54),
                          ),
                        ),
                      ),
                      if (isBroadcaster) ...[
                        const SizedBox(width: 12),
                        Obx(() => GestureDetector(
                          onTap: () => controller.toggleCamera(),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: controller.isCameraOff.value ? Colors.redAccent : Colors.black45,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              controller.isCameraOff.value ? Icons.videocam_off : Icons.videocam, 
                              color: Colors.white
                            ),
                          ),
                        )),
                        const SizedBox(width: 12),
                        Obx(() => GestureDetector(
                          onTap: () => controller.toggleMic(),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: controller.isMicOff.value ? Colors.redAccent : Colors.black45,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              controller.isMicOff.value ? Icons.mic_off : Icons.mic, 
                              color: Colors.white
                            ),
                          ),
                        )),
                        const SizedBox(width: 12),
                      ],
                      if (!isBroadcaster) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: Colors.pinkAccent,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.card_giftcard, color: Colors.white),
                        ),
                      ],
                    ],
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

// import 'package:chat_messenger/models/call.dart';
// import 'package:chat_messenger/tabs/groups/controllers/group_call_controller.dart';
// import 'package:flutter/material.dart';
// import 'package:agora_rtc_engine/agora_rtc_engine.dart';
// import 'package:get/get.dart';

// class GroupVideoCallPage extends StatefulWidget {
//    GroupVideoCallPage({
//     super.key,
//     required this.call,
//   });

//   final Call call;

//   @override
//   _GroupVideoCallPageState createState() => _GroupVideoCallPageState();
// }

// class _GroupVideoCallPageState extends State<GroupVideoCallPage> {

//   @override
//   Widget build(BuildContext context) {
//     final GroupCallController groupCallController = Get.put(GroupCallController(call: widget.call));
//     return Scaffold(
//       appBar: AppBar(title: const Text("Group Call")),
//       body: Stack(
//         children: [
//             Expanded(
//           child: AgoraVideoView(
//             controller: VideoViewController(
//               rtcEngine: groupCallController.engine,
//               canvas: const VideoCanvas(uid: 0), // Local view
//             ),
//           ),
//         ),
//         Expanded(
//           child: GridView.builder(
//             gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//                 crossAxisCount: 2),
//             itemCount: groupCallController.remoteUsers.length,
//             itemBuilder: (context, index) {
//               return AgoraVideoView(
//                 controller: VideoViewController.remote(
//                   rtcEngine: groupCallController.engine,
//                   canvas: VideoCanvas(uid: groupCallController.remoteUsers[index]),
//                   connection: const RtcConnection(channelId: 'abcd1'),
//                 ),
//               );
//             },
//           ),
//         ),

//          Align(
//       alignment: Alignment.bottomCenter,
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           IconButton(
//             icon: const Icon(Icons.call_end, color: Colors.red),
//             onPressed: () {
//               groupCallController.engine.leaveChannel();
//               Navigator.pop(context);
//             },
//           ),
//         ],
//       ),
//     )
//         ],
//       ),
//     );
//   }

//   // Widget _buildVideoViews() {
//   //   return Column(
//   //     children: [
//   //       Expanded(
//   //         child: AgoraVideoView(
//   //           controller: VideoViewController(
//   //             rtcEngine: _agoraService._engine!,
//   //             canvas: const VideoCanvas(uid: 0), // Local view
//   //           ),
//   //         ),
//   //       ),
//   //       Expanded(
//   //         child: GridView.builder(
//   //           gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//   //               crossAxisCount: 2),
//   //           itemCount: _remoteUsers.length,
//   //           itemBuilder: (context, index) {
//   //             return AgoraVideoView(
//   //               controller: VideoViewController.remote(
//   //                 rtcEngine: _agoraService._engine!,
//   //                 canvas: VideoCanvas(uid: _remoteUsers[index]),
//   //                 connection: const RtcConnection(channelId: channelName),
//   //               ),
//   //             );
//   //           },
//   //         ),
//   //       ),
//   //     ],
//   //   );
//   // }

//   // Widget _buildToolbar() {
//   //   return Align(
//   //     alignment: Alignment.bottomCenter,
//   //     child: Row(
//   //       mainAxisAlignment: MainAxisAlignment.center,
//   //       children: [
//   //         IconButton(
//   //           icon: const Icon(Icons.call_end, color: Colors.red),
//   //           onPressed: () {
//   //             _agoraService.leaveChannel();
//   //             Navigator.pop(context);
//   //           },
//   //         ),
//   //       ],
//   //     ),
//   //   );
//   // }
// }

import 'package:chat_messenger/components/app_loading.dart';
import 'package:chat_messenger/components/loading_indicator.dart';
import 'dart:async';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/models/call.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:chat_messenger/screens/calling/components/call_timer.dart';
import 'package:chat_messenger/screens/home/home_screen.dart';
import 'package:chat_messenger/tabs/groups/controllers/group_call_controller.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class GroupCallScreen extends StatefulWidget {
  final bool isVideo;
  // final List<User> participants;
  final Call call;

  const GroupCallScreen(
      {super.key,
      required this.isVideo,
      //required this.participants ,
      required this.call});

  @override
  _GroupCallScreenState createState() => _GroupCallScreenState();
}

class _GroupCallScreenState extends State<GroupCallScreen> {
  final RxList<String> receiverNames = <String>[].obs; // To hold receiver names
  final box = GetStorage();
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _receiverNamesSubscription;

  Future<bool> onPhoneBackButtonPress() async {
    box.write('groupIsActive', widget.call.toMap());
    Get.to(() => HomeScreen());
    return true;
  }

  @override
  void initState() {
    super.initState();
    _listenToReceiverNames();
  }

  @override
  void dispose() {
    _receiverNamesSubscription?.cancel();
    super.dispose();
  }

  void _listenToReceiverNames() {
    _receiverNamesSubscription = FirebaseFirestore.instance
        .collection('GroupCalls')
        .doc(widget.call.callerId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        var data = snapshot.data();
        var names = List<String>.from(data?['receiverName'] ?? []);
        receiverNames.assignAll(names); // Update receiver names list
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (Get.isRegistered<GroupCallController>()) {
      Get.delete<GroupCallController>(force: true);
    }
    final GroupCallController groupCallController =
        Get.put(GroupCallController(call: widget.call));
    groupCallController.stopRingtone();

    final User currentUser = AuthController.instance.currentUser;

    // Render the local user video
    Widget renderLocalVideo() {
      if (widget.isVideo && groupCallController.isLocalUserJoined.value) {
        return AgoraVideoView(
          controller: VideoViewController(
            rtcEngine: groupCallController.engine,
            canvas: VideoCanvas(uid: 0),
          ),
        );
      } else {
        return const Center(child: Text('Joining...'));
      }
    }

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          onPhoneBackButtonPress();
        }
      },
      child: Obx(() {
        final int? remoteUid = groupCallController.remoteUid.value;
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
                onPressed: () {
                  onPhoneBackButtonPress();
                },
                icon: Icon(Icons.arrow_back)),
            actions: [
              remoteUid != null
                  ? const CallTimerForGroupCall()
                  : LoadingIndicator(),
            ],
            title:
                Text(widget.isVideo ? 'Group Video Call' : 'Group Audio Call'),
          ),
          body: Stack(
            children: [
              // Local user video
              if (widget.isVideo) ...[renderLocalVideo()],

              // Remote users video/audio
              widget.isVideo
                  ? Align(
                      alignment: Alignment.center,
                      child: GridView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 0.8,
                          ),
                          itemCount: groupCallController.remoteUsers.length,
                          itemBuilder: (context, index) {
                            final uidForVideo =
                                groupCallController.remoteUsers[index];
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: AgoraVideoView(
                                controller: VideoViewController.remote(
                                  rtcEngine: groupCallController.engine,
                                  canvas: VideoCanvas(uid: uidForVideo),
                                  connection:
                                      RtcConnection(channelId: widget.call.callerId),
                                ),
                              ),
                            );
                          }),
                    )
                  : Align(
                      alignment: Alignment.center,
                      child: GridView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 1.0,
                          ),
                          itemCount: receiverNames.length,
                          itemBuilder: (context, index) {
                            final name = receiverNames[index];
                            return Container(
                              decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(15),
                                  color: Colors.grey[800]),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [const Icon(Icons.person, size: 50, color: Colors.white), const SizedBox(height: 8), Text(name, style: const TextStyle(color: Colors.white))],
                              ),
                            );
                          }),
                    ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () async {
              try {
                currentUser.fullname == widget.call.callerName
                    ? await FirebaseFirestore.instance
                        .collection('GroupCalls')
                        .doc(widget.call.callerId)
                        .update({
                        'callerId': widget.call.callerId,
                        'callerName': widget.call.callerName,
                        'callerPhotoUrl': widget.call.callerPhotoUrl,
                        // Set receiver info
                        'receiverName': [],
                        'state': 'decline',
                        'isVideo': widget.call.isVideo,
                        'group': true,
                      }).then((val) {
                        groupCallController.onEndCall();
                        Future.delayed(Duration(seconds: 2), () {
                          FirebaseFirestore.instance
                              .collection('GroupCalls')
                              .doc(widget.call.callerId)
                              .delete();
                          box.remove('groupIsActive');
                        });
                      })
                    : await FirebaseFirestore.instance
                        .collection('GroupCalls')
                        .doc(widget.call.callerId)
                        .update({
                        'callerId': widget.call.callerId,
                        'callerName': widget.call.callerName,
                        'callerPhotoUrl': widget.call.callerPhotoUrl,
                        // Set receiver info
                        'receiverName':
                            FieldValue.arrayRemove([currentUser.fullname]),
                        'state': 'running',
                        'isVideo': widget.call.isVideo,
                        'group': true,
                      });
                box.remove('groupIsActive');
                Get.back();
              } catch (e) {
                AppStyle().failedSnackBar(message: e.toString());
              }
            },
            backgroundColor: Colors.red,
            child: Icon(Icons.call_end),
          ),
        );
      }),
    );
  }
}

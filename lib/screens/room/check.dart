import 'dart:convert';

import 'package:agora_token_generator/agora_token_generator.dart';
import 'package:chat_messenger/config/app_config.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:chat_messenger/services/agora_service.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/game_wall_bottom_sheet.dart';

class VoiceRoomScreen4 extends StatefulWidget {
  final String userId;
  final String displayName;
  final String profileImage;

  const VoiceRoomScreen4(
      {super.key,
      required this.userId,
      required this.displayName,
      required this.profileImage});
  @override
  _VoiceRoomScreen4State createState() => _VoiceRoomScreen4State();
}

class _VoiceRoomScreen4State extends State<VoiceRoomScreen4>
    with SingleTickerProviderStateMixin {
  final TextEditingController controller = TextEditingController();
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final AudioPlayer audioPlayer = AudioPlayer();

  late RtcEngine _engine;
  late AnimationController giftAnimationController;
  late Animation<double> giftAnimation;

  bool joined = false;
  bool micMuted = false;
  bool isMusicPlaying = false;
  int layout = 1;
  int userDiamonds = 100;

  Color backgroundColor = Colors.black;
  Color seatColor = Colors.amber;
  List<int> mutedSeats = [];
  List<int> lockedSeats = [];

  String groupName = "Galaxy Room 2";
  String groupImage = "https://cdn-icons-png.flaticon.com/512/847/847969.png";
  int groupMembers = 120;
  bool showGiftAnimation = false;

  @override
  void initState() {
    super.initState();
    initializeAgora();
    giftAnimationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    );
    giftAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: giftAnimationController, curve: Curves.easeInOut),
    );
  }

  Future<void> initializeAgora() async {
    final agoraService = AgoraService();
    await agoraService.initialize();
    _engine = agoraService.engine!;

    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (conn, elapsed) => setState(() => joined = true),
        onUserOffline: (conn, uid, reason) => setState(() => joined = false),
      ),
    );

    String token = RtcTokenBuilder.buildTokenWithAccount(
      appId: AppConfig.agoraAppID,
      appCertificate: 'e08c94ba78734ae984eeb8816d5b5069',
      channelName: 'abcd1',
      account: "uid123",
      tokenExpireSeconds: 3600,
    );

    await _engine.joinChannel(
      token: token,
      channelId: 'abcd1',
      uid: 0,
      options: ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        publishMicrophoneTrack: true,
        autoSubscribeAudio: true,
      ),
    );
  }

  void toggleMic() {
    setState(() => micMuted = !micMuted);
    _engine.muteLocalAudioStream(micMuted);
  }

  void toggleMusic() async {
    try {
      if (isMusicPlaying) {
        await audioPlayer.stop();
      } else {
        await audioPlayer.play(UrlSource(
            "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3"));
      }
      setState(() => isMusicPlaying = !isMusicPlaying);
    } catch (e) {
      debugPrint("VoiceRoomScreen4 toggleMusic error: $e");
    }
  }

  void sendMessage() async {
    String text = controller.text.trim();
    if (text.isNotEmpty) {
      await firestore
          .collection("voice_room_messages")
          .doc(groupName)
          .collection("messages")
          .add({
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
        'senderName': widget.displayName
      });
      controller.clear();
    }
  }

  void sendGift() async {
    if (userDiamonds >= 10) {
      setState(() => userDiamonds -= 10);
      await firestore
          .collection("voice_room_messages")
          .doc(groupName)
          .collection("messages")
          .add({
        'text': "🎁 Sent a gift!",
        'timestamp': FieldValue.serverTimestamp(),
        'senderName': widget.displayName
      });
      triggerGiftAnimation();
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Not enough diamonds!")));
    }
  }

  void triggerGiftAnimation() {
    setState(() => showGiftAnimation = true);
    giftAnimationController.forward(from: 0).then((_) {
      Future.delayed(Duration(seconds: 1), () {
        setState(() => showGiftAnimation = false);
      });
    });
  }

  void showProfileDialog(int seatNumber) async {
    DocumentSnapshot user =
        await firestore.collection("users").doc("user_$seatNumber").get();
    String badge = user["badge"] ?? "None";
    String frame = user["frame"] ?? "None";
    String userId = user["id"] ?? "00$seatNumber";

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("👤 User Profile"),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          CircleAvatar(
              radius: 30,
              backgroundColor: seatColor,
              child: Icon(Icons.person)),
          SizedBox(height: 10),
          Text("ID: #$userId"),
          Text("Badge: $badge"),
          Text("Frame: $frame"),
          Text("Diamonds: $userDiamonds"),
        ]),
        actions: [
          TextButton(
            onPressed: () async {
              await firestore.collection("admin_panel").add({
                'report': 'Reported user #$userId',
                'time': FieldValue.serverTimestamp()
              });
              Navigator.pop(context);
            },
            child: Text("Report"),
          )
        ],
      ),
    );
  }

  Widget buildSeat(int id) {
    bool isMuted = mutedSeats.contains(id);
    bool isLocked = lockedSeats.contains(id);

    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        builder: (_) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text("🔍 View Profile"),
              onTap: () {
                Navigator.pop(context);
                showProfileDialog(id);
              },
            ),
            ListTile(
              title: Text(isMuted ? "🔊 Unmute Seat" : "🔇 Mute Seat"),
              onTap: () {
                setState(
                    () => isMuted ? mutedSeats.remove(id) : mutedSeats.add(id));
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: Text(isLocked ? "🔓 Unlock Seat" : "🔒 Lock Seat"),
              onTap: () {
                setState(() =>
                    isLocked ? lockedSeats.remove(id) : lockedSeats.add(id));
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.deepPurple,
                      width: 3.0,
                    ),
                  ),
                  child: CircleAvatar(
                      // radius: 30,
                      backgroundColor: Colors.black,
                      child: Icon(
                        Icons.chair,
                        color: Colors.deepPurple,
                      ))),
              if (isMuted)
                Positioned(
                    bottom: 0,
                    child: Icon(Icons.mic_off, color: Colors.red, size: 18)),
              if (isLocked)
                Positioned(
                    top: 0,
                    right: 0,
                    child: Icon(Icons.lock, color: Colors.white, size: 16)),
            ],
          ),
          Text("ID: #$id", style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  List<Widget> buildSeats() {
    List<Widget> rows = [];
    int id = 1;
    for (int i = 0; i < 3; i++) {
      rows.add(Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(5, (_) => buildSeat(id++)),
      ));
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text("Voice Room - Diamonds: $userDiamonds"),
        actions: [
          IconButton(icon: Icon(Icons.music_note), onPressed: toggleMusic),
          IconButton(icon: Icon(Icons.card_giftcard), onPressed: sendGift),
          IconButton(icon: Icon(Icons.mic), onPressed: toggleMic),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              ...buildSeats(),
              Expanded(
                child: StreamBuilder(
                  stream: firestore
                      .collection("voice_room_messages")
                      .doc(groupName)
                      .collection("messages")
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return CircularProgressIndicator();
                    final docs = snapshot.data!.docs;
                    return ListView.builder(
                      reverse: true,
                      itemCount: docs.length,
                      itemBuilder: (_, i) => ListTile(
                        title: Row(
                          children: [
                            Text('${docs[i]['senderName']} :'),
                            SizedBox(
                              width: 5,
                            ),
                            Text(docs[i]['text'],
                                style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          hintText: "Send message...",
                          filled: true,
                          fillColor: Colors.white10,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.send, color: Colors.white),
                      onPressed: sendMessage,
                    )
                  ],
                ),
              ),
            ],
          ),
          if (showGiftAnimation)
            Center(
              child: FadeTransition(
                opacity: giftAnimation,
                child: Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text("🎁 GIFT SENT!",
                      style: TextStyle(fontSize: 24, color: Colors.pinkAccent)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    AgoraService().dispose();
    giftAnimationController.dispose();
    try {
      audioPlayer.dispose();
    } catch (e) {
      debugPrint("VoiceRoomScreen4 dispose audioPlayer error: $e");
    }
    super.dispose();
  }
}

class VoiceRoomScreen3 extends StatefulWidget {
  final String userId;
  final String displayName;
  final String profileImage;

  const VoiceRoomScreen3(
      {super.key,
      required this.userId,
      required this.displayName,
      required this.profileImage});
  @override
  _VoiceRoomScreen3State createState() => _VoiceRoomScreen3State();
}

class _VoiceRoomScreen3State extends State<VoiceRoomScreen3>
    with SingleTickerProviderStateMixin {
  int layout = 1;
  bool micMuted = false;
  bool joined = false;
  int groupMembers = 120;
  Color backgroundColor = Colors.black;
  Color seatColor = Colors.amber;
  bool allMuted = false;
  bool allLocked = false;
  bool isMusicPlaying = false;
  List<int> mutedSeats = [];
  List<int> lockedSeats = [];
  List<String> messages = ["Welcome to the room!"];
  final TextEditingController controller = TextEditingController();

  String groupName = "abcd1";
  String groupImage = "https://cdn-icons-png.flaticon.com/512/847/847969.png";

  void toggleMic() => setState(() => micMuted = !micMuted);
  void toggleMusic() => setState(() => isMusicPlaying = !isMusicPlaying);
  void toggleMuteSeat(int id) => setState(() =>
      mutedSeats.contains(id) ? mutedSeats.remove(id) : mutedSeats.add(id));
  void toggleLockSeat(int id) => setState(() =>
      lockedSeats.contains(id) ? lockedSeats.remove(id) : lockedSeats.add(id));

  late RtcEngine _engine;

  Future<void> initAgora() async {
    await [Permission.microphone].request();
    final agoraService = AgoraService();
    await agoraService.initialize();
    _engine = agoraService.engine!;
    _engine.registerEventHandler(
      RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) async {
        debugPrint("✅ Joined Channel");
        await _engine.setEnableSpeakerphone(true);
        debugPrint("✅ Speakerphone Enabled");
      }, onUserJoined: (connection, remoteUid, elapsed) async {
        await _engine.muteRemoteAudioStream(uid: remoteUid, mute: false);
        debugPrint("✅ Remote user $remoteUid unmuted");
      }, onUserOffline: (connection, remoteUid, reason) {
        debugPrint("Remote user offline: $remoteUid, reason: $reason");
      }, onRemoteAudioStateChanged:
              (connection, remoteUid, state, reason, elapsed) {
        debugPrint(
            "Remote audio state changed: user $remoteUid, state: $state, reason: $reason");
      }, onError: (err, msg) {
        debugPrint("Agora Error: $err - $msg");
      }),
    );
  }

  Future<int> getAvailableSeat() async {
    final doc = await FirebaseFirestore.instance
        .collection('voice_room_messages')
        .doc(groupName)
        .get();

    final data = doc.data();
    final seatMap = data?['seats'] ?? {};
    for (int i = 2; i <= 15; i++) {
      final seatLocked = lockedSeats.contains(i);
      if (!seatMap.containsKey(i.toString()) && !seatLocked) {
        return i;
      }
    }
    return -1; // or handle full room
  }

  void listenToSeatAssignments() {
    FirebaseFirestore.instance
        .collection('voice_room_messages')
        .doc(groupName)
        .snapshots()
        .listen((DocumentSnapshot doc) {
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final seats = data['seats'] ?? {};

        // Convert dynamic map to seatAssignments map
        Map<int, Map> updatedAssignments = {};
        seats.forEach((key, value) {
          updatedAssignments[int.parse(key)] = Map<String, dynamic>.from(value);
        });

        setState(() {
          seatAssignments = updatedAssignments;
        });
      }
    });
  }

  Future<String?> getAgoraToken(String channelName, int uid) async {
    try {
      final uri = Uri.parse(
              "https://us-central1-YOUR_PROJECT_ID.cloudfunctions.net/generateAgoraToken")
          .replace(queryParameters: {
        'channelName': channelName,
        'uid': uid.toString(), // optional
      });

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['token'];
      } else {
        debugPrint("❌ Failed to get token: ${response.body}");
      }
    } catch (e) {
      debugPrint("❌ Token generation error: $e");
    }

    return null;
  }

  void joinGroup() async {
    // int userUid = widget.userId.hashCode & 0x7FFFFFFF; // Always positive

    //    String token = RtcTokenBuilder.buildTokenWithUid(
    //   appId: AppConfig.agoraAppID,
    //   appCertificate: 'dceb6b34aa07490e9c1ea2c864e98761',
    //   channelName: groupName,
    //   uid: 12345,
    //   tokenExpireSeconds: 3600,
    // );

    // String? token = await getAgoraToken( groupName, 12345);
    // if (token == null) {
    //   debugPrint("Token generation failed.");
    //   return;
    // }else{
    // debugPrint(token);
    // }

    //   String token = b ?? RtcTokenBuilder.buildTokenWithUid(
    //   appId: AppConfig.agoraAppID,
    //   appCertificate: 'dceb6b34aa07490e9c1ea2c864e98761',
    //   channelName: groupName,
    //   uid: 12345,
    //   tokenExpireSeconds: 3600,
    // );
    // a = b ?? GetStorage().write('token',token);
    //007eJxTYDi5uaf68iaFGUeW3eNTXTXxU8gq7WWSQSXec2++rtXcNGGrAoOxobmRhamRUZqhUbKJWXJikpmlibGFmVmSgWmimZllquTR8IyGQEaGdWr7GRihEMTnZnBPzEmsqFQIys/PZWAAAKI8Iqw=
    // String token = RtcTokenBuilder.buildTokenWithAccount(
    //   appId: AppConfig.agoraAppID,
    //   appCertificate: 'e08c94ba78734ae984eeb8816d5b5069',
    //   channelName: "Galaxy Room",
    //   tokenExpireSeconds: 3600,
    //   account: 'user' );
    debugPrint('object');
    //debugPrint("🔑 Token: $token");
    //debugPrint("🧑 UID: $userUid");
    debugPrint('object');

//     _engine.registerEventHandler(RtcEngineEventHandler(
//   onJoinChannelSuccess: (connection, elapsed) async {
//     await _engine.setEnableSpeakerphone(true);
//   },
//   onUserJoined: (connection, remoteUid, elapsed) async {
//     await _engine.muteRemoteAudioStream(uid: remoteUid, mute: false);
//      debugPrint("✅ Remote user $remoteUid unmuted");
//   },
//   onError: (err, msg) {
//     debugPrint("Agora Error: $err - $msg");
//   }
// ));

    await _engine.enableAudio();
    await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    await _engine.muteAllRemoteAudioStreams(false);
    await _engine.joinChannel(
        token:
            '007eJxTYIicrVd44mjbouMHLKe9+RXWNXOVgr+eZHYDi9LSrVdX7DyuwJBmaZBobJGSkmieZG6SkmxuaWaeZp5iaWJiYGpgmZxmxvC/IKMhkJHBgP8dMyMDBIL4rAyJSckphgwMAMulIFA=',
        channelId: groupName,
        uid: 12345,
        options: ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          publishMicrophoneTrack: true,
          autoSubscribeAudio: true,
        ));
    //  await _engine.setEnableSpeakerphone(true);
    // Assign the user to the first available seat (after seat 1)
    int assignedSeat =
        widget.userId == "owner@example.com" ? 1 : await getAvailableSeat();
    if (assignedSeat == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Room is full!")),
      );
      return;
    }

    // Assign seat in Firestore
    await FirebaseFirestore.instance
        .collection('voice_room_messages')
        .doc(groupName)
        .set({
      "seats": {
        "$assignedSeat": {
          "userId": widget.userId,
          "name": widget.displayName,
          "image": widget.profileImage
        }
      }
    }, SetOptions(merge: true));

    setState(() {
      joined = true;
      groupMembers += 1;
      currentSeatNumber = assignedSeat;
      seatAssignments[assignedSeat] = {
        'name': widget.displayName,
        'image': widget.profileImage,
        'id': widget.userId
      };
    });
    Navigator.pop(context);
  }

  Future<void> leaveGroup() async {
    try {
      // Leave Agora channel
      await _engine.leaveChannel();
      await _engine.disableAudio();

      // Clear Firestore seat assignment
      if (currentSeatNumber != null) {
        await FirebaseFirestore.instance
            .collection('voice_room_messages')
            .doc(groupName)
            .set({
          "seats": {"$currentSeatNumber": FieldValue.delete()}
        }, SetOptions(merge: true));
      }

      // Update local state
      setState(() {
        joined = false;
        groupMembers = (groupMembers > 0) ? groupMembers - 1 : 0;
        seatAssignments.remove(currentSeatNumber);
        currentSeatNumber = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("You have left the voice room.")),
      );
    } catch (e) {
      debugPrint("Error while leaving group: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error leaving room: $e")),
      );
    }
  }

  void showJoinDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Join Group"),
        content: Text("Do you want to join $groupName?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: Text("Cancel")),
          ElevatedButton(
              onPressed: joinGroup,
              child: Text(
                "Join",
                style: TextStyle(color: Colors.white),
              )),
        ],
      ),
    );
  }

  // void sendMessage() {
  //   final text = controller.text.trim();
  //   if (text.isNotEmpty) {
  //     setState(() {
  //       messages.add("Me: $text");
  //       controller.clear();
  //     });
  //   }
  // }

  void changeLayout(int type) => setState(() => layout = type);
  void changeBackground(Color color) => setState(() => backgroundColor = color);
  void changeSeatColor(Color color) => setState(() => seatColor = color);
  void allMuteUnmute(bool mute) => setState(() {
        allMuted = mute;
        mutedSeats = mute ? List.generate(15, (i) => i + 1) : [];
      });
  void allLockUnlock(bool lock) => setState(() {
        allLocked = lock;
        lockedSeats = lock ? List.generate(15, (i) => i + 1) : [];
      });

  void editGroupInfo() {
    if (!joined) {
      showJoinDialog();
      return;
    }
    loadMembers();
    // showDialog(
    //   context: context,
    //   builder: (_) => AlertDialog(
    //     title: Text("Edit Group"),
    //     content: Column(
    //       mainAxisSize: MainAxisSize.min,
    //       children: [
    //         TextField(
    //             controller: nameController,
    //             decoration: InputDecoration(labelText: "Group Name")),
    //         TextField(
    //             controller: imageController,
    //             decoration: InputDecoration(labelText: "Image URL")),
    //       ],
    //     ),
    //     actions: [
    //       TextButton(
    //           onPressed: () {
    //             setState(() {
    //               groupName = nameController.text.trim();
    //               groupImage = imageController.text.trim();
    //             });
    //             Navigator.pop(context);
    //           },
    //           child: Text("Save")),
    //     ],
    //   ),
    // );

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) {
          return Container(
            height: 550,
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(15),
                    topRight: Radius.circular(15))),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                          onPressed: () {
                            Get.back();
                          },
                          icon: Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.black,
                            size: 25,
                          )),
                      TextButton(
                          onPressed: () {},
                          child: Text(
                            '...',
                            style: TextStyle(fontSize: 25),
                          ))
                    ],
                  ),
                  Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                    child: Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: ListTile(
                        leading: Image.network(widget.profileImage),
                        title: Text(
                          'Galaxy Room',
                          style: TextStyle(
                              color: Colors.black, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: DefaultTabController(
                        length: 2,
                        child: Column(
                          children: [
                            TabBar(
                              unselectedLabelStyle:
                                  TextStyle(color: Colors.grey),
                              tabs: [
                                Tab(text: 'Room Details'),
                                Tab(text: 'Member'),
                              ],
                              labelColor: Colors.black,
                            ),
                            Expanded(
                              child: TabBarView(
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Card(
                                        color: Colors.white,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(15)),
                                        child: Padding(
                                          padding: const EdgeInsets.all(15.0),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text('Room Owner',
                                                  style: TextStyle(
                                                      color: Colors.black)),
                                              SizedBox(
                                                height: 5,
                                              ),
                                              ListTile(
                                                leading: Image.network(
                                                    widget.profileImage),
                                                title: Text(
                                                  widget.displayName,
                                                  style: TextStyle(
                                                      color: Colors.black,
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: double.maxFinite,
                                        child: Card(
                                          color: Colors.white,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(15)),
                                          child: Padding(
                                            padding: const EdgeInsets.all(15.0),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text('Room Level',
                                                    style: TextStyle(
                                                        color: Colors.black)),
                                                Text(
                                                  'Lv.3',
                                                  style: TextStyle(
                                                      fontSize: 30,
                                                      color: Colors.black,
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: double.maxFinite,
                                        child: Card(
                                          color: Colors.white,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(15)),
                                          child: Padding(
                                            padding: const EdgeInsets.all(15.0),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text('Members',
                                                    style: TextStyle(
                                                        color: Colors.black)),
                                                Text(
                                                  '11',
                                                  style: TextStyle(
                                                      fontSize: 30,
                                                      color: Colors.black,
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  ListView.builder(
                                    itemCount: groupAllMembers.length,
                                    itemBuilder: (context, index) {
                                      final member = groupAllMembers[index];
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 8.0),
                                        child: Card(
                                          color: Colors.white,
                                          elevation: 2,
                                          child: ListTile(
                                            leading: CircleAvatar(
                                              backgroundImage:
                                                  NetworkImage(member['image']),
                                            ),
                                            title: Text(
                                              member['name'],
                                              style: TextStyle(
                                                  color: Colors.black),
                                            ),
                                            subtitle: Text(
                                                'ID: ${member['userId']}',
                                                style: TextStyle(
                                                    color: Colors.black)),
                                          ),
                                        ),
                                      );
                                    },
                                  )
                                ],
                              ),
                            ),
                          ],
                        )),
                  )
                ],
              ),
            ),
          );
        });
  }

  void showSeatOptions(int seatNumber) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
              title: Text("🔍 View Profile"),
              onTap: () {
                Navigator.pop(context);
                // Get.to(()=> ProfilePageForRoom());
                // showProfileDialog(seatNumber);
              }),
          ListTile(
              title: Text(mutedSeats.contains(seatNumber)
                  ? "🔊 Unmute Seat"
                  : "🔇 Mute Seat"),
              onTap: () {
                toggleMuteSeat(seatNumber);
                Navigator.pop(context);
              }),
          ListTile(
              title: Text(lockedSeats.contains(seatNumber)
                  ? "🔓 Unlock Seat"
                  : "🔒 Lock Seat"),
              onTap: () {
                toggleLockSeat(seatNumber);
                Navigator.pop(context);
              }),
        ],
      ),
    );
  }

  void showProfileDialog(int seatNumber) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("👤 User Profile"),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          CircleAvatar(
              radius: 30,
              backgroundColor: seatColor,
              child: Icon(Icons.person)),
          SizedBox(height: 10),
          Text("ID: #00$seatNumber"),
          Text("Badge: 🎖️ VIP"),
          Text("Frame: 🌟 Golden Frame"),
        ]),
      ),
    );
  }

  Widget seatIcon(int seatNumber) {
    final isMuted = mutedSeats.contains(seatNumber);
    final isLocked = lockedSeats.contains(seatNumber);
    Map? user = seatAssignments[seatNumber];
    return GestureDetector(
      onTap: () {
        if (user != null) {
          showSeatOptions(seatNumber);
        } else {
          showModalBottomSheet(
            context: context,
            builder: (_) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                    title: Text(mutedSeats.contains(seatNumber)
                        ? "🔊 Unmute Seat"
                        : "🔇 Mute Seat"),
                    onTap: () {
                      toggleMuteSeat(seatNumber);
                      Navigator.pop(context);
                    }),
                ListTile(
                    title: Text(lockedSeats.contains(seatNumber)
                        ? "🔓 Unlock Seat"
                        : "🔒 Lock Seat"),
                    onTap: () {
                      toggleLockSeat(seatNumber);
                      Navigator.pop(context);
                    }),
              ],
            ),
          );
        }
      },
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              isLocked
                  ? DottedBorder(
                      options: CircularDottedBorderOptions(
                        color: seatColor,
                        strokeWidth: 2,
                        dashPattern: [10, 4],
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          // border: Border.all(color: seatColor, width: 2),
                          color: backgroundColor,
                        ),
                        padding: EdgeInsets.all(12),
                        child: Icon(Icons.lock, color: seatColor, size: 28),
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: seatColor, width: 2),
                        color: backgroundColor,
                      ),
                      padding: EdgeInsets.all(12),
                      child: user != null
                          ? Image.network(
                              '${user['image']}',
                              height: 20,
                              width: 20,
                            )
                          : Icon(Icons.chair, color: seatColor, size: 28),
                    ),
              if (isMuted)
                Positioned(
                    bottom: 0,
                    child: Icon(Icons.mic_off, color: Colors.red, size: 18)),
            ],
          ),
          SizedBox(height: 6),
          Text(user != null ? '${user['name']}' : 'ID: $seatNumber',
              style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  List<Widget> buildSeats() {
    List<Widget> rows = [];
    int id = 1;
    if (layout == 1) {
      rows.add(seatRow([id++]));
      rows.add(seatRow(List.generate(5, (_) => id++)));
      rows.add(seatRow(List.generate(5, (_) => id++)));
    } else {
      for (int i = 0; i < 3; i++) {
        rows.add(seatRow(List.generate(5, (_) => id++)));
      }
    }
    return rows;
  }

  Widget seatRow(List<int> ids) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: ids.map((id) => seatIcon(id)).toList(),
      ),
    );
  }

  void openSettings() {
    showModalBottomSheet(
      context: context,
      builder: (_) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.only(
              topLeft: Radius.circular(15), topRight: Radius.circular(15)),
          // color: Colors.grey
        ),
        padding: EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text("🎛 Seat Layout"),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton(
                    onPressed: () => changeLayout(1),
                    child: Text(
                      "1+5+5",
                      style: TextStyle(color: Colors.white),
                    )),
                ElevatedButton(
                    onPressed: () => changeLayout(2),
                    child:
                        Text("5+5+5", style: TextStyle(color: Colors.white))),
              ],
            ),
            Divider(),
            Text("🎨 Background Color"),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton(
                    onPressed: () => changeBackground(Colors.black),
                    child:
                        Text("Black", style: TextStyle(color: Colors.white))),
                ElevatedButton(
                    onPressed: () => changeBackground(Colors.blueGrey),
                    child: Text("Blue Grey",
                        style: TextStyle(color: Colors.white))),
              ],
            ),
            Divider(),
            Text("👑 Seat Color"),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton(
                    onPressed: () => changeSeatColor(Colors.amber),
                    child:
                        Text("Golden", style: TextStyle(color: Colors.white))),
                ElevatedButton(
                    onPressed: () => changeSeatColor(Colors.purpleAccent),
                    child:
                        Text("Purple", style: TextStyle(color: Colors.white))),
              ],
            ),
            Divider(),
            Text("🔊 Global Controls"),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton(
                    onPressed: () => allMuteUnmute(true),
                    child: Text("All Mute",
                        style: TextStyle(color: Colors.white))),
                ElevatedButton(
                    onPressed: () => allMuteUnmute(false),
                    child: Text("All Unmute",
                        style: TextStyle(color: Colors.white))),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton(
                    onPressed: () => allLockUnlock(true),
                    child: Text("All Lock",
                        style: TextStyle(color: Colors.white))),
                ElevatedButton(
                    onPressed: () => allLockUnlock(false),
                    child: Text("All Unlock",
                        style: TextStyle(color: Colors.white))),
              ],
            ),
            Divider(),
            ListTile(
              title: Text(isMusicPlaying ? "⏸ Pause Music" : "▶️ Play Music"),
              onTap: () {
                toggleMusic();
                Navigator.pop(context);
              },
            )
          ]),
        ),
      ),
    );
  }

  //new
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final AudioPlayer audioPlayer = AudioPlayer();
  late AnimationController giftAnimationController;
  late Animation<double> giftAnimation;
  int userDiamonds = 100;
  bool showGiftAnimation = false;

  void sendMessage() async {
    String text = controller.text.trim();
    if (text.isNotEmpty) {
      await firestore
          .collection("voice_room_messages")
          .doc(groupName)
          .collection("messages")
          .add({
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
        'senderName': widget.displayName
      });
      controller.clear();
    }
  }

  void sendGift() async {
    if (userDiamonds >= 10) {
      setState(() => userDiamonds -= 10);
      await firestore
          .collection("voice_room_messages")
          .doc(groupName)
          .collection("messages")
          .add({
        'text': "🎁 Sent a gift!",
        'timestamp': FieldValue.serverTimestamp(),
        'senderName': widget.displayName
      });
      triggerGiftAnimation();
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Not enough diamonds!")));
    }
  }

  void triggerGiftAnimation() {
    setState(() => showGiftAnimation = true);
    giftAnimationController.forward(from: 0).then((_) {
      Future.delayed(Duration(seconds: 1), () {
        setState(() => showGiftAnimation = false);
      });
    });
  }

  bool _showEmojiPicker = false;

  void _onEmojiSelected(Emoji emoji) {
    controller
      ..text += emoji.emoji
      ..selection = TextSelection.fromPosition(
        TextPosition(offset: controller.text.length),
      );
  }

  //group member add
  List<dynamic> memberList = [];

  void fetchMemberList() async {
    final doc = await FirebaseFirestore.instance
        .collection('voice_room_messages')
        .doc(groupName)
        .get();

    if (doc.exists) {
      final data = doc.data();
      setState(() {
        memberList = data?['memberList'] ?? [];
      });
    }
  }

  void addUserToVoiceRoom() async {
    final newMember = {
      'userId': widget.userId,
      'name': widget.displayName,
      'image': widget.profileImage,
    };
    await FirebaseFirestore.instance
        .collection('voice_room_messages')
        .doc(groupName)
        .update({
      'count': FieldValue.increment(1),
      'memberList': FieldValue.arrayUnion([newMember])
    });

    // Refresh local state
    fetchMemberList();
  }

  // seat assign
  Map<int, Map> seatAssignments = {}; // seatNumber -> userId
  int? currentSeatNumber;

  //group member

  Future<List<Map<String, dynamic>>> fetchRoomMembers(String roomName) async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('voice_room_messages')
          .doc(roomName)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        List<dynamic> rawList = data['memberList'] ?? [];

        // Convert each item to Map<String, dynamic>
        return rawList.map((item) => Map<String, dynamic>.from(item)).toList();
      } else {
        return [];
      }
    } catch (e) {
      debugPrint('Error fetching member list: $e');
      return [];
    }
  }

  List<Map<String, dynamic>> groupAllMembers = [];

  void loadMembers() async {
    groupAllMembers = await fetchRoomMembers('Galaxy Room');
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    fetchMemberList();
    initAgora();
    giftAnimationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    );
    giftAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: giftAnimationController, curve: Curves.easeInOut),
    );
    listenToSeatAssignments();
  }

  @override
  void dispose() {
    giftAnimationController.dispose();
    audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isUserInRoom =
        memberList.any((member) => member['userId'] == widget.userId);
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.black,
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: editGroupInfo,
              child: CircleAvatar(
                backgroundImage: NetworkImage(groupImage),
                radius: 18,
              ),
            ),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: editGroupInfo,
                  child: Text(
                    groupName,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
                Text("Members: ${memberList.length}",
                    style: TextStyle(fontSize: 10)),
              ],
            ),
            SizedBox(width: 10),
            if (!isUserInRoom)
              IconButton(
                  onPressed: addUserToVoiceRoom,
                  icon: Icon(
                    Icons.add_box,
                    color: Colors.blue,
                  ))
          ],
        ),
        actions: [
          IconButton(
              icon: Icon(Icons.share, color: Colors.white), onPressed: () {}),
          IconButton(
              icon: Icon(
                Icons.exit_to_app,
                color: Colors.white,
              ),
              onPressed: () {
                leaveGroup();
              }),
          IconButton(
              icon: Icon(Icons.settings, color: Colors.white),
              onPressed: openSettings),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              ...buildSeats(),
              Expanded(
                child: StreamBuilder(
                  stream: firestore
                      .collection("voice_room_messages")
                      .doc(groupName)
                      .collection("messages")
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return CircularProgressIndicator();
                    final docs = snapshot.data!.docs;
                    return ListView.builder(
                      reverse: true,
                      itemCount: docs.length,
                      itemBuilder: (_, i) => ListTile(
                        title: Row(
                          children: [
                            Text('${docs[i]['senderName']} :',
                                style: TextStyle(color: Colors.white)),
                            SizedBox(
                              width: 5,
                            ),
                            Text(docs[i]['text'],
                                style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          hintText: "Send message...",
                          filled: true,
                          fillColor: Colors.white10,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.send, color: Colors.white),
                      onPressed: sendMessage,
                    )
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                        icon:
                            Icon(Icons.card_giftcard, color: Colors.pinkAccent),
                        onPressed: sendGift),
                    //Icon(Icons.card_giftcard, color: Colors.pinkAccent),
                    IconButton(
                      icon: Icon(Icons.emoji_emotions,
                          color: Colors.yellowAccent),
                      onPressed: () {
                        setState(() {
                          _showEmojiPicker = !_showEmojiPicker;
                        });
                      },
                    ),
                    IconButton(
                        icon: Icon(micMuted ? Icons.mic_off : Icons.mic),
                        onPressed: toggleMic),
                    IconButton(
                      icon:
                          Icon(Icons.sports_esports, color: Colors.greenAccent),
                      onPressed: () => GameWallBottomSheet.show(context, isInAudioRoom: true),
                    ),
                  ],
                ),
              ),
              if (_showEmojiPicker)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    height: 250,
                    child: EmojiPicker(
                      onEmojiSelected: (category, emoji) {
                        _onEmojiSelected(emoji);
                      },
                      config: Config(),
                    ),
                  ),
                )
            ],
          ),
          if (showGiftAnimation)
            Center(
              child: FadeTransition(
                opacity: giftAnimation,
                child: Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text("🎁 GIFT SENT!",
                      style: TextStyle(fontSize: 24, color: Colors.pinkAccent)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

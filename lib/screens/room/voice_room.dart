import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:agora_token_generator/agora_token_generator.dart';
import 'package:chat_messenger/config/app_config.dart';
import 'package:chat_messenger/screens/room/controller/voice_room_controller.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:chat_messenger/services/agora_service.dart';
import 'package:chat_messenger/components/cached_circle_avatar.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/game_wall_bottom_sheet.dart';

class VoiceRoomScreen extends StatefulWidget {
  final String docId;
  const VoiceRoomScreen(this.docId, {super.key});

  @override
  State<VoiceRoomScreen> createState() => _VoiceRoomScreenState();
}

class _VoiceRoomScreenState extends State<VoiceRoomScreen> {
  late final VoiceRoomController controller;

  //final VoiceRoomController controller = Get.put(VoiceRoomController());
  bool isMicOn = true;

  bool inRoom = false;

  final TextEditingController _controller = TextEditingController();

  final List<String> messages = [];

  final List<String> userNames = [
    "Alice",
    "Bob",
    "Charlie",
    "Diana",
    "Eva",
    "Frank",
    "Grace",
    "Henry",
    "Ivy",
    "Jack"
  ];

  void toggleMic() => setState(() => isMicOn = !isMicOn);

  void joinRoom() => setState(() => inRoom = true);

  void leaveRoom() => setState(() => inRoom = false);

  void sendMessage() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        messages.add("You: $text");
        _controller.clear();
      });
    }
  }

  void showProfile(String name) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        height: 240,
        child: Column(
          children: [
            const CircleAvatar(radius: 30, backgroundColor: Colors.purple),
            const SizedBox(height: 10),
            Text(name,
                style: const TextStyle(fontSize: 18, color: Colors.white)),
            const Text("ID: 100${2023}", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 10),
            const Text("VIP Badge: GOLD",
                style: TextStyle(color: Colors.amber)),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    controller = Get.put(VoiceRoomController(widget.docId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   title: Text('Voice Room'),
      // ),
      // body: Obx(() {
      //   return controller.isJoined.value
      //       ? Column(
      //           children: [
      //             Text('Audience'),
      //             Expanded(
      //               child:controller.users.length==0?Text('No user joined'): ListView.builder(
      //                 itemCount: controller.users.length,
      //                 itemBuilder: (context, index) {
      //                   return Column(
      //                     children: [
      //                       controller.users[index]['image'] == null ||
      //                               controller.users[index]['image'].isEmpty
      //                           ? CachedCircleAvatar(
      //                               imageUrl: '',
      //                               radius: 25,
      //                               backgroundColor: Colors.grey,
      //                             )
      //                           : CachedCircleAvatar(
      //                               radius: 25,
      //                               imageUrl: '${controller.users[index]['image']}',
      //                               frameId: controller.users[index]['frameId'],
      //                               frameScale: 1.3,
      //                             ),
      //                        Text('${controller.users[index]['name']}')

      //                     ],
      //                   );
      //                 },
      //               ),
      //             ),
      //             ElevatedButton(
      //               onPressed: controller.leaveRoom,
      //               child: Text('Leave Room',style: TextStyle(color: Colors.white)),
      //             ),
      //           ],
      //         )
      //       : Center(
      //           child: ElevatedButton(
      //             onPressed: controller.initializeAgora,
      //             child: Text('Join Voice Room',style: TextStyle(color: Colors.white),),
      //           ),
      //         );
      // }),

      appBar: AppBar(
        title: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Colors.white,
              radius: 18,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("G#123",
                      style: TextStyle(fontSize: 10, color: Colors.black)),
                  Text("1.2k",
                      style: TextStyle(fontSize: 10, color: Colors.black)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Text("Voice Room"),
          ],
        ),
        actions: [
          Row(children: const [
            Icon(Icons.people, size: 18),
            SizedBox(width: 4),
            Text("380", style: TextStyle(fontSize: 14)),
          ]),
          IconButton(onPressed: () {}, icon: const Icon(Icons.share)),
          IconButton(onPressed: leaveRoom, icon: const Icon(Icons.exit_to_app)),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          Expanded(
            child: GridView.count(
              crossAxisCount: 5,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: List.generate(10, (index) {
                return GestureDetector(
                  onTap: () => showProfile(userNames[index]),
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          CachedCircleAvatar(
                            radius: 23,
                            backgroundColor: Colors.grey,
                            imageUrl:
                                '', // You might want to map real user images here
                            // frameId: ... // Pass frameId if available for these dummy users
                          ),
                          if (index % 2 == 1)
                            const Positioned(
                              child: Icon(Icons.mic_off,
                                  size: 20, color: Colors.red),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(userNames[index],
                          style: const TextStyle(
                              fontSize: 12, color: Colors.white)),
                    ],
                  ),
                );
              }),
            ),
          ),

          // Chat messages
          Container(
            color: Colors.grey,
            height: 100,
            child: ListView.builder(
              reverse: true,
              itemCount: messages.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  child: Text(messages[messages.length - 1 - index],
                      style: const TextStyle(color: Colors.white)),
                );
              },
            ),
          ),

          // Chat input
          Container(
            color: Colors.white10,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(color: Colors.white54),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.amber),
                  onPressed: sendMessage,
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white24),
          Padding(
            padding: const EdgeInsets.only(bottom: 16, top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                IconButton(
                    onPressed: toggleMic,
                    icon: Icon(isMicOn ? Icons.mic : Icons.mic_off)),
                const Icon(
                  Icons.emoji_emotions,
                ),
                const Icon(Icons.card_giftcard),
                IconButton(
                  icon: const Icon(Icons.sports_esports),
                  onPressed: () => GameWallBottomSheet.show(context),
                ),
                const Icon(Icons.favorite),
                ElevatedButton(
                  onPressed: inRoom ? leaveRoom : joinRoom,
                  child: Text(inRoom ? "End" : "Join"),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PartyRoomScreen extends StatefulWidget {
  const PartyRoomScreen({super.key});

  @override
  _PartyRoomScreenState createState() => _PartyRoomScreenState();
}

class _PartyRoomScreenState extends State<PartyRoomScreen> {
  int layoutType = 8;
  bool isMuted = false;
  bool isJoined = false;
  final TextEditingController messageController = TextEditingController();
  List<String> messages = ["Welcome to the room!"];

  void changeLayout(int seatCount) {
    setState(() {
      layoutType = seatCount;
    });
  }

  void sendMessage() {
    if (messageController.text.trim().isNotEmpty) {
      setState(() {
        messages.add("Me: ${messageController.text}");
        messageController.clear();
      });
    }
  }

  void showSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void openUserProfile(BuildContext context, int userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(userId: userId),
      ),
    );
  }

  List<Widget> buildSeats(BuildContext context) {
    List<Widget> seatWidgets = [];
    int count = 1;
    int rows = layoutType == 15 ? 3 : 2;
    int seatsPerRow = layoutType ~/ rows;

    for (int i = 0; i < rows; i++) {
      seatWidgets.add(
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(seatsPerRow, (index) {
            int userId = count;
            return GestureDetector(
              onTap: () => openUserProfile(context, userId),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.white,
                    child: Text('$userId'),
                  ),
                  SizedBox(height: 4),
                  Text('User$userId',
                      style: TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
            );
          }),
        ),
      );
      seatWidgets.add(SizedBox(height: 10));
      count += seatsPerRow;
    }

    return seatWidgets;
  }

  void openSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return Container(
          color: Colors.deepPurple[100],
          padding: EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Select Seat Layout', style: TextStyle(fontSize: 18)),
            ElevatedButton(
                onPressed: () {
                  changeLayout(8);
                  Navigator.pop(context);
                },
                child: Text('4 + 4 (8 seats)')),
            ElevatedButton(
                onPressed: () {
                  changeLayout(10);
                  Navigator.pop(context);
                },
                child: Text('5 + 5 (10 seats)')),
            ElevatedButton(
                onPressed: () {
                  changeLayout(15);
                  Navigator.pop(context);
                },
                child: Text('5 + 5 + 5 (15 seats)')),
          ]),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    double chatBoxHeight = layoutType == 15 ? 100 : 150;

    return Scaffold(
      backgroundColor: Colors.deepPurple[900],
      appBar: AppBar(
        title: Text('🎉 Party Room'),
        backgroundColor: Colors.deepPurple,
        leading: IconButton(
          icon: Icon(Icons.exit_to_app),
          onPressed: () => showSnackbar("Exit Room"),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.share),
            onPressed: () => showSnackbar("Link Shared"),
          ),
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () => openSettings(context),
          )
        ],
      ),
      body: Column(
        children: [
          // Header Info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('👑 Group: PartyX',
                      style: TextStyle(color: Colors.white, fontSize: 18)),
                  Text('Seats: $layoutType',
                      style: TextStyle(color: Colors.white70)),
                ]),
                Column(
                  children: [
                    Icon(Icons.record_voice_over, color: Colors.greenAccent),
                    Text('Online: 98', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ],
            ),
          ),

          // Seat Layout
          ...buildSeats(context),

          // Chat Box
          Container(
            height: chatBoxHeight,
            margin: EdgeInsets.symmetric(horizontal: 12),
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(10),
            ),
            child: ListView(
              children: messages
                  .map((msg) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(msg,
                            style:
                                TextStyle(color: Colors.white, fontSize: 13)),
                      ))
                  .toList(),
            ),
          ),

          // Chat Input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: messageController,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white12,
                      hintText: 'Send message...',
                      hintStyle: TextStyle(color: Colors.white54),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25.0),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                          vertical: 10.0, horizontal: 20.0),
                    ),
                  ),
                ),
                IconButton(
                    icon: Icon(Icons.send, color: Colors.tealAccent),
                    onPressed: sendMessage)
              ],
            ),
          ),

          // Bottom Buttons
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    IconButton(
                      icon: Icon(Icons.card_giftcard, color: Colors.pinkAccent),
                      onPressed: () => showSnackbar("Gift sent!"),
                    ),
                    Text("Gift",
                        style: TextStyle(color: Colors.white, fontSize: 12))
                  ],
                ),
                Column(
                  children: [
                    IconButton(
                      icon: Icon(isMuted ? Icons.mic_off : Icons.mic,
                          color: Colors.white),
                      onPressed: () {
                        setState(() {
                          isMuted = !isMuted;
                        });
                      },
                    ),
                    Text(isMuted ? "Unmute" : "Mute",
                        style: TextStyle(color: Colors.white, fontSize: 12))
                  ],
                ),
                Column(
                  children: [
                    IconButton(
                      icon: Icon(Icons.login, color: Colors.amberAccent),
                      onPressed: () {
                        setState(() {
                          isJoined = !isJoined;
                        });
                        showSnackbar(isJoined ? "You joined!" : "You left!");
                      },
                    ),
                    Text(isJoined ? "Leave" : "Join",
                        style: TextStyle(color: Colors.white, fontSize: 12))
                  ],
                ),
                Column(
                  children: [
                    IconButton(
                      icon:
                          Icon(Icons.sports_esports, color: Colors.greenAccent),
                      onPressed: () => GameWallBottomSheet.show(context),
                    ),
                    Text("Game",
                        style: TextStyle(color: Colors.white, fontSize: 12))
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class UserProfileScreen extends StatelessWidget {
  final int userId;
  const UserProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("User ID: $userId"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(radius: 40, child: Text("$userId")),
            SizedBox(height: 12),
            Text("Username: User$userId",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text("Status: Active"),
          ],
        ),
      ),
    );
  }
}

/////////////////////////////////////////////////////////////////
class VoiceRoomScreen2 extends StatefulWidget {
  final String userId;
  final String displayName;
  final String profileImage;

  const VoiceRoomScreen2(
      {super.key,
      required this.userId,
      required this.displayName,
      required this.profileImage});

  @override
  _VoiceRoomScreen2State createState() => _VoiceRoomScreen2State();
}

class _VoiceRoomScreen2State extends State<VoiceRoomScreen2> {
  final String roomId = "galaxy_room";

  bool micMuted = false;
  bool joined = false;
  int groupMembers = 0;
  int layout = 1;
  bool allMuted = false;
  bool allLocked = false;
  bool isMusicPlaying = false;
  Color backgroundColor = Colors.black;
  Color seatColor = Colors.amber;

  List<int> mutedSeats = [];
  List<int> lockedSeats = [];
  List<String> messages = [];
  final TextEditingController controller = TextEditingController();

  late DatabaseReference messagesRef;
  late DatabaseReference onlineUsersRef;
  late RtcEngine _engine;

  @override
  void initState() {
    super.initState();
    initFirebase();
    initAgora();
  }

  Future<void> initFirebase() async {
    messagesRef = FirebaseDatabase.instance.ref("rooms/$roomId/messages");
    onlineUsersRef = FirebaseDatabase.instance.ref("rooms/$roomId/onlineUsers");

    messagesRef.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      final loaded = <String>[];
      data?.forEach((key, value) => loaded.add(value.toString()));
      setState(() => messages = loaded);
    });

    onlineUsersRef.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      setState(() => groupMembers = data?.length ?? 0);
    });
  }

  String token = RtcTokenBuilder.buildTokenWithAccount(
    appId: AppConfig.agoraAppID,
    appCertificate: 'e08c94ba78734ae984eeb8816d5b5069',
    channelName: 'abcd1',
    account: "uid123",
    tokenExpireSeconds: 3600,
  );

  Future<void> initAgora() async {
    await [Permission.microphone].request();
    final agoraService = AgoraService();
    await agoraService.initialize();
    _engine = agoraService.engine!;
  }

  void joinGroup() async {
    await _engine.joinChannel(
        token: token,
        channelId: roomId,
        uid: 0,
        options: ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          publishMicrophoneTrack: true,
          autoSubscribeAudio: true,
        ));
    await onlineUsersRef.child(widget.userId).set(true);
    setState(() => joined = true);
    Navigator.pop(context);
  }

  void leaveGroup() async {
    await _engine.leaveChannel();
    await onlineUsersRef.child(widget.userId).remove();
    setState(() => joined = false);
  }

  void toggleMic() async {
    setState(() => micMuted = !micMuted);
    await _engine.muteLocalAudioStream(micMuted);
  }

  void sendMessage() {
    final text = controller.text.trim();
    if (text.isNotEmpty) {
      messagesRef.push().set("${widget.displayName}: $text");
      controller.clear();
    }
  }

  void showJoinDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Join Group"),
        content: Text("Do you want to join $roomId?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: Text("Cancel")),
          ElevatedButton(onPressed: joinGroup, child: Text("Join")),
        ],
      ),
    );
  }

  Widget seatIcon(int id) {
    final isMuted = mutedSeats.contains(id);
    final isLocked = lockedSeats.contains(id);
    return Column(children: [
      Stack(
        alignment: Alignment.center,
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: seatColor,
            child: Image.network(
              "https://cdn-icons-png.flaticon.com/512/236/236831.png",
              height: 30,
              width: 30,
              fit: BoxFit.cover,
            ),
          ),
          if (isMuted)
            Positioned(
                bottom: 0,
                child: Icon(Icons.mic_off, size: 18, color: Colors.red)),
          if (isLocked)
            Positioned(top: 0, right: 0, child: Icon(Icons.lock, size: 16)),
        ],
      ),
      SizedBox(height: 6),
      Text("ID: $id", style: TextStyle(color: Colors.white)),
    ]);
  }

  List<Widget> buildSeats() {
    List<Widget> rows = [];
    int id = 1;
    if (layout == 1) {
      rows.add(seatRow([id++]));
      rows.add(seatRow(List.generate(5, (int) => id++)));
      rows.add(seatRow(List.generate(5, (int) => id++)));
    } else {
      for (int i = 0; i < 3; i++) {
        rows.add(seatRow(List.generate(5, (_) => id++)));
      }
    }
    return rows;
  }

  Widget seatRow(List<int> ids) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: ids.map((id) => seatIcon(id)).toList(),
      ),
    );
  }

  @override
  void dispose() {
    if (joined) leaveGroup();
    _engine.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Row(children: [
          CircleAvatar(
              backgroundImage: NetworkImage(widget.profileImage), radius: 18),
          SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(roomId, style: TextStyle(fontWeight: FontWeight.bold)),
            Text("Group Members: $groupMembers", style: TextStyle(fontSize: 12))
          ]),
        ]),
        actions: [
          IconButton(icon: Icon(Icons.exit_to_app), onPressed: leaveGroup),
          IconButton(icon: Icon(Icons.settings), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          ...buildSeats(),
          Container(
            height: 120,
            margin: EdgeInsets.all(12),
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Colors.white10, borderRadius: BorderRadius.circular(10)),
            child:
                ListView(children: messages.map((msg) => Text(msg)).toList()),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: "Send message...",
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none),
                  ),
                ),
              ),
              IconButton(icon: Icon(Icons.send), onPressed: sendMessage),
            ]),
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Image.network(
                      "https://cdn-icons-png.flaticon.com/512/929/929416.png",
                      height: 28),
                  Image.network(
                      "https://cdn-icons-png.flaticon.com/512/742/742751.png",
                      height: 28),
                  IconButton(
                      icon: Icon(micMuted ? Icons.mic_off : Icons.mic),
                      onPressed: toggleMic),
                  Image.network(
                      "https://cdn-icons-png.flaticon.com/512/727/727245.png",
                      height: 28),
                ]),
          )
        ],
      ),
    );
  }
}
////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////

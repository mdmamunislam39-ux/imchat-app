import 'dart:io';

import 'package:chat_messenger/components/app_loading.dart';
import 'package:chat_messenger/components/cached_circle_avatar.dart';
import 'package:chat_messenger/components/default_button.dart';
import 'package:chat_messenger/config/theme_config.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/helpers/dialog_helper.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:chat_messenger/screens/room/controller/room_controller.dart';
import 'package:chat_messenger/screens/room/explore_tab.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/bloc/audio_rooms_bloc.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/repository/audio_rooms_repository.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/room_top_rankings_screen.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/room_id_search_screen.dart';

class RoomScreen extends StatefulWidget {
  const RoomScreen({super.key});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen>
    with SingleTickerProviderStateMixin {
  Stream<List<QueryDocumentSnapshot>> getUserRooms(String userId) {
    final allRoomsStream = FirebaseFirestore.instance
        .collection('voice_room_messages')
        .snapshots();

    return allRoomsStream.map((snapshot) {
      return snapshot.docs.where((doc) {
        final data = doc.data();

        final isCreator = data['roomCreatedUserId'] == userId;

        final memberList = data['memberList'] as List<dynamic>? ?? [];

        final isMember = memberList
            .any((member) => member is Map && member['userId'] == userId);

        return isCreator || isMember;
      }).toList();
    });
  }


  @override
  Widget build(BuildContext context) {
    final RoomController controller = Get.put(RoomController());
    final User currentUser = AuthController.instance.currentUser;

    debugPrint(currentUser.fullname);
    debugPrint(currentUser.userId);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          automaticallyImplyLeading: false,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                  child: TabBar(
                      labelColor: Colors.black,
                      dividerColor: Colors.transparent,
                      unselectedLabelColor: Colors.black,
                      labelPadding: EdgeInsets.symmetric(vertical: 6),
                      tabs: [
                    Tab(
                      child: Text('Room', style: TextStyle(fontSize: 12)),
                    ),
                    Tab(
                      child: Text('Explore', style: TextStyle(fontSize: 12)),
                    ),
                  ])),
              Expanded(child: SizedBox.shrink()),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'Top Rankings',
                    icon: const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD700)),
                    onPressed: () {
                      Get.to(() => RoomTopRankingsScreen(
                        audioRoomsBloc: AudioRoomsBloc(
                          repository: AudioRoomsRepository(),
                        ),
                      ));
                    },
                  ),
                  IconButton(
                    tooltip: 'Search by Room ID',
                    icon: const Icon(IconlyLight.search, color: Colors.black),
                    onPressed: () {
                      Get.to(() => RoomIdSearchScreen(
                        audioRoomsBloc: AudioRoomsBloc(
                          repository: AudioRoomsRepository(),
                        ),
                      ));
                    },
                  ),
                  IconButton(
                    icon:
                        Icon(Icons.notifications_outlined, color: Colors.black),
                    onPressed: () {
                      // handle notifications tap
                    },
                  ),
                ],
              )
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (context) {
                  return Container(
                    height: 440,
                    width: double.maxFinite, // Takes full width
                    padding: EdgeInsets.all(6),
                    child: Form(
                      key: controller.formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 6, right: 6),
                            child: Align(
                              alignment: Alignment.topRight,
                              child: InkWell(
                                onTap: () => Get.back(),
                                child: CircleAvatar(
                                    backgroundColor: primaryColor,
                                    radius: 14,
                                    child: Center(
                                        child: Icon(
                                      Icons.close,
                                      size: 20,
                                    ))),
                              ),
                            ),
                          ),
                          Center(
                            child: GestureDetector(
                              onTap: () async {
                                // Pick image from camera/gallery
                                final File? resultFile =
                                    await DialogHelper.showPickImageDialog(
                                  isAvatar: true,
                                );
                                // Update file
                                controller.photoFile.value = resultFile;
                              },
                              child: Obx(() {
                                // Get file
                                final File? photoFile =
                                    controller.photoFile.value;

                                return Stack(
                                  children: [
                                    // Photo
                                    Container(
                                      child: photoFile != null
                                          ? CircleAvatar(
                                              radius: 70,
                                              backgroundImage: FileImage(
                                                  File(photoFile.path)),
                                            )
                                          : CachedCircleAvatar(
                                              radius: 50,
                                              iconSize: 60,
                                              borderColor: primaryColor,
                                              backgroundColor: primaryColor,
                                              imageUrl: currentUser.photoUrl,
                                              frameUrl: AuthController.instance
                                                  .currentFrameUrl.value,
                                              frameScale: 1.3,
                                            ),
                                    ),
                                    // Icon
                                    const Positioned(
                                      right: 0,
                                      bottom: 16,
                                      child: CircleAvatar(
                                        backgroundColor: primaryColor,
                                        child: Icon(IconlyBold.camera,
                                            color: Colors.white, size: 23),
                                      ),
                                    ),
                                  ],
                                );
                              }),
                            ),
                          ),
                          TextFormField(
                            autofocus: true,
                            controller: controller.roomNameController,
                            decoration: InputDecoration(
                                filled: false,
                                hintText: 'enter your room name',
                                enabledBorder: AppStyle().defalutBorder,
                                focusedBorder: AppStyle().defalutBorder,
                                errorBorder: AppStyle().errorBorder,
                                border: AppStyle().defalutBorder),
                            validator: (String? name) {
                              if (name == null || name.trim().isEmpty) {
                                return 'enter your room name';
                              }
                              return null;
                            },
                          ),
                          TextFormField(
                            autofocus: true,
                            controller: controller.roomDescriptionController,
                            decoration: InputDecoration(
                                filled: false,
                                hintText: 'enter your room info',
                                enabledBorder: AppStyle().defalutBorder,
                                focusedBorder: AppStyle().defalutBorder,
                                errorBorder: AppStyle().errorBorder,
                                border: AppStyle().defalutBorder),
                            validator: (String? name) {
                              if (name == null || name.trim().isEmpty) {
                                return 'enter your room info';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          Obx(() => DropdownButtonFormField<String>(
                            initialValue: controller.selectedRoomType.value,
                            decoration: InputDecoration(
                                filled: false,
                                enabledBorder: AppStyle().defalutBorder,
                                focusedBorder: AppStyle().defalutBorder,
                                border: AppStyle().defalutBorder,
                            ),
                            items: const [
                              DropdownMenuItem(value: 'Party', child: Text('Audio Room (Party)')),
                              DropdownMenuItem(value: 'Live', child: Text('Video Room (Live)')),
                            ],
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                controller.selectedRoomType.value = newValue;
                              }
                            },
                          )),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: defaultPadding,
                              vertical: defaultPadding * 2,
                            ),
                            child: DefaultButton(
                              height: 45,
                              width: double.maxFinite,
                              text: 'Create Room',
                              onPress: () async {
                                controller.isLoading.value = true;
                                if (controller.photoFile.value != null) {
                                  controller.uploadRoomImage(
                                      file: File(
                                          controller.photoFile.value!.path),
                                      userId: currentUser.userId,
                                      fileName: controller
                                          .roomNameController.text
                                          .toString());
                                }
                                if (controller.photoFile.value != null) {
                                  String imageUrl =
                                      await controller.uploadRoomImage(
                                          file: File(
                                              controller.photoFile.value!.path),
                                          userId: currentUser.userId,
                                          fileName: controller
                                              .roomNameController.text
                                              .toString());
                                  controller.createNewRoom(
                                      roomCreatedUserId: currentUser.userId,
                                      roomCreatedUserName: currentUser.fullname,
                                      roomCreatedUserImage:
                                          currentUser.photoUrl,
                                      roomImage: imageUrl,
                                      roomName: controller
                                          .roomNameController.text
                                          .toString());
                                } else {
                                  controller.createNewRoom(
                                      roomCreatedUserId: currentUser.userId,
                                      roomCreatedUserName: currentUser.fullname,
                                      roomCreatedUserImage:
                                          currentUser.photoUrl,
                                      roomImage: currentUser.photoUrl.isEmpty
                                          ? null
                                          : currentUser.photoUrl,
                                      roomName: controller
                                          .roomNameController.text
                                          .toString());
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            label: Text('Create Room')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(15.0),
            child: TabBarView(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My Room',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(
                      height: 10,
                    ),

                    StreamBuilder<List<QueryDocumentSnapshot>>(
                      stream: getUserRooms(currentUser.userId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return CircularProgressIndicator();
                        }

                        if (snapshot.hasError) {
                          return Text("Error: ${snapshot.error}");
                        }

                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return Text("No rooms found");
                        }

                        final docs = snapshot.data!;

                        return SizedBox(
                          height: 150,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: docs.length,
                            itemBuilder: (context, index) {
                              var data = docs[index];
                              return Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: InkWell(
                                  onTap: () async {
                                    await Permission.microphone.request();
                                  },
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        height: 100,
                                        width: 100,
                                        decoration: BoxDecoration(
                                          color: Colors.grey,
                                          borderRadius:
                                              BorderRadius.circular(15),
                                        ),
                                        child: data['roomImage'] != null
                                            ? ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(15),
                                                child: Image.network(
                                                  data['roomImage'],
                                                  fit: BoxFit.cover,
                                                ),
                                              )
                                            : Icon(Icons.person_3),
                                      ),
                                      Text(data['roomName'] ?? ''),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                    Text('Recommended Room',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    //    AnimatedBuilder(

                    //      animation: _tabController,
                    //      builder: (BuildContext context, Widget? child) {
                    //       return Container(
                    //                  height: 48,
                    //                  padding: EdgeInsets.symmetric(horizontal: 4),
                    //                  child: Row(
                    //       children: List.generate(_titles.length, (index) {
                    //         bool isSelected = _tabController.index == index;
                    //         return Expanded(
                    //           child: GestureDetector(
                    //             onTap: () {
                    //               _tabController.animateTo(index);
                    //             },
                    //             child: Container(
                    //               margin: EdgeInsets.symmetric(horizontal: 4),
                    //               padding: EdgeInsets.symmetric( vertical: 7),
                    //               decoration: BoxDecoration(
                    //                 color: isSelected ? Colors.black : Colors.grey.shade300,
                    //                 borderRadius: BorderRadius.circular(12),
                    //               ),
                    //               child: Row(
                    //                 mainAxisAlignment: MainAxisAlignment.center,
                    //                 children: [
                    //                   Icon(_icons[index], color: isSelected ? Colors.white : Colors.black,size: 15,),
                    //                   SizedBox(width: 2),
                    //                   Text(
                    //                     _titles[index],
                    //                     style: TextStyle(
                    //                       color: isSelected ? Colors.white : Colors.black,
                    //                       fontWeight: FontWeight.w500,
                    //                       fontSize: 12
                    //                     ),
                    //                   ),
                    //                 ],
                    //               ),
                    //             ),
                    //           ),
                    //         );
                    //       }),
                    //                  ),
                    //                );
                    //       },

                    //    ),
                    // Expanded(

                    //   child: TabBarView(
                    //     controller: _tabController,
                    //   children: [
                    //      StreamBuilder(
                    //       stream: FirebaseFirestore.instance
                    //           .collection('voice_room_messages')
                    //           .snapshots(),
                    //       builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                    //         if (snapshot.connectionState == ConnectionState.waiting) {
                    //           return CircularProgressIndicator(); // Loading spinner while waiting
                    //         }

                    //         if (snapshot.hasError) {
                    //           return Text("Error: ${snapshot.error}");
                    //         }

                    //         if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    //           return Text("No data found");
                    //         }

                    //         // Data available
                    //         return Expanded(
                    //           //height: 150,
                    //           child: ListView.builder(
                    //             scrollDirection: Axis.vertical,
                    //             itemCount: snapshot.data!.docs.length,
                    //             itemBuilder: (context, index) {
                    //               var data = snapshot.data!.docs[index];
                    //               return Padding(
                    //                 padding: const EdgeInsets.only(right: 10),
                    //                 child: InkWell(
                    //                   onTap: () async{
                    //                         await Permission.microphone.request();

                    //                    // Get.to(()=>VoiceRoomScreen3(userId: currentUser.userId, displayName: currentUser.fullname, profileImage: "https://cdn-icons-png.flaticon.com/512/2922/2922506.png"));
                    //                    currentUser.userId==data['roomCreatedUserId']?Get.to(()=>LivePage(userId: currentUser.userId, displayName: currentUser.fullname, profileImage: currentUser.photoUrl,isHost: true,groupName: data['roomName'],roomId:data['roomID'] ,groupInfo: data,)): Get.to(()=>LivePage(userId: currentUser.userId, displayName: currentUser.fullname, profileImage: currentUser.photoUrl,isHost: false,groupName: data['roomName'],roomId:data['roomID'],groupInfo: data));
                    //                   },
                    //                   child: Card(
                    //                     child: Padding(
                    //                       padding: const EdgeInsets.all(12.0),
                    //                       child: Column(
                    //                         crossAxisAlignment: CrossAxisAlignment.start,
                    //                         children: [
                    //                           Row(
                    //                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    //                             children: [

                    //                               Row(
                    //                                 children: [
                    //                                   Container(
                    //                                     height: 40,
                    //                                     width: 40,
                    //                                     decoration: BoxDecoration(
                    //                                       color: Colors.grey,
                    //                                         borderRadius: BorderRadius.circular(7)),
                    //                                     child: data['roomImage'] != null
                    //                                         ? ClipRRect(
                    //                                            borderRadius: BorderRadius.circular(7),
                    //                                           child: Image.network(data[
                    //                                               'roomImage'],fit: BoxFit.cover,),
                    //                                         ) // Assuming roomImage is a URL
                    //                                         : Icon(Icons.person_3,),
                    //                                   ),
                    //                                   SizedBox(width: 5,),
                    //                               Text(data['roomName'],style: TextStyle(fontWeight: FontWeight.bold),),
                    //                                 ],
                    //                               ),

                    //                               Container(
                    //                                 decoration: BoxDecoration(
                    //                                   color: Colors.grey.shade300,
                    //                                   borderRadius: BorderRadius.circular(10)
                    //                                 ),
                    //                                 child: Padding(
                    //                                   padding: const EdgeInsets.all(4.0),
                    //                                   child: Row(
                    //                                     children: [
                    //                                       Icon(Icons.person_outline,size: 15,),
                    //                                       SizedBox(width: 2,),
                    //                                       Text(data['memberList'].length.toString()),
                    //                                     ],
                    //                                   ),
                    //                                 ),
                    //                               )
                    //                             ],
                    //                           ),
                    //                           Padding(
                    //                             padding: const EdgeInsets.symmetric(vertical: 10),
                    //                             child: Text(data['roomDescription'],style: TextStyle(fontWeight: FontWeight.bold,fontSize: 18),),
                    //                           ),
                    //                           SizedBox(
                    //                             height: 35,
                    //                             child: ListView.builder(
                    //                               scrollDirection: Axis.horizontal,
                    //                               itemCount: data['memberList'].length,
                    //                               itemBuilder: (context,index){
                    //                                 var roomMemberImage = data['memberList'][index]['image'];

                    //                             bool isValidUrl = roomMemberImage != null &&
                    //                                               roomMemberImage.toString().isNotEmpty &&
                    //                                               Uri.tryParse(roomMemberImage)?.hasAbsolutePath == true;
                    //                                 return  Padding(
                    //                                   padding: const EdgeInsets.only(right: 5),
                    //                                   child: Container(
                    //                                     height: 40,
                    //                                     width: 40,
                    //                                     decoration: BoxDecoration(
                    //                                       shape: BoxShape.circle,
                    //                                       color: Colors.grey.shade300,),
                    //                                     child: isValidUrl
                    //                                         ? ClipOval(
                    //                                           child: Image.network(roomMemberImage,fit: BoxFit.cover),
                    //                                           )
                    //                                          // Assuming roomImage is a URL
                    //                                         : Icon(Icons.person_3,)
                    //                                   ),
                    //                                 );
                    //                               }),
                    //                           )
                    //                         ],
                    //                       ),
                    //                     ),
                    //                   ),
                    //                 ),
                    //               );
                    //             },
                    //           ),
                    //         );
                    //       },
                    //     ),

                    //    Text('Nearby Room'),
                    //    Text('More')
                    //   ]))
                  ],
                ),
                ExploreTabContent(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:ui';


import 'package:chat_messenger/components/cached_card_image.dart';
import 'package:chat_messenger/components/loading_indicator.dart';
import 'package:chat_messenger/screens/home/home_screen.dart';

import 'package:flutter/material.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/components/cached_circle_avatar.dart';
import 'package:chat_messenger/models/call.dart';
import 'package:chat_messenger/config/theme_config.dart';
import 'package:get_storage/get_storage.dart';

import 'components/call_timer.dart';
import '../../components/circle_button.dart';
import 'controller/call_controller.dart';

class VoiceCallScreen extends StatelessWidget {
  VoiceCallScreen({super.key, required this.call});

  final Call call;
  final GetStorage box = GetStorage();
  void onPhoneBackButtonPress(){
    box.write('callIsActive', call.toMap());
    Get.to(()=>HomeScreen());
   }
  @override
  Widget build(BuildContext context) {
    // Ensure clean fresh CallController for every new call instance
    if (Get.isRegistered<CallController>()) {
      Get.delete<CallController>(force: true);
    }
    
    // Get call controller
    final CallController controller = Get.put(CallController(call: call));
  
    return PopScope(
      canPop: true,
      child: Obx(() {
        // Get obx vars
        final int? remoteUid = controller.remoteUid.value;
        final String photoUrl =
            call.isCaller ? call.receiverPhotoUrl : call.callerPhotoUrl;
        final String profileName =
        call.isCaller ? call.receiverName : call.callerName;

        return Scaffold(
          // extendBodyBehindAppBar: true,
          // appBar: CustomAppBar(
          //   centerTitle: false,
          //   backgroundColor: Colors.transparent,
          //   //onBackPress: () => controller.onEndCall(),
          //   onBackPress: () async {
          //     return await showDialog(
          //           context: context,
          //           builder: (context) => AlertDialog(
          //             title: Text('Leave Call?'),
          //             content: Text('Do you really want to leave the call?'),
          //             actions: [
          //               TextButton(
          //                 onPressed: () => Navigator.of(context)
          //                     .pop(false), // Dismiss dialog, do not exit
          //                 child: Text('No'),
          //               ),
          //               TextButton(
          //                 onPressed: () {
          //                   Navigator.of(context).pop(false);
          //                   controller.onEndCall();
          //                 }, // Exit the call
          //                 child: Text('Yes'),
          //               ),
          //             ],
          //           ),
          //         ) ??
          //         false;
          //   },
          // ),
          body:  Stack(
            fit: StackFit.expand,
            children: [
              // Background image with blur
              if (photoUrl.isNotEmpty) CachedCardImage(photoUrl),
              // Apply a blur effect to the background image
              if (photoUrl.isNotEmpty)
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(color: Colors.black.withValues(alpha: 0.5)),
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
                        icon: Icon(Icons.zoom_out_map,
                            color: Colors.white, size: 30),
                        onPressed: () {
                          
                            controller.isMinimized.value = true;
                         
                           box.write('callIsActive',call.toMap());
                         
                          Get.to(()=>HomeScreen(
                           
                            ));
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
                      SizedBox(height: 40,),
                      // Profile avatar
                      CachedCircleAvatar(
                        iconSize: 70,
                        imageUrl: photoUrl,
                        radius: 75,
                      ),
                      const SizedBox(height: 16),
                      // Show call duration
                      remoteUid != null
                          ? const CallTimer()
                         // : JoinCallIndicator(call),
                         : Column(
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
        if (call.isCaller && controller.isOnline.value==true)
        Text(
            'Ringing',
            style: Theme.of(context)
                .textTheme
                .bodyLarge!
                .copyWith(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        
        if (call.isCaller && controller.isOnline.value==false)
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
        LoadingIndicator(color: primaryColor),
                          ],
                         ),

                      const Spacer(),
                      SizedBox(height: 70,),
                      // <-- Call Actions -->
                      Obx(() => Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Column(
                            children: [
                              CircleButton(
                                size: 70,
                                color: Colors.black54,
                                icon: Icon(
                                  controller.speaker.value
                                      // ? IconlyBold.volumeUp
                                      // : IconlyBold.volumeOff,
                                      ?Icons.volume_up: IconlyBold.volumeUp,
                                  color: Colors.white,
                                ),
                                onPress: () => controller.onToggleSpeaker(),
                              ),
                              SizedBox(height: 10,),
                              Text('Speaker',style: TextStyle(fontSize: 18,color: Colors.white),)
                            ],
                          ),
                          const SizedBox(width: 30),
                          Column(
                            children: [
                              CircleButton(
                                size: 70,
                                color: Colors.black54,
                                icon: Icon(
                                  controller.mute.value
                                      ? Icons.mic_off
                                      : IconlyBold.voice,
                                  color: Colors.white,
                                ),
                                onPress: () => controller.onToggleMute(),
                              ),
                               SizedBox(height: 10,),
                              Text('Mute',style: TextStyle(fontSize: 18,color: Colors.white),)
                            ],
                          ),
                          const SizedBox(width: 30),
                          Column(
                            children: [
                              CircleButton(
                                size: 70,
                                color: Colors.redAccent,
                                icon: const Icon(
                                  Icons.call_end,
                                 // IconlyBold.callMissed,
                                  color: Colors.white,
                                ),
                                onPress: () {
                                  controller.onEndCall();
                                  box.remove('callIsActive');
                                } ,
                              ),
                            SizedBox(height: 10,),
                              Text('Hang Up',style: TextStyle(fontSize: 18,color: Colors.white),)
                            ],
                          ),
                        ],
                      )),
                      const Spacer(),
                      // IconButton(onPressed: (){
                      //   var box = GetStorage();
                      //   box.write('callIsActive', true);
                      //   box.write('call', call.toMap());
                      //   Get.back();
                      // }, icon: Icon(Icons.abc))
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
  
}

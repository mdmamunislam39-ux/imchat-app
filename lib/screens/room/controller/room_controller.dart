import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:chat_messenger/components/app_loading.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class RoomController extends GetxController {


  // Vars
  RxInt seconds = RxInt(0);
  Rxn<int> remoteUid = Rxn();
  RxBool isLocalUserJoined = RxBool(false);
  RxBool speaker = RxBool(false);
  RxBool mute = RxBool(false);

  // Agora SDK engine
  late RtcEngine engine;

  ////////// add new/////////////////
  // Add state field
  RxString callState = ''.obs;
  RxBool isMinimized = false.obs;
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController roomNameController = TextEditingController();
  final TextEditingController roomDescriptionController = TextEditingController();
  final Rxn<File> photoFile = Rxn();
  final RxBool isLoading = RxBool(false);
  final RxString selectedRoomType = 'Party'.obs; // 'Party' (audio) or 'Live' (video)
 

  // Toggle phone speaker
  void onToggleSpeaker() {
     final bool newValue = speaker.value = !speaker.value;
     engine.setEnableSpeakerphone(newValue);
    // engine.stopCameraCapture(VideoSourceType.videoSourceCamera);
  }

  // Toggle mute
  void onToggleMute() {
    final bool newValue = mute.value = !mute.value;
    engine.muteLocalAudioStream(newValue);
  }

  // End the call and pass the value
  void onEndCall() {
    Get.back(result: remoteUid.value);
  }
  
    Future<String> uploadRoomImage({
    required File file,
    required String userId,
    required String fileName
  }) async {
    
    // Upload file
    final UploadTask uploadTask = FirebaseStorage.instance
        .ref()
        .child('uploads/room/$userId/$fileName')
        .putFile(file);
    final TaskSnapshot snapshot = await uploadTask;
    final String url = await snapshot.ref.getDownloadURL();
    
    return url;
  }
  
String generateRoomId() {
  final random = Random();
  final length = 8 + random.nextInt(3); // Random length: 8, 9, or 10
  final buffer = StringBuffer();

  for (int i = 0; i < length; i++) {
    buffer.write(random.nextInt(10));  // Adds a digit 0–9
  }

  return buffer.toString();
}

   Future<String> createNewRoom({roomCreatedUserId,roomCreatedUserName,roomCreatedUserImage,roomImage,roomName})async{
    if (formKey.currentState!.validate()) {
      try {

     await FirebaseFirestore.instance.collection('voice_room_messages').doc(roomName).set({
     'roomName': roomName,
     'roomDescription': roomDescriptionController.text.toString(),
     'roomImage': roomImage,
     'roomID': generateRoomId(),
     'roomType': selectedRoomType.value,
     'roomCreatedUserId': roomCreatedUserId.toString(),
     'roomCreatedUserName': roomCreatedUserName,
     'roomCreatedUserImage': roomCreatedUserImage,
     'memberList': [
      {
      'image':roomCreatedUserImage,
      'name':roomCreatedUserName,
      'userId':roomCreatedUserId.toString(),
      }
     ]
    });
    Get.back();
    AppStyle().successSnackBar(message: 'New room Created');
    return '';
   } catch (e) {
     debugPrint(e.toString());
     return 'error';
   }
    } else {
     return 'fill up this field';
    }
   
  }

}

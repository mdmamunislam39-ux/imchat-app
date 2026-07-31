import 'package:chat_messenger/api/call_history_api.dart';
import 'package:chat_messenger/tabs/groups/screens/group_video_call.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/api/message_api.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/models/call.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:chat_messenger/routes/app_routes.dart';
import 'package:chat_messenger/services/push_notification_service.dart';

abstract class CallHelper {
  //
  // Call Helper Methods
  //
  

  // Make video/voice call
  static Future<void> makeCall({
    required bool isVideo,
    required User user,
  }) async {
    // Get current user
    final User currentUser = AuthController.instance.currentUser;
    
    // Get call instance
    final Call call = Call(
      isVideo: isVideo,
      // Set caller info
      callerId: currentUser.userId,
      callerName: currentUser.fullname,
      callerPhotoUrl: currentUser.photoUrl,
      // Set receiver info
      receiverName: user.fullname,
      receiverPhotoUrl: user.photoUrl,
      receiverId: user.userId
    );

  //     String getFormattedCallTime() {
  //   // Get the CallController
  //   final CallController controller = Get.put(CallController(call: call));

  //   // Get the current seconds from the controller
  //   int seconds = controller.seconds.value;

  //   // Use CallHelper's formatTime method to format it as a string
  //   return CallHelper.formatTime(seconds);
  // }
  //  String formattedTime = getFormattedCallTime();
    // Get notification body
    final String body =
        isVideo ? 'incomming_video_call'.tr : 'incomming_voice_call'.tr;
     
     
    // Send push notification call
    PushNotificationService.sendNotification(
      type: NotificationType.call,
      title: currentUser.fullname,
      body: body,
      //body: '${body} $formattedTime',
      deviceToken: user.deviceToken,
      call: call.toMap(),
    );
    
    

    // Vars
    dynamic result;
    final Map<String, Call> arguments = {'call': call};

    // Save call history
    CallHistoryApi.saveCall(isVideo: isVideo, receiver: user);

    // Check call type
    if (isVideo) {
      await FirebaseFirestore.instance.collection('Calls').doc(currentUser.userId).set({
        'callerId': currentUser.userId,
        'callerName': currentUser.fullname,
        'callerPhotoUrl': currentUser.photoUrl,
        // Set receiver info
        'receiverName': user.fullname,
        'receiverPhotoUrl': user.photoUrl,
        'receiverId': user.userId,
        'state': 'calling'
      });
      // Go to video call page
      result = await Get.toNamed(AppRoutes.videoCall, arguments: arguments);
    } else {
      await FirebaseFirestore.instance.collection('Calls').doc(currentUser.userId).set({
        'callerId': currentUser.userId,
        'callerName': currentUser.fullname,
        'callerPhotoUrl': currentUser.photoUrl,
        // Set receiver info
        'receiverName': user.fullname,
        'receiverPhotoUrl': user.photoUrl,
        'receiverId': user.userId,
        'state': 'calling'
      });
      // Go to voice call page
      result = await Get.toNamed(AppRoutes.voiceCall, arguments: arguments);
     // CallHistoryApi.saveCall(isVideo: isVideo, receiver: user);
    }

    // Check result to send missed call message
    if (result == null) {
      Future.wait([
        MessageApi.sendMissedCallMessage(isVideo: isVideo, receiver: user),
        CallHistoryApi.saveMissedCall(isVideo: isVideo, receiver: user),
      ]);
    }
  }

  // Format the call time
  static String formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  static Future<void> makeGroupCall({
    required bool isVideo,
    required List<User> recipients,  // Multiple recipients
  }) async {
    // Get current user
    final User currentUser = AuthController.instance.currentUser;
    
    // Create the base call instance for all users
    final Call call = Call(
      isVideo: isVideo,
      callerId: currentUser.userId,
      callerName: currentUser.fullname,
      callerPhotoUrl: currentUser.photoUrl,
      receiverName: 'Group Call',
      receiverPhotoUrl: '', // Optional for group calls
      receiverId: 'group_call', // Group identifier
    );

    // Notification body
    final String body = isVideo
        ? 'incoming_group_video_call'.tr
        : 'incoming_group_voice_call'.tr;

    // Send notifications and update Firestore for each recipient
    for (var recipient in recipients) {
      // Send push notification for each recipient
      PushNotificationService.sendNotification(
        type: NotificationType.call,
        title: currentUser.fullname,
        body: body,
        deviceToken: recipient.deviceToken,
        call: call.toMap(), // Send the call object
      );

      // Save call info for each recipient in Firestore
      await FirebaseFirestore.instance.collection('GroupCalls').doc(currentUser.userId)
      .set({
        'callerId': currentUser.userId,
        'callerName': currentUser.fullname,
        'callerPhotoUrl': currentUser.photoUrl,
        'receiverName': [currentUser.fullname],
        'state': 'calling',
        'isVideo': isVideo,
        'group': true,  // Indicate it's a group call
      });
      
      // Save call history for each recipient
      CallHistoryApi.saveCall(isVideo: isVideo, receiver: recipient);
    }

  // Navigate to video or voice call screen with group info
  // final Map<String, dynamic> arguments = {
  //   'call': call,
  //   'recipients': recipients, // Pass the list of recipients
  // };

  dynamic result;
  if (isVideo) {
    // Navigate to video call page
    result = await Get.to(GroupCallScreen(isVideo: isVideo,
    // participants: recipients,
      call: call));
   // result = await Get.toNamed(AppRoutes.videoCall, arguments: arguments);
  } else {
    // Navigate to voice call page
     result = await Get.to(GroupCallScreen(isVideo: isVideo,
     // participants: recipients, 
      call: call));
    //result = await Get.toNamed(AppRoutes.voiceCall, arguments: arguments);
  }

  // Handle missed call scenario for all recipients
  if (result == null) {
    for (var recipient in recipients) {
      await Future.wait([
        MessageApi.sendMissedCallMessage(isVideo: isVideo, receiver: recipient),
        CallHistoryApi.saveMissedCall(isVideo: isVideo, receiver: recipient),
      ]);
    }
  }
}



    

}

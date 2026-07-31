// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import 'package:chat_messenger/config/theme_config.dart';
// import 'package:get/get.dart';
// import 'package:chat_messenger/components/loading_indicator.dart';
// import 'package:chat_messenger/models/call.dart';

// class JoinCallIndicator extends StatelessWidget {
//    JoinCallIndicator(this.call, {super.key, this.loadingColor});

//   final Call call;
//   final Color? loadingColor;
  
//   RxBool online = false.obs;
//   @override
//   Widget build(BuildContext context) {
    
//     Future<void> fetchDocumentField() async {
//   try {
//     // Replace 'collectionName' and 'documentId' with your actual values
//     DocumentSnapshot documentSnapshot = await FirebaseFirestore.instance
//         .collection('Users')
//         .doc(call.receiverId)
//         .get();

//     if (documentSnapshot.exists) {
//       // Access specific field data
//        online.value = documentSnapshot.get('isOnline');
//        debugPrint(online.value);
      
//     } else {
//       debugPrint('Document does not exist!');
//     }
//   } catch (e) {
//     debugPrint('Error fetching document: $e');
//   }
// }
// fetchDocumentField();
//     // Vars
//     final String profileName =
//         call.isCaller ? call.receiverName : call.callerName;

//     return Column(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         // Profile name
//         Text(
//           profileName,
//           style: Theme.of(context)
//               .textTheme
//               .headlineSmall!
//               .copyWith(color: Colors.white54),
//           textAlign: TextAlign.center,
//         ),
//         const SizedBox(height: 16),
//         // Show when current user is a caller
//         if (call.isCaller && online.value==true)
//         Text(
//             'Ringing',
//             style: Theme.of(context)
//                 .textTheme
//                 .bodyLarge!
//                 .copyWith(color: Colors.white),
//             textAlign: TextAlign.center,
//           ),
        
//         if (call.isCaller && online.value==false)
//           Text(
//             'calling'.tr,
//             style: Theme.of(context)
//                 .textTheme
//                 .bodyLarge!
//                 .copyWith(color: Colors.white),
//             textAlign: TextAlign.center,
//           ),
//         const SizedBox(height: 3),
//         // Show loading
//         LoadingIndicator(color: loadingColor ?? primaryColor),
//       ],
//     );
//   }
// }

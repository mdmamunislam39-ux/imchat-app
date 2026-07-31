
// class AuthController extends GetxController {

//    //phone auth
//   Future<String> phoneAuthSendOtp(context, phoneNumber) async {
//     String result = "";

//     AppStyle().progressDialog(context);
//     try {
//       await FirebaseAuth.instance.verifyPhoneNumber(
//         phoneNumber: phoneNumber,
//         verificationCompleted: (PhoneAuthCredential credential) async {
//           // userPhoneNumber = phoneNumber;
//           // box.write('userNumber', phoneNumber);
//           // await auth.signInWithCredential(credential);
//         },
//         verificationFailed: (FirebaseAuthException e) {
//           if (e.code == 'invalid-phone-number') {
//             result = "The provided phone number is not valid.";
//             Get.back();
//             AppStyle().failedSnackBar(message: result);
//           } else {
//             Get.back();
//             AppStyle().failedSnackBar(message: e.toString());
//           }
//         },
//         codeSent: (String verificationId, int? resendToken) async {
//           result = verificationId;
//           Get.back();
//           Navigator.push(
//               context,
//               MaterialPageRoute(
//                   builder: (context) => VerifyCodeScreen(
//                         verificatonId: verificationId,
//                         number: phoneNumber
//                       )));
//         },
//         timeout: const Duration(seconds: 60),
//         codeAutoRetrievalTimeout: (String verificationId) {
//           // Navigator.pop(context);
//         },
//       );
//     } catch (e) {
//       Get.back();
//       Get.snackbar('Error', e.toString());
      
//     }
//     return result;
//   }

//   //phone auth verify otp
//   Future<String> phoneAuthVerifyOtp(verificationId, smsCode, context) async {
//     String result = "An error is occurred";
//     FirebaseAuth auth = FirebaseAuth.instance;
//     AppStyle().progressDialog(context);
//     try {
//       // Create a PhoneAuthCredential with the code
//       PhoneAuthCredential credential = PhoneAuthProvider.credential(
//           verificationId: verificationId, smsCode: smsCode);

//       // Sign the user in (or link) with the credential
//       await auth.signInWithCredential(credential);
//       result = "success";
//     } catch (e) {
//       Get.back();
//       result = e.toString();
//     }
//     return result;
//   }


// }

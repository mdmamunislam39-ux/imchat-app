import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../models/device_session_model.dart';
import '../../../services/device_session_service.dart';
import '../../../controllers/auth_controller.dart';
import '../../../components/app_loading.dart';

class ManageDevicesController extends GetxController {
  var isLoading = true.obs;
  
  var currentSession = Rxn<DeviceSessionModel>();
  var otherActiveSessions = <DeviceSessionModel>[].obs;
  var loginHistory = <DeviceSessionModel>[].obs;

  StreamSubscription? _activeSessionsSub;
  StreamSubscription? _historySessionsSub;

  final TextEditingController otpController = TextEditingController();
  var isOtpSending = false.obs;
  var isOtpVerifying = false.obs;
  String _verificationId = '';
  
  var resendTimer = 60.obs;
  Timer? _timer;

  @override
  void onInit() {
    super.onInit();
    _loadSessions();
  }

  @override
  void onClose() {
    _activeSessionsSub?.cancel();
    _historySessionsSub?.cancel();
    _timer?.cancel();
    otpController.dispose();
    super.onClose();
  }

  Future<void> _loadSessions() async {
    final user = AuthController.instance.currentUser;
    if (user.userId.isEmpty) {
      isLoading.value = false;
      return;
    }

    try {
      final currentDeviceId = await DeviceSessionService.getDeviceId();
      // Ensure the current session is registered in Firestore
      // This is crucial for users who logged in before this feature was added
      await DeviceSessionService.registerSession(user.userId);

      _activeSessionsSub = DeviceSessionService.getActiveSessions(user.userId).listen((sessions) {
        otherActiveSessions.clear();
        
        for (var session in sessions) {
          if (session.deviceId == currentDeviceId) {
            currentSession.value = session;
          } else {
            otherActiveSessions.add(session);
          }
        }
        isLoading.value = false;
      }, onError: (error) {
        debugPrint('Error loading active sessions: $error');
        isLoading.value = false;
      });

      _historySessionsSub = DeviceSessionService.getLoginHistory(user.userId).listen((sessions) {
        loginHistory.assignAll(sessions);
      }, onError: (error) {
        debugPrint('Error loading login history: $error');
      });
    } catch (e) {
      debugPrint('Exception in _loadSessions: $e');
      isLoading.value = false;
    }
  }

  void initiateLogoutFlow(BuildContext context, DeviceSessionModel targetSession) async {
    final user = AuthController.instance.currentUser;
    final phoneNumber = user.number;

    if (phoneNumber.isEmpty) {
      AppStyle().failedSnackBar(message: 'Phone number not linked to account. Cannot verify logout.');
      return;
    }

    await _sendOtp(phoneNumber, context);
    if (!context.mounted) return;
    _showOtpDialog(context, targetSession, phoneNumber);
  }

  Future<void> _sendOtp(String phoneNumber, BuildContext context) async {
    isOtpSending.value = true;
    _startTimer();

    try {
      FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification
        },
        verificationFailed: (FirebaseAuthException e) {
          AppStyle().failedSnackBar(message: e.message ?? 'Failed to send OTP');
          isOtpSending.value = false;
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          isOtpSending.value = false;
          AppStyle().successSnackBar(message: 'OTP sent to your registered mobile number.');
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      ).catchError((e) {
        isOtpSending.value = false;
        AppStyle().failedSnackBar(message: 'Error: $e');
      });
    } catch (e) {
      isOtpSending.value = false;
      AppStyle().failedSnackBar(message: 'Error: $e');
    }
  }

  void _startTimer() {
    resendTimer.value = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (resendTimer.value > 0) {
        resendTimer.value--;
      } else {
        timer.cancel();
      }
    });
  }

  void _showOtpDialog(BuildContext context, DeviceSessionModel targetSession, String phoneNumber) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text('Verify Logout', style: TextStyle(color: Colors.white)),
        content: Obx(() {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter the 6-digit OTP sent to your phone number.', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              TextField(
                controller: otpController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  hintText: '000000',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.black,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 8),
              if (isOtpVerifying.value)
                const CircularProgressIndicator()
              else ...[
                if (resendTimer.value == 0)
                  TextButton(
                    onPressed: () => _sendOtp(phoneNumber, ctx),
                    child: const Text('Resend OTP', style: TextStyle(color: Colors.blue)),
                  )
                else
                  Text('Resend in ${resendTimer.value}s', style: const TextStyle(color: Colors.grey)),
              ]
            ],
          );
        }),
        actions: [
          TextButton(
            onPressed: () {
              otpController.clear();
              Navigator.pop(ctx);
            },
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => _verifyOtpAndLogout(ctx, targetSession),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Verify & Logout'),
          ),
        ],
      ),
    );
  }

  Future<void> _verifyOtpAndLogout(BuildContext context, DeviceSessionModel targetSession) async {
    final code = otpController.text.trim();
    if (code.length < 6) {
      AppStyle().failedSnackBar(message: 'Please enter a valid 6-digit OTP.');
      return;
    }

    isOtpVerifying.value = true;
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: code,
      );

      // We just need to link or re-authenticate to verify. 
      // But actually we just need to verify the credential without breaking the current session.
      // Easiest way without modifying currentUser is to sign in anonymously or just let Firebase confirm credential?
      // Wait, we can't signInWithCredential as it changes currentUser state.
      // Wait! We CAN use the current user's reauthenticateWithCredential!
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.reauthenticateWithCredential(credential);
        
        // OTP valid!
        await DeviceSessionService.forceLogoutDevice(targetSession.deviceId);
        _logSecurityEvent(targetSession);

        AppStyle().successSnackBar(message: 'ডিভাইসটি সফলভাবে লগআউট করা হয়েছে।');
        
        otpController.clear();
        if (context.mounted) Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      AppStyle().failedSnackBar(message: 'Invalid OTP. ${e.message}');
    } catch (e) {
      AppStyle().failedSnackBar(message: 'Error verifying OTP: $e');
    } finally {
      isOtpVerifying.value = false;
    }
  }

  void _logSecurityEvent(DeviceSessionModel session) {
    FirebaseFirestore.instance.collection('security_logs').add({
      'userId': session.userId,
      'action': 'DEVICE_LOGOUT',
      'targetDeviceId': session.deviceId,
      'targetDeviceName': session.deviceName,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}

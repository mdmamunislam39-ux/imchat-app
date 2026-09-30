import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../AdminPane/models/gift.dart';
import '../../../AdminPane/services/gift_service.dart';
import '../../../controllers/auth_controller.dart';
import '../../../screens/room/wallet_screen.dart';
import '../../../services/wallet_service.dart';
import '../../../services/emoji_chat_service.dart';

class ComboBannerData {
  final String senderId;
  final String senderName;
  final String? senderImageUrl;
  final String receiverName;
  final String giftName;
  final String? giftPngUrl;
  final int giftCredits;
  final int comboCount;
  final DateTime timestamp;

  ComboBannerData({
    required this.senderId,
    required this.senderName,
    this.senderImageUrl,
    required this.receiverName,
    required this.giftName,
    this.giftPngUrl,
    required this.giftCredits,
    required this.comboCount,
    required this.timestamp,
  });
}

class GiftComboController extends GetxController {
  static GiftComboController get instance {
    if (!Get.isRegistered<GiftComboController>()) {
      return Get.put(GiftComboController());
    }
    return Get.find<GiftComboController>();
  }

  // Active combo session data
  final Rx<Gift?> activeGift = Rx<Gift?>(null);
  final RxList<Map<String, dynamic>> activeReceivers = <Map<String, dynamic>>[].obs;
  final RxInt activeQuantity = 1.obs;
  final RxInt comboCount = 1.obs;
  final RxString currentRoomId = ''.obs;
  final RxString currentSenderId = ''.obs;
  final RxString currentSenderName = ''.obs;
  final RxnString currentSenderImageUrl = RxnString(null);

  // UI state
  final RxBool isComboButtonVisible = false.obs;
  final RxDouble comboProgress = 1.0.obs;
  final Rx<ComboBannerData?> bannerData = Rx<ComboBannerData?>(null);

  // Timers
  Timer? _countdownTimer;
  Timer? _progressTimer;
  Timer? _bannerTimer;

  final GiftService _giftService = GiftService();

  static const int comboTimeoutSeconds = 4;

  /// Start a new gift combo session when a gift is sent
  void startComboSession({
    required Gift gift,
    required List<Map<String, dynamic>> receivers,
    required int quantity,
    required String roomId,
    required String senderId,
    required String senderName,
    String? senderImageUrl,
    int initialComboCount = 1,
  }) {
    activeGift.value = gift;
    activeReceivers.assignAll(receivers);
    activeQuantity.value = quantity;
    comboCount.value = initialComboCount;
    currentRoomId.value = roomId;
    currentSenderId.value = senderId;
    currentSenderName.value = senderName;
    currentSenderImageUrl.value = senderImageUrl;

    isComboButtonVisible.value = true;
    comboProgress.value = 1.0;

    _updateBannerData();
    _startCountdown();
  }

  /// Send a combo hit (tap on combo button)
  Future<void> sendComboHit() async {
    final gift = activeGift.value;
    if (gift == null || activeReceivers.isEmpty) return;

    final quantity = activeQuantity.value;
    final totalCost = gift.credits * quantity * activeReceivers.length;

    // Optimistic balance check & deduction to prevent race conditions during rapid taps
    final hasEnoughBalance = AuthController.instance.deductDiamonds(totalCost);

    if (!hasEnoughBalance) {
      // Dismiss combo button immediately so user cannot keep clicking without diamonds
      dismissComboButton();

      final user = AuthController.instance.currentUser;
      Get.snackbar(
        'Insufficient Diamonds',
        'You need $totalCost diamonds to send this combo. Please recharge.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.withValues(alpha: 0.9),
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
        mainButton: TextButton(
          onPressed: () {
            Get.to(() => DiamondRechargePage(
                  diamondBalance: user.diamonds,
                  walletService: WalletService(),
                  userId: user.userId,
                ));
          },
          child: const Text(
            'Recharge',
            style: TextStyle(
              color: Colors.yellowAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
      return;
    }

    // Increment combo counter
    comboCount.value++;
    comboProgress.value = 1.0;

    final roomId = currentRoomId.value;
    final senderId = currentSenderId.value;
    final senderName = currentSenderName.value;
    final senderImageUrl = currentSenderImageUrl.value;

    // Reset timer
    _startCountdown();

    // Update screen banner
    _updateBannerData();

    try {
      // Background transaction write
      _giftService.sendGifts(
        giftId: gift.id,
        giftName: gift.name,
        giftPngUrl: gift.pngUrl ?? '',
        giftSvgaUrl: null, // Combo hits do not re-trigger heavy SVGA animation
        giftCredits: gift.credits,
        quantity: quantity,
        senderId: senderId,
        senderName: senderName,
        senderImageUrl: senderImageUrl,
        receivers: activeReceivers,
        roomId: roomId,
        sendChatMessage: false,
        isComboHit: true,
      ).catchError((e) {
        debugPrint('❌ [GiftCombo] Error sending combo gift: $e');
        AuthController.instance.refundDiamonds(totalCost);
      });
    } catch (e) {
      debugPrint('❌ [GiftCombo] Error sending combo hit: $e');
      AuthController.instance.refundDiamonds(totalCost);
    }
  }

  /// Center banner overlay removed per user request - no extra center screen on combo
  void _updateBannerData() {
    bannerData.value = null;
  }

  /// Trigger banner for incoming gift transactions from room members (disabled)
  void triggerIncomingGiftCombo({
    required String senderId,
    required String senderName,
    required String? senderImageUrl,
    required String receiverName,
    required String giftName,
    required String? giftPngUrl,
    required int giftCredits,
    required int comboCount,
  }) {
    bannerData.value = null;
  }

  /// Start countdown timer for the combo button
  void _startCountdown() {
    _countdownTimer?.cancel();
    _progressTimer?.cancel();

    const totalMs = comboTimeoutSeconds * 1000;
    const intervalMs = 50;
    int elapsedMs = 0;

    _progressTimer = Timer.periodic(const Duration(milliseconds: intervalMs), (timer) {
      elapsedMs += intervalMs;
      comboProgress.value = (1.0 - (elapsedMs / totalMs)).clamp(0.0, 1.0);
      if (elapsedMs >= totalMs) {
        timer.cancel();
      }
    });

    _countdownTimer = Timer(const Duration(seconds: comboTimeoutSeconds), () {
      dismissComboButton();
    });
  }

  /// Hide the combo button and clear session
  void dismissComboButton() {
    _countdownTimer?.cancel();
    _progressTimer?.cancel();

    // Send a single summary chat message for the total combo hits when session finishes
    if (comboCount.value > 1) {
      final gift = activeGift.value;
      final roomId = currentRoomId.value;
      final senderId = currentSenderId.value;
      final senderName = currentSenderName.value;
      final senderImageUrl = currentSenderImageUrl.value;

      if (gift != null && roomId.isNotEmpty) {
        final totalCredits = gift.credits * activeQuantity.value * comboCount.value;
        final displayName = '${gift.name} x${activeQuantity.value * comboCount.value} (Combo)';

        for (final receiver in activeReceivers) {
          EmojiChatService.sendGiftMessage(
            roomId: roomId,
            userId: senderId,
            username: senderName,
            userAvatar: senderImageUrl,
            receiverName: receiver['name'] ?? '',
            giftName: displayName,
            giftImageUrl: gift.pngUrl ?? '',
            giftCredits: totalCredits,
          ).catchError((_) {});
        }
      }
    }

    isComboButtonVisible.value = false;
    comboProgress.value = 0.0;
  }

  @override
  void onClose() {
    _countdownTimer?.cancel();
    _progressTimer?.cancel();
    _bannerTimer?.cancel();
    super.onClose();
  }
}

import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:chat_messenger/services/global_settings_service.dart';
import 'package:chat_messenger/services/referral_service.dart';
import 'package:chat_messenger/services/ads_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

class InviteScreen extends StatefulWidget {
  const InviteScreen({super.key});

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  final ReferralService _referralService = ReferralService();
  final TextEditingController _codeController = TextEditingController();
  
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isAdLoading = false;
  String? _myReferralCode;
  
  // Real-time user from GetX
  User get _currentUser => AuthController.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadReferralCode();
    _loadAd();
  }

  void _loadAd() {
    setState(() => _isAdLoading = true);
    AdsService.instance.loadRewardedAd(
      onAdLoaded: () {
        if (mounted) setState(() => _isAdLoading = false);
      },
      onAdFailed: (error) {
        if (mounted) setState(() => _isAdLoading = false);
        debugPrint('InviteScreen Ad load failed: $error');
      }
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadReferralCode() async {
    try {
      final code = await _referralService.getOrCreateReferralCode(_currentUser.userId);
      if (mounted) {
        setState(() {
          _myReferralCode = code;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading referral code: $e')));
      }
    }
  }

  Future<void> _submitCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a referral code')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _referralService.submitReferralCode(_currentUser.userId, code);
      // Wait for auth controller to sync the update from firestore (it usually happens via stream)
      await Future.delayed(const Duration(seconds: 1));
      
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Referral code submitted successfully! You received a diamond bonus.'),
            backgroundColor: Colors.green,
          )
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          )
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Rebuild when user profile updates (e.g. after successful submission)
      final hasReferred = _currentUser.referredBy != null && _currentUser.referredBy!.isNotEmpty;
      
      int rewardDiamonds = 100;
      if (Get.isRegistered<GlobalSettingsService>()) {
        rewardDiamonds = Get.find<GlobalSettingsService>().invitationRewardDiamonds.value;
      }

      return Scaffold(
        appBar: AppBar(
          title: const Text('Free Diamond'),
          backgroundColor: const Color(0xFF1E142B),
          elevation: 0,
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1E142B), Color(0xFF0F0F1A)],
            )
          ),
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: Colors.purpleAccent))
            : SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Method 1',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2D1F3F),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.3)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.purpleAccent.withValues(alpha: 0.1),
                              blurRadius: 20,
                              spreadRadius: 2,
                            )
                          ]
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text(
                              'Watch a short advertisement video and earn free diamonds instantly! Simply tap the button below to start watching and receive your reward.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                            const SizedBox(height: 20),
                            // Illustration placeholder
                            Icon(Icons.video_library, size: 80, color: Colors.purpleAccent.withValues(alpha: 0.8)),
                            const SizedBox(height: 20),
                            const Text(
                              'Watch Video',
                              style: TextStyle(
                                color: Color(0xFFE87A38),
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '"Get free diamonds"',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'View Advertisement Video & Get Free Diamond And Use It.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _isAdLoading ? null : () async {
                                  if (!AdsService.instance.isAdReady) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ad is not ready yet. Please wait...')));
                                    _loadAd();
                                    return;
                                  }

                                  setState(() => _isAdLoading = true);
                                  await AdsService.instance.showRewardedAd(
                                    onRewardGranted: () {
                                      if (mounted) {
                                        setState(() => _isAdLoading = false);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Success! You earned ${AdsService.instance.adRewardDiamonds} diamonds.'),
                                            backgroundColor: Colors.green,
                                          )
                                        );
                                        _loadAd(); // Preload next ad
                                      }
                                    },
                                    onError: (error) {
                                      if (mounted) {
                                        setState(() => _isAdLoading = false);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text(error), backgroundColor: Colors.red)
                                        );
                                      }
                                    }
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFB122E5),
                                  disabledBackgroundColor: Colors.grey.shade600,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                child: _isAdLoading
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Text(
                                      'Watch Video Now',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold
                                      ),
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                      const Text(
                        'Method 2',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2D1F3F),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.3)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.purpleAccent.withValues(alpha: 0.1),
                              blurRadius: 20,
                              spreadRadius: 2,
                            )
                          ]
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text(
                              'Invite your friends to join using your referral code. Earn rewards every time your code is used!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Refer a Friend',
                              style: TextStyle(
                                color: Color(0xFFE87A38),
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 20),
                            
                            // Illustration placeholder
                            Icon(Icons.card_giftcard, size: 80, color: Colors.purpleAccent.withValues(alpha: 0.8)),
                            
                            const SizedBox(height: 30),
                            
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Your Refer Code:',
                                style: TextStyle(color: Colors.white70, fontSize: 14),
                              ),
                            ),
                            const SizedBox(height: 8),
                            
                            // Code display container
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E142B),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _myReferralCode ?? '------',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 2.0
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.share, color: Colors.white),
                                    onPressed: () {
                                      if (_myReferralCode != null) {
                                        // ignore: deprecated_member_use
                                        Share.share('Join imChat! Use my referral code $_myReferralCode to get $rewardDiamonds diamonds instantly!');
                                      }
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.copy, color: Colors.white),
                                    onPressed: () {
                                      if (_myReferralCode != null) {
                                        Clipboard.setData(ClipboardData(text: _myReferralCode!));
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Referral code copied to clipboard!')));
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 20),
                            
                            Text(
                                'Invite your Friends! for each payout of invited friends, you and your friend both will receive $rewardDiamonds Diamonds',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.5),
                              ),
                            
                            const SizedBox(height: 20),
                            
                            if (!hasReferred) ...[
                              TextField(
                                controller: _codeController,
                                style: const TextStyle(color: Colors.white),
                                textAlign: TextAlign.center,
                                decoration: InputDecoration(
                                  hintText: 'Enter Referral code here',
                                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                                  filled: true,
                                  fillColor: const Color(0xFF1E142B),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(30),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: _isSubmitting ? null : _submitCode,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFB122E5),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                  child: _isSubmitting
                                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                      : const Text(
                                          'Submit',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold
                                          ),
                                        ),
                                ),
                              ),
                            ] else ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(color: Colors.green.withValues(alpha: 0.5))
                                ),
                                child: Column(
                                  children: [
                                    const Icon(Icons.check_circle, color: Colors.green),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Code Applied: ${_currentUser.referredBy}',
                                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                      Center(
                        child: Text(
                          'You have ${_currentUser.referralCount} referrals',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),
        ),
      );
    });
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class AdsService {
  static final AdsService instance = AdsService._internal();
  AdsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? admobAppId;
  String? admobAdUnitId;
  int adRewardDiamonds = 10;
  int maxAdsPerDay = 5;

  RewardedAd? _rewardedAd;
  bool _isAdLoading = false;
  
  bool get isAdReady => _rewardedAd != null;
  bool get isAdLoading => _isAdLoading;

  Future<void> fetchSettings() async {
    try {
      final doc = await _firestore.collection('global_settings').doc('app_settings').get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        admobAppId = data['admobAppId'];
        admobAdUnitId = data['admobAdUnitId'];
        adRewardDiamonds = data['adRewardDiamonds'] ?? 10;
        maxAdsPerDay = data['maxAdsPerDay'] ?? 5;
      }
    } catch (e) {
      debugPrint('AdsService fetchSettings error: $e');
    }
  }

  Future<void> loadRewardedAd({required Function onAdLoaded, required Function(String) onAdFailed}) async {
    if (_isAdLoading) return;

    if (admobAdUnitId == null || admobAdUnitId!.isEmpty) {
      await fetchSettings();
    }

    final adUnitId = kDebugMode
        ? 'ca-app-pub-3940256099942544/5224354917' // Google Test Rewarded Ad Unit ID
        : ((admobAdUnitId != null && admobAdUnitId!.isNotEmpty) 
            ? admobAdUnitId! 
            : 'ca-app-pub-1906373417302947/5399803935'); // User's provided Ad Unit ID

    _isAdLoading = true;
    
    RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('AdsService: Ad loaded.');
          _rewardedAd = ad;
          _isAdLoading = false;
          onAdLoaded();
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('AdsService: RewardedAd failed to load: $error');
          _rewardedAd = null;
          _isAdLoading = false;
          onAdFailed(error.message);
        },
      ),
    );
  }

  Future<bool> canWatchAd() async {
    final user = AuthController.instance.currentUser;
    if (user.userId.isEmpty) return false;

    if (maxAdsPerDay <= 0) {
      return false;
    }

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    final doc = await _firestore
        .collection('Users')
        .doc(user.userId)
        .collection('daily_ad_views')
        .doc(today)
        .get();

    if (doc.exists) {
      int count = doc.data()?['count'] ?? 0;
      return count < maxAdsPerDay;
    }
    return true; 
  }

  Future<void> showRewardedAd({
    required Function onRewardGranted,
    required Function(String) onError,
  }) async {
    if (_rewardedAd == null) {
      onError('Ad is not ready yet. Please wait and try again.');
      return;
    }

    bool canWatch = await canWatchAd();
    if (!canWatch) {
      onError('You have reached your daily limit of $maxAdsPerDay ads.');
      return;
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) => debugPrint('AdsService: ad onAdShowedFullScreenContent.'),
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('AdsService: ad onAdDismissedFullScreenContent.');
        ad.dispose();
        _rewardedAd = null; 
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('AdsService: ad onAdFailedToShowFullScreenContent: $error');
        ad.dispose();
        _rewardedAd = null;
        onError('Failed to show ad: ${error.message}');
      },
    );

    _rewardedAd!.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) async {
        debugPrint('AdsService: User earned reward: ${reward.amount} ${reward.type}');
        
        await _grantReward();
        onRewardGranted();
      }
    );
  }

  Future<void> _grantReward() async {
    try {
      final user = AuthController.instance.currentUser;
      if (user.userId.isEmpty) return;

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
      final dailyDocRef = _firestore
          .collection('Users')
          .doc(user.userId)
          .collection('daily_ad_views')
          .doc(today);

      await dailyDocRef.set({
        'count': FieldValue.increment(1),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final userDocRef = _firestore.collection('Users').doc(user.userId);
      await userDocRef.update({
        'diamonds': FieldValue.increment(adRewardDiamonds),
      });

      final transactionId = const Uuid().v4();
      await _firestore.collection('wallet_transactions').doc(transactionId).set({
        'id': transactionId,
        'userId': user.userId,
        'amount': adRewardDiamonds,
        'type': 'credit',
        'subType': 'ad_reward',
        'title': 'Video Ad Reward',
        'description': 'Earned by watching a rewarded ad.',
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      debugPrint('AdsService: Successfully granted $adRewardDiamonds diamonds.');

    } catch (e) {
      debugPrint('AdsService _grantReward error: $e');
    }
  }
}

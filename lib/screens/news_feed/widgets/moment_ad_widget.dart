import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chat_messenger/services/news_feed_service.dart';

class MomentAdWidget extends StatefulWidget {
  final bool isReels;
  const MomentAdWidget({super.key, this.isReels = false});

  @override
  State<MomentAdWidget> createState() => _MomentAdWidgetState();
}

class _MomentAdWidgetState extends State<MomentAdWidget> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('moment_ads')
          .get();

      if (!doc.exists) return;

      final data = doc.data() ?? {};
      final bool adsEnabled = data['adsEnabled'] ?? true;
      if (!adsEnabled) return;

      final String bannerUnitId = data['bannerUnitId'] ??
          'ca-app-pub-3940256099942544/6300978111'; // Google Test Banner ID

      _bannerAd = BannerAd(
        adUnitId: bannerUnitId,
        size: widget.isReels ? AdSize.mediumRectangle : AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            if (mounted) {
              setState(() {
                _isAdLoaded = true;
              });
            }
          },
          onAdFailedToLoad: (ad, error) {
            debugPrint('⚠️ [MomentAdWidget] Ad failed to load: $error');
            ad.dispose();
          },
        ),
      );

      await _bannerAd?.load();
    } catch (e) {
      debugPrint('⚠️ [MomentAdWidget] Exception loading ad: $e');
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: NewsFeedService.getAdSettingsStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!.data() ?? {};
        final bool adsEnabled = data['adsEnabled'] ?? true;

        if (!adsEnabled) {
          return const SizedBox.shrink();
        }

        if (_isAdLoaded && _bannerAd != null) {
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            alignment: Alignment.center,
            width: _bannerAd!.size.width.toDouble(),
            height: _bannerAd!.size.height.toDouble(),
            child: AdWidget(ad: _bannerAd!),
          );
        }

        // Sponsored Ad Badge Placeholder when Ad is initializing
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E1E2F) : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDarkMode ? Colors.white10 : Colors.grey[300]!,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'AD',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Sponsored Advertisement',
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? Colors.white60 : Colors.grey[600],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

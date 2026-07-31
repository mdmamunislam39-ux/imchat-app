import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../events/event_details_screen.dart';
import '../../../AdminPane/models/banner.dart';
import '../../../AdminPane/services/banner_service.dart';

class BannerCarousel extends StatefulWidget {
  final double? height;

  const BannerCarousel({super.key, this.height = 120.0});

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  final PageController _pageController = PageController();
  final BannerService _bannerService = BannerService();
  int _currentPage = 0;
  Timer? _timer;
  Timer? _pollingTimer;
  List<AudioRoomBanner> _banners = [];
  bool _isLoading = true;
  
  StreamSubscription? _bannersSub1;
  StreamSubscription? _bannersSub2;
  StreamSubscription? _bannersSub3;
  StreamSubscription? _bannersSub4;
  StreamSubscription? _bannersSub5;
  final Map<String, AudioRoomBanner> _bannersMap = {};

  @override
  void initState() {
    super.initState();
    _subscribeToBanners();
    _loadBannersFromService();
    _startPolling();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pollingTimer?.cancel();
    _pageController.dispose();
    _bannersSub1?.cancel();
    _bannersSub2?.cancel();
    _bannersSub3?.cancel();
    _bannersSub4?.cancel();
    _bannersSub5?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        _loadBannersFromService();
      }
    });
  }

  Future<void> _loadBannersFromService() async {
    try {
      final banners = await _bannerService.getAllBanners();
      if (!mounted) return;
      
      // Update our map with the latest retrieved from the service
      for (final banner in banners) {
        _bannersMap[banner.id] = banner;
      }
      
      // Also clean up any that are no longer in the service's returned list (ignoring prefixes)
      final currentIds = banners.map((b) => b.id).toSet();
      _bannersMap.removeWhere((key, banner) {
        String docId = key;
        final prefixes = ['audio_room_banners_', 'audio_room_banner_', 'room_banners_', 'banners_', 'explore_banners_'];
        for (final prefix in prefixes) {
          if (docId.startsWith(prefix)) {
            docId = docId.substring(prefix.length);
            break;
          }
        }
        return !currentIds.contains(docId);
      });

      _updateBannersState();
    } catch (e) {
      debugPrint('⚠️ [BannerCarousel] Error loading from service: $e');
    }
  }

  void _updateBannersState() {
    final mergedBanners = _bannersMap.values.toList();
    final seenIds = <String>{};
    final uniqueBanners = <AudioRoomBanner>[];

    for (final b in mergedBanners) {
      String baseId = b.id;
      final prefixes = ['audio_room_banners_', 'audio_room_banner_', 'room_banners_', 'banners_', 'explore_banners_'];
      for (final prefix in prefixes) {
        if (baseId.startsWith(prefix)) {
          baseId = baseId.substring(prefix.length);
          break;
        }
      }
      
      if (!seenIds.contains(baseId)) {
        seenIds.add(baseId);
        uniqueBanners.add(b);
      }
    }

    // Sort in memory by createdAt descending
    uniqueBanners.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    debugPrint('📡 [BannerCarousel] Loaded ${uniqueBanners.length} deduplicated, merged and sorted banners.');

    setState(() {
      _banners = uniqueBanners;
      _isLoading = false;
    });

    _startAutoSlide();
  }

  void _subscribeToBanners() {
    debugPrint('📡 [BannerCarousel] Subscribing to all possible banner collections...');
    
    final firestore = FirebaseFirestore.instance;

    _bannersSub1 = firestore.collection('audio_room_banners').snapshots().listen(
      (snapshot) => _processSnapshots(snapshot, 'audio_room_banners'),
      onError: (e) {
        debugPrint('❌ [BannerCarousel] Error on audio_room_banners stream: $e');
        _checkLoadingState();
      },
    );

    _bannersSub2 = firestore.collection('audio_room_banner').snapshots().listen(
      (snapshot) => _processSnapshots(snapshot, 'audio_room_banner'),
      onError: (e) {
        debugPrint('❌ [BannerCarousel] Error on audio_room_banner stream: $e');
        _checkLoadingState();
      },
    );

    _bannersSub3 = firestore.collection('room_banners').snapshots().listen(
      (snapshot) => _processSnapshots(snapshot, 'room_banners'),
      onError: (e) {
        debugPrint('❌ [BannerCarousel] Error on room_banners stream: $e');
        _checkLoadingState();
      },
    );

    _bannersSub4 = firestore.collection('banners').snapshots().listen(
      (snapshot) => _processSnapshots(snapshot, 'banners'),
      onError: (e) {
        debugPrint('❌ [BannerCarousel] Error on banners stream: $e');
        _checkLoadingState();
      },
    );

    _bannersSub5 = firestore.collection('explore_banners').snapshots().listen(
      (snapshot) => _processSnapshots(snapshot, 'explore_banners'),
      onError: (e) {
        debugPrint('❌ [BannerCarousel] Error on explore_banners stream: $e');
        _checkLoadingState();
      },
    );

    // Force an immediate one-time server pull to bypass any snapshot lag or offline cache blocks!
    _forceImmediateServerPull();
  }

  void _checkLoadingState() {
    if (mounted && _banners.isEmpty) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _forceImmediateServerPull() async {
    final firestore = FirebaseFirestore.instance;
    final collections = ['audio_room_banners', 'audio_room_banner', 'room_banners', 'banners', 'explore_banners'];

    for (final colName in collections) {
      try {
        final snapshot = await firestore.collection(colName).get(
          const GetOptions(source: Source.serverAndCache),
        );
        if (snapshot.docs.isNotEmpty) {
          debugPrint('⚡ [BannerCarousel] Server pull succeeded for $colName. Found ${snapshot.docs.length} docs.');
          _processSnapshots(snapshot, colName);
        }
      } catch (e) {
        debugPrint('⚠️ [BannerCarousel] Server pull warning for $colName: $e');
        
        try {
          final cacheSnapshot = await firestore.collection(colName).get(
            const GetOptions(source: Source.cache),
          );
          if (cacheSnapshot.docs.isNotEmpty) {
            debugPrint('⚡ [BannerCarousel] Cache fallback pull succeeded for $colName. Found ${cacheSnapshot.docs.length} docs.');
            _processSnapshots(cacheSnapshot, colName);
          }
        } catch (_) {}
      }
    }

    _checkLoadingState();
  }

  void _processSnapshots(QuerySnapshot snapshot, String collectionName) {
    if (!mounted) return;
    
    debugPrint('📡 [BannerCarousel] Received snapshot/get for $collectionName. Document count: ${snapshot.docs.length}');
    
    // Clear out any deleted banners for this specific collection
    final activeIds = snapshot.docs.map((doc) => doc.id).toSet();
    _bannersMap.removeWhere((id, banner) => 
        id.startsWith('${collectionName}_') && 
        !activeIds.contains(id.replaceFirst('${collectionName}_', '')));

    for (final doc in snapshot.docs) {
      try {
        if (doc.exists && doc.data() != null) {
          final banner = AudioRoomBanner.fromFirestore(doc);
          final uniqueId = '${collectionName}_${doc.id}';
          
          _bannersMap[uniqueId] = AudioRoomBanner(
            id: uniqueId,
            imageUrl: banner.imageUrl,
            clickUrl: banner.clickUrl,
            eventId: banner.eventId,
            createdAt: banner.createdAt,
          );
          debugPrint('✅ [BannerCarousel] Parsed from $collectionName: id=${doc.id}, imageUrl=${banner.imageUrl}, eventId=${banner.eventId}, clickUrl=${banner.clickUrl}');
        }
      } catch (docError) {
        debugPrint('❌ [BannerCarousel] Error parsing doc ${doc.id} from $collectionName: $docError');
      }
    }

    final mergedBanners = _bannersMap.values.toList();
    // Sort in memory by createdAt descending
    mergedBanners.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    debugPrint('📡 [BannerCarousel] Loaded ${mergedBanners.length} merged banners before deduplication.');

    _updateBannersState();
  }

  void _startAutoSlide() {
    _timer?.cancel();
    if (_banners.length <= 1) return;

    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted || !_pageController.hasClients) return;
      
      final nextPage = (_currentPage + 1) % _banners.length;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  Future<void> _handleBannerTap(AudioRoomBanner banner) async {
    if (banner.eventId != null && banner.eventId!.trim().isNotEmpty) {
      // Fast instant open — no slow slide animation
      Get.to(
        () => EventDetailsScreen(eventId: banner.eventId!.trim()),
        transition: Transition.fadeIn,
        duration: const Duration(milliseconds: 150),
      );
      return;
    }

    if (banner.clickUrl == null || banner.clickUrl!.isEmpty) return;

    try {
      final uri = Uri.parse(banner.clickUrl!);
      // Direct launch is much more reliable under modern Android/iOS security query limitations
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Error launching banner url: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildSkeletonLoader();
    }

    if (_banners.isEmpty) {
      return _buildDefaultFallbackBanner();
    }

    return Container(
      height: widget.height ?? 120.0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: PageView.builder(
              controller: _pageController,
              physics: const BouncingScrollPhysics(), // Enable smooth manual swipe
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemCount: _banners.length,
              itemBuilder: (context, index) {
                final banner = _banners[index];
                final hasValidUrl = banner.imageUrl.isNotEmpty && banner.imageUrl.startsWith('http');
                return GestureDetector(
                  onTap: () => _handleBannerTap(banner),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (hasValidUrl)
                        CachedNetworkImage(
                          imageUrl: banner.imageUrl.startsWith('http://')
                              ? banner.imageUrl.replaceFirst('http://', 'https://')
                              : banner.imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.black12,
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: Colors.purpleAccent,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) {
                            debugPrint('❌ [BannerCarousel] Error loading network image: $url - Error: $error');
                            return _buildGradientBackgroundPlaceholder();
                          },
                        )
                      else
                        _buildGradientBackgroundPlaceholder(),
                      // Premium subtle bottom shadow overlay
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.5),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // Page indicators
          if (_banners.length > 1)
            Positioned(
              bottom: 10,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _banners.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? Colors.purpleAccent
                          : Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return Container(
      height: widget.height ?? 120.0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: Colors.purpleAccent),
      ),
    );
  }

  Widget _buildGradientBackgroundPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF3E2B5E), Color(0xFF1A1226)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.broken_image, color: Colors.white24, size: 40),
      ),
    );
  }

  Widget _buildDefaultFallbackBanner() {
    return Container(
      height: widget.height ?? 120.0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF3E2B5E), Color(0xFF1A1226)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(
              Icons.stars,
              size: 150,
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'VISION AGENCY',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Thanks for your lovely support',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.card_giftcard, color: Colors.amber, size: 26),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

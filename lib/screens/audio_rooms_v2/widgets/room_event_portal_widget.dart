import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/room_event_portal_model.dart';
import '../../../services/room_event_portal_service.dart';
import '../../../services/event_service.dart';
import '../../events/event_details_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../models/event_model.dart';

class RoomEventPortalWidget extends StatefulWidget {
  const RoomEventPortalWidget({super.key});

  @override
  State<RoomEventPortalWidget> createState() => _RoomEventPortalWidgetState();
}

class _RoomEventPortalWidgetState extends State<RoomEventPortalWidget> {
  final RoomEventPortalService _service = RoomEventPortalService();
  final PageController _pageController = PageController();
  Timer? _timer;
  int _currentPage = 0;
  List<RoomEventPortalModel> _portals = [];
  final Map<String, EventModel> _preloadedEvents = {};

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    if (_portals.length <= 1) return;

    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) return;
      if (_pageController.hasClients) {
        _currentPage++;
        if (_currentPage >= _portals.length) {
          _currentPage = 0;
          _pageController.jumpToPage(0);
        } else {
          _pageController.animateToPage(
            _currentPage,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      }
    });
  }

  Future<void> _preloadEvents(List<RoomEventPortalModel> portals) async {
    final futures = portals.map((portal) async {
      if (portal.eventId != null && portal.eventId!.trim().isNotEmpty) {
        final String cleanEventId = portal.eventId!.trim();
        if (!_preloadedEvents.containsKey(cleanEventId)) {
          final event = await EventService.getEventByEventId(cleanEventId);
          if (event != null) {
            _preloadedEvents[cleanEventId] = event;
          }
        }
      }
    });
    await Future.wait(futures);
  }

  Future<void> _handleTap(RoomEventPortalModel portal) async {
    if (portal.eventId != null && portal.eventId!.trim().isNotEmpty) {
      final String cleanEventId = portal.eventId!.trim();
      final event = _preloadedEvents[cleanEventId];
      
      // Open instantly! If preloaded, use event. If not, use eventId and the screen will load it.
      Get.to(
        () => EventDetailsScreen(event: event, eventId: cleanEventId),
        transition: Transition.noTransition,
      );
      return;
    }

    if (portal.redirectUrl != null && portal.redirectUrl!.isNotEmpty) {
      final uri = Uri.parse(portal.redirectUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<RoomEventPortalModel>>(
      stream: _service.getActivePortals(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final newPortals = snapshot.data!;
        
        // Restart timer if list changes
        if (_portals.length != newPortals.length || 
            _portals.isEmpty || 
            _portals.first.id != newPortals.first.id) {
          _portals = newPortals;
          _preloadEvents(newPortals);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _startTimer();
          });
        }

        return Container(
          width: 75, // Slightly wider as requested
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 75,
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                      _startTimer();
                    },
                    itemCount: _portals.length,
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTap: () => _handleTap(_portals[index]),
                        behavior: HitTestBehavior.opaque,
                        child: CachedNetworkImage(
                          imageUrl: _portals[index].imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.black26,
                            child: const Center(
                              child: SizedBox(
                                width: 15,
                                height: 15,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.black26,
                            child: const Icon(Icons.image, color: Colors.white, size: 20),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              if (_portals.length > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _portals.length,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        width: _currentPage == index ? 6 : 4,
                        height: _currentPage == index ? 6 : 4,
                        decoration: BoxDecoration(
                          color: _currentPage == index ? const Color(0xFFFFD700) : Colors.white.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

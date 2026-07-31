import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../models/event_model.dart';
import '../../../services/event_service.dart';
import '../../events/event_details_screen.dart';

class HomeEventBanner extends StatefulWidget {
  const HomeEventBanner({super.key});

  @override
  State<HomeEventBanner> createState() => _HomeEventBannerState();
}

class _HomeEventBannerState extends State<HomeEventBanner> {
  final PageController _pageController = PageController(viewportFraction: 0.92);
  Timer? _timer;
  int _currentPage = 0;

  void _startTimer(int pageCount) {
    _timer?.cancel();
    if (pageCount > 1) {
      _timer = Timer.periodic(const Duration(seconds: 5), (Timer timer) {
        if (_pageController.hasClients) {
          _currentPage++;
          if (_currentPage >= pageCount) {
            _currentPage = 0;
            _pageController.animateToPage(
              _currentPage,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeIn,
            );
          } else {
            _pageController.animateToPage(
              _currentPage,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeIn,
            );
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<EventModel>>(
      stream: EventService.getActiveEventsStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final events = snapshot.data!;
        _startTimer(events.length);

        return Container(
          height: 120.0,
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (int page) {
              _currentPage = page;
            },
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = events[index];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EventDetailsScreen(event: event),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: event.banner,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: Colors.grey[300]),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[300], 
                        child: const Icon(Icons.event, size: 50, color: Colors.grey)
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

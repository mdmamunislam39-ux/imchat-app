import 'package:flutter/material.dart';

/// Animated notification that slides down from the top
class AnimatedNotification extends StatefulWidget {
  final String message;
  final Color backgroundColor;
  final IconData icon;
  final Duration duration;
  final VoidCallback? onDismiss;

  const AnimatedNotification({
    super.key,
    required this.message,
    this.backgroundColor = Colors.green,
    this.icon = Icons.person_add,
    this.duration = const Duration(seconds: 3),
    this.onDismiss,
  });

  @override
  State<AnimatedNotification> createState() => _AnimatedNotificationState();
}

class _AnimatedNotificationState extends State<AnimatedNotification>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));

    // Start animations
    _slideController.forward();
    _fadeController.forward();

    // Auto dismiss after duration
    Future.delayed(widget.duration, () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  void _dismiss() {
    _fadeController.reverse().then((_) {
      if (mounted) {
        widget.onDismiss?.call();
      }
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_slideAnimation, _fadeAnimation]),
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Container(
              width: double.infinity, // Full width background
              margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: widget.backgroundColor.withValues(alpha: 0.95),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center, // Center content
                children: [
                  // Small dot indicator
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // Small icon
                  Icon(
                    widget.icon,
                    color: Colors.white,
                    size: 14,
                  ),
                  
                  const SizedBox(width: 6),
                  
                  // Message text
                  Text(
                    widget.message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.none, // Remove underline
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  // Small dismiss button
                  GestureDetector(
                    onTap: _dismiss,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        Icons.close,
                        color: Colors.white70,
                        size: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Notification manager to show animated notifications
class NotificationManager {
  static OverlayEntry? _currentNotification;
  
  static void show({
    required BuildContext context,
    required String message,
    Color backgroundColor = Colors.green,
    IconData icon = Icons.person_add,
    Duration duration = const Duration(seconds: 3),
  }) {
    // Remove existing notification if any
    dismiss();
    
    _currentNotification = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 80, // Position above message list
        left: 0,
        right: 0,
        child: AnimatedNotification(
          message: message,
          backgroundColor: backgroundColor,
          icon: icon,
          duration: duration,
          onDismiss: dismiss,
        ),
      ),
    );
    
    Overlay.of(context).insert(_currentNotification!);
  }
  
  static void dismiss() {
    _currentNotification?.remove();
    _currentNotification = null;
  }
}

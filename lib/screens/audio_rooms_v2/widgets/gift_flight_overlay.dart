import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Representation of an active flying gift item
class FlyingGiftItem {
  final String id;
  final String pngUrl;
  final Offset startOffset;
  final Offset endOffset;

  FlyingGiftItem({
    required this.id,
    required this.pngUrl,
    required this.startOffset,
    required this.endOffset,
  });
}

/// A hardware-accelerated widget that animates a PNG gift thumbnail 
/// from the center of the screen to a receiver's seat avatar.
class FlyingGiftWidget extends StatefulWidget {
  final String pngUrl;
  final Offset startOffset;
  final Offset endOffset;
  final VoidCallback onComplete;

  const FlyingGiftWidget({
    super.key,
    required this.pngUrl,
    required this.startOffset,
    required this.endOffset,
    required this.onComplete,
  });

  @override
  State<FlyingGiftWidget> createState() => _FlyingGiftWidgetState();
}

class _FlyingGiftWidgetState extends State<FlyingGiftWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    // Smooth 1.2 second flight duration
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Smooth cubic ease-in-out path
    _progressAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );

    // Starts at 0.2 scale, pops out to 1.3 scale, then shrinks as it hits the target avatar
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.2, end: 1.3).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.3, end: 1.0),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeInBack)),
        weight: 30,
      ),
    ]).animate(_controller);

    // Fades in quickly, stays fully opaque, and fades out as it lands
    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.0),
        weight: 65,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0),
        weight: 20,
      ),
    ]).animate(_controller);

    _controller.forward().then((_) {
      widget.onComplete();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Interpolate current path positions
        final double x = widget.startOffset.dx +
            (widget.endOffset.dx - widget.startOffset.dx) * _progressAnimation.value;
        final double y = widget.startOffset.dy +
            (widget.endOffset.dy - widget.startOffset.dy) * _progressAnimation.value;

        const double imageSize = 56.0;

        return Positioned(
          left: x - imageSize / 2,
          top: y - imageSize / 2,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: SizedBox(
                width: imageSize,
                height: imageSize,
                child: CachedNetworkImage(
                  imageUrl: widget.pngUrl,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const SizedBox.shrink(),
                  errorWidget: (context, url, error) => const Icon(
                    Icons.card_giftcard,
                    color: Colors.amber,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

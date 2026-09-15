import 'package:flutter/material.dart';
import 'package:chat_messenger/models/news_feed_post.dart';

class FbReactionPickerOverlay extends StatefulWidget {
  final Offset position;
  final Function(ReactionType) onReactionSelected;
  final VoidCallback onDismiss;

  const FbReactionPickerOverlay({
    super.key,
    required this.position,
    required this.onReactionSelected,
    required this.onDismiss,
  });

  static void show(
    BuildContext context, {
    required GlobalKey targetKey,
    required Function(ReactionType) onReactionSelected,
  }) {
    final RenderBox? renderBox =
        targetKey.currentContext?.findRenderObject() as RenderBox?;
    Offset position = const Offset(50, 300);
    if (renderBox != null) {
      final targetOffset = renderBox.localToGlobal(Offset.zero);
      position = Offset(
        targetOffset.dx.clamp(20.0, MediaQuery.of(context).size.width - 280),
        targetOffset.dy - 60.0,
      );
    } else {
      final size = MediaQuery.of(context).size;
      position = Offset(size.width / 2 - 130, size.height / 2 - 40);
    }

    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          GestureDetector(
            onTap: () {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (overlayEntry.mounted) {
                  overlayEntry.remove();
                }
              });
            },
            behavior: HitTestBehavior.translucent,
            child: const SizedBox.expand(),
          ),
          Positioned(
            left: position.dx,
            top: position.dy,
            child: Material(
              color: Colors.transparent,
              child: FbReactionPickerOverlay(
                position: position,
                onReactionSelected: (reaction) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (overlayEntry.mounted) {
                      overlayEntry.remove();
                    }
                  });
                  onReactionSelected(reaction);
                },
                onDismiss: () {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (overlayEntry.mounted) {
                      overlayEntry.remove();
                    }
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );

    final overlayState =
        Overlay.maybeOf(context, rootOverlay: true) ?? Overlay.of(context);
    overlayState.insert(overlayEntry);
  }

  @override
  State<FbReactionPickerOverlay> createState() => _FbReactionPickerOverlayState();
}

class _FbReactionPickerOverlayState extends State<FbReactionPickerOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  final ValueNotifier<int?> _hoveredNotifier = ValueNotifier<int?>(null);

  final List<ReactionType> _reactions = ReactionType.values;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _hoveredNotifier.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return ScaleTransition(
      scale: _scaleAnimation,
      alignment: Alignment.bottomLeft,
      child: ValueListenableBuilder<int?>(
        valueListenable: _hoveredNotifier,
        builder: (context, hoveredIndex, child) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hovered Reaction Label Tooltip
              if (hoveredIndex != null)
                Container(
                  margin: EdgeInsets.only(
                    left: 12 + (hoveredIndex * 38.0),
                    bottom: 6,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _reactions[hoveredIndex].label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else
                const SizedBox(height: 25),

              // Animated Reaction Icons Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? const Color(0xFF1E142B).withValues(alpha: 0.95)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 15,
                      spreadRadius: 2,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.15)
                        : Colors.grey.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(_reactions.length, (index) {
                    final reaction = _reactions[index];
                    final isHovered = hoveredIndex == index;

                    return GestureDetector(
                      onTapDown: (_) => _hoveredNotifier.value = index,
                      onTapUp: (_) {
                        final selectedReaction = reaction;
                        widget.onReactionSelected(selectedReaction);
                      },
                      onTapCancel: () => _hoveredNotifier.value = null,
                      child: MouseRegion(
                        onEnter: (_) => _hoveredNotifier.value = index,
                        onExit: (_) => _hoveredNotifier.value = null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          curve: Curves.easeOut,
                          transform: Matrix4.identity()
                            ..scale(isHovered ? 1.45 : 1.0)
                            ..translate(0.0, isHovered ? -8.0 : 0.0),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: _buildPickerReactionWidget(reaction),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPickerReactionWidget(ReactionType reaction) {
    if (reaction == ReactionType.like) {
      return Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: Color(0xFF1877F2),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.thumb_up_rounded, color: Colors.white, size: 18),
      );
    }
    if (reaction == ReactionType.love) {
      return Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: Color(0xFFE41E3F),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.favorite, color: Colors.white, size: 18),
      );
    }
    return Text(
      reaction.emoji,
      style: const TextStyle(fontSize: 28),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:chat_messenger/controllers/follow_controller.dart';

/// Clean follow button widget with proper state management
class FollowButton extends StatefulWidget {
  final String currentUserId;
  final String targetUserId;
  final String targetUserName;
  final FollowController followController;
  final VoidCallback? onFollowChanged;
  final bool? initialFollowStatus;
  final Color? textColor;
  final Color? borderColor;
  final Color? backgroundColor;
  final double? fontSize;
  final double? iconSize;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;

  const FollowButton({
    super.key,
    required this.currentUserId,
    required this.targetUserId,
    required this.targetUserName,
    required this.followController,
    this.onFollowChanged,
    this.initialFollowStatus,
    this.textColor,
    this.borderColor,
    this.backgroundColor,
    this.fontSize,
    this.iconSize,
    this.padding,
    this.borderRadius,
  });

  @override
  State<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<FollowButton> {
  @override
  void initState() {
    super.initState();
    
    // If initial follow status is provided, set it immediately
    if (widget.initialFollowStatus != null) {
      // Set the initial status in the controller
      widget.followController.setInitialFollowStatus(
        widget.targetUserId, 
        widget.initialFollowStatus!
      );
    }
    // Note: Follow status is loaded by the parent FutureBuilder, so we don't load it here
  }

  Future<void> _handleFollowToggle() async {
    try {
      // Check if we can toggle (spam protection)
      if (!widget.followController.canToggle(widget.targetUserId)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please wait a moment before toggling again'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      final result = await widget.followController.toggleFollow(
        currentUserId: widget.currentUserId,
        targetUserId: widget.targetUserId,
      );

      if (mounted) {
        if (!result.isSuccess) {
          // Show error message if toggle failed
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message.isNotEmpty ? result.message : 'Failed to update follow status'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          // Success - notify parent if callback provided
          widget.onFollowChanged?.call();
        }
      }
    } catch (e) {
      debugPrint('❌ FollowButton: Error toggling follow: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An unexpected error occurred: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.followController,
      builder: (context, child) {
        final isFollowing = widget.followController.isFollowing(widget.targetUserId);
        final isLoading = widget.followController.isLoading(widget.targetUserId);

        debugPrint('🔍 [FollowButton] Building for ${widget.targetUserId}: isFollowing=$isFollowing, isLoading=$isLoading');

        final btnColor = widget.textColor ?? Colors.white;
        final borderCol = widget.borderColor ?? Colors.white.withValues(alpha: 0.3);

        return OutlinedButton.icon(
          onPressed: _handleFollowToggle,
          icon: Icon(
            isFollowing ? Icons.person_remove : Icons.person_add,
            color: btnColor,
            size: widget.iconSize ?? 18,
          ),
          label: Text(
            isFollowing ? 'Following' : 'Follow',
            style: TextStyle(
              color: btnColor,
              fontSize: widget.fontSize,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          style: OutlinedButton.styleFrom(
            backgroundColor: widget.backgroundColor,
            side: BorderSide(color: borderCol),
            padding: widget.padding ?? const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
            ),
          ),
        );
      },
    );
  }
}

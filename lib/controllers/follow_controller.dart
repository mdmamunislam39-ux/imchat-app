import 'package:flutter/material.dart';
import 'package:chat_messenger/services/follow_service.dart';

/// Clean follow controller to manage follow state
class FollowController extends ChangeNotifier {
  final Map<String, bool> _followStatus = {};
  final Map<String, int> _followerCounts = {};
  final Map<String, bool> _loadingStates = {};
  final Map<String, DateTime> _lastToggleTimes = {};
  
  // Spam protection: minimum time between toggles (in milliseconds)
  static const int _minToggleInterval = 1000; // 1 second

  // Getters
  bool isFollowing(String userId) => _followStatus[userId] ?? false;
  int getFollowerCount(String userId) => _followerCounts[userId] ?? 0;
  bool isLoading(String userId) => _loadingStates[userId] ?? false;
  
  /// Check if enough time has passed since last toggle (spam protection)
  bool canToggle(String userId) {
    final lastToggle = _lastToggleTimes[userId];
    if (lastToggle == null) return true;
    
    final now = DateTime.now();
    final timeDiff = now.difference(lastToggle).inMilliseconds;
    return timeDiff >= _minToggleInterval;
  }

  /// Set initial follow status (for immediate UI updates)
  void setInitialFollowStatus(String userId, bool isFollowing) {
    _followStatus[userId] = isFollowing;
    notifyListeners();
  }

  /// Force load follow status from server (ignores cache)
  Future<void> loadFollowStatusFromServer({
    required String currentUserId,
    required String targetUserId,
  }) async {
    try {
      _loadingStates[targetUserId] = true;
      notifyListeners();

      final result = await FollowService.isFollowing(
        currentUserId: currentUserId,
        targetUserId: targetUserId,
      );

      debugPrint('🔍 [FollowController] Server response: ${result.data}');
      debugPrint('🔍 [FollowController] Is success: ${result.isSuccess}');
      debugPrint('🔍 [FollowController] Message: ${result.message}');

      if (result.isSuccess) {
        final isFollowing = result.data == 'true';
        _followStatus[targetUserId] = isFollowing;
        debugPrint('🔍 [FollowController] Set follow status for $targetUserId: $isFollowing');
      } else {
        debugPrint('❌ Error loading follow status from server: ${result.message}');
        _followStatus[targetUserId] = false;
      }

      // Load follower count
      final countResult = await FollowService.getFollowerCount(targetUserId);
      if (countResult.isSuccess) {
        _followerCounts[targetUserId] = int.tryParse(countResult.data ?? '0') ?? 0;
      }
    } catch (e) {
      debugPrint('❌ Exception loading follow status from server: $e');
      _followStatus[targetUserId] = false;
    } finally {
      _loadingStates[targetUserId] = false;
      notifyListeners();
    }
  }

  /// Load follow status for a user
  Future<void> loadFollowStatus({
    required String currentUserId,
    required String targetUserId,
  }) async {
    // Don't reload if already loaded and not loading
    if (_followStatus.containsKey(targetUserId) && !_loadingStates[targetUserId]!) {
      return;
    }

    try {
      _loadingStates[targetUserId] = true;
      notifyListeners();

      final result = await FollowService.isFollowing(
        currentUserId: currentUserId,
        targetUserId: targetUserId,
      );

      if (result.isSuccess) {
        _followStatus[targetUserId] = result.data == 'true';
      } else {
        debugPrint('❌ Error loading follow status: ${result.message}');
        _followStatus[targetUserId] = false;
      }

      // Load follower count
      final countResult = await FollowService.getFollowerCount(targetUserId);
      if (countResult.isSuccess) {
        _followerCounts[targetUserId] = int.tryParse(countResult.data ?? '0') ?? 0;
      }
    } catch (e) {
      debugPrint('❌ Exception loading follow status: $e');
      _followStatus[targetUserId] = false;
    } finally {
      _loadingStates[targetUserId] = false;
      notifyListeners();
    }
  }

  /// Toggle follow status with instant UI updates and spam protection
  Future<FollowResult> toggleFollow({
    required String currentUserId,
    required String targetUserId,
  }) async {
    try {
      // Spam protection: check if enough time has passed
      if (!canToggle(targetUserId)) {
        final lastToggle = _lastToggleTimes[targetUserId];
        final timeLeft = _minToggleInterval - DateTime.now().difference(lastToggle!).inMilliseconds;
        return FollowResult.error('Please wait ${(timeLeft / 1000).ceil()} seconds before toggling again');
      }

      // Check if already loading
      if (_loadingStates[targetUserId] == true) {
        return FollowResult.error('Operation already in progress');
      }

      final isCurrentlyFollowing = _followStatus[targetUserId] ?? false;
      
      // INSTANT UI UPDATE - Update UI immediately without loading state
      _followStatus[targetUserId] = !isCurrentlyFollowing;
      _lastToggleTimes[targetUserId] = DateTime.now();
      if (!isCurrentlyFollowing) {
        _followerCounts[targetUserId] = (_followerCounts[targetUserId] ?? 0) + 1;
      } else {
        _followerCounts[targetUserId] = (_followerCounts[targetUserId] ?? 0) - 1;
      }
      notifyListeners();

      // Perform the actual operation in background (no loading state)
      FollowResult result;
      if (isCurrentlyFollowing) {
        result = await FollowService.unfollowUser(
          currentUserId: currentUserId,
          targetUserId: targetUserId,
        );
      } else {
        result = await FollowService.followUser(
          currentUserId: currentUserId,
          targetUserId: targetUserId,
        );
      }

      // If operation failed, revert the optimistic update
      if (!result.isSuccess) {
        _followStatus[targetUserId] = isCurrentlyFollowing;
        if (isCurrentlyFollowing) {
          _followerCounts[targetUserId] = (_followerCounts[targetUserId] ?? 0) + 1;
        } else {
          _followerCounts[targetUserId] = (_followerCounts[targetUserId] ?? 0) - 1;
        }
        notifyListeners();
      }

      return result;
    } catch (e) {
      debugPrint('❌ Exception in toggleFollow: $e');
      
      // Revert optimistic update on error
      final isCurrentlyFollowing = _followStatus[targetUserId] ?? false;
      _followStatus[targetUserId] = !isCurrentlyFollowing;
      if (isCurrentlyFollowing) {
        _followerCounts[targetUserId] = (_followerCounts[targetUserId] ?? 0) + 1;
      } else {
        _followerCounts[targetUserId] = (_followerCounts[targetUserId] ?? 0) - 1;
      }
      notifyListeners();
      
      return FollowResult.error('An unexpected error occurred: $e');
    }
  }

  /// Clear follow status for a specific user
  void clearFollowStatus(String userId) {
    _followStatus.remove(userId);
    _followerCounts.remove(userId);
    _loadingStates.remove(userId);
    _lastToggleTimes.remove(userId);
    notifyListeners();
  }

  /// Clear all data
  void clear() {
    _followStatus.clear();
    _followerCounts.clear();
    _loadingStates.clear();
    _lastToggleTimes.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    clear();
    super.dispose();
  }
}

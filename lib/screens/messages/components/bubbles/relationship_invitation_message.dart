import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/models/message.dart';
import 'package:chat_messenger/services/relationship_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class RelationshipInvitationMessage extends StatefulWidget {
  final Message message;
  final bool isGroup;

  const RelationshipInvitationMessage({
    super.key,
    required this.message,
    this.isGroup = false,
  });

  @override
  State<RelationshipInvitationMessage> createState() => _RelationshipInvitationMessageState();
}

class _RelationshipInvitationMessageState extends State<RelationshipInvitationMessage> {
  bool _isProcessing = false;
  bool _alreadyResponded = false;
  bool _isExpired = false;
  String _status = 'pending';
  StreamSubscription<DocumentSnapshot>? _invitationSub;

  final _relationshipService = RelationshipService();

  @override
  void initState() {
    super.initState();
    _listenToInvitation();
  }

  @override
  void dispose() {
    _invitationSub?.cancel();
    super.dispose();
  }

  void _listenToInvitation() {
    final invitationId = widget.message.invitationId;
    if (invitationId == null || invitationId.isEmpty) return;

    _invitationSub = FirebaseFirestore.instance
        .collection('relationshipInvitations')
        .doc(invitationId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        final data = snapshot.data();
        if (data != null) {
          final status = data['status'] ?? 'pending';
          final expiresAt = data['expiresAt'] as Timestamp?;
          
          bool expired = false;
          if (expiresAt != null && DateTime.now().isAfter(expiresAt.toDate())) {
            expired = true;
          }
          
          if (mounted) {
            setState(() {
              _status = status;
              _alreadyResponded = status != 'pending';
              _isExpired = expired && status == 'pending';
            });
          }
        }
      }
    });
  }

  Future<void> _accept() async {
    final invitationId = widget.message.invitationId;
    if (invitationId == null || invitationId.isEmpty) return;

    if (mounted) setState(() => _isProcessing = true);
    try {
      final userId = AuthController.instance.currentUser.userId;
      await _relationshipService.acceptInvitation(invitationId, userId);
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _status = 'accepted';
          _alreadyResponded = true;
        });
      }
      Get.snackbar(
        '🎉 Congratulations!',
        'Relationship request accepted!',
        backgroundColor: Colors.green.shade700,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      if (mounted) setState(() => _isProcessing = false);
      Get.snackbar(
        'Error',
        'Failed to accept invitation: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _decline() async {
    final invitationId = widget.message.invitationId;
    if (invitationId == null || invitationId.isEmpty) return;

    if (mounted) setState(() => _isProcessing = true);
    try {
      await _relationshipService.rejectInvitation(invitationId);
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _status = 'rejected';
          _alreadyResponded = true;
        });
      }
      Get.snackbar(
        'Declined',
        'You have declined the request.',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      if (mounted) setState(() => _isProcessing = false);
      Get.snackbar(
        'Error',
        'Failed to decline invitation: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final senderName = widget.message.invitationAgencyName ?? 'User';
    final relationshipType = widget.message.invitationAgencyId ?? 'friend';
    final isCouple = relationshipType.toLowerCase() == 'couple';
    final double screenWidth = MediaQuery.of(context).size.width;
    final isSender = widget.message.isSender;

    // Gradient matching relationship type
    final gradientColors = isCouple
        ? [const Color(0xFFEC407A), const Color(0xFFAB47BC)] // Couple: Pink gradient
        : [const Color(0xFF2196F3), const Color(0xFF00BCD4)]; // Friend: Cyan-Blue gradient

    return Container(
      width: screenWidth * 0.75,
      constraints: const BoxConstraints(maxWidth: 310),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(!isSender ? 2 : 18),
          topRight: const Radius.circular(18),
          bottomLeft: const Radius.circular(18),
          bottomRight: Radius.circular(!isSender ? 18 : 2),
        ),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Banner Title
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCouple ? Icons.favorite : Icons.people_alt,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isCouple ? 'Couple Invitation' : 'Friend Invitation',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'imChat Intimacy',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 12),

          // Message Body Greeting
          Text(
            isCouple
                ? 'হাই! $senderName আপনাকে Couple পার্টনার হওয়ার আহ্বান জানিয়েছেন!'
                : 'হাই! আপনি কি আমার বন্ধু হতে চান?',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isCouple
                ? 'Accept to create an intimate CP relationship and earn intimacy rewards together.'
                : 'Accept to build an intimate Friendship relationship together.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12,
              height: 1.3,
            ),
          ),

          const SizedBox(height: 14),

          // Action Buttons / Status display
          if (_isExpired)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Invitation Expired',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else if (_status == 'accepted')
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.green.shade800.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white38, width: 1),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Text(
                    '✓ Accepted',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )
          else if (_status == 'rejected')
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.orange.shade800.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cancel, color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Text(
                    '✕ Declined',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )
          else if (_alreadyResponded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Invitation Responded',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else if (!isSender) ...[
            // Accept Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _accept,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: gradientColors[0],
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: _isProcessing
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: gradientColors[0],
                        ),
                      )
                    : const Text(
                        '✓ Accept Request',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            // Decline Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _isProcessing ? null : _decline,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white70, width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                ),
                child: const Text(
                  'Decline',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ] else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Pending Response',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

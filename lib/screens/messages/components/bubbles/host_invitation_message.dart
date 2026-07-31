import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/helpers/date_helper.dart';
import 'package:chat_messenger/models/message.dart';
import 'package:chat_messenger/services/agency_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class HostInvitationMessage extends StatefulWidget {
  final Message message;
  final bool isGroup;

  const HostInvitationMessage({
    super.key,
    required this.message,
    this.isGroup = false,
  });

  @override
  State<HostInvitationMessage> createState() => _HostInvitationMessageState();
}

class _HostInvitationMessageState extends State<HostInvitationMessage> {
  bool _isProcessing = false;
  bool _alreadyResponded = false;
  StreamSubscription<DocumentSnapshot>? _invitationSub;

  final _agencyService = AgencyService();

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
        .collection('host_invitations')
        .doc(invitationId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        final data = snapshot.data();
        if (data != null) {
          final status = data['status'] ?? 'pending';
          if (status != 'pending') {
            if (mounted) {
              setState(() {
                _alreadyResponded = true;
              });
            }
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
      await _agencyService.acceptInvitation(invitationId, userId);
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _alreadyResponded = true;
        });
      }
      Get.snackbar(
        '🎉 Congratulations!',
        'You are now an official Host!',
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
      await _agencyService.rejectInvitation(invitationId);
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _alreadyResponded = true;
        });
      }
      Get.snackbar(
        'Invitation Declined',
        'You have declined the invitation.',
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
    final agencyName = widget.message.invitationAgencyName ?? 'an Agency';
    final double screenWidth = MediaQuery.of(context).size.width;
    final isSender = widget.message.isSender;

    return Container(
      width: screenWidth * 0.72,
      constraints: const BoxConstraints(maxWidth: 300),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF283593)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(!isSender ? 2 : 16),
          topRight: const Radius.circular(16),
          bottomLeft: const Radius.circular(16),
          bottomRight: Radius.circular(!isSender ? 16 : 2),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A237E).withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.amber.shade700,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.business_center_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'imChat Team',
                      style: TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const Text(
                      'Agency Invitation',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
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
            color: Colors.white.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 12),

          // Invitation message body
          const Text(
            'You have been invited to become a Host!',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            agencyName,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'has invited you to join their agency as an official Host.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 14),

          // Action buttons
          if (_alreadyResponded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Invitation Responded',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else if (!isSender) ...[
            // Accept button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _accept,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade700,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        '✓ Accept & Become Host',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            // Decline button
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _isProcessing ? null : _decline,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white54,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                ),
                child: const Text(
                  'Decline',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
          ] else ...[
            // Sender view
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Invitation Sent',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],

          const SizedBox(height: 8),
          // Timestamp
          Align(
            alignment: Alignment.bottomRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Opacity(
                  opacity: 0.6,
                  child: Text(
                    widget.message.isDeleted
                        ? widget.message.updatedAt?.formatMsgTime ?? ''
                        : widget.message.sentAt?.formatMsgTime ?? '',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (isSender && !widget.isGroup) ...[
                  const SizedBox(width: 4),
                  Icon(
                    widget.message.sentAt == null
                        ? Icons.access_time_rounded
                        : (widget.message.isRead ? Icons.done_all : Icons.done),
                    size: 13,
                    color: Colors.white60,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

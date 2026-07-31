import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../api/official_team_api.dart';

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() => _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _userIdController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  
  String _targetType = 'broadcast'; // 'broadcast' or 'specific'
  bool _isSubmitting = false;

  @override
  void dispose() {
    _messageController.dispose();
    _userIdController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  void _insertPlaceholder(String placeholder) {
    final text = _messageController.text;
    final selection = _messageController.selection;
    
    int start = selection.start;
    int end = selection.end;
    
    // If no active selection cursor, append to the end
    if (start < 0 || end < 0) {
      start = text.length;
      end = text.length;
    }

    final newText = text.replaceRange(start, end, placeholder);
    _messageController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + placeholder.length),
    );
    
    _messageFocusNode.requestFocus();
  }

  Future<void> _sendNotification() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      _showSnackBar('Please write a message to post.', isError: true);
      return;
    }

    if (_targetType == 'specific' && _userIdController.text.trim().isEmpty) {
      _showSnackBar('Please specify a target User ID.', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      if (_targetType == 'broadcast') {
        // Send global broadcast to all users
        await OfficialTeamApi.broadcastOfficialMessage(message);
        _showSnackBar('📢 Notification broadcasted to all users successfully!');
      } else {
        // Send specific message to targeted User ID
        final targetUserId = _userIdController.text.trim();
        
        // Lookup target user document to fetch device token
        final userDoc = await FirebaseFirestore.instance.collection('Users').doc(targetUserId).get();
        if (!userDoc.exists) {
          _showSnackBar('❌ User ID not found in database.', isError: true);
          setState(() => _isSubmitting = false);
          return;
        }
        
        final data = userDoc.data() as Map<String, dynamic>;
        final deviceToken = data['deviceToken'] ?? '';
        
        await OfficialTeamApi.sendOfficialMessage(
          receiverId: targetUserId,
          receiverDeviceToken: deviceToken,
          messageText: message,
        );
        _showSnackBar('✅ Notification sent to user successfully!');
      }

      _messageController.clear();
      _userIdController.clear();
    } catch (e) {
      _showSnackBar('❌ Failed to post notification: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF120C1C),
      appBar: AppBar(
        title: const Text(
          'imChat Official Notification Desk',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1E142B),
        elevation: 0,
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Left side - Composition & Controls
          Expanded(
            flex: 6,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title Block
                  const Text(
                    'Compose Official Notification',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Draft messages to publish on the "imChat Team" channel.',
                    style: TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                  const SizedBox(height: 24),

                  // Target selection
                  Row(
                    children: [
                      Expanded(
                        child: _buildTargetSelectorCard(
                          title: 'Broadcast to All',
                          subtitle: 'Sends notification globally to everyone.',
                          icon: Icons.campaign,
                          isSelected: _targetType == 'broadcast',
                          onTap: () => setState(() => _targetType = 'broadcast'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTargetSelectorCard(
                          title: 'Specific User ID',
                          subtitle: 'Direct notification to one selected user.',
                          icon: Icons.person_search,
                          isSelected: _targetType == 'specific',
                          onTap: () => setState(() => _targetType = 'specific'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Specific User ID text field
                  if (_targetType == 'specific') ...[
                    TextField(
                      controller: _userIdController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Recipient User ID',
                        labelStyle: const TextStyle(color: Colors.white38),
                        hintText: 'Enter specific firebase User ID',
                        hintStyle: const TextStyle(color: Colors.white24),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.03),
                        prefixIcon: const Icon(Icons.badge, color: Colors.purpleAccent),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.purpleAccent.withValues(alpha: 0.2)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.purpleAccent),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Placeholder Quick Injector Chips
                  const Text(
                    'Interactive Placeholder Shortcuts',
                    style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildPlaceholderChip('[UserName]', 'Inject recipient name'),
                      _buildPlaceholderChip('[Amount]', 'Inject diamond values'),
                      _buildPlaceholderChip('[BadgeName]', 'Inject badge names'),
                      _buildPlaceholderChip('[RewardName]', 'Inject store gift names'),
                      _buildPlaceholderChip('[RoomLink]', 'Inject direct voice room url'),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Text area composition box
                  TextField(
                    controller: _messageController,
                    focusNode: _messageFocusNode,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 5,
                    keyboardType: TextInputType.multiline,
                    decoration: InputDecoration(
                      labelText: 'Write Announcement Content',
                      labelStyle: const TextStyle(color: Colors.white38),
                      hintText: 'Type announcement text... emojis and custom placeholders are supported!',
                      hintStyle: const TextStyle(color: Colors.white24),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.03),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.purpleAccent.withValues(alpha: 0.2)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.purpleAccent),
                      ),
                    ),
                    onChanged: (_) => setState(() {}), // Trigger preview card update
                  ),
                  const SizedBox(height: 24),

                  // Send button
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _sendNotification,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purpleAccent,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.purpleAccent.withValues(alpha: 0.3),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : Text(
                            _targetType == 'broadcast' ? 'Broadcast Message Now' : 'Send Direct Message',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ],
              ),
            ),
          ),

          // Divider line
          Container(width: 1, color: Colors.purpleAccent.withValues(alpha: 0.1)),

          // 2. Right side - Real-Time Preview & Historical Logs
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Section 1: Real-time visual preview card
                  const Text(
                    'Live Channel Card Preview',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildLivePreviewCard(),
                  const SizedBox(height: 32),

                  // Section 2: Audit Logs
                  const Row(
                    children: [
                      Icon(Icons.history, color: Colors.purpleAccent, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Notification Desk Audit Logs',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _buildAuditLogStream(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetSelectorCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2E1A47) : const Color(0xFF1E142B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.purpleAccent : Colors.purpleAccent.withValues(alpha: 0.1),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.purpleAccent : Colors.white54, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderChip(String placeholder, String tooltip) {
    return ActionChip(
      label: Text(
        placeholder,
        style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold, fontSize: 12),
      ),
      backgroundColor: Colors.purpleAccent.withValues(alpha: 0.1),
      side: BorderSide(color: Colors.purpleAccent.withValues(alpha: 0.3)),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      onPressed: () => _insertPlaceholder(placeholder),
      tooltip: tooltip,
    );
  }

  Widget _buildLivePreviewCard() {
    final writtenText = _messageController.text;
    final messagePreviewText = writtenText.isEmpty
        ? 'Compose a message on the left to see its preview.'
        : writtenText;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E142B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mega icon channel avatar
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFFE91E63), Color(0xFF9C27B0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(Icons.campaign, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header details
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Text(
                          'imChat Team',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.verified, color: Colors.blue, size: 16),
                      ],
                    ),
                    const Text(
                      'Just Now',
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Message content preview
                Text(
                  messagePreviewText,
                  style: TextStyle(
                    color: writtenText.isEmpty ? Colors.white24 : Colors.white70,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditLogStream() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('official_notification_logs')
          .orderBy('sentAt', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.purpleAccent));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'No notification logs recorded yet.',
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
          );
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index].data() as Map<String, dynamic>;
            final receiverId = doc['receiverId'] ?? 'Broadcast';
            final textMsg = doc['textMsg'] ?? '';
            final sentAt = doc['sentAt'] is Timestamp
                ? (doc['sentAt'] as Timestamp).toDate()
                : DateTime.now();

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1224),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: receiverId == 'Broadcast' || receiverId.isEmpty
                              ? Colors.cyan.withValues(alpha: 0.1)
                              : Colors.purpleAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          receiverId == 'Broadcast' || receiverId.isEmpty
                              ? '🌎 BROADCAST'
                              : '👤 Recipient: $receiverId',
                          style: TextStyle(
                            color: receiverId == 'Broadcast' || receiverId.isEmpty
                                ? Colors.cyanAccent
                                : Colors.purpleAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        sentAt.toLocal().toString().split('.')[0],
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    textMsg,
                    style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

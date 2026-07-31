import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class LiveEndedSummaryScreen extends StatelessWidget {
  final int durationMinutes;
  final int totalUsers;
  final int totalDiamonds;
  final int totalGifts;
  final String hostName;
  final String? hostAvatar;

  const LiveEndedSummaryScreen({
    super.key,
    required this.durationMinutes,
    required this.totalUsers,
    required this.totalDiamonds,
    required this.totalGifts,
    required this.hostName,
    this.hostAvatar,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E), // Dark theme
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),
            
            // "Live Ended" Title
            const Text(
              'Live Ended',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Host Avatar
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.amber, width: 3),
                image: (hostAvatar != null && hostAvatar!.isNotEmpty)
                    ? DecorationImage(
                        image: CachedNetworkImageProvider(hostAvatar!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: (hostAvatar == null || hostAvatar!.isEmpty)
                  ? const Icon(Icons.person, size: 60, color: Colors.white)
                  : null,
            ),
            
            const SizedBox(height: 16),
            
            // Host Name
            Text(
              hostName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
            
            const SizedBox(height: 50),
            
            // Statistics Grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatColumn('Duration', '$durationMinutes min'),
                  _buildStatColumn('Viewers', '$totalUsers'),
                  _buildStatColumn('Diamonds', '$totalDiamonds'),
                  _buildStatColumn('Gifts', '$totalGifts'),
                ],
              ),
            ),
            
            const Spacer(),
            
            // Return Home Button
            Padding(
              padding: const EdgeInsets.all(30.0),
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pinkAccent,
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  'Return to Home',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

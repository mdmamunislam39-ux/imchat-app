import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chat_messenger/components/universal_asset_widget.dart';

/// Full-screen luxury Badge Detail View matching the reference screenshots.
/// Screenshot 1: Own badge (shows "Valid until YYYY-MM-DD" pill).
/// Screenshot 2: Other user's badge (omits "Valid until" pill).
class BadgeDetailDialog extends StatelessWidget {
  final Map<String, dynamic> badge;
  final bool isOwner;
  final bool isUnlocked;

  const BadgeDetailDialog({
    super.key,
    required this.badge,
    required this.isOwner,
    this.isUnlocked = true,
  });

  static Future<void> show(
    BuildContext context, {
    required Map<String, dynamic> badge,
    required bool isOwner,
    bool isUnlocked = true,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'BadgeDetail',
      barrierColor: Colors.black.withValues(alpha: 0.92),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, anim1, anim2) {
        return BadgeDetailDialog(
          badge: badge,
          isOwner: isOwner,
          isUnlocked: isUnlocked,
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(
              CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        );
      },
    );
  }

  String _formatValidUntil(dynamic expiresAt) {
    if (expiresAt == null) return 'Permanent';
    DateTime? date;
    if (expiresAt is Timestamp) {
      date = expiresAt.toDate();
    } else if (expiresAt is DateTime) {
      date = expiresAt;
    }
    if (date == null) return 'Permanent';
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _formatFirstObtained(dynamic assignedAt, dynamic createdAt) {
    DateTime? date;
    final source = assignedAt ?? createdAt;
    if (source is Timestamp) {
      date = source.toDate();
    } else if (source is DateTime) {
      date = source;
    }
    date ??= DateTime.now();
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y.$m.$d';
  }

  @override
  Widget build(BuildContext context) {
    final name = badge['storeItemName'] ?? badge['name'] ?? 'Badge';
    final imageUrl = badge['imageUrl'] as String?;
    final description = badge['description'] as String? ??
        'Become an official assistant to get this honor';
    final expiresAt = badge['expiresAt'];
    final assignedAt = badge['assignedAt'];
    final createdAt = badge['createdAt'];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(),
        child: Stack(
          children: [
            // Layer 1: Dark base with dramatic golden light rays from top-left
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF070605),
                  gradient: LinearGradient(
                    begin: Alignment(-1.2, -1.0),
                    end: Alignment(0.6, 0.45),
                    colors: [
                      Color(0x99E6A100),
                      Color(0x55D98200),
                      Color(0x22B25E00),
                      Color(0x08070605),
                      Color(0xFF070605),
                    ],
                    stops: [0.0, 0.22, 0.45, 0.75, 1.0],
                  ),
                ),
              ),
            ),

            // Layer 2: Soft radiant glow behind the badge
            Positioned(
              top: MediaQuery.of(context).size.height * 0.12,
              left: 0,
              right: 0,
              height: 240,
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, 0),
                    radius: 0.6,
                    colors: [
                      const Color(0xFFFFB300).withValues(alpha: 0.22),
                      const Color(0xFFFF9800).withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Layer 3: Top-left close 'X' button
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12, top: 8),
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 26),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ),

            // Layer 4: Content column
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 20),

                        // Badge Artwork
                        SizedBox(
                          height: 145,
                          width: 145,
                          child: imageUrl != null && imageUrl.isNotEmpty
                              ? (isUnlocked
                                  ? UniversalAssetWidget(
                                      url: imageUrl,
                                      fit: BoxFit.contain,
                                      looping: true,
                                    )
                                  : ColorFiltered(
                                      colorFilter: const ColorFilter.mode(
                                        Colors.grey,
                                        BlendMode.saturation,
                                      ),
                                      child: UniversalAssetWidget(
                                        url: imageUrl,
                                        fit: BoxFit.contain,
                                        looping: false,
                                      ),
                                    ))
                              : const Icon(
                                  Icons.shield,
                                  size: 110,
                                  color: Color(0xFFFFB300),
                                ),
                        ),

                        const SizedBox(height: 48),

                        // Badge Name (Bold, serif-like italic style matching screenshots)
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                            fontStyle: FontStyle.italic,
                            fontFamily: 'serif',
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        // Pill (ONLY for Owner viewing their own badge)
                        if (isOwner) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 5.5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF221A0F).withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFF8A6C35).withValues(alpha: 0.55),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              'Valid until ${_formatValidUntil(expiresAt)}',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFFE5C578),
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 22),

                        // Description (Muted grey-gold, italic)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            description,
                            style: const TextStyle(
                              fontSize: 13.5,
                              color: Color(0xFFA09B93),
                              fontStyle: FontStyle.italic,
                              height: 1.45,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // First obtained date
                        Text(
                          'First obtained on ${_formatFirstObtained(assignedAt, createdAt)}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF757067),
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:chat_messenger/models/user.dart' as model;
import 'package:chat_messenger/components/cached_circle_avatar.dart';
import 'package:chat_messenger/components/dynamic_diamond_icon.dart';
import 'package:flutter_svga/flutter_svga.dart';
import 'package:chat_messenger/api/official_team_api.dart';
import 'package:chat_messenger/services/svip_service.dart';

class SvipScreen extends StatefulWidget {
  final model.User currentUser;
  final bool isSvip;
  const SvipScreen({super.key, required this.currentUser, this.isSvip = true});

  @override
  State<SvipScreen> createState() => _SvipScreenState();
}

class _SvipScreenState extends State<SvipScreen> with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  bool _isSaving = false;
  List<Map<String, dynamic>> _vipLevels = [];
  final Map<String, bool> _claimedStatus = {};

  int _currentMonthlyRecharge = 0;
  int _userDiamonds = 0;
  int _userActiveVipLevel = 0;
  int _userActiveLevel = 0;
  String _userSvipValidUntilMonth = '';
  DateTime? _userVipValidUntil;
  TabController? _tabController;
  StreamSubscription<DocumentSnapshot>? _userSubscription;
  StreamSubscription<QuerySnapshot>? _configsSubscription;
  StreamSubscription<DocumentSnapshot>? _claimedSubscription;

  @override
  void initState() {
    super.initState();
    _userActiveLevel = widget.isSvip ? widget.currentUser.activeSvipLevel : widget.currentUser.activeVipLevel;
    _userSvipValidUntilMonth = widget.currentUser.svipValidUntilMonth;
    _checkMonthlyReset(widget.currentUser.monthlyRechargeAmount, widget.currentUser.lastRechargeMonth);
    _listenToUserUpdates();
    _listenToVipConfigsAndClaims();
  }

  void _listenToUserUpdates() {
    _userSubscription = _firestore.collection('Users').doc(widget.currentUser.userId).snapshots().listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data()!;
        final int monthlyAmount = (data['monthlyRechargeAmount'] ?? 0) is int 
            ? data['monthlyRechargeAmount'] as int 
            : (data['monthlyRechargeAmount'] as num?)?.toInt() ?? 0;
        final String lastMonth = data['lastRechargeMonth'] as String? ?? '';
        
        final int diamonds = (data['diamonds'] ?? 0) is int 
            ? data['diamonds'] as int 
            : (data['diamonds'] as num?)?.toInt() ?? 0;
        
        final int activeVip = (data['activeVipLevel'] as num?)?.toInt() ?? 0;
        final int activeSvip = (data['activeSvipLevel'] as num?)?.toInt() ?? 0;
        final String svipMonth = data['svipValidUntilMonth'] as String? ?? '';
        final dynamic vipValidRaw = data['vipValidUntil'];
        DateTime? vipValid;
        if (vipValidRaw is Timestamp) {
          vipValid = vipValidRaw.toDate();
        } else if (vipValidRaw is String) {
          vipValid = DateTime.tryParse(vipValidRaw);
        }

        if (mounted) {
          setState(() {
            _checkMonthlyReset(monthlyAmount, lastMonth);
            _userDiamonds = diamonds;
            _userActiveVipLevel = activeVip;
            _userActiveLevel = widget.isSvip ? activeSvip : activeVip;
            _userSvipValidUntilMonth = svipMonth;
            _userVipValidUntil = vipValid;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    _configsSubscription?.cancel();
    _claimedSubscription?.cancel();
    _tabController?.dispose();
    super.dispose();
  }

  void _checkMonthlyReset(int amount, String? lastMonth) {
    final now = DateTime.now();
    final currentMonth = "${now.year}-${now.month.toString().padLeft(2, '0')}";

    if (lastMonth == currentMonth) {
      _currentMonthlyRecharge = amount;
    } else {
      _currentMonthlyRecharge = 0;
    }
  }

  void _listenToVipConfigsAndClaims() {
    final configDocName = widget.isSvip ? 'svip_levels' : 'vip_levels';
    final claimedColl = widget.isSvip ? 'claimed_svips' : 'claimed_vips';
    final now = DateTime.now();
    final currentMonth = "${now.year}-${now.month.toString().padLeft(2, '0')}";

    _configsSubscription?.cancel();
    _configsSubscription = _firestore
        .collection('config')
        .doc(configDocName)
        .collection('levels')
        .snapshots()
        .listen((configSnapshot) {
      
      final levels = configSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      levels.sort((a, b) {
        final aNum = int.tryParse((a['id'] as String).replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        final bNum = int.tryParse((b['id'] as String).replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        return aNum.compareTo(bNum);
      });

      _claimedSubscription?.cancel();
      _claimedSubscription = _firestore
          .collection('Users')
          .doc(widget.currentUser.userId)
          .collection(claimedColl)
          .doc(currentMonth)
          .snapshots()
          .listen((claimSnapshot) {
        
        final Map<String, bool> claimed = {};
        if (claimSnapshot.exists && claimSnapshot.data() != null) {
          final data = claimSnapshot.data()!;
          for (var lvl in levels) {
            claimed[lvl['id']] = data[lvl['id']] == true;
          }
        } else {
          for (var lvl in levels) {
            claimed[lvl['id']] = false;
          }
        }

        if (mounted) {
          setState(() {
            _vipLevels = levels;
            _claimedStatus.clear();
            _claimedStatus.addAll(claimed);
            
            // Only initialize tab controller if it hasn't been initialized or level count changed
            if (_tabController == null || _tabController!.length != levels.length) {
              _tabController?.dispose();
              _tabController = TabController(length: levels.length, vsync: this);
              
              // Set initial tab to active level or target
              int targetIndex = 0;
              for (int i = 0; i < levels.length; i++) {
                final rawTarget = levels[i]['rechargeTarget'];
                final target = rawTarget is int ? rawTarget : (rawTarget is double ? rawTarget.toInt() : (int.tryParse(rawTarget?.toString() ?? '0') ?? 0));
                if (_currentMonthlyRecharge < target) {
                  targetIndex = i;
                  break;
                }
              }
              if (levels.isNotEmpty) {
                final lastRawTarget = levels.last['rechargeTarget'];
                final lastTarget = lastRawTarget is int ? lastRawTarget : (lastRawTarget is double ? lastRawTarget.toInt() : (int.tryParse(lastRawTarget?.toString() ?? '0') ?? 0));
                if (targetIndex == 0 && _currentMonthlyRecharge >= lastTarget) {
                  targetIndex = levels.length - 1;
                }
              }
              _tabController!.index = targetIndex.clamp(0, (levels.length - 1).clamp(0, levels.length));
              
              int currentIndex = _tabController!.index;
              _tabController!.addListener(() {
                if (_tabController!.index != currentIndex) {
                  currentIndex = _tabController!.index;
                  setState(() {});
                }
              });
            }
            
            _isLoading = false;
          });
        }
      }, onError: (e) {
        debugPrint('Error listening to claimed status: $e');
        if (mounted) setState(() => _isLoading = false);
      });

    }, onError: (e) {
      debugPrint('Error listening to VIP/SVIP configs: $e');
      if (mounted) setState(() => _isLoading = false);
    });
  }

  Future<void> _claimReward() async {
    if (_tabController == null || _vipLevels.isEmpty) return;
    
    final selectedLevel = _vipLevels[_tabController!.index];
    final levelId = selectedLevel['id'] as String;
    final levelNum = int.tryParse(levelId.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
    final rawTarget = selectedLevel['rechargeTarget'];
    final target = rawTarget is int ? rawTarget : (rawTarget is double ? rawTarget.toInt() : (int.tryParse(rawTarget?.toString() ?? '0') ?? 0));

    if (widget.isSvip) {
      if (_currentMonthlyRecharge < target) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.stars, color: Color(0xFFFFD700)),
                SizedBox(width: 8),
                Text('SVIP Level Progress', style: TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
            content: Text(
              'SVIP Level increases exclusively through valid Seller Page recharges.\n\n'
              'Current Eligible Seller Recharge: $_currentMonthlyRecharge / $target Diamonds.\n\n'
              'Note: Diamonds from Rewards, Events, Bonuses, or Games add to your Wallet balance, but do not contribute to SVIP level progression.',
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Got it', style: TextStyle(color: Color(0xFFFFD700))),
              ),
            ],
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('SVIP rewards and levels are automatically applied by backend upon valid Seller Recharge!'),
          backgroundColor: Colors.green,
        ),
      );
      return;
    }

    if (_currentMonthlyRecharge < target) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Target not reached! Recharge more to level up.'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_claimedStatus[levelId] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Already claimed for this month!'), backgroundColor: Colors.orange),
      );
      return;
    }

    try {
      final now = DateTime.now();
      final currentMonth = "${now.year}-${now.month.toString().padLeft(2, '0')}";

      final claimedColl = widget.isSvip ? 'claimed_svips' : 'claimed_vips';
      await _firestore
          .collection('Users')
          .doc(widget.currentUser.userId)
          .collection(claimedColl)
          .doc(currentMonth)
          .set({levelId: true}, SetOptions(merge: true));

      final userRef = _firestore.collection('Users').doc(widget.currentUser.userId);

      await _firestore.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        final userData = userDoc.data() ?? {};

        final String activeLevelField = widget.isSvip ? 'activeSvipLevel' : 'activeVipLevel';
        final String validUntilField = widget.isSvip ? 'svipValidUntilMonth' : 'vipValidUntilMonth';

        Map<String, dynamic> custData = userData['customization'] ?? {};
        int currentActiveLevel = userData[activeLevelField] ?? 0;
        if (levelNum > currentActiveLevel) {
          transaction.update(userRef, {
            activeLevelField: levelNum,
            validUntilField: currentMonth,
          });

          // SVIP Upgrade: Automatically remove previous SVIP level items from user_store_items
          if (widget.isSvip) {
            final suffixes = ['badge', 'frame', 'entry', 'skin', 'nameplate'];
            for (int old = 1; old < levelNum; old++) {
              for (final s in suffixes) {
                final oldDocRef = _firestore
                    .collection('user_store_items')
                    .doc('${widget.currentUser.userId}_svip_svip${old}_$s');
                transaction.delete(oldDocRef);
              }
            }

            // Clean previous SVIP asset URLs from customization lists
            for (var lvl in _vipLevels) {
              final lId = lvl['id'] as String? ?? '';
              final lNum = int.tryParse(lId.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
              if (lNum > 0 && lNum < levelNum) {
                final oldUrls = [
                  lvl['badgeMediaUrl']?.toString() ?? '',
                  lvl['badgeUrl']?.toString() ?? '',
                  lvl['frameMediaUrl']?.toString() ?? '',
                  lvl['frameUrl']?.toString() ?? '',
                  lvl['entryEffectMediaUrl']?.toString() ?? '',
                  lvl['entryEffectUrl']?.toString() ?? '',
                  lvl['profileSkinMediaUrl']?.toString() ?? '',
                  lvl['profileSkinUrl']?.toString() ?? '',
                  lvl['nameplateMediaUrl']?.toString() ?? '',
                  lvl['nameplateUrl']?.toString() ?? '',
                ];
                for (final u in oldUrls) {
                  if (u.isNotEmpty) {
                    (custData['ownedBadges'] as List?)?.remove(u);
                    (custData['ownedFrames'] as List?)?.remove(u);
                    (custData['ownedEntryEffects'] as List?)?.remove(u);
                    (custData['ownedBackgroundThemes'] as List?)?.remove(u);
                    (custData['ownedNameplates'] as List?)?.remove(u);
                  }
                }
              }
            }

            // Unequip previous SVIP items if equipped
            final selFrame = custData['selectedFrameId']?.toString() ?? '';
            final selEntry = custData['selectedEntryEffectId']?.toString() ?? '';
            final selTheme = custData['selectedBackgroundThemeId']?.toString() ?? '';
            for (int old = 1; old < levelNum; old++) {
              if (selFrame == 'svip_svip${old}_frame') {
                custData['selectedFrameId'] = null;
              }
              if (selEntry == 'svip_svip${old}_entry') {
                custData['selectedEntryEffectId'] = null;
              }
              if (selTheme == 'svip_svip${old}_skin') {
                custData['selectedBackgroundThemeId'] = null;
              }
            }

            if (custData['selectedNameplateIds'] is List) {
              final npIds = List<String>.from(custData['selectedNameplateIds'] as List);
              for (int old = 1; old < levelNum; old++) {
                npIds.remove('svip_svip${old}_nameplate');
              }
              custData['selectedNameplateIds'] = npIds;
            }
          }
        }

        void addAssetToInventory(String listKey, String url, [String? storeItemId]) {
          List<String> currentList = List<String>.from(custData[listKey] ?? []);
          if (url.isNotEmpty && !currentList.contains(url)) {
            currentList.add(url);
          }
          if (storeItemId != null && storeItemId.isNotEmpty && !currentList.contains(storeItemId)) {
            currentList.add(storeItemId);
          }
          custData[listKey] = currentList;
        }

        String extractUrl(List<String> keys) {
          for (final key in keys) {
            final val = selectedLevel[key];
            if (val != null) {
              final s = val.toString().trim();
              if (s.isNotEmpty && (s.startsWith('http://') || s.startsWith('https://') || s.startsWith('assets/'))) {
                return s;
              }
            }
          }
          return '';
        }

        final String badgeUrl = extractUrl(['badgeMediaUrl', 'badgeUrl', 'badge']);
        final String frameUrl = extractUrl(['frameMediaUrl', 'frameUrl', 'avatarFrame', 'frame']);
        final String entryEffectUrl = extractUrl(['entryEffectMediaUrl', 'entryEffectUrl', 'entryTagUrl', 'entryEffect']);
        final String profileSkinUrl = extractUrl(['profileSkinMediaUrl', 'profileSkinUrl', 'profileCardUrl', 'profileSkin', 'backgroundTheme']);
        final String nameplateUrl = extractUrl(['nameplateMediaUrl', 'nameplateUrl', 'svipTagUrl', 'nameplate', 'svipTag']);

        final badgeStoreId = 'svip_${levelId}_badge';
        final frameStoreId = 'svip_${levelId}_frame';
        final entryStoreId = 'svip_${levelId}_entry';
        final skinStoreId = 'svip_${levelId}_skin';
        final nameplateStoreId = 'svip_${levelId}_nameplate';

        addAssetToInventory('ownedBadges', badgeUrl, badgeStoreId);
        addAssetToInventory('ownedFrames', frameUrl, frameStoreId);
        addAssetToInventory('ownedEntryEffects', entryEffectUrl, entryStoreId);
        addAssetToInventory('ownedBackgroundThemes', profileSkinUrl, skinStoreId);
        addAssetToInventory('ownedNameplates', nameplateUrl, nameplateStoreId);

        // Requirement 5: VIP/SVIP Nameplate is automatically active
        if (nameplateUrl.isNotEmpty) {
          custData['selectedNameplateId'] = nameplateStoreId;
          custData['selectedNameplateUrl'] = nameplateUrl;
          custData['selectedNameplate'] = nameplateUrl;
          final currentNameplateIds = List<String>.from(custData['selectedNameplateIds'] ?? []);
          if (!currentNameplateIds.contains(nameplateStoreId)) {
            currentNameplateIds.add(nameplateStoreId);
          }
          custData['selectedNameplateIds'] = currentNameplateIds;
        }

        // Requirements 1, 2, 4: Frame, entry effect, and profile skin are NEVER auto-equipped.
        // Existing equipped frame remains untouched. User equips manually from My Items.
        transaction.update(userRef, {'customization': custData});

        // Add SVIP items to user_store_items for My Items inventory management
        final now = DateTime.now();
        final nextMonth = DateTime(now.year, now.month + 1, 1);
        final List<Map<String, String>> itemsToAdd = [
          {'type': 'badge', 'idSuffix': 'badge', 'name': 'SVIP $levelNum Badge', 'url': badgeUrl},
          {'type': 'avatarFrame', 'idSuffix': 'frame', 'name': 'SVIP $levelNum Frame', 'url': frameUrl},
          {'type': 'entryEffect', 'idSuffix': 'entry', 'name': 'SVIP $levelNum Entry Effect', 'url': entryEffectUrl},
          {'type': 'backgroundTheme', 'idSuffix': 'skin', 'name': 'SVIP $levelNum Profile Skin', 'url': profileSkinUrl},
          {'type': 'nameplate', 'idSuffix': 'nameplate', 'name': 'SVIP $levelNum Nameplate', 'url': nameplateUrl},
        ];

        for (final item in itemsToAdd) {
          final url = item['url'] ?? '';
          if (url.isNotEmpty) {
            final storeItemId = 'svip_${levelId}_${item['idSuffix']}';
            final docRef = _firestore
                .collection('user_store_items')
                .doc('${widget.currentUser.userId}_$storeItemId');

            transaction.set(docRef, {
              'userId': widget.currentUser.userId,
              'storeItemId': storeItemId,
              'storeItemName': item['name'],
              'name': item['name'],
              'itemType': item['type'],
              'type': item['type'],
              'imageUrl': url,
              'fileUrl': url,
              'thumbnailUrl': url,
              'image': url,
              'assignedAt': FieldValue.serverTimestamp(),
              'expiresAt': Timestamp.fromDate(nextMonth),
              'isActive': true,
            }, SetOptions(merge: true));
          }
        }
      });

      if (widget.isSvip) {
        SvipService.cleanupPreviousSvipItemsFromFirestore(widget.currentUser.userId, levelNum);
      }

      // Send imChat Team Notification about level claim
      try {
        final String levelType = widget.isSvip ? "SVIP" : "VIP";
        await OfficialTeamApi.sendOfficialMessage(
          receiverId: widget.currentUser.userId,
          receiverDeviceToken: widget.currentUser.deviceToken,
          messageText: "🎉 Congratulations! You have successfully claimed rewards for $levelType level ${levelId.toUpperCase()}. $levelType rewards (Frames, Entry Effects, and Background Skins) have been unlocked and added to your profile/room customization settings!",
        );
      } catch (e) {
        debugPrint('⚠️ SvipScreen: Error sending notification: $e');
      }

      setState(() {
        _claimedStatus[levelId] = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('${levelId.toUpperCase()} Claimed Successfully!'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint('Error claiming SVIP reward: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to claim: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'imChat ',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
                fontSize: 22,
                fontFamily: 'Inter',
              ),
            ),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
              ).createShader(bounds),
              child: Text(
                widget.isSvip ? 'SVIP' : 'VIP',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  fontSize: 22,
                  letterSpacing: 1.2,
                  fontFamily: 'Inter',
                ),
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Color(0xFFFFD700)),
            onPressed: () {
              // Help info
            },
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: widget.isSvip
                ? [
                    const Color(0xFF0F2027),
                    const Color(0xFF203A43),
                    const Color(0xFF121E24),
                  ]
                : [
                    const Color(0xFF3D0C5A),
                    const Color(0xFF1E0234),
                    const Color(0xFF120020),
                  ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)))
            : _vipLevels.isEmpty
                ? Center(child: Text(widget.isSvip ? 'No SVIP configs found' : 'No VIP configs found', style: const TextStyle(color: Colors.white)))
                : Column(
                    children: [
                      SizedBox(height: MediaQuery.of(context).padding.top + kToolbarHeight),
                      
                      // Custom Tab Bar
                      _buildTabBar(),
                      
                      // Main Content Scrollable Area
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              // Large SVIP Badge Image
                              _buildMainBadgeDisplay(),
                              
                              // SVIP Identification Section (Grid)
                              _buildSectionTitle('${widget.isSvip ? 'SVIP' : 'VIP'} Identification', '9/9'),
                              _buildRewardsGrid(),
                              
                              const SizedBox(height: 20),
                              
                              // Exclusive Privileges Section
                              _buildSectionTitle('Exclusive Privileges', '18/25'),
                              _buildPrivilegesGrid(),
                              
                              // Bottom padding for the sticky footer
                              const SizedBox(height: 140),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
      
      // Sticky Bottom Bar
      bottomSheet: _isLoading || _vipLevels.isEmpty ? null : _buildStickyBottomBar(),
    );
  }

  Widget _buildTabBar() {
    return Container(
      height: 45,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: const Color(0xFFFFD700),
        indicatorWeight: 3,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white54,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 15),
        tabs: _vipLevels.map((lvl) {
          String rawId = lvl['id'].toString().toUpperCase(); // e.g., VIP1 or SVIP1
          String displayPrefix = widget.isSvip ? 'SVIP' : 'VIP';
          int numberStartIndex = rawId.startsWith('SVIP') ? 4 : (rawId.startsWith('VIP') ? 3 : 0);
          String numberPart = numberStartIndex > 0 ? rawId.substring(numberStartIndex) : rawId;
          return Tab(text: '$displayPrefix $numberPart');
        }).toList(),
      ),
    );
  }

  Widget _buildMainBadgeDisplay() {
    if (_tabController == null || _vipLevels.isEmpty) return const SizedBox();
    
    final selectedLevel = _vipLevels[_tabController!.index];
    final badgeUrl = selectedLevel['badgeUrl'] as String? ?? '';
    
    return Container(
      width: 250,
      height: 250,
      margin: const EdgeInsets.only(top: 20, bottom: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: widget.isSvip
              ? [
                  const Color(0xFF203A43).withValues(alpha: 0.8),
                  const Color(0xFF0F2027).withValues(alpha: 0.9),
                ]
              : [
                  const Color(0xFF6A0DAD).withValues(alpha: 0.8),
                  const Color(0xFF3D0C5A).withValues(alpha: 0.9),
                ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(50),
          bottomRight: Radius.circular(50),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withValues(alpha: 0.2),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
        border: Border(
          bottom: BorderSide(color: const Color(0xFFFFD700).withValues(alpha: 0.5), width: 3),
          left: BorderSide(color: const Color(0xFFFFD700).withValues(alpha: 0.5), width: 2),
          right: BorderSide(color: const Color(0xFFFFD700).withValues(alpha: 0.5), width: 2),
        ),
      ),
      child: Center(
        child: _buildMediaPreview(
          (selectedLevel['badgeMediaUrl']?.toString() ?? '').isNotEmpty 
              ? selectedLevel['badgeMediaUrl'].toString() 
              : badgeUrl,
          width: 200,
          height: 200,
        ),
      ),
    );
  }
  
  Widget _buildMediaPreview(String url, {double width = 200, double height = 200}) {
    if (url.isEmpty) return _buildFallbackBadge();
    
    if (url.toLowerCase().contains('.svga')) {
      return SizedBox(
        width: width,
        height: height,
        child: SVGAEasyPlayer(resUrl: url),
      );
    } else if (url.toLowerCase().contains('.mp4') || url.toLowerCase().contains('.vap')) {
      // For MP4 without full player integration, fallback to placeholder
      return Container(
        width: width,
        height: height,
        color: Colors.black26,
        child: const Center(child: Icon(Icons.video_file, color: Colors.white, size: 40)),
      );
    } else {
      return Image.network(
        url,
        width: width,
        height: height,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _buildFallbackBadge(),
      );
    }
  }
  
  Widget _buildFallbackBadge() {
    return Container(
      width: 150,
      height: 150,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.amber,
        boxShadow: [
          BoxShadow(color: Colors.amberAccent, blurRadius: 20, spreadRadius: 5)
        ]
      ),
      child: const Icon(Icons.stars_rounded, size: 100, color: Colors.white),
    );
  }

  Widget _buildSectionTitle(String title, String countText) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/images/wing_left.webp', width: 30, errorBuilder: (_,__,___) => const Icon(Icons.eco, color: Colors.amber, size: 16)),
          const SizedBox(width: 8),
          Column(
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              Text(
                countText,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Image.asset('assets/images/wing_right.webp', width: 30, errorBuilder: (_,__,___) => const Icon(Icons.eco, color: Colors.amber, size: 16)),
        ],
      ),
    );
  }

  Widget _buildRewardsGrid() {
    if (_tabController == null || _vipLevels.isEmpty) return const SizedBox();
    
    final selectedLevel = _vipLevels[_tabController!.index];
    
    final String typeLabel = widget.isSvip ? 'SVIP' : 'VIP';
    final List<Map<String, dynamic>> gridItems = [
      {'title': '$typeLabel Tag', 'url': selectedLevel['nameplateUrl']?.toString() ?? '', 'mediaUrl': selectedLevel['nameplateMediaUrl']?.toString() ?? ''},
      {'title': '$typeLabel Badge', 'url': selectedLevel['badgeUrl']?.toString() ?? '', 'mediaUrl': selectedLevel['badgeMediaUrl']?.toString() ?? ''},
      {'title': 'Entry Tag', 'url': selectedLevel['entryEffectUrl']?.toString() ?? '', 'mediaUrl': selectedLevel['entryEffectMediaUrl']?.toString() ?? ''},
      {'title': 'Profile Card', 'url': selectedLevel['profileSkinUrl']?.toString() ?? '', 'mediaUrl': selectedLevel['profileSkinMediaUrl']?.toString() ?? ''},
      {'title': '$typeLabel Frame', 'url': selectedLevel['frameUrl']?.toString() ?? '', 'mediaUrl': selectedLevel['frameMediaUrl']?.toString() ?? ''},
      {'title': '$typeLabel Chat Bubble', 'url': '', 'mediaUrl': ''}, // Dummy
      {'title': 'Mic Voice Wave', 'url': '', 'mediaUrl': ''},     // Dummy
      {'title': 'Entrance Effect', 'url': '', 'mediaUrl': ''},    // Dummy
      {'title': 'Room Theme', 'url': '', 'mediaUrl': ''},         // Dummy
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: gridItems.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 1.05,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemBuilder: (context, index) {
          return _buildGridCard(
            gridItems[index]['title'] as String, 
            gridItems[index]['url'] as String, 
            gridItems[index]['mediaUrl'] as String
          );
        },
      ),
    );
  }

  Widget _buildPrivilegesGrid() {
    final String typeLabel = widget.isSvip ? 'SVIP' : 'VIP';
    final List<Map<String, String>> privItems = [
      {'title': 'Upgrade notification', 'icon': 'rocket'},
      {'title': 'Visitors', 'icon': 'group'},
      {'title': '$typeLabel Gifts', 'icon': 'card_giftcard'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: privItems.map((item) {
          IconData iconData = Icons.star;
          if (item['icon'] == 'rocket') iconData = Icons.rocket_launch;
          if (item['icon'] == 'group') iconData = Icons.people;
          if (item['icon'] == 'card_giftcard') iconData = Icons.card_giftcard;
          
          return Column(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF531E7A), Color(0xFF280B42)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.3)),
                ),
                child: Center(
                  child: Icon(iconData, color: Colors.white, size: 28),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 80,
                child: Text(
                  item['title']!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGridCard(String title, String imageUrl, String mediaUrl) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: widget.isSvip
              ? [
                  const Color(0xFF142C36),
                  const Color(0xFF224452),
                ]
              : [
                  const Color(0xFF2E004F),
                  const Color(0xFF4A0080),
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.8), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: widget.isSvip
                ? const Color(0xFF00E5FF).withValues(alpha: 0.3)
                : const Color(0xFF8A2BE2).withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Play icon at top right
          if (mediaUrl.isNotEmpty)
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () => _showMediaPreviewDialog(mediaUrl),
                child: const Icon(Icons.play_circle_fill, color: Colors.white, size: 20),
              ),
            )
          else
            const Positioned(
              top: 4,
              right: 4,
              child: Icon(Icons.play_circle_fill, color: Colors.white30, size: 16),
            ),
          
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Center(
                  child: imageUrl.isNotEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(Icons.image, color: Colors.white30, size: 40),
                          ),
                        )
                      : const Icon(Icons.auto_awesome, color: Colors.white30, size: 40), // Placeholder
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(14),
                    bottomRight: Radius.circular(14),
                  ),
                ),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showMediaPreviewDialog(String mediaUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          children: [
            _buildMediaPreview(mediaUrl, width: 300, height: 300),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStickyBottomBar() {
    if (_tabController == null || _vipLevels.isEmpty) return const SizedBox();
    
    final selectedLevel = _vipLevels[_tabController!.index];
    final rawTarget = selectedLevel['rechargeTarget'];
    final target = rawTarget is int ? rawTarget : (rawTarget is double ? rawTarget.toInt() : (int.tryParse(rawTarget?.toString() ?? '0') ?? 0));
    final levelId = selectedLevel['id'] as String;
    final levelNum = int.tryParse(levelId.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
    String levelName = levelId.toUpperCase();
    if (widget.isSvip) {
      if (levelName.startsWith('SVIP') && levelName.length > 4) {
        levelName = 'SVIP ${levelName.substring(4)}';
      } else if (levelName.startsWith('VIP') && levelName.length > 3) {
        levelName = 'SVIP ${levelName.substring(3)}';
      } else {
        levelName = 'SVIP $levelName';
      }
    } else {
      if (levelName.startsWith('VIP') && levelName.length > 3) {
        levelName = 'VIP ${levelName.substring(3)}';
      } else {
        levelName = 'VIP $levelName';
      }
    }
    
    final bool isUnlocked = _currentMonthlyRecharge >= target;
    final bool isClaimed = _claimedStatus[levelId] == true;
    
    // Format large numbers
    String formatPoints(int p) {
      if (p >= 1000000) return '${(p / 1000000).toStringAsFixed(1)}M';
      if (p >= 1000) return '${(p / 1000).toStringAsFixed(1)}k';
      return p.toString();
    }
    
    final String levelType = widget.isSvip ? "SVIP" : "VIP";
    final int userActiveLevel = _userActiveLevel;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    if (!widget.isSvip) {
      // VIP Purchase Layout
      String expiryText = '';
      if (_userActiveVipLevel > 0 && _userVipValidUntil != null) {
        if (_userVipValidUntil!.isAfter(DateTime.now())) {
          final diff = _userVipValidUntil!.difference(DateTime.now()).inDays;
          expiryText = diff > 0 ? 'Active ($diff days left)' : 'Expires today';
        } else {
          expiryText = 'Expired';
        }
      } else {
        expiryText = 'Inactive';
      }

      return Container(
        height: 100 + bottomPadding,
        decoration: const BoxDecoration(
          color: Color(0xFF1E0234),
          border: Border(top: BorderSide(color: Colors.white12)),
        ),
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: 12 + bottomPadding,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar
            CachedCircleAvatar(
              imageUrl: widget.currentUser.photoUrl,
              radius: 24,
              userId: widget.currentUser.userId,
              isOnline: true,
            ),
            const SizedBox(width: 12),
            
            // Expiry and state info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _userActiveVipLevel > 0 
                        ? 'VIP Level $_userActiveVipLevel' 
                        : 'Not a VIP member',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Status: $expiryText',
                    style: TextStyle(
                      color: _userActiveVipLevel > 0 && (_userVipValidUntil?.isAfter(DateTime.now()) ?? false)
                          ? Colors.greenAccent
                          : Colors.redAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Current Balance: $_userDiamonds',
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                      const SizedBox(width: 4),
                      const DynamicDiamondIcon(width: 12, height: 12),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            
            // Purchase Button
            GestureDetector(
              onTap: () => _showPurchaseBottomSheet(selectedLevel),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFE259), Color(0xFFFFA751)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFA751).withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Text(
                  'Purchase',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // SVIP Layout (Recharge & Claim)
    String progressText = '${formatPoints(_currentMonthlyRecharge)}/${formatPoints(target)}';
    double progressRatio = target == 0 ? 1.0 : (_currentMonthlyRecharge / target).clamp(0.0, 1.0);
    final bool isTierAchieved = userActiveLevel >= levelNum || isClaimed;

    return Container(
      height: 100 + bottomPadding,
      decoration: BoxDecoration(
        color: const Color(0xFF121E24),
        border: const Border(top: BorderSide(color: Colors.white12)),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: 12 + bottomPadding,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar
          CachedCircleAvatar(
            imageUrl: widget.currentUser.photoUrl,
            radius: 24,
            userId: widget.currentUser.userId,
            isOnline: true,
          ),
          const SizedBox(width: 12),
          
          // Texts and progress
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  userActiveLevel > 0 
                      ? (_userSvipValidUntilMonth.isNotEmpty 
                          ? 'You are $levelType $userActiveLevel (Until $_userSvipValidUntilMonth)'
                          : 'You are $levelType $userActiveLevel')
                      : 'You are not a $levelType yet',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      'Seller Recharge: $_currentMonthlyRecharge',
                      style: const TextStyle(color: Color(0xFFFFD700), fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 3),
                    const DynamicDiamondIcon(width: 12, height: 12),
                    const SizedBox(width: 6),
                    Text(
                      '(Wallet: $_userDiamonds)',
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        isUnlocked 
                            ? 'Target reached for $levelType ${levelName.replaceAll(RegExp(r'[^0-9]'), '')}!' 
                            : 'Need ${target - _currentMonthlyRecharge} more Seller Recharge',
                        style: const TextStyle(color: Colors.white54, fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      progressText,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progressRatio,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Level Up / Status Button
          GestureDetector(
            onTap: () => _claimReward(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isTierAchieved 
                      ? [const Color(0xFF10B981), const Color(0xFF059669)]
                      : (isUnlocked 
                          ? [const Color(0xFFFFE259), const Color(0xFFFFA751)]
                          : [const Color(0xFF4A4A4A), const Color(0xFF2D2D2D)]),
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: (isUnlocked || isTierAchieved) ? [
                  BoxShadow(
                    color: (isTierAchieved ? const Color(0xFF10B981) : const Color(0xFFFFA751)).withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ] : null,
              ),
              child: Text(
                isTierAchieved ? 'Active' : (isUnlocked ? 'Unlocked' : 'Level Up'),
                style: TextStyle(
                  color: (isUnlocked || isTierAchieved) ? Colors.white : Colors.white54,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _purchaseVip(Map<String, dynamic> selectedLevel, int days, int cost) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    
    try {
      final userRef = _firestore.collection('Users').doc(widget.currentUser.userId);
      final levelId = selectedLevel['id'] as String;
      final levelNum = int.tryParse(levelId.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
      
      final result = await _firestore.runTransaction<String>((transaction) async {
        final userDoc = await transaction.get(userRef);
        if (!userDoc.exists) {
          throw Exception("User profile does not exist!");
        }
        
        final userData = userDoc.data() ?? {};
        final int currentDiamonds = (userData['diamonds'] ?? 0) is int 
            ? userData['diamonds'] as int 
            : (userData['diamonds'] as num?)?.toInt() ?? 0;
            
        if (currentDiamonds < cost) {
          return "insufficient_diamonds";
        }
        
        final dynamic currentVipValidUntilRaw = userData['vipValidUntil'];
        final int currentVipLevel = userData['activeVipLevel'] as int? ?? 0;
        
        DateTime currentExpiry;
        if (currentVipLevel == levelNum && currentVipValidUntilRaw != null) {
          DateTime? parsedDate;
          if (currentVipValidUntilRaw is Timestamp) {
            parsedDate = currentVipValidUntilRaw.toDate();
          } else if (currentVipValidUntilRaw is String) {
            parsedDate = DateTime.tryParse(currentVipValidUntilRaw);
          }
          
          if (parsedDate != null && parsedDate.isAfter(DateTime.now())) {
            currentExpiry = parsedDate;
          } else {
            currentExpiry = DateTime.now();
          }
        } else {
          currentExpiry = DateTime.now();
        }
        
        final DateTime newExpiry = currentExpiry.add(Duration(days: days));
        
        transaction.update(userRef, {
          'diamonds': FieldValue.increment(-cost),
          'activeVipLevel': levelNum,
          'vipValidUntil': Timestamp.fromDate(newExpiry),
        });
        
        Map<String, dynamic> custData = userData['customization'] ?? {};
        
        void addAssetToInventory(String listKey, String url) {
          if (url.isNotEmpty) {
            List<String> currentList = List<String>.from(custData[listKey] ?? []);
            if (!currentList.contains(url)) {
              currentList.add(url);
              custData[listKey] = currentList;
            }
          }
        }
        
        final String badgeUrl = (selectedLevel['badgeMediaUrl']?.toString() ?? '').isNotEmpty 
            ? selectedLevel['badgeMediaUrl'].toString() 
            : selectedLevel['badgeUrl']?.toString() ?? '';
            
        final String frameUrl = (selectedLevel['frameMediaUrl']?.toString() ?? '').isNotEmpty 
            ? selectedLevel['frameMediaUrl'].toString() 
            : selectedLevel['frameUrl']?.toString() ?? '';
            
        final String entryEffectUrl = (selectedLevel['entryEffectMediaUrl']?.toString() ?? '').isNotEmpty 
            ? selectedLevel['entryEffectMediaUrl'].toString() 
            : selectedLevel['entryEffectUrl']?.toString() ?? '';
            
        final String profileSkinUrl = (selectedLevel['profileSkinMediaUrl']?.toString() ?? '').isNotEmpty 
            ? selectedLevel['profileSkinMediaUrl'].toString() 
            : selectedLevel['profileSkinUrl']?.toString() ?? '';
            
        final String nameplateUrl = (selectedLevel['nameplateMediaUrl']?.toString() ?? '').isNotEmpty 
            ? selectedLevel['nameplateMediaUrl'].toString() 
            : selectedLevel['nameplateUrl']?.toString() ?? '';
            
        addAssetToInventory('ownedBadges', badgeUrl);
        addAssetToInventory('ownedFrames', frameUrl);
        addAssetToInventory('ownedEntryEffects', entryEffectUrl);
        addAssetToInventory('ownedBackgroundThemes', profileSkinUrl);
        addAssetToInventory('ownedNameplates', nameplateUrl);

        // Requirement 5: VIP/SVIP Nameplate is automatically active
        if (nameplateUrl.isNotEmpty) {
          final nameplateStoreId = 'vip_${levelId}_nameplate';
          custData['selectedNameplateId'] = nameplateStoreId;
          final currentNameplateIds = List<String>.from(custData['selectedNameplateIds'] ?? []);
          if (!currentNameplateIds.contains(nameplateStoreId)) {
            currentNameplateIds.add(nameplateStoreId);
          }
          custData['selectedNameplateIds'] = currentNameplateIds;
        }

        // Requirements 1, 4: VIP Frame, entry effect, profile skin are NOT auto-equipped.
        // Existing equipped frame remains untouched. User manually equips from My Items.
        transaction.update(userRef, {'customization': custData});
        
        final List<Map<String, String>> itemsToAdd = [
          {'type': 'badge', 'idSuffix': 'badge', 'name': 'VIP $levelNum Badge', 'url': badgeUrl},
          {'type': 'avatarFrame', 'idSuffix': 'frame', 'name': 'VIP $levelNum Frame', 'url': frameUrl},
          {'type': 'entryEffect', 'idSuffix': 'entry', 'name': 'VIP $levelNum Entry Effect', 'url': entryEffectUrl},
          {'type': 'backgroundTheme', 'idSuffix': 'skin', 'name': 'VIP $levelNum Profile Skin', 'url': profileSkinUrl},
          {'type': 'nameplate', 'idSuffix': 'nameplate', 'name': 'VIP $levelNum Nameplate', 'url': nameplateUrl},
        ];
        
        for (final item in itemsToAdd) {
          final url = item['url'] ?? '';
          if (url.isNotEmpty) {
            final storeItemId = 'vip_${levelId}_${item['idSuffix']}';
            final docRef = _firestore
                .collection('user_store_items')
                .doc('${widget.currentUser.userId}_$storeItemId');
                
            transaction.set(docRef, {
              'userId': widget.currentUser.userId,
              'storeItemId': storeItemId,
              'storeItemName': item['name'],
              'itemType': item['type'],
              'imageUrl': url,
              'assignedAt': FieldValue.serverTimestamp(),
              'expiresAt': Timestamp.fromDate(newExpiry),
              'isActive': true,
            }, SetOptions(merge: true));
          }
        }
        
        return "success";
      });
      
      if (mounted) {
        if (result == "success") {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Successfully purchased VIP $levelNum for $days days!'), backgroundColor: Colors.green),
          );
        } else if (result == "insufficient_diamonds") {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Insufficient diamonds balance! Please recharge.'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      debugPrint('Error purchasing VIP: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Purchase error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showPurchaseBottomSheet(Map<String, dynamic> selectedLevel) {
    final levelId = selectedLevel['id'] as String;
    final levelNum = levelId.replaceAll(RegExp(r'[^0-9]'), '');
    
    final int p1 = _getPrice(selectedLevel, 'price1Day', 10);
    final int p7 = _getPrice(selectedLevel, 'price7Days', 50);
    final int p15 = _getPrice(selectedLevel, 'price15Days', 100);
    final int p30 = _getPrice(selectedLevel, 'price30Days', 180);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E0234),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Purchase VIP $levelNum',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        Text(
                          'Your Balance: $_userDiamonds',
                          style: const TextStyle(color: Colors.yellow, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 4),
                        const DynamicDiamondIcon(width: 16, height: 16),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildPurchaseOptionTile('1 Day', p1, () {
                  Navigator.pop(context);
                  _purchaseVip(selectedLevel, 1, p1);
                }),
                const SizedBox(height: 12),
                _buildPurchaseOptionTile('7 Days', p7, () {
                  Navigator.pop(context);
                  _purchaseVip(selectedLevel, 7, p7);
                }),
                const SizedBox(height: 12),
                _buildPurchaseOptionTile('15 Days', p15, () {
                  Navigator.pop(context);
                  _purchaseVip(selectedLevel, 15, p15);
                }),
                const SizedBox(height: 12),
                _buildPurchaseOptionTile('30 Days', p30, () {
                  Navigator.pop(context);
                  _purchaseVip(selectedLevel, 30, p30);
                }),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  int _getPrice(Map<String, dynamic> selectedLevel, String key, int defaultValue) {
    final val = selectedLevel[key];
    if (val is int) return val;
    if (val is double) return val.toInt();
    if (val != null) {
      final parsed = int.tryParse(val.toString());
      if (parsed != null) return parsed;
    }
    return defaultValue;
  }

  Widget _buildPurchaseOptionTile(String duration, int price, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              duration,
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                Text(
                  '$price',
                  style: const TextStyle(color: Colors.yellow, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 4),
                const DynamicDiamondIcon(width: 18, height: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:chat_messenger/config/theme_config.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'widgets/level_list_item.dart';

class LevelScreen extends StatefulWidget {
  final User currentUser;
  
  const LevelScreen({
    super.key, 
    required this.currentUser,
  });

  @override
  State<LevelScreen> createState() => _LevelScreenState();
}

class _LevelScreenState extends State<LevelScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('My Level'),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
        titleTextStyle: const TextStyle(
          color: Colors.black, 
          fontSize: 18, 
          fontWeight: FontWeight.bold
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: primaryColor,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Wealth'),
            Tab(text: 'Charm'),
            Tab(text: 'Active'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLevelTab('sending_config', 'sendingLevel', Colors.amber.shade700),
          _buildLevelTab('receiving_config', 'receivingLevel', Colors.pink.shade400),
          _buildLevelTab('room_config', 'roomLevel', Colors.blue.shade500),
        ],
      ),
    );
  }

  Widget _buildLevelTab(String configDoc, String userLevelField, Color themeColor) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('Users').doc(widget.currentUser.userId).snapshots(),
      builder: (context, userSnapshot) {
        UserLevel? liveUserLevel;
        if (userSnapshot.hasData && userSnapshot.data!.exists) {
          final userData = userSnapshot.data!.data() as Map<String, dynamic>;
          // Parse the specific level field
          if (userData[userLevelField] != null) {
            liveUserLevel = UserLevel.fromMap(userData[userLevelField]);
          }
        } else {
          // Fallback to initial if not loaded yet
          if (userLevelField == 'sendingLevel') liveUserLevel = widget.currentUser.sendingLevel;
          if (userLevelField == 'receivingLevel') liveUserLevel = widget.currentUser.receivingLevel;
          if (userLevelField == 'roomLevel') liveUserLevel = widget.currentUser.roomLevel;
        }

        return StreamBuilder<DocumentSnapshot>(
          stream: _firestore.collection('level_configurations').doc(configDoc).snapshots(),
          builder: (context, configSnapshot) {
            if (configSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (configSnapshot.hasError) {
              return Center(child: Text('Error: ${configSnapshot.error}'));
            }

            List<Map<String, dynamic>> levels = [];
            if (configSnapshot.hasData && configSnapshot.data!.exists) {
              final data = configSnapshot.data!.data() as Map<String, dynamic>?;
              if (data != null && data['levels'] != null) {
                levels = List<Map<String, dynamic>>.from(data['levels']);
                levels.sort((a, b) => (a['levelNumber'] ?? 0).compareTo(b['levelNumber'] ?? 0));
              }
            }

            return Column(
              children: [
                // Top User Progress Section
                _buildUserProgressSection(levels, liveUserLevel, themeColor),
                
                // Header for the list
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  color: Colors.grey.shade50,
                  child: Row(
                    children: [
                      Expanded(flex: 2, child: Text('Level range(Lv.)', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade700, fontSize: 13))),
                      Expanded(flex: 2, child: Center(child: Text('Level icon', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade700, fontSize: 13)))),
                      Expanded(flex: 3, child: Align(alignment: Alignment.centerRight, child: Text('Diamonds Required', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade700, fontSize: 13)))),
                    ],
                  ),
                ),
                
                // List of configured levels
                Expanded(
                  child: levels.isEmpty 
                      ? const Center(child: Text('No levels configured yet.'))
                      : ListView.builder(
                          itemCount: levels.length,
                          itemBuilder: (context, index) {
                            return LevelListItem(levelData: levels[index]);
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildUserProgressSection(List<Map<String, dynamic>> levels, UserLevel? userLevel, Color themeColor) {
    int currentProgress = userLevel?.currentProgress ?? 0;
    int assignedLevel = userLevel?.level ?? 1;
    
    // Calculate accurate current level and next level requirement based on the fetched configurations
    int currentLevelNum = 1;
    double requiredForNext = 1000; // default
    double previousLevelReq = 0; // Baseline for current level

    if (levels.isNotEmpty) {
      // 1. Find natural level
      int naturalLevel = 1;
      for (int i = 0; i < levels.length; i++) {
        final req = (levels[i]['diamondRequirement'] as num?)?.toDouble() ?? 1000.0;
        if (currentProgress >= req) {
          naturalLevel = (levels[i]['levelNumber'] ?? (i + 1));
        } else {
          break;
        }
      }

      // 2. Heal currentProgress for UI if admin manually changed assignedLevel
      if (assignedLevel != naturalLevel) {
        for (int i = 0; i < levels.length; i++) {
          int lvlNum = levels[i]['levelNumber'] ?? (i + 1);
          if (lvlNum == assignedLevel) {
            currentProgress = (levels[i]['diamondRequirement'] as num?)?.toInt() ?? currentProgress;
            break;
          }
        }
      }

      // 3. Calculate final UI stats
      for (int i = 0; i < levels.length; i++) {
        final req = (levels[i]['diamondRequirement'] as num?)?.toDouble() ?? 1000.0;
        if (currentProgress >= req) {
          currentLevelNum = (levels[i]['levelNumber'] ?? (i + 1));
          previousLevelReq = req;
        } else {
          requiredForNext = req;
          break;
        }
      }
    } else {
      currentLevelNum = userLevel?.level ?? 1;
      requiredForNext = (userLevel?.requiredForNext ?? 1000).toDouble();
    }

    double levelProgress = (currentProgress - previousLevelReq).clamp(0.0, double.infinity);
    double levelRequirement = (requiredForNext - previousLevelReq).clamp(1.0, double.infinity);
    double progressPercent = (levelProgress / levelRequirement).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'LV.$currentLevelNum',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: themeColor,
                  fontStyle: FontStyle.italic,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Next LV.${currentLevelNum + 1}',
                    style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${(requiredForNext - currentProgress).clamp(0, double.infinity).toInt()} remaining',
                    style: TextStyle(fontSize: 12, color: themeColor, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progressPercent,
              minHeight: 10,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(themeColor),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Current experience', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Text(levelProgress.toInt().toString(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Next level experience', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Text(levelRequirement.toInt().toString(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

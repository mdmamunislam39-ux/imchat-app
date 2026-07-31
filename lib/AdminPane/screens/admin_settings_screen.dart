import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  final _levelController = TextEditingController();
  final _diamondsController = TextEditingController();
  final _memberLimitController = TextEditingController();
  final _familyRulesController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isResetting = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _levelController.dispose();
    _diamondsController.dispose();
    _memberLimitController.dispose();
    _familyRulesController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      setState(() => _isLoading = true);

      final doc = await _firestore
          .collection('system_configs')
          .doc('family_settings')
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _levelController.text = (data['requiredLevel'] ?? 1).toString();
        _diamondsController.text = (data['requiredDiamonds'] ?? 100).toString();
        _memberLimitController.text = (data['memberLimit'] ?? 50).toString();
        _familyRulesController.text = data['familyRules'] ?? _defaultRules();
      } else {
        // Defaults
        _levelController.text = '1';
        _diamondsController.text = '100';
        _memberLimitController.text = '50';
        _familyRulesController.text = _defaultRules();
      }

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading settings: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() => _isSaving = true);

      final requiredLevel = int.parse(_levelController.text.trim());
      final requiredDiamonds = int.parse(_diamondsController.text.trim());
      final memberLimit = int.parse(_memberLimitController.text.trim());

      await _firestore.collection('system_configs').doc('family_settings').set({
        'requiredLevel': requiredLevel,
        'requiredDiamonds': requiredDiamonds,
        'memberLimit': memberLimit,
        'familyRules': _familyRulesController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      setState(() => _isSaving = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Family settings updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _resetAllUsersDiamonds() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset All Users?'),
        content: const Text('This will reset all sending and receiving levels for ALL users to 0. Cannot be undone!'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('RESET', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isResetting = true);
    try {
      final snapshot = await _firestore.collection('Users').get();
      final batch = _firestore.batch();
      
      final defaultSending = {
        'level': 1,
        'currentProgress': 0,
        'requiredForNext': 100,
        'levelName': 'Beginner',
        'lastUpdated': FieldValue.serverTimestamp(),
      };
      
      final defaultReceiving = {
        'level': 1,
        'currentProgress': 0,
        'requiredForNext': 50,
        'levelName': 'Beginner',
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {
          'sendingLevel': defaultSending,
          'receivingLevel': defaultReceiving,
        });
      }
      
      await batch.commit();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All users reset successfully!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isResetting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        title: const Text('Family Settings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Family Creation Configurations',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Configure requirements and limits for families across the platform.',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _levelController,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Required Level to Create Family',
                        labelStyle: TextStyle(color: Colors.grey),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white24),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.blue),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter required level';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _diamondsController,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Required Diamonds to Create Family',
                        labelStyle: TextStyle(color: Colors.grey),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white24),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.blue),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter required diamonds';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _memberLimitController,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Default Member Limit per Family',
                        labelStyle: TextStyle(color: Colors.grey),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white24),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.blue),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter member limit';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _familyRulesController,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 8,
                      decoration: const InputDecoration(
                        labelText: 'Family Rules / Announcement',
                        labelStyle: TextStyle(color: Colors.grey),
                        alignLabelWithHint: true,
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white24),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.blue),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter family rules';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveSettings,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isSaving
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Save Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isResetting ? null : _resetAllUsersDiamonds,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isResetting
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('TEMPORARY: Reset All User Levels to 0', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  String _defaultRules() {
    return '''1. What is a family?
A family is an organization created by users on their own. Users join to join the family and work together like-minded partners to keep the family growing.

2. How to create / join a family?
Create a family: you can create a family after your wealth level meet the requirement. Upload the family cover, name and notice, you can run your family after passing the review.
Join the family: On the family homepage, click "Join Family" to initiate the application, and you can join the family after passing the family review.

3. Can I join multiple families?
No, one person can only create or join one family.

4. How many people can the family hold?
The number of members is related to the family level, and the initial number is 300. The higher the family level, the greater the capacity.

5. How many administrators can be set in a family?
A family can have up to 10 administrators.

6. How is the family list ranked?
Sort by the total contribution of family members.

7. What is the family level?
The family level represents the strength of the family. The stronger the family, the higher the level. The current family level is divided into four levels: steel, bronze, silver, and gold.

8. What can the family level upgrade bring?
As the level increases, the upper limit of members and administrators will continue to increase; at the same time, the style of family badge and family frame will continue to upgrade as the level increases. Upgrade to the Golden Family to unlock the exclusive gifts of the Golden Family.

9. How to improve the family level?
Calculate the sum of the contribution of family members in each season. The higher the contribution value, the higher the level. The level will be settled at the end of the season as the initial level for the next season.

10. How is the contribution calculated?
- Log in: 20 per person per day
- Watch a 10-minutes live broadcast: +50, 250 per person per day
- Have a 10-minutes guest call: +150, 750 per person per day
- Every 10 minutes of broadcasting: +150, 1500 per person per day
- 1 chat with a friend: +5, 100 per person per day
- Bet: 1000 = 1, 20K per person per day
- Recharge: 10 = 1, users who recharge > 50M daily receive 1M
- Gift giving: 10 = 1, users who send gifts > 100M daily receive 1M
- Receive gifts: 10 = 1

11. What are the rewards for the weekly clan rankings?
The top three Families on the weekly ranking will receive Family rewards, including:
1. World Notice during peak hours: Showcases the Family's weekly ranking.
2. Family member livestream notice: Showcases livestream information for the Family member with the highest contribution points this week.
3. Family contribution point rewards: 50M contribution points for TOP1, 30M contribution points for TOP2, and 10M contribution points for TOP3.''';
  }
}

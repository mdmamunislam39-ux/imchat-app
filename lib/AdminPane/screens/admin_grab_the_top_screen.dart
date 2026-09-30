import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:chat_messenger/models/grab_the_top_model.dart';
import 'package:chat_messenger/services/grab_the_top_service.dart';

/// Admin Screen to configure Grab the Top & Top Exposure showing time and rules in real-time
class AdminGrabTheTopScreen extends StatefulWidget {
  const AdminGrabTheTopScreen({super.key});

  @override
  State<AdminGrabTheTopScreen> createState() => _AdminGrabTheTopScreenState();
}

class _AdminGrabTheTopScreenState extends State<AdminGrabTheTopScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  bool _isFeatureEnabled = true;
  final TextEditingController _defaultShowingTimeController = TextEditingController(text: '10');
  final TextEditingController _minDiamondsController = TextEditingController(text: '600');

  bool _isLoading = true;
  bool _isSaving = false;

  final List<int> _presetDurations = [10, 30, 60, 180, 300];

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _defaultShowingTimeController.dispose();
    _minDiamondsController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    setState(() => _isLoading = true);
    try {
      final doc = await _firestore.collection('platform_config').doc('grab_the_top').get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _isFeatureEnabled = data['isFeatureEnabled'] ?? true;
        _defaultShowingTimeController.text =
            (data['defaultShowingTimeSeconds'] ?? data['showingTimeSeconds'] ?? 10).toString();
      }

      final topExpDoc = await _firestore.collection('platform_config').doc('top_exposure').get();
      if (topExpDoc.exists && topExpDoc.data() != null) {
        final data = topExpDoc.data()!;
        _minDiamondsController.text = (data['minDiamonds'] ?? 600).toString();
      }
    } catch (e) {
      debugPrint('Error loading Grab the Top config: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final showingTime = int.parse(_defaultShowingTimeController.text.trim());
      final minDiamonds = int.parse(_minDiamondsController.text.trim());

      await _firestore.collection('platform_config').doc('grab_the_top').set({
        'isFeatureEnabled': _isFeatureEnabled,
        'defaultShowingTimeSeconds': showingTime,
        'showingTimeSeconds': showingTime,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _firestore.collection('platform_config').doc('top_exposure').set({
        'defaultDurationSeconds': showingTime,
        'minDiamonds': minDiamonds,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Grab the Top real-time settings saved!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error saving: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _showRuleDialog({GrabTheTopRule? rule}) async {
    final giftNameController = TextEditingController(text: rule?.giftName ?? '');
    final giftIdController = TextEditingController(text: rule?.giftId ?? '');
    final minCountController = TextEditingController(text: (rule?.minGiftCount ?? 1).toString());
    final durationController = TextEditingController(
        text: (rule?.showingTimeSeconds ?? int.parse(_defaultShowingTimeController.text)).toString());
    final bannerTitleController = TextEditingController(
        text: rule?.bannerTitle ?? '👑 {sender} sent {count}x {gift} to {receiver} and Grabbed the Top! 🪑');
    bool isActive = rule?.isActive ?? true;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E142B),
              title: Text(
                rule == null ? '➕ Add Grab the Top Rule' : '✏️ Edit Grab the Top Rule',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Gift Selector Dropdown / Auto-fill
                    StreamBuilder<QuerySnapshot>(
                      stream: _firestore.collection('gift').snapshots(),
                      builder: (context, giftSnap) {
                        if (giftSnap.hasData && giftSnap.data!.docs.isNotEmpty) {
                          final gifts = giftSnap.data!.docs;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A1B3D),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.3)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                dropdownColor: const Color(0xFF1E142B),
                                hint: const Text('🎁 Select Existing Gift (Auto-fill)', style: TextStyle(color: Colors.white70, fontSize: 13)),
                                items: gifts.map((doc) {
                                  final data = doc.data() as Map<String, dynamic>;
                                  final name = data['name']?.toString() ?? doc.id;
                                  final credits = data['credits'] ?? 0;
                                  return DropdownMenuItem<String>(
                                    value: doc.id,
                                    child: Text('$name ($credits 💎)', style: const TextStyle(color: Colors.white, fontSize: 13)),
                                  );
                                }).toList(),
                                onChanged: (selectedId) {
                                  if (selectedId == null) return;
                                  final selectedDoc = gifts.firstWhere((d) => d.id == selectedId);
                                  final data = selectedDoc.data() as Map<String, dynamic>;
                                  setDialogState(() {
                                    giftNameController.text = data['name']?.toString() ?? selectedId;
                                    giftIdController.text = selectedId;
                                  });
                                },
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                    TextField(
                      controller: giftNameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Gift Name (Required)',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.purpleAccent)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: giftIdController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Gift ID (Optional / Auto-filled)',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: minCountController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Minimum Gift Quantity',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.purpleAccent)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: durationController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Showing Time (Seconds)',
                        labelStyle: TextStyle(color: Colors.white70),
                        suffixText: 'sec',
                        suffixStyle: TextStyle(color: Colors.amberAccent),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.purpleAccent)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: bannerTitleController,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Banner Template',
                        labelStyle: TextStyle(color: Colors.white70),
                        hintText: '👑 {sender} sent {count}x {gift} to {receiver}...',
                        hintStyle: TextStyle(color: Colors.white30, fontSize: 11),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('Rule Active', style: TextStyle(color: Colors.white)),
                      value: isActive,
                      activeThumbColor: Colors.purpleAccent,
                      onChanged: (val) => setDialogState(() => isActive = val),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx, false),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
                  onPressed: () async {
                    final giftName = giftNameController.text.trim();
                    if (giftName.isEmpty) return;

                    final ruleData = {
                      'giftName': giftName,
                      'giftId': giftIdController.text.trim(),
                      'minGiftCount': int.tryParse(minCountController.text.trim()) ?? 1,
                      'showingTimeSeconds': int.tryParse(durationController.text.trim()) ?? 10,
                      'bannerTitle': bannerTitleController.text.trim(),
                      'isActive': isActive,
                      'updatedAt': FieldValue.serverTimestamp(),
                    };

                    if (rule == null) {
                      await _firestore
                          .collection('platform_config')
                          .doc('grab_the_top')
                          .collection('rules')
                          .add(ruleData);
                    } else {
                      await _firestore
                          .collection('platform_config')
                          .doc('grab_the_top')
                          .collection('rules')
                          .doc(rule.id)
                          .update(ruleData);
                    }

                    if (dialogCtx.mounted) Navigator.pop(dialogCtx, true);
                  },
                  child: Text(rule == null ? 'Add Rule' : 'Save Rule', style: const TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      GrabTheTopService.instance.initialize();
    }
  }

  Future<void> _deleteRule(String ruleId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E142B),
        title: const Text('Delete Rule?', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to remove this rule?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _firestore
          .collection('platform_config')
          .doc('grab_the_top')
          .collection('rules')
          .doc(ruleId)
          .delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0917),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E142B),
        title: const Text(
          '👑 Grab the Top & Showing Time',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.purpleAccent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E142B),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.chair, color: Colors.amberAccent, size: 24),
                                  SizedBox(width: 10),
                                  Text(
                                    'Enable Grab the Top',
                                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              Switch(
                                value: _isFeatureEnabled,
                                activeThumbColor: Colors.purpleAccent,
                                onChanged: (val) => setState(() => _isFeatureEnabled = val),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Showing Time Configuration Card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E142B),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '⏱️ Global Default Showing Time (Real-Time)',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Sets how long the Grab the Top banner/pill stays visible in real-time in audio rooms.',
                            style: TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                          const SizedBox(height: 16),

                          // Preset buttons
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _presetDurations.map((sec) {
                              final isSelected = _defaultShowingTimeController.text == sec.toString();
                              return ChoiceChip(
                                label: Text('${sec}s', style: TextStyle(color: isSelected ? Colors.white : Colors.white70)),
                                selected: isSelected,
                                selectedColor: Colors.purpleAccent,
                                backgroundColor: const Color(0xFF2A1B3D),
                                onSelected: (_) {
                                  setState(() {
                                    _defaultShowingTimeController.text = sec.toString();
                                  });
                                },
                              );
                            }).toList(),
                          ),

                          const SizedBox(height: 16),

                          TextFormField(
                            controller: _defaultShowingTimeController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Showing Time (Seconds)',
                              labelStyle: const TextStyle(color: Colors.white70),
                              suffixText: 'seconds',
                              suffixStyle: const TextStyle(color: Colors.amberAccent),
                              filled: true,
                              fillColor: const Color(0xFF2A1B3D),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return 'Enter showing time';
                              if (int.tryParse(val.trim()) == null || int.parse(val.trim()) <= 0) {
                                return 'Enter valid seconds';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 16),

                          TextFormField(
                            controller: _minDiamondsController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Minimum Diamond Threshold for Top Exposure',
                              labelStyle: const TextStyle(color: Colors.white70),
                              prefixIcon: const Icon(Icons.diamond, color: Colors.cyanAccent),
                              filled: true,
                              fillColor: const Color(0xFF2A1B3D),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return 'Enter minimum diamonds';
                              return null;
                            },
                          ),

                          const SizedBox(height: 20),

                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: _isSaving ? null : _saveConfig,
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Icon(Icons.save),
                              label: Text(_isSaving ? 'Saving...' : 'Save Real-Time Settings'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purpleAccent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Rules List Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '📜 Grab the Top Rules',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _showRuleDialog(),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Rule'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Rules Stream
                    StreamBuilder<QuerySnapshot>(
                      stream: _firestore
                          .collection('platform_config')
                          .doc('grab_the_top')
                          .collection('rules')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(color: Colors.purpleAccent));
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E142B),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'No specific rules configured. Default showing time will be used for qualifying gifts.',
                              style: TextStyle(color: Colors.white54, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          );
                        }

                        final rules = snapshot.data!.docs
                            .map((doc) => GrabTheTopRule.fromFirestore(doc))
                            .toList();

                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: rules.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final rule = rules[index];
                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E142B),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: rule.isActive
                                      ? Colors.purpleAccent.withValues(alpha: 0.4)
                                      : Colors.white12,
                                ),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: rule.isActive
                                        ? Colors.purpleAccent.withValues(alpha: 0.2)
                                        : Colors.white10,
                                    child: Icon(
                                      Icons.star,
                                      color: rule.isActive ? Colors.amberAccent : Colors.white38,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Gift: ${rule.giftName.isEmpty ? '(Any Gift)' : rule.giftName} (Min: ${rule.minGiftCount}x)',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Showing Time: ${rule.showingTimeSeconds}s | Status: ${rule.isActive ? 'Active' : 'Disabled'}',
                                          style: TextStyle(
                                            color: rule.isActive ? Colors.amberAccent : Colors.white38,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blueAccent, size: 20),
                                    onPressed: () => _showRuleDialog(rule: rule),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                                    onPressed: () => _deleteRule(rule.id),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

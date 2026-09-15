import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminGreedyGameScreen extends StatefulWidget {
  const AdminGreedyGameScreen({super.key});

  @override
  State<AdminGreedyGameScreen> createState() => _AdminGreedyGameScreenState();
}

class _AdminGreedyGameScreenState extends State<AdminGreedyGameScreen> {
  final _formKey = GlobalKey<FormState>();
  final _winRatioController = TextEditingController();
  final _thumbnailUrlController = TextEditingController();
  final _customItemController = TextEditingController();

  bool _isCustomScheduled = false;
  bool _isActive = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _winRatioController.dispose();
    _thumbnailUrlController.dispose();
    _customItemController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('greedy_game')
          .get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _winRatioController.text = (data['winRatio'] ?? 50).toString();
        _thumbnailUrlController.text = data['thumbnailUrl'] ?? '';
        _customItemController.text = data['customItem'] ?? '';
        _isCustomScheduled = data['isCustomScheduled'] ?? false;
        _isActive = data['isActive'] ?? true;
      } else {
        _winRatioController.text = '50';
      }
    } catch (e) {
      debugPrint('Error loading greedy game config: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final int winRatio = int.tryParse(_winRatioController.text) ?? 50;
      await FirebaseFirestore.instance
          .collection('config')
          .doc('greedy_game')
          .set({
        'winRatio': winRatio,
        'thumbnailUrl': _thumbnailUrlController.text.trim(),
        'customItem': _customItemController.text.trim(),
        'isCustomScheduled': _isCustomScheduled,
        'isActive': _isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Greedy Game Config Updated!'),
          backgroundColor: Colors.teal,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.redAccent,
        ));
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E142B),
      appBar: AppBar(
        title: const Text('Greedy Game Config',
            style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF2D2D44),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Winning Chance (%)',
                        style: TextStyle(
                            color: Colors.amber, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _winRatioController,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'e.g. 50',
                        hintStyle: const TextStyle(color: Colors.white30),
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'Required';
                        }
                        final num = int.tryParse(val);
                        if (num == null || num < 1 || num > 100) {
                          return 'Must be between 1 and 100';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    const Text('Thumbnail URL (For Game Wall)',
                        style: TextStyle(
                            color: Colors.amber, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _thumbnailUrlController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'https://...',
                        hintStyle: const TextStyle(color: Colors.white30),
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Custom Winning Item (Admin Override)',
                        style: TextStyle(
                            color: Colors.amber, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _customItemController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'e.g. Tomato, Steak, Salad, Pizza',
                        hintStyle: const TextStyle(color: Colors.white30),
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SwitchListTile(
                      title: const Text('Game Active on Game Wall',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: const Text(
                          'Show or hide Greedy Game from the Game Wall',
                          style: TextStyle(color: Colors.white54)),
                      value: _isActive,
                      activeThumbColor: Colors.amber,
                      onChanged: (val) {
                        setState(() {
                          _isActive = val;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('Enable Custom Scheduled Win',
                          style: TextStyle(color: Colors.white)),
                      subtitle: const Text(
                          'If true, the custom winning item will be selected',
                          style: TextStyle(color: Colors.white54)),
                      value: _isCustomScheduled,
                      activeThumbColor: Colors.amber,
                      onChanged: (val) {
                        setState(() {
                          _isCustomScheduled = val;
                        });
                      },
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25)),
                        ),
                        onPressed: _saveConfig,
                        child: const Text('Save Configuration',
                            style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

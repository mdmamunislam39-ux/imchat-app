import 'package:flutter/material.dart';
import 'services/gift_service.dart';

/// Simple test for gift service
class TestGiftService extends StatefulWidget {
  const TestGiftService({super.key});

  @override
  State<TestGiftService> createState() => _TestGiftServiceState();
}

class _TestGiftServiceState extends State<TestGiftService> {
  final GiftService _giftService = GiftService();
  bool _isLoading = false;
  String _result = '';

  Future<void> _testAddGift() async {
    setState(() {
      _isLoading = true;
      _result = 'Testing...';
    });

    try {
      debugPrint('🧪 TestGiftService: Starting test...');
      
      final giftId = await _giftService.addGift(
        name: 'Test Gift',
        category: 'love',
        credits: 100,
        pngFile: null,
        svgaFile: null,
      );
      
      debugPrint('✅ TestGiftService: Gift added with ID: $giftId');
      
      setState(() {
        _result = 'Success! Gift ID: $giftId';
      });
    } catch (e, stackTrace) {
      debugPrint('❌ TestGiftService: Error: $e');
      debugPrint('❌ TestGiftService: Stack trace: $stackTrace');
      
      setState(() {
        _result = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Gift Service'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _isLoading ? null : _testAddGift,
              child: _isLoading 
                ? const CircularProgressIndicator()
                : const Text('Test Add Gift'),
            ),
            const SizedBox(height: 20),
            Text(_result),
          ],
        ),
      ),
    );
  }
}

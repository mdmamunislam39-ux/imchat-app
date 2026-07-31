import 'package:flutter/material.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/roulette/roulette_controller.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/roulette/roulette_widget.dart';

class RouletteSetupSheet extends StatefulWidget {
  final RouletteController controller;

  const RouletteSetupSheet({super.key, required this.controller});

  @override
  State<RouletteSetupSheet> createState() => _RouletteSetupSheetState();
}

class _RouletteSetupSheetState extends State<RouletteSetupSheet> {
  final List<TextEditingController> _controllers = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Initialize with existing custom options or start with 2 empty fields
    if (widget.controller.customOptions.isNotEmpty) {
      for (final option in widget.controller.customOptions) {
        _controllers.add(TextEditingController(text: option));
      }
    } else {
      _controllers.add(TextEditingController());
      _controllers.add(TextEditingController());
    }

    // Add listeners to rebuild wheel preview on text change
    for (var controller in _controllers) {
      controller.addListener(_onTextChanged);
    }
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  void _addOption() {
    setState(() {
      final newController = TextEditingController();
      newController.addListener(_onTextChanged);
      _controllers.add(newController);
    });
    // Scroll to bottom
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _removeOption(int index) {
    setState(() {
      final controller = _controllers.removeAt(index);
      controller.removeListener(_onTextChanged);
      controller.dispose();
    });
  }

  void _saveAndClose() {
    // Filter empty options
    final validOptions = _controllers
        .map((c) => c.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();

    widget.controller.saveCustomOptions(validOptions);
    Navigator.of(context).pop();
  }

  List<String> get _currentOptions {
    final valid = _controllers
        .map((c) => c.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();
    return valid;
  }

  @override
  Widget build(BuildContext context) {
    final options = _currentOptions;
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Color(0xFF1E2235), // Dark background matching the app
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Top Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Row(
                    children: [
                      Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
                      SizedBox(width: 4),
                      Text('Edit', style: TextStyle(color: Colors.white, fontSize: 18)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _saveAndClose,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          
          // Wheel Preview
          const SizedBox(height: 20),
          SizedBox(
            width: 200,
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFF06292), // Pink background if empty
                    boxShadow: [
                      BoxShadow(color: const Color(0xFFF06292).withValues(alpha: 0.5), blurRadius: 15, spreadRadius: 2),
                    ],
                  ),
                  child: options.length >= 2
                    ? CustomPaint(
                        size: const Size(200, 200),
                        painter: WheelPainter(
                          options: options,
                          primaryColor: const Color(0xFFF06292),
                          secondaryColor: Colors.white,
                          textColorPrimary: Colors.white,
                          textColorSecondary: const Color(0xFFF06292),
                        ),
                      )
                    : null,
                ),
                // Center circle (Empty state vs GO state)
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: options.length >= 2 ? Colors.orange : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    gradient: options.length >= 2 
                        ? const RadialGradient(colors: [Colors.yellow, Colors.orange])
                        : null,
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 5)],
                  ),
                  child: Center(
                    child: Text(
                      options.length >= 2 ? 'GO' : 'Empty', 
                      style: TextStyle(
                        color: options.length >= 2 ? Colors.white : Colors.black38, 
                        fontWeight: FontWeight.bold, 
                        fontSize: 12
                      ),
                    ),
                  ),
                ),
                if (options.length >= 2)
                  Positioned(
                    top: -5,
                    child: CustomPaint(
                      size: const Size(20, 25),
                      painter: PointerPainter(),
                    ),
                  ),
              ],
            ),
          ),
          
          const SizedBox(height: 30),
          
          // Options List
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        itemCount: _controllers.length,
                        itemBuilder: (context, index) {
                          return _buildOptionRow(index);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Add Button
                  GestureDetector(
                    onTap: _addOption,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add, color: Colors.blueAccent, size: 20),
                          SizedBox(width: 8),
                          Text('Add', style: TextStyle(color: Colors.blueAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionRow(int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Number circle
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: Colors.black26,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // TextField
          Expanded(
            child: TextField(
              controller: _controllers[index],
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Please Enter',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 16),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          // Delete button
          if (_controllers.length > 2)
            GestureDetector(
              onTap: () => _removeOption(index),
              child: const Icon(Icons.close, color: Colors.white54, size: 20),
            ),
        ],
      ),
    );
  }
}

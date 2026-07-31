
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class FloatingBubbleContent extends StatelessWidget {
  const FloatingBubbleContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.blue,
      child: Center(
        child: GestureDetector(
          onTap: () {
            FlutterOverlayWindow.closeOverlay(); // Close the overlay when tapped
          },
          child: CircleAvatar(
            backgroundColor: Colors.white,
            child: Icon(Icons.message, color: Colors.blue),
          ),
        ),
      ),
    );
  }
}
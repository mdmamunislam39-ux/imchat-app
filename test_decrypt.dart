import 'package:flutter/foundation.dart';

void main() {
  String encryptedText = "This is a normal string, not encrypted";

  final List<String> parts = encryptedText.split(':');
  if (parts.length != 2) {
    debugPrint("Returned plain text");
    return;
  }
}

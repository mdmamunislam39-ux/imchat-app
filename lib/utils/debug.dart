import 'package:flutter/foundation.dart';

/// Debug utility function for logging
void debug(String message) {
  if (kDebugMode) {
    debugPrint('[DEBUG] $message');
  }
}

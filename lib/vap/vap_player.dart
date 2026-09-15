import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class VapPlayer {
  static const MethodChannel _channel = MethodChannel("imchat/vap");

  static Future<void> play(String url) async {
    String finalPath = url;
    if (url.startsWith('http://') || url.startsWith('https://')) {
      try {
        final file = await DefaultCacheManager().getSingleFile(url);
        finalPath = file.path;
        if (!finalPath.toLowerCase().endsWith('.mp4') && !finalPath.toLowerCase().endsWith('.vap')) {
          final newPath = '$finalPath.mp4';
          final newFile = File(newPath);
          if (!await newFile.exists()) {
            await File(finalPath).copy(newPath);
          }
          finalPath = newPath;
        }
      } catch (e) {
        debugPrint("❌ [VapPlayer] Error caching VAP file: $e");
      }
    }
    await _channel.invokeMethod("play", {
      "url": finalPath,
    });
  }

  static Future<void> stop() async {
    await _channel.invokeMethod("stop");
  }
}

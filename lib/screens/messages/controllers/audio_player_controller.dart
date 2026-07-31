import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:get/get.dart';

class AudioPlayerController extends GetxController {
  final String fileUrl;
  final bool isRecording;

  AudioPlayerController({required this.fileUrl, this.isRecording = false});

  // Variables
  final _audioPlayer = AudioPlayer();
  RxBool isPlaying = false.obs;
  Rx<Duration> duration = Rx(Duration.zero);
  Rx<Duration> position = Rx(Duration.zero);

  // Load the Audio URL
  void _loadAudioUrl() async {
    try {
      if (fileUrl.isEmpty) return;
      // Set audio URL
      if (!fileUrl.startsWith('http')) {
        await _audioPlayer.setSourceDeviceFile(fileUrl);
      } else {
        await _audioPlayer.setSourceUrl(fileUrl);
      }
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      final Duration? audioDuration = await _audioPlayer.getDuration();
      if (audioDuration != null) {
        duration.value = audioDuration;
      }
    } catch (e) {
      debugPrint("AudioPlayerController _loadAudioUrl error: $e");
    }
  }

  // Get audio updates
  void _audioPlayerEvents() {
    // Listen to: playing, paused, stopped
    _audioPlayer.onPlayerStateChanged.listen((event) {
      isPlaying.value = event == PlayerState.playing;
    });

    // Listen to "duration" changes
    _audioPlayer.onDurationChanged.listen((Duration d) {
      duration.value = d;
    });

    // Listen to "position" changes
    _audioPlayer.onPositionChanged.listen((Duration p) {
      position.value = p;
    });
  }

  void playAudio() async {
    try {
      if (isPlaying.value) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.resume();
      }
    } catch (e) {
      debugPrint("AudioPlayerController playAudio error: $e");
    }
  }

  Future<void> seekAudio(Duration position) async {
    try {
      await _audioPlayer.seek(position);
      // Play audio if was paused
      await _audioPlayer.resume();
    } catch (e) {
      debugPrint("AudioPlayerController seekAudio error: $e");
    }
  }

  @override
  void onInit() {
    _loadAudioUrl();
    _audioPlayerEvents();
    super.onInit();
  }

  @override
  void onClose() {
    try {
      _audioPlayer.dispose();
    } catch (e) {
      debugPrint("AudioPlayerController onClose error: $e");
    }
    super.onClose();
  }
}

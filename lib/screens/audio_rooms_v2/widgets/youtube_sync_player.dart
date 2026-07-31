import 'dart:async';
import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:chat_messenger/models/audio_room_v2.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/repository/audio_rooms_repository.dart';

class YoutubeSyncPlayer extends StatefulWidget {
  final AudioRoomV2 room;
  final bool isHost;
  final AudioRoomsRepository repository;
  final VoidCallback onClose;
  final VoidCallback onSearch;

  const YoutubeSyncPlayer({
    super.key,
    required this.room,
    required this.isHost,
    required this.repository,
    required this.onClose,
    required this.onSearch,
  });

  @override
  State<YoutubeSyncPlayer> createState() => _YoutubeSyncPlayerState();
}

class _YoutubeSyncPlayerState extends State<YoutubeSyncPlayer> {
  YoutubePlayerController? _controller;
  
  // Track the current video to detect changes
  String? _currentVideoId;
  
  // Debounce updates to Firestore to avoid spamming
  Timer? _syncTimer;
  
  // Flag to prevent infinite update loops between Firestore and Player
  bool _isUpdatingFromRemote = false;

  // Custom Controls Visibility
  bool _showCustomControls = true;
  Timer? _controlsTimer;

  // Volume state
  double _currentVolume = 100.0;

  @override
  void initState() {
    super.initState();
    _currentVideoId = widget.room.activeYoutubeVideoId;
    if (_currentVideoId != null) {
      _initPlayer(_currentVideoId!);
    }
  }

  void _initPlayer(String videoId) {
    _controller = YoutubePlayerController.fromVideoId(
      videoId: videoId,
      autoPlay: widget.room.youtubeIsPlaying,
      params: YoutubePlayerParams(
        showControls: widget.isHost, // Only host can use native controls easily
        showFullscreenButton: false,
        mute: false,
        pointerEvents: widget.isHost ? PointerEvents.initial : PointerEvents.none, // Prevent interactions for non-hosts
      ),
    );
    
    _controller!.listen((event) async {
      if (!widget.isHost) return;
      if (_isUpdatingFromRemote) return;

      final isPlaying = event.playerState == PlayerState.playing;

      bool shouldSync = false;
      if (widget.room.youtubeIsPlaying != isPlaying) {
        shouldSync = true;
      }

      if (shouldSync) {
        final currentTime = await _controller!.currentTime;
        _syncToRemote(isPlaying, currentTime.toInt());
      }

      if (isPlaying) {
        _startControlsTimer();
      } else {
        _controlsTimer?.cancel();
        if (mounted && !_showCustomControls) {
          setState(() {
            _showCustomControls = true;
          });
        }
      }
    });

    if (widget.isHost) {
      _syncTimer = Timer.periodic(const Duration(seconds: 4), (timer) async {
        if (_controller == null || _isUpdatingFromRemote) return;
        final state = await _controller!.playerState;
        if (state == PlayerState.playing) {
          final currentTime = await _controller!.currentTime;
          
          // Only sync if significant drift
          if ((widget.room.youtubeSyncPosition - currentTime.toInt()).abs() > 2) {
             _syncToRemote(true, currentTime.toInt());
          }
        }
      });
    }
  }

  void _syncToRemote(bool isPlaying, int position) {
    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(milliseconds: 500), () {
      widget.repository.updateYoutubeState(
        roomId: widget.room.id,
        videoId: _currentVideoId,
        isPlaying: isPlaying,
        syncPosition: position,
      );
    });
  }


  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        _controller?.playerState.then((state) {
          if (state == PlayerState.playing) {
            setState(() {
              _showCustomControls = false;
            });
          }
        });
      }
    });
  }

  @override
  void didUpdateWidget(YoutubeSyncPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Check if video changed
    if (widget.room.activeYoutubeVideoId != oldWidget.room.activeYoutubeVideoId) {
      if (widget.room.activeYoutubeVideoId == null) {
        // Video closed
        _controller?.close();
        _controller = null;
      } else {
        // New video
        _currentVideoId = widget.room.activeYoutubeVideoId;
        _controller?.close();
        _initPlayer(_currentVideoId!);
      }
    } else if (_controller != null) {
      // Handle remote state changes
      _syncFromRemote();
    }
  }

  Future<void> _syncFromRemote() async {
    if (widget.isHost) return;
    
    _isUpdatingFromRemote = true;
    
    final remoteIsPlaying = widget.room.youtubeIsPlaying;
    
    if (remoteIsPlaying) {
      _controller!.playVideo();
    } else {
      _controller!.pauseVideo();
    }
    
    // Seek if difference is > 3 seconds
    // We cannot easily get current position synchronously in iframe, so we just rely on event listener for hosts.
    // For participants, we just seek to the sync position directly whenever it updates
    if (widget.room.youtubeSyncPosition > 0) {
      _controller!.seekTo(seconds: widget.room.youtubeSyncPosition.toDouble());
    }
    
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _isUpdatingFromRemote = false;
      }
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _controlsTimer?.cancel();
    _controller?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || _currentVideoId == null) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (widget.isHost)
            Padding(
              padding: const EdgeInsets.only(right: 16, top: 0, bottom: 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: widget.onSearch,
                    child: const Padding(
                      padding: EdgeInsets.all(4.0),
                      child: Icon(Icons.search, color: Colors.white, size: 26),
                    ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: _showVolumeSlider,
                    child: const Padding(
                      padding: EdgeInsets.all(4.0),
                      child: Icon(Icons.volume_up_rounded, color: Colors.white, size: 26),
                    ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: Colors.grey[900],
                          title: const Text('Close Video', style: TextStyle(color: Colors.white)),
                          content: const Text('Are you sure you want to close the video?', style: TextStyle(color: Colors.white)),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                widget.repository.updateYoutubeState(
                                  roomId: widget.room.id,
                                  videoId: null,
                                  isPlaying: false,
                                  syncPosition: 0,
                                );
                                widget.onClose();
                              },
                              child: const Text('Sure', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(4.0),
                      child: Icon(Icons.power_settings_new, color: Colors.redAccent, size: 26),
                    ),
                  ),
                ],
              ),
            ),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: YoutubePlayer(
              controller: _controller!,
            ),
          ),
        ],
      ),
    );
  }

  void _showVolumeSlider() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text('Adjust Volume', style: TextStyle(color: Colors.white, fontSize: 16)),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return SizedBox(
                height: 50,
                child: Row(
                  children: [
                    const Icon(Icons.volume_down, color: Colors.white),
                    Expanded(
                      child: Slider(
                        value: _currentVolume,
                        min: 0.0,
                        max: 100.0,
                        activeColor: Colors.blueAccent,
                        inactiveColor: Colors.grey,
                        onChanged: (value) {
                          setDialogState(() {
                            _currentVolume = value;
                          });
                          _controller?.setVolume(value.toInt());
                        },
                      ),
                    ),
                    const Icon(Icons.volume_up, color: Colors.white),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close', style: TextStyle(color: Colors.blueAccent)),
            ),
          ],
        );
      },
    );
  }
}

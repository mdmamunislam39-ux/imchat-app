import 'dart:async';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chat_messenger/models/agora_models.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/bloc/audio_rooms_bloc.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/bloc/audio_rooms_event.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/bloc/audio_rooms_state.dart';
import 'package:chat_messenger/services/agora_service.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';

enum LoopMode { none, single, playlist }

class FloatingMusicPlayer extends StatefulWidget {
  final VoidCallback onClose;
  final bool isHost;
  final String roomId;

  const FloatingMusicPlayer({
    super.key,
    required this.onClose,
    required this.isHost,
    required this.roomId,
  });

  @override
  State<FloatingMusicPlayer> createState() => _FloatingMusicPlayerState();
}

class _FloatingMusicPlayerState extends State<FloatingMusicPlayer> with SingleTickerProviderStateMixin {
  List<Map<String, String>> _musicList = [];
  int _currentIndex = -1;
  bool _isPlaying = false;
  LoopMode _loopMode = LoopMode.playlist;
  int _volume = 50;
  bool _showPlaylist = false;
  bool _showVolumeSlider = false;

  // Track position
  int _currentPositionMs = 0;
  int _totalDurationMs = 0;
  Timer? _progressTimer;

  // CD/Vinyl Rotation Animation
  late AnimationController _rotationController;

  bool _isMinimized = false;
  Offset _position = const Offset(16, 400);
  bool _isInitPosition = false;
  bool _showUserOverlay = false;

  // Firebase Ref for sync
  late DatabaseReference _musicRef;
  StreamSubscription? _musicSubscription;
  int _lastSyncMs = 0;

  // User listener data
  String _userSongName = '';
  String _userHostName = '';
  int _userDurationMs = 0;
  int _userPositionAtUpdateMs = 0;
  int _userUpdatedAtMs = 0;
  bool _userIsPlaying = false;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
    _isMinimized = !widget.isHost;

    if (widget.isHost) {
      _loadPlaylist();
      _startProgressTimer();
    }

    _musicRef = FirebaseDatabase.instance.ref('rooms/${widget.roomId}/music_state');
    if (!widget.isHost) {
      _startUserListener();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitPosition) {
      final size = MediaQuery.of(context).size;
      _position = Offset(16, size.height - 350);
      _isInitPosition = true;
    }
  }

  void _startUserListener() {
    _musicSubscription = _musicRef.onValue.listen((event) {
      if (event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        if (mounted) {
          setState(() {
            _userIsPlaying = data['isPlaying'] ?? false;
            _userSongName = data['songName'] ?? '';
            _userHostName = data['hostName'] ?? '';
            _userDurationMs = data['durationMs'] ?? 0;
            _userPositionAtUpdateMs = data['positionMs'] ?? 0;
            _userUpdatedAtMs = data['updatedAt'] ?? DateTime.now().millisecondsSinceEpoch;
          });

          if (_userIsPlaying) {
            _rotationController.repeat();
          } else {
            _rotationController.stop();
          }
        }
      }
    });

    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_userIsPlaying && mounted) {
        setState(() {}); 
      }
    });
  }

  int _calculateUserRemainingMs() {
    if (!_userIsPlaying || _userDurationMs == 0) return 0;
    int nowMs = DateTime.now().millisecondsSinceEpoch;
    int elapsedSinceUpdate = nowMs - _userUpdatedAtMs;
    int currentPos = _userPositionAtUpdateMs + elapsedSinceUpdate;
    int remaining = _userDurationMs - currentPos;
    if (remaining < 0) return 0;
    return remaining;
  }

  void _syncMusicState(bool isPlaying) {
    if (!widget.isHost) return;
    String currentSongName = 'Unknown';
    if (_currentIndex >= 0 && _currentIndex < _musicList.length) {
      currentSongName = _musicList[_currentIndex]['name'] ?? 'Unknown';
    }
    _musicRef.set({
      'isPlaying': isPlaying,
      'songName': currentSongName,
      'updatedAt': ServerValue.timestamp,
      'durationMs': _totalDurationMs,
      'positionMs': _currentPositionMs,
      'hostName': AuthController.instance.currentUser.fullname,
    });
  }

  @override
  void dispose() {
    if (widget.isHost && _isPlaying) {
      _syncMusicState(false);
    }
    _progressTimer?.cancel();
    _rotationController.dispose();
    _musicSubscription?.cancel();
    super.dispose();
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      if (_isPlaying && mounted) {
        final pos = await AgoraService().getAudioMixingCurrentPosition();
        final dur = await AgoraService().getAudioMixingDuration();
        if (mounted) {
          setState(() {
            _currentPositionMs = pos;
            if (dur > 0) {
              _totalDurationMs = dur;
            }
          });

          int nowMs = DateTime.now().millisecondsSinceEpoch;
          if (nowMs - _lastSyncMs > 5000 && _totalDurationMs > 0) {
            _syncMusicState(true);
            _lastSyncMs = nowMs;
          }
        }
      }
    });
  }

  Future<void> _loadPlaylist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('audio_room_playlist');
      if (jsonStr != null) {
        final decoded = jsonDecode(jsonStr) as List;
        setState(() {
          _musicList = decoded.map((e) => Map<String, String>.from(e as Map)).toList();
          if (_musicList.isNotEmpty) {
            _currentIndex = 0;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading playlist: $e');
    }
  }

  Future<void> _savePlaylist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('audio_room_playlist', jsonEncode(_musicList));
    } catch (e) {
      debugPrint('Error saving playlist: $e');
    }
  }

  void _playSong(int index) {
    if (index < 0 || index >= _musicList.length) return;
    _currentIndex = index;
    final song = _musicList[index];
    final path = song['path']!;

    final config = AudioMixingConfig(
      filePath: path,
      loopback: false,
      cycle: _loopMode == LoopMode.single ? -1 : 1, // -1 in Agora is infinite loop
      playoutVolume: _volume,
      publishVolume: _volume,
    );

    context.read<AudioRoomsBloc>().add(StartBackgroundMusic(config: config));
    setState(() {
      _isPlaying = true;
      _currentPositionMs = 0;
      _totalDurationMs = 0;
    });
    _rotationController.repeat();
  }

  void _togglePlay() {
    if (_currentIndex < 0 || _currentIndex >= _musicList.length) {
      _pickFile();
      return;
    }

    if (_isPlaying) {
      context.read<AudioRoomsBloc>().add(const PauseBackgroundMusic());
      _syncMusicState(false);
      setState(() {
        _isPlaying = false;
      });
      _rotationController.stop();
    } else {
      if (AgoraService().isConnected) {
        context.read<AudioRoomsBloc>().add(const ResumeBackgroundMusic());
        _syncMusicState(true);
        setState(() {
          _isPlaying = true;
        });
        _rotationController.repeat();
      } else {
        _playSong(_currentIndex);
      }
    }
  }

  void _stop() {
    context.read<AudioRoomsBloc>().add(const StopBackgroundMusic());
    _syncMusicState(false);
    setState(() {
      _isPlaying = false;
      _currentPositionMs = 0;
    });
    _rotationController.reset();
  }

  void _playNext() {
    if (_musicList.isEmpty) return;
    final nextIndex = (_currentIndex + 1) % _musicList.length;
    _playSong(nextIndex);
  }

  void _playPrevious() {
    if (_musicList.isEmpty) return;
    final prevIndex = (_currentIndex - 1 + _musicList.length) % _musicList.length;
    _playSong(prevIndex);
  }

  void _onMusicFinished() {
    if (_loopMode == LoopMode.single) {
      _playSong(_currentIndex);
    } else if (_loopMode == LoopMode.playlist) {
      _playNext();
    } else {
      if (_currentIndex + 1 < _musicList.length) {
        _playNext();
      } else {
        setState(() {
          _isPlaying = false;
          _currentPositionMs = 0;
        });
        _rotationController.reset();
        _syncMusicState(false);
      }
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final path = result.files.single.path;
        final name = result.files.single.name;

        if (path != null) {
          final newSong = {'path': path, 'name': name};
          setState(() {
            _musicList.add(newSong);
            _currentIndex = _musicList.length - 1;
          });
          await _savePlaylist();
          _playSong(_currentIndex);
        }
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking file: $e')),
        );
      }
    }
  }

  void _deleteSong(int index) async {
    setState(() {
      _musicList.removeAt(index);
      if (_currentIndex >= _musicList.length) {
        _currentIndex = _musicList.length - 1;
      }
      if (_musicList.isEmpty) {
        _currentIndex = -1;
        _isPlaying = false;
        _rotationController.reset();
        _syncMusicState(false);
      }
    });
    await _savePlaylist();
  }

  void _setVolume(int val) {
    setState(() {
      _volume = val;
    });
    AgoraService().setAudioMixingVolume(val);
  }

  void _toggleLoopMode() {
    setState(() {
      if (_loopMode == LoopMode.playlist) {
        _loopMode = LoopMode.single;
      } else if (_loopMode == LoopMode.single) {
        _loopMode = LoopMode.none;
      } else {
        _loopMode = LoopMode.playlist;
      }
    });

    if (_isPlaying && _currentIndex >= 0) {
      _playSong(_currentIndex);
    }
  }

  String _formatDuration(int ms) {
    if (ms <= 0) return '00:00';
    final sec = (ms / 1000).floor() % 60;
    final min = (ms / 60000).floor();
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  Widget _buildUserOverlay() {
    int remaining = _calculateUserRemainingMs();
    return Container(
       width: 220,
       padding: const EdgeInsets.all(12),
       decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.cyan.withValues(alpha: 0.3)),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 4)),
          ],
       ),
       child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
             const Text('Now Playing', style: TextStyle(color: Colors.cyan, fontSize: 10, fontWeight: FontWeight.bold)),
             const SizedBox(height: 2),
             Text(_userSongName, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
             const SizedBox(height: 6),
             Row(
               children: [
                 const Icon(Icons.timer_outlined, color: Colors.white70, size: 12),
                 const SizedBox(width: 4),
                 Text('${_formatDuration(_userDurationMs)} total • ${_formatDuration(remaining)} left', style: const TextStyle(color: Colors.white70, fontSize: 11)),
               ],
             ),
             const SizedBox(height: 4),
             Text('Played by $_userHostName', style: const TextStyle(color: Colors.white38, fontSize: 10)),
          ]
       )
    );
  }

  Widget _buildMinimizedCD() {
    return GestureDetector(
      onTap: () {
        if (widget.isHost) {
          setState(() {
            _isMinimized = false;
          });
        } else {
          setState(() {
             _showUserOverlay = !_showUserOverlay;
          });
        }
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          RotationTransition(
            turns: _rotationController,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: [
                    Colors.grey[900]!,
                    Colors.grey[800]!,
                    Colors.grey[700]!,
                    Colors.grey[800]!,
                    Colors.grey[900]!,
                  ],
                ),
                border: Border.all(color: Colors.black, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 5,
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.cyan, width: 1.5),
                  ),
                  child: Center(
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (!widget.isHost && _showUserOverlay)
            Positioned(
               bottom: 70,
               left: -80,
               child: _buildUserOverlay(),
            )
        ]
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isHost && !_userIsPlaying) return const SizedBox.shrink();

    if (_isMinimized || !widget.isHost) {
       return Positioned(
          left: _position.dx,
          top: _position.dy,
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                _position += details.delta;
              });
            },
            child: _buildMinimizedCD(),
          ),
       );
    }

    final String hostName = AuthController.instance.currentUser.fullname;
    final currentSongName = _currentIndex >= 0 && _currentIndex < _musicList.length
        ? (_musicList[_currentIndex]['name'] ?? 'Unknown')
        : 'No music selected';

    IconData loopIcon;
    Color loopColor = Colors.cyan;
    switch (_loopMode) {
      case LoopMode.playlist:
        loopIcon = Icons.repeat;
        break;
      case LoopMode.single:
        loopIcon = Icons.repeat_one;
        break;
      case LoopMode.none:
        loopIcon = Icons.repeat;
        loopColor = Colors.white54;
        break;
    }

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _isMinimized = true;
              });
            },
            behavior: HitTestBehavior.translucent,
            child: Container(color: Colors.transparent),
          ),
        ),
        Positioned(
          left: _position.dx,
          top: _position.dy,
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                _position += details.delta;
              });
            },
            child: BlocListener<AudioRoomsBloc, AudioRoomsState>(
              listener: (context, state) {
                if (state is BackgroundMusicStopped) {
                  _onMusicFinished();
                } else if (state is BackgroundMusicStarted) {
                  setState(() {
                    _isPlaying = true;
                  });
                  _rotationController.repeat();
                  _syncMusicState(true);
                } else if (state is BackgroundMusicPaused) {
                  setState(() {
                    _isPlaying = false;
                  });
                  _rotationController.stop();
                  _syncMusicState(false);
                } else if (state is BackgroundMusicResumed) {
                  setState(() {
                    _isPlaying = true;
                  });
                  _rotationController.repeat();
                  _syncMusicState(true);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                width: MediaQuery.of(context).size.width - 32,
                decoration: BoxDecoration(
                  color: const Color(0xE61E1E1E), // Dark transparent background
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 15,
                      spreadRadius: 2,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Player Controls Header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Spinning CD Disk
                            RotationTransition(
                              turns: _rotationController,
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: SweepGradient(
                                    colors: [
                                      Colors.grey[900]!,
                                      Colors.grey[800]!,
                                      Colors.grey[700]!,
                                      Colors.grey[800]!,
                                      Colors.grey[900]!,
                                    ],
                                  ),
                                  border: Border.all(color: Colors.black, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.5),
                                      blurRadius: 5,
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[900],
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.cyan, width: 1.5),
                                    ),
                                    child: Center(
                                      child: Container(
                                        width: 4,
                                        height: 4,
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Song Info and Status
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    currentSongName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '★$hostName is playing music',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                    ),
                                    maxLines: 1,
                                  ),
                                ],
                              ),
                            ),

                            // Upper Right action buttons
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.power_settings_new, color: Colors.redAccent, size: 20),
                                  onPressed: () {
                                    _stop();
                                    widget.onClose();
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                const SizedBox(width: 12),
                                IconButton(
                                  icon: Icon(loopIcon, color: loopColor, size: 20),
                                  onPressed: _toggleLoopMode,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                const SizedBox(width: 12),
                                IconButton(
                                  icon: const Icon(Icons.minimize, color: Colors.white70, size: 22),
                                  onPressed: () {
                                    setState(() {
                                      _isMinimized = true;
                                    });
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                const SizedBox(width: 12),
                                IconButton(
                                  icon: const Icon(Icons.close, color: Colors.white70, size: 22),
                                  onPressed: widget.onClose,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Progress Slider and Timers
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Text(
                              _formatDuration(_currentPositionMs),
                              style: const TextStyle(color: Colors.white54, fontSize: 10),
                            ),
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 3.0,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12.0),
                                  activeTrackColor: Colors.cyan,
                                  inactiveTrackColor: Colors.white24,
                                  thumbColor: Colors.white,
                                ),
                                child: Slider(
                                  value: _currentPositionMs.toDouble().clamp(0.0, _totalDurationMs > 0 ? _totalDurationMs.toDouble() : 1.0),
                                  min: 0.0,
                                  max: _totalDurationMs > 0 ? _totalDurationMs.toDouble() : 1.0,
                                  onChanged: (val) {
                                    setState(() {
                                      _currentPositionMs = val.toInt();
                                    });
                                  },
                                  onChangeEnd: (val) {
                                    AgoraService().setAudioMixingPosition(val.toInt());
                                  },
                                ),
                              ),
                            ),
                            Text(
                              _formatDuration(_totalDurationMs),
                              style: const TextStyle(color: Colors.white54, fontSize: 10),
                            ),
                          ],
                        ),
                      ),

                      // Volume slide & Playback button row
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Volume Control
                            Row(
                              children: [
                                IconButton(
                                  icon: Icon(
                                    _volume == 0 ? Icons.volume_off : Icons.volume_up,
                                    color: Colors.white70,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _showVolumeSlider = !_showVolumeSlider;
                                    });
                                  },
                                ),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: _showVolumeSlider ? 100 : 0,
                                  height: 30,
                                  child: _showVolumeSlider
                                      ? SliderTheme(
                                          data: SliderTheme.of(context).copyWith(
                                            trackHeight: 2.0,
                                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5.0),
                                            activeTrackColor: Colors.cyan,
                                            inactiveTrackColor: Colors.white24,
                                            thumbColor: Colors.white,
                                          ),
                                          child: Slider(
                                            value: _volume.toDouble(),
                                            min: 0.0,
                                            max: 100.0,
                                            onChanged: (val) => _setVolume(val.toInt()),
                                          ),
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              ],
                            ),

                            // Skip Prev, Play/Pause, Skip Next
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.skip_previous, color: Colors.white, size: 24),
                                  onPressed: _playPrevious,
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: _togglePlay,
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.cyan,
                                    ),
                                    child: Icon(
                                      _isPlaying ? Icons.pause : Icons.play_arrow,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.skip_next, color: Colors.white, size: 24),
                                  onPressed: _playNext,
                                ),
                              ],
                            ),

                            // Playlist button
                            IconButton(
                              icon: Icon(
                                Icons.queue_music,
                                color: _showPlaylist ? Colors.cyan : Colors.white70,
                                size: 22,
                              ),
                              onPressed: () {
                                setState(() {
                                  _showPlaylist = !_showPlaylist;
                                });
                              },
                            ),
                          ],
                        ),
                      ),

                      // Expanding Playlist Box
                      if (_showPlaylist) ...[
                        Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 200),
                          color: Colors.black12,
                          child: _musicList.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 24),
                                  child: Center(
                                    child: Text(
                                      'Playlist is empty. Add some music!',
                                      style: TextStyle(color: Colors.white54, fontSize: 12),
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  itemCount: _musicList.length,
                                  itemBuilder: (context, idx) {
                                    final isCurrent = idx == _currentIndex;
                                    return Container(
                                      color: isCurrent ? Colors.cyan.withValues(alpha: 0.08) : Colors.transparent,
                                      child: ListTile(
                                        dense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                                        leading: Icon(
                                          Icons.music_note,
                                          color: isCurrent ? Colors.cyan : Colors.white54,
                                          size: 16,
                                        ),
                                        title: Text(
                                          _musicList[idx]['name'] ?? 'Unknown',
                                          style: TextStyle(
                                            color: isCurrent ? Colors.cyan : Colors.white,
                                            fontSize: 12,
                                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (isCurrent && _isPlaying)
                                              const Icon(Icons.volume_up, color: Colors.cyan, size: 14)
                                            else
                                              IconButton(
                                                icon: const Icon(Icons.delete_outline, color: Colors.white38, size: 14),
                                                onPressed: () => _deleteSong(idx),
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                              ),
                                          ],
                                        ),
                                        onTap: () => _playSong(idx),
                                      ),
                                    );
                                  },
                                ),
                        ),
                        Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: ElevatedButton.icon(
                            onPressed: _pickFile,
                            icon: const Icon(Icons.add, size: 14),
                            label: const Text('Add Music', style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.cyan,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              minimumSize: const Size(double.infinity, 36),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

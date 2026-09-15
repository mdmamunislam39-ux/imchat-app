import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get/get.dart';
import '../../../models/agora_models.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/bloc/audio_rooms_bloc.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/bloc/audio_rooms_event.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/bloc/audio_rooms_state.dart';

/// Advanced Agora audio controls widget with all features
class AgoraControls extends StatefulWidget {
  final String roomId;
  final String channelName;
  final int uid;
  final String userId;
  final String userName;
  final String? userImageUrl;
  final VoidCallback? onLeaveRoom;

  const AgoraControls({
    super.key,
    required this.roomId,
    required this.channelName,
    required this.uid,
    required this.userId,
    required this.userName,
    this.userImageUrl,
    this.onLeaveRoom,
  });

  @override
  State<AgoraControls> createState() => _AgoraControlsState();
}

class _AgoraControlsState extends State<AgoraControls>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  bool _showAdvancedControls = false;
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  AgoraConnectionState _connectionState = AgoraConnectionState.disconnected;
  AudioQuality _currentQuality = AudioQuality.high;
  AudioEffect _currentEffect = AudioEffect.none;
  VoiceChanger _currentVoiceChanger = VoiceChanger.none;
  AgoraStats? _currentStats;
  List<AgoraUser> _users = [];

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeAgora();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _initializeAgora() {
    final bloc = context.read<AudioRoomsBloc>();

    // Initialize Agora
    bloc.add(InitializeAgora(
      roomId: widget.roomId,
      userId: widget.userId,
      userName: widget.userName,
      userImageUrl: widget.userImageUrl,
      audioQuality: _currentQuality,
    ));
  }

  void _joinChannel() {
    final bloc = context.read<AudioRoomsBloc>();
    bloc.add(JoinAgoraChannel(
      channelName: widget.channelName,
      uid: widget.uid,
      userId: widget.userId,
      userName: widget.userName,
      userImageUrl: widget.userImageUrl,
      isMuted: true, // Default to muted for agora controls
    ));
  }

  void _leaveChannel() {
    final bloc = context.read<AudioRoomsBloc>();
    bloc.add(const LeaveAgoraChannel());
    widget.onLeaveRoom?.call();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AudioRoomsBloc, AudioRoomsState>(
      listener: (context, state) {
        _handleStateChanges(state);
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.8),
              Colors.black.withValues(alpha: 0.9),
            ],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildConnectionStatus(),
            _buildMainControls(),
            if (_showAdvancedControls) _buildAdvancedControls(),
            _buildStatsAndUsers(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _handleStateChanges(AudioRoomsState state) {
    if (state is AgoraInitialized) {
      _joinChannel();
    } else if (state is AgoraChannelJoined) {
      setState(() {
        _connectionState = state.connectionState;
        _isMuted = state.isMuted;
        _isSpeakerOn = state.isSpeakerOn;
        _currentQuality = state.audioQuality;
        _currentEffect = state.audioEffect;
        _currentVoiceChanger = state.voiceChanger;
        _users = state.users;
      });
      WidgetsBinding.instance.scheduleFrame();
    } else if (state is MicrophoneToggled) {
      setState(() {
        _isMuted = state.isMuted;
      });
      if (!_isMuted) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
      }
      WidgetsBinding.instance.scheduleFrame();
    } else if (state is SpeakerToggled) {
      setState(() {
        _isSpeakerOn = state.isSpeakerOn;
      });
      WidgetsBinding.instance.scheduleFrame();
    } else if (state is AgoraConnectionUpdated) {
      setState(() {
        _connectionState = state.state;
      });
      WidgetsBinding.instance.scheduleFrame();
    } else if (state is AudioQualityChanged) {
      setState(() {
        _currentQuality = state.quality;
      });
      WidgetsBinding.instance.scheduleFrame();
    } else if (state is AudioEffectApplied) {
      setState(() {
        _currentEffect = state.effect;
      });
      WidgetsBinding.instance.scheduleFrame();
    } else if (state is VoiceChangerApplied) {
      setState(() {
        _currentVoiceChanger = state.changer;
      });
      WidgetsBinding.instance.scheduleFrame();
    } else if (state is AgoraStatsUpdated) {
      setState(() {
        _currentStats = state.stats;
      });
    } else if (state is AgoraUserUpdated) {
      // Handle user updates if needed
    } else if (state is AgoraError) {
      _showErrorSnackbar(state.message);
    }
  }

  Widget _buildConnectionStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _getConnectionColor(),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _connectionState.displayName,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (_currentStats != null) ...[
            const SizedBox(width: 16),
            Text(
              _currentStats!.connectionQuality,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 10,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMainControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Microphone control
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: !_isMuted ? _pulseAnimation.value : 1.0,
                child: _buildControlButton(
                  icon: _isMuted ? Icons.mic_off : Icons.mic,
                  isActive: !_isMuted,
                  onTap: () {
                    context
                        .read<AudioRoomsBloc>()
                        .add(SetMicrophoneMute(muted: !_isMuted));
                  },
                  color: _isMuted ? Colors.red : Colors.green,
                ),
              );
            },
          ),

          // Speaker control
          _buildControlButton(
            icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
            isActive: _isSpeakerOn,
            onTap: () {
              context.read<AudioRoomsBloc>().add(const ToggleSpeaker());
            },
            color: Colors.blue,
          ),

          // Advanced controls toggle
          _buildControlButton(
            icon: Icons.tune,
            isActive: _showAdvancedControls,
            onTap: () {
              setState(() {
                _showAdvancedControls = !_showAdvancedControls;
              });
            },
            color: Colors.purple,
          ),

          // Leave room
          _buildControlButton(
            icon: Icons.call_end,
            isActive: false,
            onTap: _leaveChannel,
            color: Colors.red,
            size: 28,
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedControls() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Audio Quality
          _buildAdvancedSection(
            title: 'Audio Quality',
            child: _buildQualitySelector(),
          ),
          const SizedBox(height: 16),

          // Audio Effects
          _buildAdvancedSection(
            title: 'Audio Effects',
            child: _buildEffectSelector(),
          ),
          const SizedBox(height: 16),

          // Voice Changer
          _buildAdvancedSection(
            title: 'Voice Changer',
            child: _buildVoiceChangerSelector(),
          ),
          const SizedBox(height: 16),

          // Background Music
          _buildAdvancedSection(
            title: 'Background Music',
            child: _buildMusicControls(),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildQualitySelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: AudioQuality.values.map((quality) {
          final isSelected = _currentQuality == quality;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                context
                    .read<AudioRoomsBloc>()
                    .add(SetAudioQuality(quality: quality));
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue : Colors.grey[800],
                  borderRadius: BorderRadius.circular(16),
                  border: isSelected
                      ? Border.all(color: Colors.blue, width: 2)
                      : null,
                ),
                child: Text(
                  quality.displayName,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[400],
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEffectSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: AudioEffect.values.map((effect) {
          final isSelected = _currentEffect == effect;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                context
                    .read<AudioRoomsBloc>()
                    .add(ApplyAudioEffect(effect: effect));
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.purple : Colors.grey[800],
                  borderRadius: BorderRadius.circular(16),
                  border: isSelected
                      ? Border.all(color: Colors.purple, width: 2)
                      : null,
                ),
                child: Text(
                  effect.displayName,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[400],
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildVoiceChangerSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: VoiceChanger.values.map((changer) {
          final isSelected = _currentVoiceChanger == changer;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                context
                    .read<AudioRoomsBloc>()
                    .add(ApplyVoiceChanger(changer: changer));
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.orange : Colors.grey[800],
                  borderRadius: BorderRadius.circular(16),
                  border: isSelected
                      ? Border.all(color: Colors.orange, width: 2)
                      : null,
                ),
                child: Text(
                  changer.displayName,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[400],
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMusicControls() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _showMusicPicker(),
            icon: const Icon(Icons.music_note, size: 16),
            label: const Text('Add Music'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: () {
            context.read<AudioRoomsBloc>().add(const StopBackgroundMusic());
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red[700],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          ),
          child: const Icon(Icons.stop, size: 16),
        ),
      ],
    );
  }

  Widget _buildStatsAndUsers() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Users count
          Row(
            children: [
              const Icon(Icons.people, color: Colors.white60, size: 16),
              const SizedBox(width: 4),
              Text(
                '${_users.length} users',
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                ),
              ),
            ],
          ),

          // Network stats
          if (_currentStats != null)
            Row(
              children: [
                const Icon(Icons.signal_cellular_alt,
                    color: Colors.white60, size: 16),
                const SizedBox(width: 4),
                Text(
                  '${_currentStats!.gatewayRtt}ms',
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(_currentStats!.totalDataUsageMB).toStringAsFixed(1)}MB',
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    required Color color,
    double size = 24,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.2) : Colors.grey[800],
          border: Border.all(
            color: isActive ? color : Colors.grey[600]!,
            width: 2,
          ),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isActive ? color : Colors.grey[400],
          size: size,
        ),
      ),
    );
  }

  Color _getConnectionColor() {
    switch (_connectionState) {
      case AgoraConnectionState.connected:
        return Colors.green;
      case AgoraConnectionState.connecting:
      case AgoraConnectionState.reconnecting:
        return Colors.orange;
      case AgoraConnectionState.failed:
        return Colors.red;
      case AgoraConnectionState.disconnected:
        return Colors.grey;
    }
  }

  void _showMusicPicker() {
    // Show a dialog to pick music files
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Background Music'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.folder),
              title: const Text('Choose from Files'),
              onTap: () {
                Navigator.pop(context);
                _pickMusicFile();
              },
            ),
            ListTile(
              leading: const Icon(Icons.library_music),
              title: const Text('Default Music'),
              onTap: () {
                Navigator.pop(context);
                _playDefaultMusic();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _pickMusicFile() async {
    // Implementation for file picker would go here
    // For now, show a placeholder
    Get.snackbar(
      'Music',
      'File picker integration needed',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  void _playDefaultMusic() {
    // Play a default music file
    final config = AudioMixingConfig(
      filePath: 'assets/sound.mp3', // Your default music file
      loopback: false,
      cycle: -1, // Loop indefinitely
      playoutVolume: 50,
      publishVolume: 50,
    );

    context.read<AudioRoomsBloc>().add(StartBackgroundMusic(config: config));
  }

  void _showErrorSnackbar(String message) {
    Get.snackbar(
      'Error',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.red[700],
      colorText: Colors.white,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }
}

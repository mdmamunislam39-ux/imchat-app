import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:chat_messenger/components/cached_circle_avatar.dart';
import 'package:chat_messenger/components/default_button.dart';
import 'package:chat_messenger/config/theme_config.dart';
import 'package:chat_messenger/helpers/dialog_helper.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:chat_messenger/models/audio_room_v2.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/bloc/audio_rooms_bloc.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/bloc/audio_rooms_event.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/bloc/audio_rooms_state.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Reusable bottom sheet widget for creating audio rooms
class CreateRoomBottomSheet extends StatefulWidget {
  final User currentUser;
  final VoidCallback? onRoomCreated;
  final Function(AudioRoomV2)? onRoomCreatedAndNavigate;
  final AudioRoomsBloc audioRoomsBloc;

  const CreateRoomBottomSheet({
    super.key,
    required this.currentUser,
    required this.audioRoomsBloc,
    this.onRoomCreated,
    this.onRoomCreatedAndNavigate,
  });

  @override
  State<CreateRoomBottomSheet> createState() => _CreateRoomBottomSheetState();
}

class _CreateRoomBottomSheetState extends State<CreateRoomBottomSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _roomNameController = TextEditingController();
  final TextEditingController _roomDescriptionController =
      TextEditingController();

  File? _selectedImageFile;
  bool _isLoading = false;
  String _selectedCategory = 'Game';

  @override
  void dispose() {
    _roomNameController.dispose();
    _roomDescriptionController.dispose();
    super.dispose();
  }

  /// Handle image selection
  Future<void> _handleImageSelection() async {
    try {
      final File? resultFile = await DialogHelper.showPickImageDialog(
        isAvatar: true,
      );

      if (resultFile != null) {
        setState(() {
          _selectedImageFile = resultFile;
        });
      }
    } catch (e) {
      _showErrorSnackBar('Failed to select image: ${e.toString()}');
    }
  }

  /// Handle room creation
  Future<void> _handleCreateRoom() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Direct Firestore check to prevent ANY duplicate active rooms (Audio or Live)
      // The user can only have ONE active room where they are the creator.
      final existingRoomsQuery = await FirebaseFirestore.instance
          .collection('audio_rooms_v2')
          .where('creatorId', isEqualTo: widget.currentUser.userId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (existingRoomsQuery.docs.isNotEmpty) {
        final existingRoom = AudioRoomV2.fromFirestore(existingRoomsQuery.docs.first);
        debugPrint('▶️ [AudioRooms] Found existing active room in Firestore. Resuming instead of creating new.');
        
        widget.audioRoomsBloc.add(ResumeAudioRoom(room: existingRoom));
        
        if (mounted) {
          Navigator.of(context).pop();
        }
        
        if (widget.onRoomCreatedAndNavigate != null) {
          widget.onRoomCreatedAndNavigate!(existingRoom);
        } else {
          widget.onRoomCreated?.call();
        }
        return;
      }
    } catch (e) {
      debugPrint('Error checking existing rooms: $e');
      // If error occurs, we just proceed to try creating.
    }

    setState(() {
      _isLoading = true;
    });

    try {
      widget.audioRoomsBloc.add(
        CreateAudioRoom(
          name: _roomNameController.text.trim(),
          description: _roomDescriptionController.text.trim(),
          imageFile: _selectedImageFile,
          creatorId: widget.currentUser.userId,
          creatorName: widget.currentUser.fullname,
          creatorImageUrl: widget.currentUser.photoUrl,
          creatorFrameId: widget.currentUser.customization?.selectedFrameId,
          category: _selectedCategory,
          settings: const AudioRoomSettings(
            allowRequestToSpeak: true,
            autoMuteNewParticipants: true,
            maxSpeakers: 8,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Failed to create room: ${e.toString()}');
    }
  }

  /// Show error snackbar
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  /// Show success snackbar
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: widget.audioRoomsBloc,
      child: BlocListener<AudioRoomsBloc, AudioRoomsState>(
        listener: (context, state) {
          if (state is AudioRoomCreated) {
            setState(() {
              _isLoading = false;
            });
            _showSuccessSnackBar('Room created successfully!');
            Navigator.of(context).pop();

            // Call the navigation callback if provided
            if (widget.onRoomCreatedAndNavigate != null) {
              widget.onRoomCreatedAndNavigate!(state.room);
            } else {
              // Fallback to the old callback
              widget.onRoomCreated?.call();
            }
          } else if (state is AudioRoomCreationFailed) {
            setState(() {
              _isLoading = false;
            });
            _showErrorSnackBar(state.message);
          } else if (state is CreatingAudioRoom) {
            setState(() {
              _isLoading = true;
            });
          }
        },
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: BlocBuilder<AudioRoomsBloc, AudioRoomsState>(
            builder: (context, state) {
              AudioRoomV2? existingRoom;
              if (state is AudioRoomsLoaded) {
                for (final room in state.userRooms) {
                  if (room.creatorId == widget.currentUser.userId) {
                    existingRoom = room;
                    break;
                  }
                }
                if (existingRoom == null) {
                  for (final room in state.rooms) {
                    if (room.creatorId == widget.currentUser.userId) {
                      existingRoom = room;
                      break;
                    }
                  }
                }
              }

              return Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min, // Use min size for height
                  children: [
                    // Close button and Title
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            existingRoom != null
                                ? 'My Room'
                                : 'Create New Room',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                    // Only show fields if no existing room
                    if (existingRoom == null) ...[
                      // Room image selection
                      Center(
                        child: GestureDetector(
                          onTap: _handleImageSelection,
                          child: Stack(
                            children: [
                              // Photo
                              Container(
                                child: _selectedImageFile != null
                                    ? CircleAvatar(
                                        radius: 60,
                                        backgroundImage:
                                            FileImage(_selectedImageFile!),
                                      )
                                    : CachedCircleAvatar(
                                        radius: 50,
                                        iconSize: 60,
                                        borderColor: primaryColor,
                                        backgroundColor:
                                            primaryColor.withValues(alpha: 0.1),
                                        imageUrl: widget.currentUser.photoUrl,
                                      ),
                              ),
                              // Camera icon
                              const Positioned(
                                right: 0,
                                bottom: 10,
                                child: CircleAvatar(
                                  backgroundColor: primaryColor,
                                  radius: 18,
                                  child: Icon(
                                    IconlyBold.camera,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Room name field
                      TextFormField(
                        controller: _roomNameController,
                        decoration: InputDecoration(
                          filled: false,
                          hintText: 'Enter room name',
                          hintStyle: TextStyle(color: Colors.grey[600]),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: primaryColor, width: 2),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.red),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Colors.red, width: 2),
                          ),
                        ),
                        validator: (String? name) {
                          if (name == null || name.trim().isEmpty) {
                            return 'Please enter a room name';
                          }
                          if (name.trim().length < 3) {
                            return 'Room name must be at least 3 characters';
                          }
                          if (name.trim().length > 50) {
                            return 'Room name must be less than 50 characters';
                          }
                          return null;
                        },
                      ),

                      // Room description field
                      TextFormField(
                        controller: _roomDescriptionController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          filled: false,
                          hintText: 'Enter room description',
                          hintStyle: TextStyle(color: Colors.grey[600]),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: primaryColor, width: 2),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.red),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Colors.red, width: 2),
                          ),
                        ),
                        validator: (String? description) {
                          if (description == null ||
                              description.trim().isEmpty) {
                            return 'Please enter a room description';
                          }
                          if (description.trim().length < 10) {
                            return 'Description must be at least 10 characters';
                          }
                          if (description.trim().length > 200) {
                            return 'Description must be less than 200 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // Category selection
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Category',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            {'name': 'Game', 'emoji': '🎮'},
                            {'name': 'PK', 'emoji': '⚔️'},
                            {'name': 'Event', 'emoji': '🏆'},
                            {'name': 'Islamic', 'emoji': '☪️'},
                            {'name': 'Talk Show', 'emoji': '🎤'},
                          ].map((cat) {
                            final category = cat['name']!;
                            final emoji = cat['emoji']!;
                            final isSelected = _selectedCategory == category;
                            return Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: ChoiceChip(
                                label: Text(
                                  '$emoji $category',
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : Colors.black87,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                selected: isSelected,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() {
                                      _selectedCategory = category;
                                    });
                                  }
                                },
                                selectedColor: primaryColor,
                                backgroundColor: Colors.grey[200],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],

                    if (existingRoom != null) ...[
                      const SizedBox(height: 20),
                      // Show current room info if it exists
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: existingRoom.imageUrl != null
                            ? NetworkImage(existingRoom.imageUrl!)
                            : null,
                        child: existingRoom.imageUrl == null
                            ? const Icon(Icons.room, size: 50)
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        existingRoom.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        existingRoom.description,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Action button
                    Padding(
                      padding: const EdgeInsets.only(top: 20, bottom: 10),
                      child: DefaultButton(
                        height: 50,
                        width: double.maxFinite,
                        text: existingRoom != null
                            ? 'Enter My Room'
                            : 'Create Room',
                        isLoading: _isLoading,
                        onPress: _isLoading
                            ? null
                            : (existingRoom != null
                                ? () {
                                    Navigator.of(context).pop();
                                    widget.audioRoomsBloc.add(JoinAudioRoom(
                                      roomId: existingRoom!.id,
                                      userId: widget.currentUser.userId,
                                      userName: widget.currentUser.fullname,
                                      userImageUrl: widget.currentUser.photoUrl,
                                      userFrameId: widget.currentUser
                                          .customization?.selectedFrameId,
                                    ));
                                  }
                                : _handleCreateRoom),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Helper function to show the create room bottom sheet
Future<void> showCreateRoomBottomSheet({
  required BuildContext context,
  required User currentUser,
  required AudioRoomsBloc audioRoomsBloc,
  VoidCallback? onRoomCreated,
  Function(AudioRoomV2)? onRoomCreatedAndNavigate,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: CreateRoomBottomSheet(
          currentUser: currentUser,
          audioRoomsBloc: audioRoomsBloc,
          onRoomCreated: onRoomCreated,
          onRoomCreatedAndNavigate: onRoomCreatedAndNavigate,
        ),
      );
    },
  );
}

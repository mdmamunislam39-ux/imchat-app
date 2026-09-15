import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:chat_messenger/api/story_api.dart';
import 'package:chat_messenger/config/theme_config.dart';
import 'package:chat_messenger/helpers/dialog_helper.dart';
import 'package:chat_messenger/routes/app_routes.dart';
import 'package:get/get.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';

/// Representation of a freehand doodle stroke
class DoodleLine {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;

  DoodleLine({
    required this.points,
    required this.color,
    required this.strokeWidth,
  });
}

/// Custom painter for doodles
class DoodlePainter extends CustomPainter {
  final List<DoodleLine> lines;
  final DoodleLine? currentLine;

  DoodlePainter({required this.lines, this.currentLine});

  @override
  void paint(Canvas canvas, Size size) {
    for (final line in lines) {
      _drawLine(canvas, line);
    }
    if (currentLine != null) {
      _drawLine(canvas, currentLine!);
    }
  }

  void _drawLine(Canvas canvas, DoodleLine line) {
    if (line.points.isEmpty) return;
    final paint = Paint()
      ..color = line.color
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = line.strokeWidth
      ..style = PaintingStyle.stroke;

    if (line.points.length == 1) {
      canvas.drawCircle(line.points.first, line.strokeWidth / 2, paint);
      return;
    }

    final path = Path();
    path.moveTo(line.points.first.dx, line.points.first.dy);
    for (int i = 1; i < line.points.length; i++) {
      path.lineTo(line.points[i].dx, line.points[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant DoodlePainter oldDelegate) => true;
}

/// Model for interactive draggable overlays (Text, Emoji, Location, Mention)
class StoryOverlayItem {
  final String id;
  String text;
  Offset position;
  Color color;
  Color? backgroundColor;
  double fontSize;
  bool isSticker;
  bool isLocation;
  bool isMention;

  StoryOverlayItem({
    required this.id,
    required this.text,
    required this.position,
    this.color = Colors.white,
    this.backgroundColor,
    this.fontSize = 26,
    this.isSticker = false,
    this.isLocation = false,
    this.isMention = false,
  });
}

/// Photo filter presets
enum StoryFilter {
  normal,
  vivid,
  warm,
  cool,
  vintage,
  bw,
  sepia,
  cyberpunk,
}

class StoryEditorScreen extends StatefulWidget {
  final File imageFile;

  const StoryEditorScreen({super.key, required this.imageFile});

  @override
  State<StoryEditorScreen> createState() => _StoryEditorScreenState();
}

class _StoryEditorScreenState extends State<StoryEditorScreen> {
  final GlobalKey _repaintBoundaryKey = GlobalKey();

  late File _currentImage;
  int _rotationTurns = 0;
  StoryFilter _activeFilter = StoryFilter.normal;
  bool _showFilterBar = false;

  // Doodling state
  bool _isDoodling = false;
  Color _doodleColor = Colors.white;
  final double _doodleStrokeWidth = 5.0;
  final List<DoodleLine> _doodleLines = [];
  DoodleLine? _activeDoodleLine;

  // Overlay items (stickers, text, location, mentions)
  final List<StoryOverlayItem> _overlays = [];

  // Music & Privacy
  String? _selectedMusic;
  String _privacy = 'Everyone';
  bool _isPosting = false;

  final List<Color> _palette = const [
    Colors.white,
    Color(0xFFFF2A6D),
    Color(0xFFFFD166),
    Color(0xFF06D6A0),
    Color(0xFF118AB2),
    Color(0xFF7928CA),
    Color(0xFFFF6B6B),
    Colors.black,
  ];

  @override
  void initState() {
    super.initState();
    _currentImage = widget.imageFile;
  }

  // --- Filter Color Matrices ---
  ColorFilter? _getColorFilter(StoryFilter filter) {
    switch (filter) {
      case StoryFilter.normal:
        return null;
      case StoryFilter.vivid:
        return const ColorFilter.matrix(<double>[
          1.2, 0, 0, 0, 0,
          0, 1.2, 0, 0, 0,
          0, 0, 1.2, 0, 0,
          0, 0, 0, 1, 0,
        ]);
      case StoryFilter.warm:
        return const ColorFilter.matrix(<double>[
          1.2, 0, 0, 0, 15,
          0, 1.05, 0, 0, 5,
          0, 0, 0.85, 0, -10,
          0, 0, 0, 1, 0,
        ]);
      case StoryFilter.cool:
        return const ColorFilter.matrix(<double>[
          0.9, 0, 0, 0, -10,
          0, 1.05, 0, 0, 5,
          0, 0, 1.3, 0, 20,
          0, 0, 0, 1, 0,
        ]);
      case StoryFilter.vintage:
        return const ColorFilter.matrix(<double>[
          0.9, 0.1, 0.1, 0, 20,
          0.1, 0.8, 0.1, 0, 15,
          0.1, 0.1, 0.6, 0, 10,
          0, 0, 0, 1, 0,
        ]);
      case StoryFilter.bw:
        return const ColorFilter.matrix(<double>[
          0.33, 0.59, 0.11, 0, 0,
          0.33, 0.59, 0.11, 0, 0,
          0.33, 0.59, 0.11, 0, 0,
          0, 0, 0, 1, 0,
        ]);
      case StoryFilter.sepia:
        return const ColorFilter.matrix(<double>[
          0.393, 0.769, 0.189, 0, 0,
          0.349, 0.686, 0.168, 0, 0,
          0.272, 0.534, 0.131, 0, 0,
          0, 0, 0, 1, 0,
        ]);
      case StoryFilter.cyberpunk:
        return const ColorFilter.matrix(<double>[
          1.3, 0, 0.2, 0, 20,
          0, 0.9, 0.1, 0, 0,
          0.2, 0, 1.4, 0, 30,
          0, 0, 0, 1, 0,
        ]);
    }
  }

  // --- Add Text Tool ---
  void _openTextDialog({StoryOverlayItem? existingItem}) {
    final textController =
        TextEditingController(text: existingItem?.text ?? '');
    Color selectedColor = existingItem?.color ?? Colors.white;
    bool hasBackground = existingItem?.backgroundColor != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                top: 20,
                left: 16,
                right: 16,
              ),
              decoration: const BoxDecoration(
                color: Color(0xEE12121A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              hasBackground
                                  ? Icons.font_download
                                  : Icons.font_download_outlined,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              setModalState(() {
                                hasBackground = !hasBackground;
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 8),
                            ),
                            onPressed: () {
                              final text = textController.text.trim();
                              if (text.isNotEmpty) {
                                setState(() {
                                  if (existingItem != null) {
                                    existingItem.text = text;
                                    existingItem.color = selectedColor;
                                    existingItem.backgroundColor = hasBackground
                                        ? (selectedColor == Colors.white
                                            ? Colors.black87
                                            : Colors.white70)
                                        : null;
                                  } else {
                                    _overlays.add(
                                      StoryOverlayItem(
                                        id: DateTime.now()
                                            .millisecondsSinceEpoch
                                            .toString(),
                                        text: text,
                                        position: const Offset(100, 250),
                                        color: selectedColor,
                                        backgroundColor: hasBackground
                                            ? (selectedColor == Colors.white
                                                ? Colors.black87
                                                : Colors.white70)
                                            : null,
                                      ),
                                    );
                                  }
                                });
                              }
                              Navigator.pop(ctx);
                            },
                            child: const Text('Done',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: textController,
                    autofocus: true,
                    maxLines: null,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selectedColor,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      backgroundColor: hasBackground
                          ? (selectedColor == Colors.white
                              ? Colors.black87
                              : Colors.white70)
                          : Colors.transparent,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Type text here...',
                      hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5), fontSize: 24),
                      border: InputBorder.none,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Color picker row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: _palette.map((color) {
                        final isSelected = selectedColor == color;
                        return GestureDetector(
                          onTap: () =>
                              setModalState(() => selectedColor = color),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.transparent,
                                width: 3,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                          color: color.withValues(alpha: 0.8),
                                          blurRadius: 8)
                                    ]
                                  : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- Sticker / Emoji Picker ---
  void _openStickerPicker() {
    final List<String> popularEmojis = [
      '🔥', '❤️', '😍', '👑', '✨', '💯', '🥳', '🎉',
      '😎', '🥰', '🚀', '🌟', '💖', '👏', '🍕', '🍦',
      '🌹', '🦋', '⚡', '☕', '🎵', '💥', '🤩', '🤙',
      '🌈', '🌺', '💎', '🦄', '🏖️', '🎬', '🏆', '💫'
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xEE12121A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: 320,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Stickers & Emojis',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: GridView.builder(
                  itemCount: popularEmojis.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemBuilder: (_, index) {
                    final emoji = popularEmojis[index];
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _overlays.add(
                            StoryOverlayItem(
                              id: DateTime.now()
                                  .millisecondsSinceEpoch
                                  .toString(),
                              text: emoji,
                              position: const Offset(150, 300),
                              fontSize: 54,
                              isSticker: true,
                            ),
                          );
                        });
                        Navigator.pop(ctx);
                      },
                      child: Center(
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 34),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Location Tag ---
  void _addLocationTag() {
    final controller = TextEditingController(text: 'Dhaka, Bangladesh');
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1B1B26),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.location_on, color: primaryColor),
              SizedBox(width: 8),
              Text('Add Location', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Enter city or place...',
              hintStyle: TextStyle(color: Colors.white54),
              enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white30)),
              focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: primaryColor)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
              onPressed: () {
                final loc = controller.text.trim();
                if (loc.isNotEmpty) {
                  setState(() {
                    _overlays.add(
                      StoryOverlayItem(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        text: loc,
                        position: const Offset(80, 200),
                        fontSize: 16,
                        isLocation: true,
                      ),
                    );
                  });
                }
                Navigator.pop(ctx);
              },
              child: const Text('Add', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // --- Mention Tag ---
  void _addMentionTag() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1B1B26),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.alternate_email, color: primaryColor),
              SizedBox(width: 8),
              Text('Mention Friend', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              prefixText: '@',
              prefixStyle: TextStyle(color: primaryColor, fontSize: 18),
              hintText: 'username',
              hintStyle: TextStyle(color: Colors.white54),
              enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white30)),
              focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: primaryColor)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  setState(() {
                    _overlays.add(
                      StoryOverlayItem(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        text: '@$name',
                        position: const Offset(120, 220),
                        fontSize: 16,
                        isMention: true,
                      ),
                    );
                  });
                }
                Navigator.pop(ctx);
              },
              child:
                  const Text('Mention', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // --- Music Selector ---
  void _openMusicSelector() {
    final List<Map<String, String>> musicList = [
      {'title': 'Chill Vibes', 'artist': 'Lofi Beats', 'icon': '🎧'},
      {'title': 'Night Drive', 'artist': 'Synthwave 80s', 'icon': '🚗'},
      {'title': 'Golden Hour', 'artist': 'Acoustic Sunset', 'icon': '🌅'},
      {'title': 'Trending Viral', 'artist': 'Top Hits', 'icon': '🔥'},
      {'title': 'Happy Life', 'artist': 'Upbeat Energy', 'icon': '✨'},
      {'title': 'Deep Thought', 'artist': 'Piano Melodies', 'icon': '🎹'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xEE12121A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: 380,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Music',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  if (_selectedMusic != null)
                    TextButton(
                      onPressed: () {
                        setState(() => _selectedMusic = null);
                        Navigator.pop(ctx);
                      },
                      child: const Text('Remove',
                          style: TextStyle(color: Colors.redAccent)),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: musicList.length,
                  itemBuilder: (_, index) {
                    final item = musicList[index];
                    final isSelected = _selectedMusic == item['title'];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(item['icon'] ?? '🎵',
                            style: const TextStyle(fontSize: 22)),
                      ),
                      title: Text(item['title'] ?? '',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600)),
                      subtitle: Text(item['artist'] ?? '',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 13)),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle, color: primaryColor)
                          : const Icon(Icons.play_circle_outline,
                              color: Colors.white60),
                      onTap: () {
                        setState(() => _selectedMusic = item['title']);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Privacy Selector ---
  void _openPrivacySelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xEE12121A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Who can view your story?',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.public, color: Colors.white),
                title: const Text('Everyone',
                    style: TextStyle(color: Colors.white)),
                subtitle: const Text('Anyone can see this story',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
                trailing: _privacy == 'Everyone'
                    ? const Icon(Icons.check, color: primaryColor)
                    : null,
                onTap: () {
                  setState(() => _privacy = 'Everyone');
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.group_outlined, color: Colors.white),
                title: const Text('Contacts Only',
                    style: TextStyle(color: Colors.white)),
                subtitle: const Text('Only your contacts can see',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
                trailing: _privacy == 'Contacts Only'
                    ? const Icon(Icons.check, color: primaryColor)
                    : null,
                onTap: () {
                  setState(() => _privacy = 'Contacts Only');
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.lock_outline, color: Colors.white),
                title: const Text('Only Me',
                    style: TextStyle(color: Colors.white)),
                subtitle: const Text('Only visible to you',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
                trailing: _privacy == 'Only Me'
                    ? const Icon(Icons.check, color: primaryColor)
                    : null,
                onTap: () {
                  setState(() => _privacy = 'Only Me');
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Crop / Rotate Action ---
  Future<void> _handleCropOrRotate() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xEE12121A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.rotate_90_degrees_cw,
                    color: Colors.white),
                title: const Text('Rotate 90°',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  setState(() {
                    _rotationTurns = (_rotationTurns + 1) % 4;
                  });
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.crop, color: Colors.white),
                title:
                    const Text('Crop Image', style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final cropped = await ImageCropper().cropImage(
                    sourcePath: _currentImage.path,
                    uiSettings: [
                      AndroidUiSettings(
                        toolbarTitle: 'Crop Story',
                        toolbarColor: primaryColor,
                        toolbarWidgetColor: Colors.white,
                        initAspectRatio: CropAspectRatioPreset.original,
                        lockAspectRatio: false,
                      ),
                      IOSUiSettings(title: 'Crop Story'),
                    ],
                  );
                  if (cropped != null) {
                    setState(() {
                      _currentImage = File(cropped.path);
                    });
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Render Composition & Post Story ---
  Future<void> _postStory() async {
    if (_isPosting) return;

    File fileToUpload;

    try {
      final boundary = _repaintBoundaryKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;

      if (boundary != null) {
        // Fast capture of story canvas at ~300KB instead of 20MB raw camera file
        final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
        final byteData =
            await image.toByteData(format: ui.ImageByteFormat.png);

        if (byteData != null) {
          final buffer = byteData.buffer.asUint8List();
          final tempDir = await getTemporaryDirectory();
          final storyFilePath =
              '${tempDir.path}/story_${DateTime.now().millisecondsSinceEpoch}.png';
          fileToUpload = File(storyFilePath);
          await fileToUpload.writeAsBytes(buffer);
        } else {
          fileToUpload = _currentImage;
        }
      } else {
        fileToUpload = _currentImage;
      }

      if (mounted) {
        setState(() {
          _isPosting = true;
        });
      }

      // Upload story to Firestore and Storage (showDialog: false avoids blocking route dialogs)
      final success =
          await StoryApi.uploadImageStory(fileToUpload, showDialog: false);
      if (success) {
        // Pop back to home screen cleanly
        Get.offAllNamed(AppRoutes.home);
      } else {
        if (mounted) {
          setState(() {
            _isPosting = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Story capture/post error: $e');
      if (mounted) {
        setState(() {
          _isPosting = false;
        });
      }
      DialogHelper.showSnackbarMessage(SnackMsgType.error, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070612),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Visual Canvas with RepaintBoundary for capture
          Center(
            child: RepaintBoundary(
              key: _repaintBoundaryKey,
              child: Stack(
                fit: StackFit.expand,
                alignment: Alignment.center,
                children: [
                  // Atmospheric background gradient
                  Container(
                    decoration: const BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(0, -0.2),
                        radius: 1.2,
                        colors: [
                          Color(0xFF1E143E),
                          Color(0xFF0F0B24),
                          Color(0xFF06050F),
                        ],
                      ),
                    ),
                  ),

                  // The Selected Photo with Filter and Rotation
                  Center(
                    child: RotatedBox(
                      quarterTurns: _rotationTurns,
                      child: ColorFiltered(
                        colorFilter: _getColorFilter(_activeFilter) ??
                            const ColorFilter.mode(
                                Colors.transparent, BlendMode.dst),
                        child: Image.file(
                          _currentImage,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),

                  // Doodles Custom Paint
                  Positioned.fill(
                    child: CustomPaint(
                      painter: DoodlePainter(
                        lines: _doodleLines,
                        currentLine: _activeDoodleLine,
                      ),
                    ),
                  ),

                  // Overlays (Text, Stickers, Location, Mention)
                  ..._overlays.map((item) {
                    return Positioned(
                      left: item.position.dx,
                      top: item.position.dy,
                      child: GestureDetector(
                        onPanUpdate: (details) {
                          setState(() {
                            item.position = Offset(
                              item.position.dx + details.delta.dx,
                              item.position.dy + details.delta.dy,
                            );
                          });
                        },
                        onTap: () {
                          if (!item.isSticker &&
                              !item.isLocation &&
                              !item.isMention) {
                            _openTextDialog(existingItem: item);
                          }
                        },
                        onLongPress: () {
                          // Quick delete on long press
                          setState(() {
                            _overlays.remove(item);
                          });
                        },
                        child: _buildOverlayWidget(item),
                      ),
                    );
                  }),

                  // Music badge overlay if selected
                  if (_selectedMusic != null)
                    Positioned(
                      bottom: 80,
                      left: 20,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: primaryColor.withValues(alpha: 0.8),
                              width: 1.2),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.music_note,
                                color: primaryColor, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              _selectedMusic!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Doodling Touch Area (when active)
          if (_isDoodling)
            Positioned.fill(
              child: GestureDetector(
                onPanStart: (details) {
                  setState(() {
                    _activeDoodleLine = DoodleLine(
                      points: [details.localPosition],
                      color: _doodleColor,
                      strokeWidth: _doodleStrokeWidth,
                    );
                  });
                },
                onPanUpdate: (details) {
                  setState(() {
                    _activeDoodleLine?.points.add(details.localPosition);
                  });
                },
                onPanEnd: (_) {
                  setState(() {
                    if (_activeDoodleLine != null) {
                      _doodleLines.add(_activeDoodleLine!);
                      _activeDoodleLine = null;
                    }
                  });
                },
              ),
            ),

          // Top Bar (Close Button + Select Music Button)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: _isDoodling
                ? _buildDoodleTopBar()
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Close button (X)
                      _buildCircleIconButton(
                        icon: Icons.close_rounded,
                        onTap: _isPosting ? () {} : () => Get.back(),
                      ),

                      // Select Music Pill button
                      GestureDetector(
                        onTap: _isPosting ? null : _openMusicSelector,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white24, width: 1),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.music_note,
                                  color: Colors.white, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                _selectedMusic ?? 'Select Music',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 44), // balance spacing
                    ],
                  ),
          ),

          // Right Toolbar (IMO Vertical Tools: Emoji, Text, Doodle, Location, Mention, Filter, Crop)
          if (!_isDoodling && !_isPosting)
            Positioned(
              top: MediaQuery.of(context).padding.top + 70,
              right: 14,
              child: Column(
                children: [
                  _buildToolbarButton(
                    icon: Icons.sentiment_satisfied_alt_outlined,
                    onTap: _openStickerPicker,
                  ),
                  const SizedBox(height: 14),
                  _buildToolbarButton(
                    icon: Icons.text_fields_rounded,
                    onTap: () => _openTextDialog(),
                  ),
                  const SizedBox(height: 14),
                  _buildToolbarButton(
                    icon: Icons.edit_outlined,
                    onTap: () => setState(() => _isDoodling = true),
                  ),
                  const SizedBox(height: 14),
                  _buildToolbarButton(
                    icon: Icons.location_on_outlined,
                    onTap: _addLocationTag,
                  ),
                  const SizedBox(height: 14),
                  _buildToolbarButton(
                    icon: Icons.alternate_email_rounded,
                    onTap: _addMentionTag,
                  ),
                  const SizedBox(height: 14),
                  _buildToolbarButton(
                    icon: Icons.auto_awesome_rounded,
                    isActive: _showFilterBar,
                    onTap: () =>
                        setState(() => _showFilterBar = !_showFilterBar),
                  ),
                  const SizedBox(height: 14),
                  _buildToolbarButton(
                    icon: Icons.crop_rotate_rounded,
                    onTap: _handleCropOrRotate,
                  ),
                ],
              ),
            ),

          // Bottom Filter Bar (when filter icon is toggled)
          if (_showFilterBar && !_isDoodling && !_isPosting)
            Positioned(
              bottom: 90,
              left: 0,
              right: 0,
              child: Container(
                height: 80,
                color: Colors.black.withValues(alpha: 0.6),
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: StoryFilter.values.map((filter) {
                    final isSelected = _activeFilter == filter;
                    return GestureDetector(
                      onTap: () => setState(() => _activeFilter = filter),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? primaryColor
                              : Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? Colors.white : Colors.white24,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          filter.name.capitalizeFirst ?? filter.name,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

          // Bottom Bar: Privacy Pill + Vibrant Blue Circular Send Button
          if (!_isDoodling)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 16,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Privacy selector pill: [🌐 Everyone >]
                  GestureDetector(
                    onTap: _isPosting ? null : _openPrivacySelector,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.public,
                              color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            _privacy,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right,
                              color: Colors.white70, size: 18),
                        ],
                      ),
                    ),
                  ),

                  // Vibrant Blue Circular Send Button (IMO style)
                  GestureDetector(
                    onTap: _isPosting ? null : _postStory,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0072FF).withValues(alpha: 0.5),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: _isPosting
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                                size: 26,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Loading overlay during story upload
          if (_isPosting)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.55),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xEE1E143E),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: primaryColor,
                            strokeWidth: 2.5,
                          ),
                        ),
                        SizedBox(width: 16),
                        Text(
                          'Sharing story...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- Widget Builders ---

  Widget _buildOverlayWidget(StoryOverlayItem item) {
    if (item.isSticker) {
      return Text(item.text, style: TextStyle(fontSize: item.fontSize));
    }

    if (item.isLocation) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.3), blurRadius: 6)
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_on, color: primaryColor, size: 16),
            const SizedBox(width: 4),
            Text(
              item.text,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    if (item.isMention) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: primaryColor.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.3), blurRadius: 6)
          ],
        ),
        child: Text(
          item.text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: item.backgroundColor ?? Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        item.text,
        style: TextStyle(
          color: item.color,
          fontSize: item.fontSize,
          fontWeight: FontWeight.bold,
          shadows: item.backgroundColor == null
              ? const [Shadow(blurRadius: 8, color: Colors.black)]
              : null,
        ),
      ),
    );
  }

  Widget _buildCircleIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 1),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _buildToolbarButton({
    required IconData icon,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isActive
              ? primaryColor
              : Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
          border: Border.all(
            color: isActive ? Colors.white : Colors.white24,
            width: 1,
          ),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _buildDoodleTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Undo button
        _buildCircleIconButton(
          icon: Icons.undo_rounded,
          onTap: () {
            setState(() {
              if (_doodleLines.isNotEmpty) {
                _doodleLines.removeLast();
              }
            });
          },
        ),

        // Color selector
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _palette.map((color) {
              final isSelected = _doodleColor == color;
              return GestureDetector(
                onTap: () => setState(() => _doodleColor = color),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // Done button
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          onPressed: () => setState(() => _isDoodling = false),
          child: const Text('Done',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

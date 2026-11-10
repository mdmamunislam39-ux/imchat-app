// ignore_for_file: deprecated_member_use
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../../../services/agora_service.dart';

/// Controller to persist and manage Beauty & Video Effects
class VideoEffectsController extends ChangeNotifier {
  // Beauty / Retouch State
  bool isBeautyEnabled = false;
  double smoothness = 0.5;
  double lightening = 0.6;
  double redness = 0.1;
  double sharpness = 0.3;
  double colorEnhance = 0.4;

  // Filter Preset State
  String selectedFilterId = 'none';
  double filterIntensity = 0.8;

  // Background State
  String activeBackgroundMode = 'none';
  int blurDegree = 2;
  String? downloadingUrl;

  void notify() => notifyListeners();
}

/// Filter Preset definition with Agora beauty options and ColorMatrix
class VideoFilterPreset {
  final String id;
  final String name;
  final List<Color> previewColors;
  final double smoothness;
  final double lightening;
  final double redness;
  final double sharpness;
  final double colorEnhance;
  final List<double>? colorMatrix;

  const VideoFilterPreset({
    required this.id,
    required this.name,
    this.previewColors = const [Color(0xFF64748B), Color(0xFF475569)],
    this.smoothness = 0.5,
    this.lightening = 0.6,
    this.redness = 0.1,
    this.sharpness = 0.3,
    this.colorEnhance = 0.4,
    this.colorMatrix,
  });
}

const List<VideoFilterPreset> videoFilterPresets = [
  VideoFilterPreset(
    id: 'none',
    name: 'Original',
    previewColors: [Color(0xFF64748B), Color(0xFF475569)],
    smoothness: 0.0,
    lightening: 0.0,
    redness: 0.0,
    sharpness: 0.0,
    colorEnhance: 0.0,
    colorMatrix: null,
  ),
  VideoFilterPreset(
    id: 'natural',
    name: 'Natural',
    previewColors: [Color(0xFFFDE68A), Color(0xFFF59E0B)],
    smoothness: 0.55,
    lightening: 0.60,
    redness: 0.18,
    sharpness: 0.40,
    colorEnhance: 0.35,
    colorMatrix: [
      1.05, 0.00, 0.00, 0.0, 10,
      0.00, 1.02, 0.00, 0.0, 8,
      0.00, 0.00, 0.98, 0.0, 0,
      0.00, 0.00, 0.00, 1.0, 0,
    ],
  ),
  VideoFilterPreset(
    id: 'rosy',
    name: 'Rosy Pink',
    previewColors: [Color(0xFFFDA4AF), Color(0xFFE11D48)],
    smoothness: 0.70,
    lightening: 0.72,
    redness: 0.55,
    sharpness: 0.35,
    colorEnhance: 0.50,
    colorMatrix: [
      1.12, 0.00, 0.00, 0.0, 16,
      0.00, 1.00, 0.00, 0.0, 6,
      0.00, 0.00, 1.04, 0.0, 10,
      0.00, 0.00, 0.00, 1.0, 0,
    ],
  ),
  VideoFilterPreset(
    id: 'white',
    name: 'Fair White',
    previewColors: [Color(0xFFE0E7FF), Color(0xFF6366F1)],
    smoothness: 0.75,
    lightening: 0.88,
    redness: 0.12,
    sharpness: 0.45,
    colorEnhance: 0.30,
    colorMatrix: [
      1.08, 0.00, 0.00, 0.0, 20,
      0.00, 1.08, 0.00, 0.0, 20,
      0.00, 0.00, 1.10, 0.0, 22,
      0.00, 0.00, 0.00, 1.0, 0,
    ],
  ),
  VideoFilterPreset(
    id: 'glass',
    name: 'Glass Skin',
    previewColors: [Color(0xFFCFFAFE), Color(0xFF06B6D4)],
    smoothness: 0.85,
    lightening: 0.78,
    redness: 0.25,
    sharpness: 0.55,
    colorEnhance: 0.45,
    colorMatrix: [
      1.06, 0.00, 0.00, 0.0, 14,
      0.00, 1.08, 0.00, 0.0, 16,
      0.00, 0.00, 1.12, 0.0, 20,
      0.00, 0.00, 0.00, 1.0, 0,
    ],
  ),
  VideoFilterPreset(
    id: 'sunset',
    name: 'Warm Sunset',
    previewColors: [Color(0xFFFED7AA), Color(0xFFEA580C)],
    smoothness: 0.60,
    lightening: 0.65,
    redness: 0.38,
    sharpness: 0.40,
    colorEnhance: 0.70,
    colorMatrix: [
      1.16, 0.00, 0.00, 0.0, 20,
      0.00, 1.06, 0.00, 0.0, 10,
      0.00, 0.00, 0.92, 0.0, -5,
      0.00, 0.00, 0.00, 1.0, 0,
    ],
  ),
  VideoFilterPreset(
    id: 'peach',
    name: 'Peach Bloom',
    previewColors: [Color(0xFFFECDD3), Color(0xFFF43F5E)],
    smoothness: 0.68,
    lightening: 0.75,
    redness: 0.45,
    sharpness: 0.35,
    colorEnhance: 0.55,
    colorMatrix: [
      1.15, 0.00, 0.00, 0.0, 18,
      0.00, 1.04, 0.00, 0.0, 8,
      0.00, 0.00, 0.96, 0.0, 2,
      0.00, 0.00, 0.00, 1.0, 0,
    ],
  ),
  VideoFilterPreset(
    id: 'fresh',
    name: 'Fresh Pop',
    previewColors: [Color(0xFFA7F3D0), Color(0xFF059669)],
    smoothness: 0.50,
    lightening: 0.68,
    redness: 0.20,
    sharpness: 0.65,
    colorEnhance: 0.75,
    colorMatrix: [
      1.10, 0.00, 0.00, 0.0, 10,
      0.00, 1.12, 0.00, 0.0, 14,
      0.00, 0.00, 1.08, 0.0, 10,
      0.00, 0.00, 0.00, 1.0, 0,
    ],
  ),
  VideoFilterPreset(
    id: 'cool',
    name: 'Cool Studio',
    previewColors: [Color(0xFFBAE6FD), Color(0xFF0284C7)],
    smoothness: 0.60,
    lightening: 0.80,
    redness: 0.08,
    sharpness: 0.55,
    colorEnhance: 0.40,
    colorMatrix: [
      0.96, 0.00, 0.00, 0.0, 0,
      0.00, 1.04, 0.00, 0.0, 8,
      0.00, 0.00, 1.18, 0.0, 22,
      0.00, 0.00, 0.00, 1.0, 0,
    ],
  ),
  VideoFilterPreset(
    id: 'angel',
    name: 'Sweet Angel',
    previewColors: [Color(0xFFF5D0FE), Color(0xFFC026D3)],
    smoothness: 0.90,
    lightening: 0.85,
    redness: 0.30,
    sharpness: 0.25,
    colorEnhance: 0.40,
    colorMatrix: [
      1.12, 0.00, 0.00, 0.0, 18,
      0.00, 1.06, 0.00, 0.0, 12,
      0.00, 0.00, 1.10, 0.0, 16,
      0.00, 0.00, 0.00, 1.0, 0,
    ],
  ),
];

/// Overlay that applies color grading matrices over video stream
class VideoFilterColorOverlay extends StatelessWidget {
  final VideoEffectsController controller;
  final Widget child;

  const VideoFilterColorOverlay({
    super.key,
    required this.controller,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.selectedFilterId == 'none' ||
            controller.filterIntensity <= 0) {
          return child;
        }

        final preset = videoFilterPresets.firstWhere(
          (p) => p.id == controller.selectedFilterId,
          orElse: () => videoFilterPresets.first,
        );

        if (preset.colorMatrix == null) return child;

        final t = controller.filterIntensity.clamp(0.0, 1.0);
        final base = preset.colorMatrix!;
        final scaled = <double>[
          1.0 + (base[0] - 1.0) * t, base[1] * t, base[2] * t, base[3] * t, base[4] * t,
          base[5] * t, 1.0 + (base[6] - 1.0) * t, base[7] * t, base[8] * t, base[9] * t,
          base[10] * t, base[11] * t, 1.0 + (base[12] - 1.0) * t, base[13] * t, base[14] * t,
          base[15] * t, base[16] * t, base[17] * t, 1.0 + (base[18] - 1.0) * t, base[19] * t,
        ];

        return ColorFiltered(
          colorFilter: ColorFilter.matrix(scaled),
          child: child,
        );
      },
    );
  }
}

/// Beauty & Retouch Bottom Sheet UI
class BeautyEffectSheet extends StatefulWidget {
  final VideoEffectsController controller;
  final VoidCallback? onClose;

  const BeautyEffectSheet({
    super.key,
    required this.controller,
    this.onClose,
  });

  @override
  State<BeautyEffectSheet> createState() => _BeautyEffectSheetState();
}

class _BeautyEffectSheetState extends State<BeautyEffectSheet> {
  final AgoraService _agoraService = AgoraService();
  VideoEffectsController get _ctrl => widget.controller;
  int _selectedTab = 0; // 0: Filters, 1: Retouch

  void _applySettings() {
    if (_ctrl.selectedFilterId == 'none') {
      _agoraService.setBeautyEffect(
        _ctrl.isBeautyEnabled,
        smoothnessLevel: _ctrl.smoothness,
        lighteningLevel: _ctrl.lightening,
        rednessLevel: _ctrl.redness,
        sharpnessLevel: _ctrl.sharpness,
      );
      _agoraService.setColorEnhance(
        enabled: _ctrl.isBeautyEnabled,
        strength: _ctrl.colorEnhance,
        skinProtect: 0.6,
      );
    } else {
      final preset = videoFilterPresets.firstWhere(
        (p) => p.id == _ctrl.selectedFilterId,
        orElse: () => videoFilterPresets.first,
      );
      final intensity = _ctrl.filterIntensity;
      _agoraService.setBeautyEffect(
        true,
        smoothnessLevel: (preset.smoothness * intensity).clamp(0.0, 1.0),
        lighteningLevel: (preset.lightening * intensity).clamp(0.0, 1.0),
        rednessLevel: (preset.redness * intensity).clamp(0.0, 1.0),
        sharpnessLevel: (preset.sharpness * intensity).clamp(0.0, 1.0),
      );
      _agoraService.setColorEnhance(
        enabled: true,
        strength: (preset.colorEnhance * intensity).clamp(0.0, 1.0),
        skinProtect: 0.65,
      );
    }
    _ctrl.notify();
  }

  void _selectFilter(VideoFilterPreset preset) {
    setState(() {
      _ctrl.selectedFilterId = preset.id;
      if (preset.id != 'none') {
        _ctrl.isBeautyEnabled = true;
        _ctrl.smoothness = preset.smoothness;
        _ctrl.lightening = preset.lightening;
        _ctrl.redness = preset.redness;
        _ctrl.sharpness = preset.sharpness;
        _ctrl.colorEnhance = preset.colorEnhance;
      }
    });
    _applySettings();
  }

  void _resetToDefault() {
    setState(() {
      _ctrl.selectedFilterId = 'none';
      _ctrl.filterIntensity = 0.8;
      _ctrl.isBeautyEnabled = false;
      _ctrl.smoothness = 0.5;
      _ctrl.lightening = 0.6;
      _ctrl.redness = 0.1;
      _ctrl.sharpness = 0.3;
      _ctrl.colorEnhance = 0.4;
    });
    _applySettings();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.20),
            Colors.black.withOpacity(0.40),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Handle Bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            // Header Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: Color(0xFFD946EF),
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Filters & Beauty',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(color: Colors.black87, blurRadius: 4),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Reset Button
                  TextButton.icon(
                    onPressed: _resetToDefault,
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: Colors.white70,
                      size: 15,
                    ),
                    label: const Text(
                      'Reset',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      backgroundColor: Colors.white.withOpacity(0.08),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Close Button
                  IconButton(
                    onPressed: widget.onClose ?? () => Navigator.of(context).pop(),
                    icon: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 18),
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Segmented Tabs: [ Filters | Retouch ]
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedTab = 0),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _selectedTab == 0
                                ? const Color(0xFFD946EF)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: _selectedTab == 0
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFFD946EF).withOpacity(0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.filter_vintage_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Filters',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedTab = 1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _selectedTab == 1
                                ? const Color(0xFFD946EF)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: _selectedTab == 1
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFFD946EF).withOpacity(0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.face_retouching_natural,
                                color: Colors.white,
                                size: 16,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Retouch',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Tab Content
            if (_selectedTab == 0)
              _buildFiltersTab()
            else
              _buildRetouchTab(),
          ],
        ),
      ),
    );
  }

  // TAB 1: FILTERS VIEW
  Widget _buildFiltersTab() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Intensity Slider when a filter is active
        if (_ctrl.selectedFilterId != 'none')
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
            child: _buildSleekSlider(
              'Filter Intensity',
              _ctrl.filterIntensity,
              (val) {
                setState(() => _ctrl.filterIntensity = val);
                _applySettings();
              },
            ),
          )
        else
          const SizedBox(height: 8),

        // Horizontal Carousel of Filters
        SizedBox(
          height: 104,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            scrollDirection: Axis.horizontal,
            itemCount: videoFilterPresets.length,
            separatorBuilder: (context, index) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final preset = videoFilterPresets[index];
              final isSelected = _ctrl.selectedFilterId == preset.id;

              return GestureDetector(
                onTap: () => _selectFilter(preset),
                child: SizedBox(
                  width: 68,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Preview Circle Thumbnail with Model Face
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFFD946EF)
                                    : Colors.white.withOpacity(0.4),
                                width: isSelected ? 2.5 : 1.2,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFFD946EF).withOpacity(0.55),
                                        blurRadius: 8,
                                        spreadRadius: 1.5,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: ClipOval(
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  // Base Model Photo with Color Matrix applied
                                  if (preset.colorMatrix != null)
                                    ColorFiltered(
                                      colorFilter: ColorFilter.matrix(preset.colorMatrix!),
                                      child: Image.asset(
                                        'assets/images/beauty_model.jpg',
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  else
                                    Image.asset(
                                      'assets/images/beauty_model.jpg',
                                      fit: BoxFit.cover,
                                    ),

                                  // Subtle preset color tint gradient over the model image
                                  if (preset.id != 'none')
                                    Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            preset.previewColors.first.withOpacity(0.20),
                                            preset.previewColors.last.withOpacity(0.32),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                    ),

                                  // For Original ('none'), display subtle cancel icon badge
                                  if (preset.id == 'none')
                                    Container(
                                      color: Colors.black.withOpacity(0.28),
                                      child: const Center(
                                        child: Icon(
                                          Icons.block_rounded,
                                          color: Colors.white,
                                          size: 22,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          // Selected Check Badge
                          if (isSelected)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFD946EF),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black54,
                                      blurRadius: 3,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 11,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        preset.name,
                        style: TextStyle(
                          color: isSelected ? const Color(0xFFE879F9) : Colors.white,
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          shadows: const [
                            Shadow(color: Colors.black87, blurRadius: 4),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // TAB 2: RETOUCH SLIDERS VIEW
  Widget _buildRetouchTab() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Face Retouch Master Toggle Card
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _ctrl.isBeautyEnabled
                  ? Colors.white.withOpacity(0.08)
                  : Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _ctrl.isBeautyEnabled
                    ? const Color(0xFFD946EF).withOpacity(0.6)
                    : Colors.white.withOpacity(0.12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _ctrl.isBeautyEnabled
                        ? const Color(0xFFD946EF)
                        : Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.face_retouching_natural,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Face Retouch',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _ctrl.isBeautyEnabled ? 'Active' : 'Enhance your look',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _ctrl.isBeautyEnabled,
                  onChanged: (val) {
                    setState(() => _ctrl.isBeautyEnabled = val);
                    _applySettings();
                  },
                  activeColor: const Color(0xFFD946EF),
                  activeTrackColor: const Color(0xFFD946EF).withOpacity(0.4),
                ),
              ],
            ),
          ),
        ),

        // Sliders when active
        if (_ctrl.isBeautyEnabled)
          Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.38,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSleekSlider('Smooth Skin', _ctrl.smoothness, (val) {
                    setState(() => _ctrl.smoothness = val);
                    _applySettings();
                  }),
                  _buildSleekSlider('Whitening / Brightness', _ctrl.lightening, (val) {
                    setState(() => _ctrl.lightening = val);
                    _applySettings();
                  }),
                  _buildSleekSlider('Rosy Tone', _ctrl.redness, (val) {
                    setState(() => _ctrl.redness = val);
                    _applySettings();
                  }),
                  _buildSleekSlider('Sharpness', _ctrl.sharpness, (val) {
                    setState(() => _ctrl.sharpness = val);
                    _applySettings();
                  }),
                  _buildSleekSlider('Color Enhancement', _ctrl.colorEnhance, (val) {
                    setState(() => _ctrl.colorEnhance = val);
                    _applySettings();
                  }),
                ],
              ),
            ),
          ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildSleekSlider(String label, double value, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  shadows: [
                    Shadow(color: Colors.black87, blurRadius: 4),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${(value * 100).toInt()}%',
                  style: const TextStyle(
                    color: Color(0xFFD946EF),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          SizedBox(
            height: 32,
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 4,
                activeTrackColor: const Color(0xFFD946EF),
                inactiveTrackColor: Colors.white.withOpacity(0.3),
                thumbColor: Colors.white,
                overlayColor: const Color(0xFFD946EF).withOpacity(0.2),
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 8,
                  elevation: 3,
                ),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              ),
              child: Slider(value: value, onChanged: onChanged),
            ),
          ),
        ],
      ),
    );
  }
}

/// Virtual Background Effect Bottom Sheet UI
class BackgroundEffectSheet extends StatefulWidget {
  final VideoEffectsController controller;
  final VoidCallback? onClose;

  const BackgroundEffectSheet({
    super.key,
    required this.controller,
    this.onClose,
  });

  @override
  State<BackgroundEffectSheet> createState() => _BackgroundEffectSheetState();
}

class _BackgroundEffectSheetState extends State<BackgroundEffectSheet> {
  final AgoraService _agoraService = AgoraService();
  VideoEffectsController get _ctrl => widget.controller;

  final List<Map<String, String>> _presetWallpapers = [
    {
      'name': 'Studio 1',
      'url': 'https://images.unsplash.com/photo-1513694203232-719a280e022f?w=600&auto=format&fit=crop&q=80',
    },
    {
      'name': 'Neon Lights',
      'url': 'https://images.unsplash.com/photo-1508739773434-c26b3d09e071?w=600&auto=format&fit=crop&q=80',
    },
    {
      'name': 'Cozy Cafe',
      'url': 'https://images.unsplash.com/photo-1554118811-1e0d58224f24?w=600&auto=format&fit=crop&q=80',
    },
    {
      'name': 'Luxury Living',
      'url': 'https://images.unsplash.com/photo-1600210492486-724fe5c67fb0?w=600&auto=format&fit=crop&q=80',
    },
    {
      'name': 'Cyberpunk',
      'url': 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=600&auto=format&fit=crop&q=80',
    },
  ];

  Future<void> _downloadAndApplyWallpaper(String url) async {
    try {
      setState(() => _ctrl.downloadingUrl = url);
      final directory = await getTemporaryDirectory();
      final safeName = url.hashCode.abs().toString();
      final savePath = '${directory.path}/bg_$safeName.jpg';
      final file = File(savePath);
      if (!await file.exists()) {
        final res = await http.get(Uri.parse(url));
        if (res.statusCode == 200) {
          await file.writeAsBytes(res.bodyBytes);
        }
      }
      await _agoraService.enableVirtualBackground(enabled: true, imagePath: savePath);
      setState(() {
        _ctrl.activeBackgroundMode = 'img_$url';
        _ctrl.downloadingUrl = null;
      });
      _ctrl.notify();
    } catch (e) {
      debugPrint('Error downloading wallpaper: $e');
      setState(() => _ctrl.downloadingUrl = null);
    }
  }

  void _applyBlur(int degree) {
    setState(() {
      _ctrl.blurDegree = degree;
      _ctrl.activeBackgroundMode = 'blur_$degree';
    });
    _agoraService.enableVirtualBackground(
      enabled: true,
      blurDegree: degree,
    );
    _ctrl.notify();
  }

  void _clearBackground() {
    setState(() {
      _ctrl.activeBackgroundMode = 'none';
    });
    _agoraService.enableVirtualBackground(enabled: false);
    _ctrl.notify();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF131722).withOpacity(0.96),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.55,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.image_outlined,
                    color: Color(0xFF38BDF8),
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Virtual Background',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: widget.onClose ?? () => Navigator.of(context).pop(),
                    icon: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 18),
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Blur Options
                    const Text(
                      'Background Blur',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildBlurOption('None', 'none', Icons.block, () => _clearBackground()),
                        const SizedBox(width: 10),
                        _buildBlurOption('Low Blur', 'blur_1', Icons.blur_linear, () => _applyBlur(1)),
                        const SizedBox(width: 10),
                        _buildBlurOption('Medium Blur', 'blur_2', Icons.blur_on, () => _applyBlur(2)),
                        const SizedBox(width: 10),
                        _buildBlurOption('High Blur', 'blur_3', Icons.blur_circular, () => _applyBlur(3)),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Wallpaper Grid
                    const Text(
                      'Wallpapers',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.8,
                      ),
                      itemCount: _presetWallpapers.length,
                      itemBuilder: (context, index) {
                        final wallpaper = _presetWallpapers[index];
                        final url = wallpaper['url']!;
                        final isSelected = _ctrl.activeBackgroundMode == 'img_$url';
                        final isDownloading = _ctrl.downloadingUrl == url;

                        return GestureDetector(
                          onTap: () => _downloadAndApplyWallpaper(url),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: isSelected
                                  ? Border.all(color: const Color(0xFFD946EF), width: 2.5)
                                  : Border.all(color: Colors.white.withOpacity(0.12)),
                              image: DecorationImage(
                                image: NetworkImage(url),
                                fit: BoxFit.cover,
                              ),
                            ),
                            child: Stack(
                              children: [
                                if (isSelected)
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      color: Colors.black.withOpacity(0.3),
                                    ),
                                    child: const Center(
                                      child: Icon(Icons.check_circle, color: Colors.white, size: 28),
                                    ),
                                  ),
                                if (isDownloading)
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      color: Colors.black.withOpacity(0.5),
                                    ),
                                    child: const Center(
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    ),
                                  ),
                                Positioned(
                                  bottom: 4,
                                  left: 4,
                                  right: 4,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      wallpaper['name']!,
                                      style: const TextStyle(color: Colors.white, fontSize: 10),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlurOption(String title, String modeKey, IconData icon, VoidCallback onTap) {
    final isSelected = _ctrl.activeBackgroundMode == modeKey;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFD946EF).withOpacity(0.2)
                : Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFFD946EF) : Colors.white.withOpacity(0.1),
              width: isSelected ? 1.8 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? const Color(0xFFD946EF) : Colors.white70,
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

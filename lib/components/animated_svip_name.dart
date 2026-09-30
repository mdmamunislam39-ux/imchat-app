import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:chat_messenger/services/svip_service.dart';

/// Global Real-time VIP & SVIP Level Config Manager
class VipLevelConfigService {
  static final VipLevelConfigService _instance = VipLevelConfigService._internal();
  factory VipLevelConfigService() => _instance;
  static VipLevelConfigService get instance => _instance;

  final Map<String, dynamic> _configs = {};
  final ValueNotifier<int> versionNotifier = ValueNotifier<int>(0);
  
  StreamSubscription? _vipSub;
  StreamSubscription? _svipSub;
  bool _isListening = false;

  VipLevelConfigService._internal() {
    initListeners();
  }

  void initListeners() {
    if (_isListening) return;
    _isListening = true;

    // 1. Real-time stream for VIP Levels
    _vipSub?.cancel();
    _vipSub = FirebaseFirestore.instance
        .collection('config')
        .doc('vip_levels')
        .collection('levels')
        .snapshots()
        .listen((snapshot) {
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final rawId = doc.id.toLowerCase().trim();
        _configs['vip_levels_$rawId'] = data;
        
        final numOnly = doc.id.replaceAll(RegExp(r'[^0-9]'), '');
        if (numOnly.isNotEmpty) {
          _configs['vip_levels_$numOnly'] = data;
          _configs['vip_levels_vip$numOnly'] = data;
          _configs['vip_levels_vip_$numOnly'] = data;
          _configs['vip_levels_level_$numOnly'] = data;
          _configs['vip_levels_level$numOnly'] = data;
        }
      }
      versionNotifier.value++;
    }, onError: (e) {
      debugPrint('Error in real-time VIP config listener: $e');
    });

    // 2. Real-time stream for SVIP Levels
    _svipSub?.cancel();
    _svipSub = FirebaseFirestore.instance
        .collection('config')
        .doc('svip_levels')
        .collection('levels')
        .snapshots()
        .listen((snapshot) {
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final rawId = doc.id.toLowerCase().trim();
        _configs['svip_levels_$rawId'] = data;
        
        final numOnly = doc.id.replaceAll(RegExp(r'[^0-9]'), '');
        if (numOnly.isNotEmpty) {
          _configs['svip_levels_$numOnly'] = data;
          _configs['svip_levels_svip$numOnly'] = data;
          _configs['svip_levels_svip_$numOnly'] = data;
          _configs['svip_levels_level_$numOnly'] = data;
          _configs['svip_levels_level$numOnly'] = data;
        }
      }
      versionNotifier.value++;
    }, onError: (e) {
      debugPrint('Error in real-time SVIP config listener: $e');
    });
  }

  Map<String, dynamic>? getConfig(bool isSvip, int levelNum) {
    initListeners();
    final collectionName = isSvip ? 'svip_levels' : 'vip_levels';
    final prefix = isSvip ? 'svip' : 'vip';

    final candidateKeys = [
      '${collectionName}_$prefix$levelNum',
      '${collectionName}_${prefix}_$levelNum',
      '${collectionName}_$levelNum',
      '${collectionName}_level_$levelNum',
      '${collectionName}_level$levelNum',
    ];

    for (final key in candidateKeys) {
      if (_configs.containsKey(key) && _configs[key] != null) {
        return _configs[key];
      }
    }
    return null;
  }
}

class AnimatedSvipName extends StatefulWidget {
  final String name;
  final int activeSvipLevel;
  final String svipValidUntilMonth;
  final int activeVipLevel;
  final String vipValidUntilMonth;
  final DateTime? vipValidUntil;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  const AnimatedSvipName({
    super.key,
    required this.name,
    required this.activeSvipLevel,
    required this.svipValidUntilMonth,
    this.activeVipLevel = 0,
    this.vipValidUntilMonth = '',
    this.vipValidUntil,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  /// Factory constructor to build AnimatedSvipName directly from User model
  static Widget fromUser({
    Key? key,
    required User user,
    TextStyle? style,
    int? maxLines,
    TextOverflow? overflow,
    TextAlign? textAlign,
  }) {
    return AnimatedSvipName(
      key: key,
      name: user.fullname.isNotEmpty ? user.fullname : 'User',
      activeSvipLevel: user.activeSvipLevel,
      svipValidUntilMonth: user.svipValidUntilMonth,
      activeVipLevel: user.activeVipLevel,
      vipValidUntilMonth: user.vipValidUntilMonth,
      vipValidUntil: user.vipValidUntil,
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );
  }

  /// Factory constructor to build AnimatedSvipName directly from raw user Map
  static Widget fromUserData({
    Key? key,
    required Map<String, dynamic> data,
    String? defaultName,
    TextStyle? style,
    int? maxLines,
    TextOverflow? overflow,
    TextAlign? textAlign,
  }) {
    final String name = (data['fullname'] ?? data['name'] ?? data['userName'] ?? defaultName ?? 'User').toString();
    final int activeSvip = (data['activeSvipLevel'] as num?)?.toInt() ?? 0;
    final String svipMonth = (data['svipValidUntilMonth'] ?? '').toString();
    final int activeVip = (data['activeVipLevel'] as num?)?.toInt() ?? 0;
    final String vipMonth = (data['vipValidUntilMonth'] ?? '').toString();
    
    DateTime? vipUntil;
    if (data['vipValidUntil'] != null) {
      if (data['vipValidUntil'] is Timestamp) {
        vipUntil = (data['vipValidUntil'] as Timestamp).toDate();
      } else if (data['vipValidUntil'] is String) {
        vipUntil = DateTime.tryParse(data['vipValidUntil'].toString());
      }
    }

    return AnimatedSvipName(
      key: key,
      name: name,
      activeSvipLevel: activeSvip,
      svipValidUntilMonth: svipMonth,
      activeVipLevel: activeVip,
      vipValidUntilMonth: vipMonth,
      vipValidUntil: vipUntil,
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );
  }

  /// Real-time builder that listens to Firestore user document by userId
  static Widget fromUserId({
    Key? key,
    required String userId,
    String? defaultName,
    TextStyle? style,
    int? maxLines,
    TextOverflow? overflow,
    TextAlign? textAlign,
  }) {
    if (userId.isEmpty || userId == 'system') {
      return Text(
        defaultName ?? 'System',
        style: style,
        maxLines: maxLines,
        overflow: overflow,
        textAlign: textAlign,
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      key: key,
      stream: FirebaseFirestore.instance.collection('Users').doc(userId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists || snapshot.data!.data() == null) {
          return Text(
            defaultName ?? 'User',
            style: style,
            maxLines: maxLines,
            overflow: overflow,
            textAlign: textAlign,
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        return fromUserData(
          data: data,
          defaultName: defaultName,
          style: style,
          maxLines: maxLines,
          overflow: overflow,
          textAlign: textAlign,
        );
      },
    );
  }

  @override
  State<AnimatedSvipName> createState() => _AnimatedSvipNameState();
}

class _AnimatedSvipNameState extends State<AnimatedSvipName> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  VoidCallback? _configVersionListener;
  bool _isStyleActive = false;
  bool _isSvipActive = false;
  bool _isVipActive = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _checkSvipStatus();

    // Listen to real-time Admin Panel level configuration updates
    _configVersionListener = () {
      if (mounted) {
        setState(() {});
      }
    };
    VipLevelConfigService.instance.versionNotifier.addListener(_configVersionListener!);
  }

  @override
  void didUpdateWidget(AnimatedSvipName oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeSvipLevel != widget.activeSvipLevel || 
        oldWidget.svipValidUntilMonth != widget.svipValidUntilMonth ||
        oldWidget.activeVipLevel != widget.activeVipLevel ||
        oldWidget.vipValidUntilMonth != widget.vipValidUntilMonth ||
        oldWidget.vipValidUntil != widget.vipValidUntil ||
        oldWidget.name != widget.name) {
      _checkSvipStatus();
    }
  }

  @override
  void dispose() {
    if (_configVersionListener != null) {
      VipLevelConfigService.instance.versionNotifier.removeListener(_configVersionListener!);
    }
    _animationController.dispose();
    super.dispose();
  }

  void _checkSvipStatus() {
    _isSvipActive = SvipService.isSvipActive(widget.activeSvipLevel, widget.svipValidUntilMonth);
    _isVipActive = SvipService.isVipActive(widget.activeVipLevel, widget.vipValidUntil, widget.vipValidUntilMonth);
    _isStyleActive = _isSvipActive || _isVipActive;
  }

  List<String> _extractColorsList(Map<String, dynamic>? config) {
    if (config == null) return [];
    
    // Check multiple potential keys from Admin Panel:
    dynamic raw = config['nameColors'] ?? 
                  config['nameColor'] ?? 
                  config['textColor'] ?? 
                  config['color'] ?? 
                  config['colorCode'] ?? 
                  config['hexColor'] ?? 
                  config['nameColorCode'] ?? 
                  config['colors'];
    if (raw == null) return [];

    if (raw is List) {
      return raw.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
    }

    if (raw is int) {
      return ['#${raw.toRadixString(16).padLeft(8, '0')}'];
    }

    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.contains(',')) {
        return trimmed.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      }
      if (trimmed.isNotEmpty) {
        return [trimmed];
      }
    }

    return [];
  }

  Map<String, dynamic> _getDefaultConfigForLevel(bool isSvip, int level) {
    if (isSvip) {
      switch (level) {
        case 1:
          return {
            'nameColorMode': 'gradient',
            'nameColors': ['#FFD700', '#FFA500', '#FF8C00'],
            'nameAnimation': 'shimmer',
          };
        case 2:
          return {
            'nameColorMode': 'gradient',
            'nameColors': ['#00E5FF', '#7C4DFF', '#E040FB'],
            'nameAnimation': 'shimmer',
          };
        case 3:
          return {
            'nameColorMode': 'gradient',
            'nameColors': ['#FF1744', '#FF4081', '#7C4DFF'],
            'nameAnimation': 'shimmer',
          };
        case 4:
          return {
            'nameColorMode': 'gradient',
            'nameColors': ['#FFD700', '#FF007F', '#00E5FF'],
            'nameAnimation': 'shimmer',
          };
        default:
          return {
            'nameColorMode': 'gradient',
            'nameColors': ['#FF007F', '#7928CA', '#00DFD8', '#FFD700'],
            'nameAnimation': 'shimmer',
          };
      }
    } else {
      // VIP standard tiers
      switch (level) {
        case 1:
          return {
            'nameColorMode': 'gradient',
            'nameColors': ['#FFD700', '#FFA000'],
            'nameAnimation': 'none',
          };
        case 2:
          return {
            'nameColorMode': 'gradient',
            'nameColors': ['#00E5FF', '#0091EA'],
            'nameAnimation': 'none',
          };
        case 3:
          return {
            'nameColorMode': 'gradient',
            'nameColors': ['#D500F9', '#7C4DFF'],
            'nameAnimation': 'none',
          };
        case 4:
          return {
            'nameColorMode': 'gradient',
            'nameColors': ['#FF1744', '#FF4081'],
            'nameAnimation': 'none',
          };
        case 5:
          return {
            'nameColorMode': 'gradient',
            'nameColors': ['#FF6D00', '#FFD700', '#FF9100'],
            'nameAnimation': 'shimmer',
          };
        case 6:
          return {
            'nameColorMode': 'gradient',
            'nameColors': ['#FF1744', '#FFD700', '#FF3D00'],
            'nameAnimation': 'shimmer',
          };
        default: // VIP 7+
          return {
            'nameColorMode': 'gradient',
            'nameColors': ['#00E5FF', '#D500F9', '#FF1744', '#FFD700'],
            'nameAnimation': 'shimmer',
          };
      }
    }
  }

  Color _hexToColor(String hexCode) {
    hexCode = hexCode.replaceAll('#', '').replaceAll('0x', '').replaceAll('0X', '').trim();
    if (hexCode.length == 6) {
      hexCode = 'FF$hexCode';
    } else if (hexCode.length == 8) {
      // already has alpha
    } else if (hexCode.length == 3) {
      hexCode = 'FF${hexCode[0]}${hexCode[0]}${hexCode[1]}${hexCode[1]}${hexCode[2]}${hexCode[2]}';
    } else {
      final val = int.tryParse(hexCode);
      if (val != null) {
        return Color(val);
      }
      return Colors.white;
    }
    return Color(int.parse(hexCode, radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    if (!_isStyleActive) {
      return Text(
        widget.name,
        style: widget.style,
        maxLines: widget.maxLines,
        overflow: widget.overflow,
        textAlign: widget.textAlign,
      );
    }

    final int levelNum = _isSvipActive ? widget.activeSvipLevel : widget.activeVipLevel;
    final liveConfig = VipLevelConfigService.instance.getConfig(_isSvipActive, levelNum);
    final fallbackConfig = _getDefaultConfigForLevel(_isSvipActive, levelNum);
    
    final customColors = _extractColorsList(liveConfig);
    final fallbackColors = _extractColorsList(fallbackConfig);
    final colorsStr = customColors.isNotEmpty ? customColors : fallbackColors;

    final colorMode = (liveConfig?['nameColorMode'] ?? fallbackConfig['nameColorMode'] ?? (colorsStr.length > 1 ? 'gradient' : 'solid')).toString();
    final animationType = (liveConfig?['nameAnimation'] ?? fallbackConfig['nameAnimation'] ?? 'none').toString();
    
    List<Color> colors = colorsStr.map((c) {
      try {
        return _hexToColor(c);
      } catch (_) {
        return const Color(0xFFFFD700);
      }
    }).toList();
    
    if (colors.isEmpty) colors = [const Color(0xFFFFD700)];
    
    if (colorMode == 'solid' && colors.length == 1 && animationType == 'none') {
      return Text(
        widget.name,
        style: (widget.style ?? const TextStyle()).copyWith(color: colors.first),
        maxLines: widget.maxLines,
        overflow: widget.overflow,
        textAlign: widget.textAlign,
      );
    }
    
    // Gradient rendering
    if (colors.length == 1) colors.add(colors.first);
    
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        Gradient gradient;
        
        if (animationType == 'shimmer') {
          gradient = LinearGradient(
            colors: [colors.first, colors.last, colors.first],
            stops: [
              _animationController.value - 0.3,
              _animationController.value,
              _animationController.value + 0.3
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          );
        } else if (animationType == 'pulse') {
          final t = (math.sin(_animationController.value * 2 * 3.14159) + 1) / 2;
          gradient = LinearGradient(
            colors: colors.map((c) => Color.lerp(c, Colors.white, t) ?? c).toList(),
          );
        } else {
          gradient = LinearGradient(colors: colors);
        }

        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => gradient.createShader(bounds),
          child: Text(
            widget.name,
            style: (widget.style ?? const TextStyle()).copyWith(color: Colors.white),
            maxLines: widget.maxLines,
            overflow: widget.overflow,
            textAlign: widget.textAlign,
          ),
        );
      },
    );
  }
}

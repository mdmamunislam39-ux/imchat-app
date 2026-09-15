import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AnimatedSvipName extends StatefulWidget {
  final String name;
  final int activeSvipLevel;
  final String svipValidUntilMonth;
  final int activeVipLevel;
  final String vipValidUntilMonth;
  final DateTime? vipValidUntil;
  final TextStyle? style;

  const AnimatedSvipName({
    super.key,
    required this.name,
    required this.activeSvipLevel,
    required this.svipValidUntilMonth,
    this.activeVipLevel = 0,
    this.vipValidUntilMonth = '',
    this.vipValidUntil,
    this.style,
  });

  @override
  State<AnimatedSvipName> createState() => _AnimatedSvipNameState();
}

class _AnimatedSvipNameState extends State<AnimatedSvipName> with SingleTickerProviderStateMixin {
  // Global cache for SVIP and VIP configs to avoid excessive Firestore reads
  static final Map<String, dynamic> _configsCache = {};
  static bool _isLoadingCache = false;
  static DateTime? _lastCacheTime;
  
  late AnimationController _animationController;
  Map<String, dynamic>? _myConfig;
  bool _isStyleActive = false;
  bool _isSvipActive = false;
  bool _isVipActive = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _checkSvipStatus();
  }

  @override
  void didUpdateWidget(AnimatedSvipName oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeSvipLevel != widget.activeSvipLevel || 
        oldWidget.svipValidUntilMonth != widget.svipValidUntilMonth ||
        oldWidget.activeVipLevel != widget.activeVipLevel ||
        oldWidget.vipValidUntilMonth != widget.vipValidUntilMonth ||
        oldWidget.vipValidUntil != widget.vipValidUntil) {
      _checkSvipStatus();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _checkSvipStatus() {
    final now = DateTime.now();
    final currentMonth = "${now.year}-${now.month.toString().padLeft(2, '0')}";
    
    _isSvipActive = widget.activeSvipLevel > 0 && widget.svipValidUntilMonth == currentMonth;
    _isVipActive = widget.activeVipLevel > 0 && 
        ((widget.vipValidUntil != null && widget.vipValidUntil!.isAfter(now)) || 
         widget.vipValidUntilMonth == currentMonth);
    _isStyleActive = _isSvipActive || _isVipActive;
    
    if (_isStyleActive) {
      _loadConfigForLevel();
    } else {
      if (mounted) {
        setState(() {
          _myConfig = null;
        });
      }
    }
  }

  Future<void> _loadConfigForLevel() async {
    // Prioritize SVIP
    final String collectionName = _isSvipActive ? 'svip_levels' : 'vip_levels';
    final String levelId = _isSvipActive 
        ? 'svip${widget.activeSvipLevel}' 
        : 'vip${widget.activeVipLevel}';
    
    final cacheKey = '${collectionName}_$levelId';
    
    // Check if cache is fresh (less than 5 mins old)
    if (_configsCache.containsKey(cacheKey) && 
        _lastCacheTime != null && 
        DateTime.now().difference(_lastCacheTime!).inMinutes < 5) {
      if (mounted) {
        setState(() {
          _myConfig = _configsCache[cacheKey];
        });
      }
      return;
    }
    
    // Fetch if not loading already
    if (!_isLoadingCache) {
      _isLoadingCache = true;
      try {
        final snapshot = await FirebaseFirestore.instance.collection('config').doc(collectionName).collection('levels').get();
        for (var doc in snapshot.docs) {
          _configsCache['${collectionName}_${doc.id}'] = doc.data();
        }
        _lastCacheTime = DateTime.now();
      } catch (e) {
        debugPrint('Error loading $collectionName configs for animated name: $e');
      } finally {
        _isLoadingCache = false;
      }
    } else {
      // wait a bit for the other process to finish fetching
      await Future.delayed(const Duration(seconds: 1));
    }
    
    if (mounted) {
      setState(() {
        _myConfig = _configsCache[cacheKey];
      });
    }
  }

  Color _hexToColor(String hexCode) {
    hexCode = hexCode.replaceAll('#', '');
    if (hexCode.length == 6) {
      hexCode = 'FF$hexCode';
    }
    return Color(int.parse(hexCode, radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    if (!_isStyleActive || _myConfig == null) {
      return Text(widget.name, style: widget.style);
    }
    
    final colorMode = _myConfig!['nameColorMode'] ?? 'solid';
    final colorsStr = List<String>.from(_myConfig!['nameColors'] ?? ['#FFFFFF']);
    final animationType = _myConfig!['nameAnimation'] ?? 'none';
    
    List<Color> colors = colorsStr.map((c) {
      try {
        return _hexToColor(c);
      } catch (_) {
        return Colors.white;
      }
    }).toList();
    
    if (colors.isEmpty) colors = [Colors.white];
    
    if (colorMode == 'solid') {
      return Text(widget.name, style: (widget.style ?? const TextStyle()).copyWith(color: colors.first));
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
          shaderCallback: (bounds) => gradient.createShader(bounds),
          child: Text(
            widget.name,
            style: (widget.style ?? const TextStyle()).copyWith(color: Colors.white),
          ),
        );
      },
    );
  }
}

import 'dart:ui';
import 'package:chat_messenger/screens/audio_rooms_v2/widgets/ludo/ludo_models.dart';

class LudoPath {
  // Master path of 52 coordinates around the edge
  static const List<Offset> mainPath = [
    // Red start and left arm
    Offset(1, 8), Offset(2, 8), Offset(3, 8), Offset(4, 8), Offset(5, 8),
    // Top arm left col
    Offset(6, 5), Offset(6, 4), Offset(6, 3), Offset(6, 2), Offset(6, 1), Offset(6, 0),
    // Top edge
    Offset(7, 0), Offset(8, 0),
    // Top arm right col
    Offset(8, 1), Offset(8, 2), Offset(8, 3), Offset(8, 4), Offset(8, 5),
    // Right arm top row
    Offset(9, 6), Offset(10, 6), Offset(11, 6), Offset(12, 6), Offset(13, 6), Offset(14, 6),
    // Right edge
    Offset(14, 7), Offset(14, 8),
    // Right arm bottom row
    Offset(13, 8), Offset(12, 8), Offset(11, 8), Offset(10, 8), Offset(9, 8),
    // Bottom arm right col
    Offset(8, 9), Offset(8, 10), Offset(8, 11), Offset(8, 12), Offset(8, 13), Offset(8, 14),
    // Bottom edge
    Offset(7, 14), Offset(6, 14),
    // Bottom arm left col
    Offset(6, 13), Offset(6, 12), Offset(6, 11), Offset(6, 10), Offset(6, 9),
    // Left arm top row
    Offset(5, 6), Offset(4, 6), Offset(3, 6), Offset(2, 6), Offset(1, 6), Offset(0, 6),
    // Left edge
    Offset(0, 7),
  ];

  // Safe zones (Stars)
  static const List<Offset> safeZones = [
    Offset(1, 8),  // Red start
    Offset(6, 1),  // Top left star
    Offset(8, 1),  // Green start
    Offset(13, 6), // Top right star
    Offset(13, 8), // Yellow start
    Offset(8, 13), // Bottom right star
    Offset(6, 13), // Blue start
    Offset(1, 6),  // Bottom left star
  ];

  // Home paths (indices 52-56)
  static const Map<LudoColor, List<Offset>> homePaths = {
    LudoColor.red: [
      Offset(1, 7), Offset(2, 7), Offset(3, 7), Offset(4, 7), Offset(5, 7)
    ],
    LudoColor.green: [
      Offset(7, 1), Offset(7, 2), Offset(7, 3), Offset(7, 4), Offset(7, 5)
    ],
    LudoColor.yellow: [
      Offset(13, 7), Offset(12, 7), Offset(11, 7), Offset(10, 7), Offset(9, 7)
    ],
    LudoColor.blue: [
      Offset(7, 13), Offset(7, 12), Offset(7, 11), Offset(7, 10), Offset(7, 9)
    ],
  };

  // Base positions for each color
  static const Map<LudoColor, List<Offset>> basePositions = {
    LudoColor.red: [Offset(2, 11), Offset(3, 11), Offset(2, 12), Offset(3, 12)],
    LudoColor.green: [Offset(2, 2), Offset(3, 2), Offset(2, 3), Offset(3, 3)],
    LudoColor.yellow: [Offset(11, 2), Offset(12, 2), Offset(11, 3), Offset(12, 3)],
    LudoColor.blue: [Offset(11, 11), Offset(12, 11), Offset(11, 12), Offset(12, 12)],
  };

  // The index on the mainPath where each color starts
  static const Map<LudoColor, int> startIndices = {
    LudoColor.red: 0,
    LudoColor.green: 13,
    LudoColor.yellow: 26,
    LudoColor.blue: 39,
  };

  static Offset getPosition(LudoColor color, int position) {
    if (position == -1) {
      // In base, we shouldn't really use this directly unless we know which token (0-3) it is,
      // but for generic bounds checking we can just return a fallback.
      return Offset(0, 0); 
    }
    
    if (position >= 0 && position <= 51) {
      // It's on the main path
      final startIndex = startIndices[color]!;
      final actualIndex = (startIndex + position) % 52;
      return mainPath[actualIndex];
    }
    
    if (position >= 52 && position <= 56) {
      // It's in the home stretch
      return homePaths[color]![position - 52];
    }
    
    if (position == 57) {
      // Won (in the center triangle)
      // Return a point in the center based on color for visual winning position
      switch (color) {
        case LudoColor.red: return const Offset(6, 7.5);
        case LudoColor.green: return const Offset(7.5, 6);
        case LudoColor.yellow: return const Offset(8, 7.5);
        case LudoColor.blue: return const Offset(7.5, 8);
        default: return const Offset(7, 7);
      }
    }

    return const Offset(0, 0);
  }
}

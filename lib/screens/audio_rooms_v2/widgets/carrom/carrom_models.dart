import 'dart:math';
import 'package:equatable/equatable.dart';

enum CarromColor { white, black, red, striker, none }

class CarromPiece extends Equatable {
  final String id;
  final double x; // 0.0 to 1.0 (normalized board coordinates)
  final double y; // 0.0 to 1.0
  final double vx; // Velocity x
  final double vy; // Velocity y
  final double radius; // Normalized radius
  final CarromColor color;
  final bool isPocketed;

  const CarromPiece({
    required this.id,
    required this.x,
    required this.y,
    this.vx = 0.0,
    this.vy = 0.0,
    required this.radius,
    required this.color,
    this.isPocketed = false,
  });

  factory CarromPiece.fromJson(Map<String, dynamic> json) {
    return CarromPiece(
      id: json['id']?.toString() ?? '',
      x: (json['x'] as num?)?.toDouble() ?? 0.0,
      y: (json['y'] as num?)?.toDouble() ?? 0.0,
      vx: (json['vx'] as num?)?.toDouble() ?? 0.0,
      vy: (json['vy'] as num?)?.toDouble() ?? 0.0,
      radius: (json['radius'] as num?)?.toDouble() ?? 0.024,
      color: CarromColor.values.firstWhere(
        (e) => e.toString() == json['color'],
        orElse: () => CarromColor.none,
      ),
      isPocketed: json['isPocketed'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'x': x,
      'y': y,
      'vx': vx,
      'vy': vy,
      'radius': radius,
      'color': color.toString(),
      'isPocketed': isPocketed,
    };
  }

  CarromPiece copyWith({
    double? x,
    double? y,
    double? vx,
    double? vy,
    double? radius,
    CarromColor? color,
    bool? isPocketed,
  }) {
    return CarromPiece(
      id: id,
      x: x ?? this.x,
      y: y ?? this.y,
      vx: vx ?? this.vx,
      vy: vy ?? this.vy,
      radius: radius ?? this.radius,
      color: color ?? this.color,
      isPocketed: isPocketed ?? this.isPocketed,
    );
  }

  @override
  List<Object?> get props => [id, x, y, vx, vy, radius, color, isPocketed];
}

class CarromGameState extends Equatable {
  final Map<String, String?> players; // Seat ('bottom', 'left', 'top', 'right') to UserId mapping
  final int maxPlayers;
  final bool isStarted;
  final String currentTurn; // 'bottom', 'left', 'top', 'right'
  final List<CarromPiece> pieces;
  final String? winner;
  final int lastTurnStartTime;
  final Map<String, int> scores; // 'white' and 'black' team scores
  final String queenStatus; // 'none', 'pocketed_waiting_cover', 'covered'
  final String? queenOwner; // Who pocketed the queen ('bottom', 'left', etc.)
  final Map<String, dynamic>? shotState; // active shot: { 'strikerX': x, 'strikerY': y, 'vx': vx, 'vy': vy, 'timestamp': time }

  const CarromGameState({
    this.players = const {},
    this.maxPlayers = 2,
    this.isStarted = false,
    this.currentTurn = 'bottom',
    this.pieces = const [],
    this.winner,
    this.lastTurnStartTime = 0,
    this.scores = const {'white': 0, 'black': 0},
    this.queenStatus = 'none',
    this.queenOwner,
    this.shotState,
  });

  factory CarromGameState.initial({int maxPlayers = 2}) {
    // Generate pieces in the center
    final List<CarromPiece> initialPieces = [];
    final double cx = 0.5;
    final double cy = 0.5;
    final double pieceRad = 0.024; // standard piece radius

    // 1. Red Queen in center
    initialPieces.add(CarromPiece(id: 'queen', x: cx, y: cy, radius: pieceRad, color: CarromColor.red));

    // 2. Inner ring (6 pieces: 3 White, 3 Black alternating)
    final double r1 = 0.048;
    for (int i = 0; i < 6; i++) {
      final double angle = i * pi / 3;
      final double px = cx + r1 * cos(angle);
      final double py = cy + r1 * sin(angle);
      final color = (i % 2 == 0) ? CarromColor.white : CarromColor.black;
      initialPieces.add(CarromPiece(
        id: '${color.name}_inner_$i',
        x: px,
        y: py,
        radius: pieceRad,
        color: color,
      ));
    }

    // 3. Outer ring (12 pieces: 6 White, 6 Black alternating)
    // Offset angle by 15 degrees (pi / 12) so they interlock with inner ring
    final double r2 = 0.092;
    for (int i = 0; i < 12; i++) {
      final double angle = i * pi / 6 + pi / 12;
      final double px = cx + r2 * cos(angle);
      final double py = cy + r2 * sin(angle);
      final color = (i % 2 == 0) ? CarromColor.white : CarromColor.black;
      initialPieces.add(CarromPiece(
        id: '${color.name}_outer_$i',
        x: px,
        y: py,
        radius: pieceRad,
        color: color,
      ));
    }

    return CarromGameState(
      maxPlayers: maxPlayers,
      isStarted: false,
      currentTurn: 'bottom',
      pieces: initialPieces,
      lastTurnStartTime: DateTime.now().millisecondsSinceEpoch,
      scores: const {'white': 0, 'black': 0},
      queenStatus: 'none',
    );
  }

  factory CarromGameState.fromJson(Map<String, dynamic> json) {
    // Parse players
    final Map<String, String?> parsedPlayers = {};
    if (json['players'] != null) {
      final playersMap = Map<dynamic, dynamic>.from(json['players'] as Map);
      playersMap.forEach((key, value) {
        parsedPlayers[key.toString()] = value?.toString();
      });
    }

    // Parse pieces
    List<CarromPiece> parsedPieces = [];
    if (json['pieces'] != null) {
      parsedPieces = (json['pieces'] as List<dynamic>)
          .map((e) => CarromPiece.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } else {
      parsedPieces = CarromGameState.initial(maxPlayers: (json['maxPlayers'] as num?)?.toInt() ?? 2).pieces;
    }

    // Parse scores
    Map<String, int> parsedScores = {'white': 0, 'black': 0};
    if (json['scores'] != null) {
      final scoreMap = Map<String, dynamic>.from(json['scores'] as Map);
      parsedScores['white'] = (scoreMap['white'] as num?)?.toInt() ?? 0;
      parsedScores['black'] = (scoreMap['black'] as num?)?.toInt() ?? 0;
    }

    return CarromGameState(
      players: parsedPlayers,
      maxPlayers: (json['maxPlayers'] as num?)?.toInt() ?? 2,
      isStarted: json['isStarted'] == true,
      currentTurn: json['currentTurn']?.toString() ?? 'bottom',
      pieces: parsedPieces,
      winner: json['winner']?.toString(),
      lastTurnStartTime: (json['lastTurnStartTime'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      scores: parsedScores,
      queenStatus: json['queenStatus']?.toString() ?? 'none',
      queenOwner: json['queenOwner']?.toString(),
      shotState: json['shotState'] != null ? Map<String, dynamic>.from(json['shotState'] as Map) : null,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, String?> jsonPlayers = {};
    players.forEach((key, value) {
      jsonPlayers[key] = value;
    });

    return {
      'players': jsonPlayers,
      'maxPlayers': maxPlayers,
      'isStarted': isStarted,
      'currentTurn': currentTurn,
      'pieces': pieces.map((e) => e.toJson()).toList(),
      'winner': winner,
      'lastTurnStartTime': lastTurnStartTime,
      'scores': scores,
      'queenStatus': queenStatus,
      'queenOwner': queenOwner,
      'shotState': shotState,
    };
  }

  CarromGameState copyWith({
    Map<String, String?>? players,
    int? maxPlayers,
    bool? isStarted,
    String? currentTurn,
    List<CarromPiece>? pieces,
    String? winner,
    int? lastTurnStartTime,
    Map<String, int>? scores,
    String? queenStatus,
    String? queenOwner,
    Map<String, dynamic>? shotState,
  }) {
    return CarromGameState(
      players: players ?? this.players,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      isStarted: isStarted ?? this.isStarted,
      currentTurn: currentTurn ?? this.currentTurn,
      pieces: pieces ?? this.pieces,
      winner: winner ?? this.winner,
      lastTurnStartTime: lastTurnStartTime ?? this.lastTurnStartTime,
      scores: scores ?? this.scores,
      queenStatus: queenStatus ?? this.queenStatus,
      queenOwner: queenOwner ?? this.queenOwner,
      shotState: shotState, // Allows setting to null explicitly if we don't pass it or pass it.
    );
  }

  @override
  List<Object?> get props => [
        players,
        maxPlayers,
        isStarted,
        currentTurn,
        pieces,
        winner,
        lastTurnStartTime,
        scores,
        queenStatus,
        queenOwner,
        shotState,
      ];
}

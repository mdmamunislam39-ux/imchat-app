import 'package:equatable/equatable.dart';

enum LudoColor { red, green, yellow, blue, none }

class LudoToken extends Equatable {
  final String id;
  final LudoColor color;
  final int index; // 0-3 for the 4 tokens of a color
  final int position; // -1 = Home, 0-56 = Path, 57 = Won

  const LudoToken({
    required this.id,
    required this.color,
    required this.index,
    required this.position,
  });

  factory LudoToken.fromJson(Map<String, dynamic> json) {
    return LudoToken(
      id: json['id']?.toString() ?? '',
      color: LudoColor.values.firstWhere((e) => e.toString() == json['color'], orElse: () => LudoColor.red),
      index: (json['index'] as num?)?.toInt() ?? 0,
      position: (json['position'] as num?)?.toInt() ?? -1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'color': color.toString(),
      'index': index,
      'position': position,
    };
  }

  LudoToken copyWith({int? position}) {
    return LudoToken(
      id: id,
      color: color,
      index: index,
      position: position ?? this.position,
    );
  }

  @override
  List<Object?> get props => [id, color, index, position];
}

class LudoGameState extends Equatable {
  final Map<LudoColor, String?> players; // Color to UserId mapping
  final int maxPlayers;
  final LudoColor currentTurn;
  final int diceValue;
  final bool isDiceRolled;
  final List<LudoToken> tokens;
  final String? winner;
  final int lastTurnStartTime;

  const LudoGameState({
    this.players = const {},
    this.maxPlayers = 4,
    this.currentTurn = LudoColor.red,
    this.diceValue = 1,
    this.isDiceRolled = false,
    this.tokens = const [],
    this.winner,
    this.lastTurnStartTime = 0,
  });

  factory LudoGameState.initial({int maxPlayers = 4}) {
    List<LudoToken> initialTokens = [];
    for (var color in [LudoColor.red, LudoColor.green, LudoColor.yellow, LudoColor.blue]) {
      for (int i = 0; i < 4; i++) {
        initialTokens.add(LudoToken(id: '${color.name}_$i', color: color, index: i, position: -1));
      }
    }
    return LudoGameState(
      maxPlayers: maxPlayers, 
      tokens: initialTokens,
      lastTurnStartTime: DateTime.now().millisecondsSinceEpoch,
    );
  }

  factory LudoGameState.fromJson(Map<String, dynamic> json) {
    final Map<LudoColor, String?> parsedPlayers = {};
    if (json['players'] != null) {
      (json['players'] as Map<String, dynamic>).forEach((key, value) {
        final color = LudoColor.values.firstWhere((e) => e.toString() == key, orElse: () => LudoColor.none);
        if (color != LudoColor.none) {
          parsedPlayers[color] = value?.toString();
        }
      });
    }

    final parsedTokens = (json['tokens'] as List<dynamic>?)
            ?.map((e) => LudoToken.fromJson(e as Map<String, dynamic>))
            .toList() ??
        LudoGameState.initial().tokens;

    return LudoGameState(
      players: parsedPlayers,
      maxPlayers: (json['maxPlayers'] as num?)?.toInt() ?? 4,
      currentTurn: LudoColor.values.firstWhere((e) => e.toString() == json['currentTurn'], orElse: () => LudoColor.red),
      diceValue: (json['diceValue'] as num?)?.toInt() ?? 1,
      isDiceRolled: json['isDiceRolled'] == true,
      tokens: parsedTokens,
      winner: json['winner']?.toString(),
      lastTurnStartTime: (json['lastTurnStartTime'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, String?> jsonPlayers = {};
    players.forEach((key, value) {
      jsonPlayers[key.toString()] = value;
    });

    return {
      'players': jsonPlayers,
      'maxPlayers': maxPlayers,
      'currentTurn': currentTurn.toString(),
      'diceValue': diceValue,
      'isDiceRolled': isDiceRolled,
      'tokens': tokens.map((e) => e.toJson()).toList(),
      'winner': winner,
      'lastTurnStartTime': lastTurnStartTime,
    };
  }

  LudoGameState copyWith({
    Map<LudoColor, String?>? players,
    int? maxPlayers,
    LudoColor? currentTurn,
    int? diceValue,
    bool? isDiceRolled,
    List<LudoToken>? tokens,
    String? winner,
    int? lastTurnStartTime,
  }) {
    return LudoGameState(
      players: players ?? this.players,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      currentTurn: currentTurn ?? this.currentTurn,
      diceValue: diceValue ?? this.diceValue,
      isDiceRolled: isDiceRolled ?? this.isDiceRolled,
      tokens: tokens ?? this.tokens,
      winner: winner ?? this.winner,
      lastTurnStartTime: lastTurnStartTime ?? this.lastTurnStartTime,
    );
  }

  @override
  List<Object?> get props => [players, maxPlayers, currentTurn, diceValue, isDiceRolled, tokens, winner, lastTurnStartTime];
}

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
      color: LudoColor.values.firstWhere((e) => e.name == json['color'] || e.toString() == json['color'], orElse: () => LudoColor.red),
      index: (json['index'] as num?)?.toInt() ?? 0,
      position: (json['position'] as num?)?.toInt() ?? -1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'color': color.name,
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
  final Map<LudoColor, String?> playerNames; // Color to display name mapping
  final Map<LudoColor, String?> playerAvatars; // Color to avatar image URL mapping
  final int maxPlayers;
  final bool isStarted;
  final LudoColor currentTurn;
  final int diceValue;
  final bool isDiceRolled;
  final List<LudoToken> tokens;
  final String? winner;
  final int lastTurnStartTime;

  const LudoGameState({
    this.players = const {},
    this.playerNames = const {},
    this.playerAvatars = const {},
    this.maxPlayers = 2,
    this.isStarted = false,
    this.currentTurn = LudoColor.red,
    this.diceValue = 1,
    this.isDiceRolled = false,
    this.tokens = const [],
    this.winner,
    this.lastTurnStartTime = 0,
  });

  factory LudoGameState.initial({int maxPlayers = 2}) {
    List<LudoToken> initialTokens = [];
    for (var color in [LudoColor.red, LudoColor.yellow]) {
      for (int i = 0; i < 4; i++) {
        initialTokens.add(LudoToken(id: '${color.name}_$i', color: color, index: i, position: -1));
      }
    }
    return LudoGameState(
      maxPlayers: maxPlayers,
      isStarted: false,
      currentTurn: LudoColor.red,
      tokens: initialTokens,
      lastTurnStartTime: DateTime.now().millisecondsSinceEpoch,
    );
  }

  factory LudoGameState.fromJson(Map<String, dynamic> json) {
    final Map<LudoColor, String?> parsedPlayers = {};
    if (json['players'] != null) {
      (json['players'] as Map<dynamic, dynamic>).forEach((key, value) {
        final color = LudoColor.values.firstWhere((e) => e.name == key || e.toString() == key, orElse: () => LudoColor.none);
        if (color != LudoColor.none) {
          parsedPlayers[color] = value?.toString();
        }
      });
    }

    final Map<LudoColor, String?> parsedNames = {};
    if (json['playerNames'] != null) {
      (json['playerNames'] as Map<dynamic, dynamic>).forEach((key, value) {
        final color = LudoColor.values.firstWhere((e) => e.name == key || e.toString() == key, orElse: () => LudoColor.none);
        if (color != LudoColor.none) {
          parsedNames[color] = value?.toString();
        }
      });
    }

    final Map<LudoColor, String?> parsedAvatars = {};
    if (json['playerAvatars'] != null) {
      (json['playerAvatars'] as Map<dynamic, dynamic>).forEach((key, value) {
        final color = LudoColor.values.firstWhere((e) => e.name == key || e.toString() == key, orElse: () => LudoColor.none);
        if (color != LudoColor.none) {
          parsedAvatars[color] = value?.toString();
        }
      });
    }

    final parsedTokens = (json['tokens'] as List<dynamic>?)
            ?.map((e) => LudoToken.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList() ??
        LudoGameState.initial().tokens;

    return LudoGameState(
      players: parsedPlayers,
      playerNames: parsedNames,
      playerAvatars: parsedAvatars,
      maxPlayers: (json['maxPlayers'] as num?)?.toInt() ?? 2,
      isStarted: json['isStarted'] == true,
      currentTurn: LudoColor.values.firstWhere((e) => e.name == json['currentTurn'] || e.toString() == json['currentTurn'], orElse: () => LudoColor.red),
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
      jsonPlayers[key.name] = value;
    });

    final Map<String, String?> jsonNames = {};
    playerNames.forEach((key, value) {
      jsonNames[key.name] = value;
    });

    final Map<String, String?> jsonAvatars = {};
    playerAvatars.forEach((key, value) {
      jsonAvatars[key.name] = value;
    });

    return {
      'players': jsonPlayers,
      'playerNames': jsonNames,
      'playerAvatars': jsonAvatars,
      'maxPlayers': maxPlayers,
      'isStarted': isStarted,
      'currentTurn': currentTurn.name,
      'diceValue': diceValue,
      'isDiceRolled': isDiceRolled,
      'tokens': tokens.map((e) => e.toJson()).toList(),
      'winner': winner,
      'lastTurnStartTime': lastTurnStartTime,
    };
  }

  LudoGameState copyWith({
    Map<LudoColor, String?>? players,
    Map<LudoColor, String?>? playerNames,
    Map<LudoColor, String?>? playerAvatars,
    int? maxPlayers,
    bool? isStarted,
    LudoColor? currentTurn,
    int? diceValue,
    bool? isDiceRolled,
    List<LudoToken>? tokens,
    String? winner,
    int? lastTurnStartTime,
  }) {
    return LudoGameState(
      players: players ?? this.players,
      playerNames: playerNames ?? this.playerNames,
      playerAvatars: playerAvatars ?? this.playerAvatars,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      isStarted: isStarted ?? this.isStarted,
      currentTurn: currentTurn ?? this.currentTurn,
      diceValue: diceValue ?? this.diceValue,
      isDiceRolled: isDiceRolled ?? this.isDiceRolled,
      tokens: tokens ?? this.tokens,
      winner: winner ?? this.winner,
      lastTurnStartTime: lastTurnStartTime ?? this.lastTurnStartTime,
    );
  }

  @override
  List<Object?> get props => [players, playerNames, playerAvatars, maxPlayers, isStarted, currentTurn, diceValue, isDiceRolled, tokens, winner, lastTurnStartTime];
}

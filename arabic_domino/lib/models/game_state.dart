import 'domino_tile.dart';

enum PlayerKind { human, ai }

enum Difficulty { easy, medium, hard }

enum GameStatus { ongoing, humanWon, aiWon, draw }

enum BoardSide { left, right }

/// A tile on the board with the orientation it was played in.
class BoardTile {
  final DominoTile tile;
  // exposed values on each side of the chain.
  final int leftValue;
  final int rightValue;
  BoardTile(this.tile, this.leftValue, this.rightValue);
}

class GameState {
  final List<DominoTile> humanHand;
  final List<DominoTile> aiHand;
  final List<DominoTile> boneyard;
  final List<BoardTile> board;
  final PlayerKind turn;
  final GameStatus status;
  final int humanScore;
  final int aiScore;
  final int humanRoundsWon;
  final int aiRoundsWon;
  final Difficulty difficulty;
  // When a player passes (no playable + boneyard empty), record consecutive passes
  final int consecutivePasses;
  // Track which suits opponent has shown they don't have (drew/passed on)
  // For the AI to model the human; index 0..6 -> known to lack
  final Set<int> humanLacks;
  final Set<int> aiLacks;
  // last move marker (for animations / sound)
  final DominoTile? lastPlayedTile;
  final BoardSide? lastPlayedSide;
  final PlayerKind? lastMover;
  // event message to show in UI (Arabic)
  final String? lastEventMessage;

  GameState({
    required this.humanHand,
    required this.aiHand,
    required this.boneyard,
    required this.board,
    required this.turn,
    required this.status,
    required this.humanScore,
    required this.aiScore,
    required this.humanRoundsWon,
    required this.aiRoundsWon,
    required this.difficulty,
    this.consecutivePasses = 0,
    Set<int>? humanLacks,
    Set<int>? aiLacks,
    this.lastPlayedTile,
    this.lastPlayedSide,
    this.lastMover,
    this.lastEventMessage,
  })  : humanLacks = humanLacks ?? <int>{},
        aiLacks = aiLacks ?? <int>{};

  int? get leftEnd => board.isEmpty ? null : board.first.leftValue;
  int? get rightEnd => board.isEmpty ? null : board.last.rightValue;

  GameState copyWith({
    List<DominoTile>? humanHand,
    List<DominoTile>? aiHand,
    List<DominoTile>? boneyard,
    List<BoardTile>? board,
    PlayerKind? turn,
    GameStatus? status,
    int? humanScore,
    int? aiScore,
    int? humanRoundsWon,
    int? aiRoundsWon,
    Difficulty? difficulty,
    int? consecutivePasses,
    Set<int>? humanLacks,
    Set<int>? aiLacks,
    DominoTile? lastPlayedTile,
    BoardSide? lastPlayedSide,
    PlayerKind? lastMover,
    String? lastEventMessage,
    bool clearLastEvent = false,
  }) {
    return GameState(
      humanHand: humanHand ?? this.humanHand,
      aiHand: aiHand ?? this.aiHand,
      boneyard: boneyard ?? this.boneyard,
      board: board ?? this.board,
      turn: turn ?? this.turn,
      status: status ?? this.status,
      humanScore: humanScore ?? this.humanScore,
      aiScore: aiScore ?? this.aiScore,
      humanRoundsWon: humanRoundsWon ?? this.humanRoundsWon,
      aiRoundsWon: aiRoundsWon ?? this.aiRoundsWon,
      difficulty: difficulty ?? this.difficulty,
      consecutivePasses: consecutivePasses ?? this.consecutivePasses,
      humanLacks: humanLacks ?? this.humanLacks,
      aiLacks: aiLacks ?? this.aiLacks,
      lastPlayedTile: lastPlayedTile ?? this.lastPlayedTile,
      lastPlayedSide: lastPlayedSide ?? this.lastPlayedSide,
      lastMover: lastMover ?? this.lastMover,
      lastEventMessage:
          clearLastEvent ? null : (lastEventMessage ?? this.lastEventMessage),
    );
  }
}

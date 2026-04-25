import 'dart:math';

import '../models/domino_tile.dart';
import '../models/game_state.dart';

/// Stateless rule helpers + state transitions for classic 1v1 draw domino.
class GameEngine {
  static const int handSize = 7;

  /// Create the starting state of a fresh round.
  ///
  /// Whoever holds the highest double opens with it. If neither player has any
  /// double, the player with the heaviest single tile opens with that tile. If
  /// nothing matches at all (extremely rare), the human starts.
  static GameState newRound({
    required Difficulty difficulty,
    int humanRoundsWon = 0,
    int aiRoundsWon = 0,
    int humanScore = 0,
    int aiScore = 0,
    Random? rng,
  }) {
    final r = rng ?? Random();
    final tiles = DominoTile.standardSet()..shuffle(r);
    final human = tiles.sublist(0, handSize);
    final ai = tiles.sublist(handSize, handSize * 2);
    final boneyard = tiles.sublist(handSize * 2);

    // Determine opener.
    PlayerKind opener = PlayerKind.human;
    DominoTile? openTile;
    for (var v = 6; v >= 0; v--) {
      final candidate = DominoTile(v, v);
      final inHuman = human.contains(candidate);
      final inAi = ai.contains(candidate);
      if (inHuman || inAi) {
        opener = inHuman ? PlayerKind.human : PlayerKind.ai;
        openTile = candidate;
        break;
      }
    }
    // Fallback: heaviest single.
    if (openTile == null) {
      DominoTile? best;
      PlayerKind bestOwner = PlayerKind.human;
      for (final t in human) {
        if (best == null || t.pips > best.pips) {
          best = t;
          bestOwner = PlayerKind.human;
        }
      }
      for (final t in ai) {
        if (best == null || t.pips > best.pips) {
          best = t;
          bestOwner = PlayerKind.ai;
        }
      }
      openTile = best;
      opener = bestOwner;
    }

    // Auto-play opening tile.
    final humanHand = List<DominoTile>.from(human);
    final aiHand = List<DominoTile>.from(ai);
    if (openTile != null) {
      if (opener == PlayerKind.human) {
        humanHand.remove(openTile);
      } else {
        aiHand.remove(openTile);
      }
    }
    final board = <BoardTile>[];
    String? message;
    if (openTile != null) {
      board.add(BoardTile(openTile, openTile.left, openTile.right));
      message = opener == PlayerKind.human
          ? 'بدأت اللعبة بحجر ${_arabicTile(openTile)}'
          : 'الكمبيوتر بدأ بحجر ${_arabicTile(openTile)}';
    }

    final nextTurn = opener == PlayerKind.human ? PlayerKind.ai : PlayerKind.human;

    return GameState(
      humanHand: humanHand,
      aiHand: aiHand,
      boneyard: boneyard,
      board: board,
      turn: nextTurn,
      status: GameStatus.ongoing,
      humanScore: humanScore,
      aiScore: aiScore,
      humanRoundsWon: humanRoundsWon,
      aiRoundsWon: aiRoundsWon,
      difficulty: difficulty,
      lastPlayedTile: openTile,
      lastPlayedSide: BoardSide.right,
      lastMover: opener,
      lastEventMessage: message,
    );
  }

  static String _arabicTile(DominoTile t) => '(${t.left}|${t.right})';

  /// Returns true if the hand contains any playable tile against the board.
  static bool hasPlayable(List<DominoTile> hand, GameState s) {
    if (s.board.isEmpty) return hand.isNotEmpty;
    final l = s.leftEnd!;
    final r = s.rightEnd!;
    return hand.any((t) => t.hasValue(l) || t.hasValue(r));
  }

  /// All legal moves: pairs of (tile, side) where side indicates which end.
  static List<({DominoTile tile, BoardSide side})> legalMoves(
      List<DominoTile> hand, GameState s) {
    final moves = <({DominoTile tile, BoardSide side})>[];
    if (s.board.isEmpty) {
      for (final t in hand) {
        moves.add((tile: t, side: BoardSide.right));
      }
      return moves;
    }
    final l = s.leftEnd!;
    final r = s.rightEnd!;
    for (final t in hand) {
      if (t.hasValue(l)) moves.add((tile: t, side: BoardSide.left));
      if (t.hasValue(r) && (t.hasValue(l) ? l != r : true)) {
        // avoid duplicate when both ends are same value AND tile matches both
        if (!(t.hasValue(l) && l == r)) {
          moves.add((tile: t, side: BoardSide.right));
        }
      }
    }
    return moves;
  }

  /// Apply a move (must be legal). Updates board, removes tile from mover hand,
  /// and toggles turn / detects round end.
  static GameState applyMove(
    GameState s,
    DominoTile tile,
    BoardSide side,
    PlayerKind mover,
  ) {
    final newBoard = List<BoardTile>.from(s.board);

    if (newBoard.isEmpty) {
      newBoard.add(BoardTile(tile, tile.left, tile.right));
    } else if (side == BoardSide.left) {
      final l = s.leftEnd!;
      // Orient so the tile's right side equals l (it then exposes its OTHER side on the new left).
      late BoardTile bt;
      if (tile.right == l) {
        bt = BoardTile(tile, tile.left, l);
      } else {
        bt = BoardTile(DominoTile(tile.right, tile.left), tile.right, l);
      }
      // After insertion the new left exposed end is bt.leftValue; rightValue of bt equals the previous leftEnd.
      newBoard.insert(0, bt);
    } else {
      final r = s.rightEnd!;
      late BoardTile bt;
      if (tile.left == r) {
        bt = BoardTile(tile, r, tile.right);
      } else {
        bt = BoardTile(DominoTile(tile.right, tile.left), r, tile.left);
      }
      newBoard.add(bt);
    }

    final newHumanHand = List<DominoTile>.from(s.humanHand);
    final newAiHand = List<DominoTile>.from(s.aiHand);
    if (mover == PlayerKind.human) {
      newHumanHand.remove(tile);
    } else {
      newAiHand.remove(tile);
    }

    GameStatus status = GameStatus.ongoing;
    int hScore = s.humanScore;
    int aScore = s.aiScore;
    int hWon = s.humanRoundsWon;
    int aWon = s.aiRoundsWon;
    String? msg;

    // Round-end check: hand emptied.
    if (mover == PlayerKind.human && newHumanHand.isEmpty) {
      status = GameStatus.humanWon;
      final pts = newAiHand.fold<int>(0, (a, t) => a + t.pips);
      hScore += pts;
      hWon += 1;
      msg = 'كسبت! +$pts نقطة';
    } else if (mover == PlayerKind.ai && newAiHand.isEmpty) {
      status = GameStatus.aiWon;
      final pts = newHumanHand.fold<int>(0, (a, t) => a + t.pips);
      aScore += pts;
      aWon += 1;
      msg = 'الكمبيوتر كسب! +$pts نقطة';
    }

    return s.copyWith(
      humanHand: newHumanHand,
      aiHand: newAiHand,
      board: newBoard,
      turn: mover == PlayerKind.human ? PlayerKind.ai : PlayerKind.human,
      status: status,
      humanScore: hScore,
      aiScore: aScore,
      humanRoundsWon: hWon,
      aiRoundsWon: aWon,
      consecutivePasses: 0,
      lastPlayedTile: tile,
      lastPlayedSide: side,
      lastMover: mover,
      lastEventMessage: msg,
    );
  }

  /// Draw a single tile from boneyard for [mover]. Returns the new state.
  /// Records that the mover lacks both ends (only if drawn because no playable).
  static GameState drawTile(GameState s, PlayerKind mover, {bool recordLack = true}) {
    if (s.boneyard.isEmpty) return s;
    final newBoneyard = List<DominoTile>.from(s.boneyard);
    final t = newBoneyard.removeLast();
    final newHumanHand = List<DominoTile>.from(s.humanHand);
    final newAiHand = List<DominoTile>.from(s.aiHand);
    final newHumanLacks = Set<int>.from(s.humanLacks);
    final newAiLacks = Set<int>.from(s.aiLacks);
    if (mover == PlayerKind.human) {
      newHumanHand.add(t);
      if (recordLack && s.board.isNotEmpty) {
        newHumanLacks.add(s.leftEnd!);
        newHumanLacks.add(s.rightEnd!);
      }
    } else {
      newAiHand.add(t);
      if (recordLack && s.board.isNotEmpty) {
        newAiLacks.add(s.leftEnd!);
        newAiLacks.add(s.rightEnd!);
      }
    }
    return s.copyWith(
      humanHand: newHumanHand,
      aiHand: newAiHand,
      boneyard: newBoneyard,
      humanLacks: newHumanLacks,
      aiLacks: newAiLacks,
      lastEventMessage: mover == PlayerKind.human
          ? 'سحبت حجر من البنك'
          : 'الكمبيوتر سحب حجر',
    );
  }

  /// When a player cannot play and the boneyard is empty: pass.
  static GameState pass(GameState s, PlayerKind mover) {
    final passes = s.consecutivePasses + 1;
    GameStatus status = s.status;
    int hScore = s.humanScore;
    int aScore = s.aiScore;
    int hWon = s.humanRoundsWon;
    int aWon = s.aiRoundsWon;
    String? msg = mover == PlayerKind.human
        ? 'مفيش عندك حجر تلعبه — دور الكمبيوتر'
        : 'الكمبيوتر معندوش حجر — دورك';

    final newHumanLacks = Set<int>.from(s.humanLacks);
    final newAiLacks = Set<int>.from(s.aiLacks);
    if (s.board.isNotEmpty) {
      if (mover == PlayerKind.human) {
        newHumanLacks.add(s.leftEnd!);
        newHumanLacks.add(s.rightEnd!);
      } else {
        newAiLacks.add(s.leftEnd!);
        newAiLacks.add(s.rightEnd!);
      }
    }

    if (passes >= 2) {
      // Both players blocked. Lower pip count wins.
      final hPips = s.humanHand.fold<int>(0, (a, t) => a + t.pips);
      final aPips = s.aiHand.fold<int>(0, (a, t) => a + t.pips);
      if (hPips < aPips) {
        status = GameStatus.humanWon;
        hScore += aPips;
        hWon += 1;
        msg = 'مسدودة! كسبت بفارق النقاط +$aPips';
      } else if (aPips < hPips) {
        status = GameStatus.aiWon;
        aScore += hPips;
        aWon += 1;
        msg = 'مسدودة! الكمبيوتر كسب +$hPips';
      } else {
        status = GameStatus.draw;
        msg = 'تعادل! مفيش نقاط';
      }
    }

    return s.copyWith(
      turn: mover == PlayerKind.human ? PlayerKind.ai : PlayerKind.human,
      consecutivePasses: passes,
      status: status,
      humanScore: hScore,
      aiScore: aScore,
      humanRoundsWon: hWon,
      aiRoundsWon: aWon,
      humanLacks: newHumanLacks,
      aiLacks: newAiLacks,
      lastEventMessage: msg,
    );
  }
}

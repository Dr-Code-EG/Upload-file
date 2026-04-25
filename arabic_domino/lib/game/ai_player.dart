import 'dart:math';

import '../models/domino_tile.dart';
import '../models/game_state.dart';
import 'game_engine.dart';

/// AI move selection. Three difficulty levels:
///  - easy   : random legal move
///  - medium : heuristic — prefer heavy pips, prefer doubles, prefer ends the
///             player likely lacks; small randomization.
///  - hard   : same heuristic plus look-ahead one ply (minimax-style) and
///             stronger opponent modelling using tracked lacks.
class AIPlayer {
  final Random _rng;
  AIPlayer([Random? rng]) : _rng = rng ?? Random();

  ({DominoTile tile, BoardSide side})? choose(GameState s) {
    final moves = GameEngine.legalMoves(s.aiHand, s);
    if (moves.isEmpty) return null;
    switch (s.difficulty) {
      case Difficulty.easy:
        return moves[_rng.nextInt(moves.length)];
      case Difficulty.medium:
        return _heuristicChoice(s, moves, lookAhead: false);
      case Difficulty.hard:
        return _heuristicChoice(s, moves, lookAhead: true);
    }
  }

  ({DominoTile tile, BoardSide side}) _heuristicChoice(
    GameState s,
    List<({DominoTile tile, BoardSide side})> moves, {
    required bool lookAhead,
  }) {
    double bestScore = -1e9;
    var best = moves.first;
    for (final m in moves) {
      final score = _scoreMove(s, m, lookAhead: lookAhead);
      // tiny randomness on hard avoids being too predictable
      final jitter = _rng.nextDouble() * 0.5;
      if (score + jitter > bestScore) {
        bestScore = score + jitter;
        best = m;
      }
    }
    return best;
  }

  double _scoreMove(
    GameState s,
    ({DominoTile tile, BoardSide side}) move, {
    required bool lookAhead,
  }) {
    // Apply the move hypothetically.
    final after = GameEngine.applyMove(s, move.tile, move.side, PlayerKind.ai);
    if (after.status == GameStatus.aiWon) return 1e6;

    double score = 0;

    // Get rid of heavy tiles first.
    score += move.tile.pips * 1.0;

    // Doubles are valuable to dump (otherwise they become hard to place).
    if (move.tile.isDouble) score += 6.0;

    // Hand-balance: how many tiles in remaining hand can still play vs new ends.
    final remaining = after.aiHand;
    final newL = after.leftEnd!;
    final newR = after.rightEnd!;
    int playableCount = 0;
    for (final t in remaining) {
      if (t.hasValue(newL) || t.hasValue(newR)) playableCount++;
    }
    score += playableCount * 1.5;

    // Diversity of suits remaining (avoid getting stuck on one number).
    final suits = <int>{};
    for (final t in remaining) {
      suits.add(t.left);
      suits.add(t.right);
    }
    score += suits.length * 0.6;

    // Block opponent: if we know the human lacks a value, pushing both ends
    // toward that value is great.
    if (s.humanLacks.contains(newL)) score += 4.0;
    if (s.humanLacks.contains(newR)) score += 4.0;
    if (newL == newR && s.humanLacks.contains(newL)) score += 6.0;

    // Penalize keeping huge tiles in hand at end.
    final remainingPips = remaining.fold<int>(0, (a, t) => a + t.pips);
    score -= remainingPips * 0.25;

    if (lookAhead) {
      // One-ply: simulate human's best response with simple heuristic
      // (assume human plays heaviest legal tile).
      final humanMoves = GameEngine.legalMoves(after.humanHand, after);
      if (humanMoves.isEmpty) {
        // Even better — opponent likely needs to draw / pass.
        score += 8.0;
      } else {
        humanMoves.sort((a, b) => b.tile.pips.compareTo(a.tile.pips));
        final hMove = humanMoves.first;
        // Subtract their playable strength as cost.
        score -= hMove.tile.pips * 0.4;
        // Simulate one more step to estimate our follow-up.
        final after2 = GameEngine.applyMove(
            after, hMove.tile, hMove.side, PlayerKind.human);
        if (after2.status == GameStatus.humanWon) {
          score -= 200; // disastrous
        } else {
          // Are we still playable?
          final playable2 = GameEngine.hasPlayable(after2.aiHand, after2);
          if (!playable2) score -= 6.0;
        }
      }
    }

    return score;
  }
}

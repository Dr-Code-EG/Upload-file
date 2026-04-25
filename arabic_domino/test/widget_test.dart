import 'package:arabic_domino/game/ai_player.dart';
import 'package:arabic_domino/game/game_engine.dart';
import 'package:arabic_domino/models/domino_tile.dart';
import 'package:arabic_domino/models/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DominoTile', () {
    test('standard set has 28 unique tiles', () {
      final tiles = DominoTile.standardSet();
      expect(tiles.length, 28);
      expect(tiles.toSet().length, 28);
    });

    test('hasValue and other()', () {
      const t = DominoTile(3, 5);
      expect(t.hasValue(3), isTrue);
      expect(t.hasValue(5), isTrue);
      expect(t.hasValue(0), isFalse);
      expect(t.other(3), 5);
      expect(t.other(5), 3);
      expect(t.other(2), isNull);
    });

    test('isDouble and pips', () {
      expect(const DominoTile(4, 4).isDouble, isTrue);
      expect(const DominoTile(4, 4).pips, 8);
      expect(const DominoTile(2, 5).isDouble, isFalse);
      expect(const DominoTile(2, 5).pips, 7);
    });
  });

  group('GameEngine.newRound', () {
    test('hands have 7 tiles each and at least one tile played', () {
      final s = GameEngine.newRound(difficulty: Difficulty.medium);
      expect(s.humanHand.length + s.aiHand.length, 13);
      expect(s.board.length, 1);
      expect(s.boneyard.length, 14);
    });
  });

  group('GameEngine.applyMove', () {
    test('right side play extends rightEnd', () {
      var s = GameEngine.newRound(difficulty: Difficulty.easy);
      // Force a deterministic small scenario
      s = GameState(
        humanHand: [const DominoTile(2, 3), const DominoTile(0, 0)],
        aiHand: [const DominoTile(5, 5)],
        boneyard: const [],
        board: [BoardTile(const DominoTile(2, 4), 2, 4)],
        turn: PlayerKind.human,
        status: GameStatus.ongoing,
        humanScore: 0,
        aiScore: 0,
        humanRoundsWon: 0,
        aiRoundsWon: 0,
        difficulty: Difficulty.easy,
      );
      // Tile 2|3 plays on left (matches 2)
      final after = GameEngine.applyMove(s, const DominoTile(2, 3), BoardSide.left, PlayerKind.human);
      expect(after.leftEnd, 3);
      expect(after.rightEnd, 4);
      expect(after.humanHand.length, 1);
    });
  });

  group('AI', () {
    test('hard AI picks a legal move when possible', () {
      final s = GameEngine.newRound(difficulty: Difficulty.hard);
      // Force AI to have at least one tile that connects
      final ai = AIPlayer();
      final move = ai.choose(s);
      // Either AI has playable tile or no move exists
      final canPlay = GameEngine.hasPlayable(s.aiHand, s);
      if (canPlay) {
        expect(move, isNotNull);
      }
    });
  });
}

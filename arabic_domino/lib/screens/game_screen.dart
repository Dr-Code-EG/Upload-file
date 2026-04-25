import 'dart:async';

import 'package:flutter/material.dart';

import '../game/ai_player.dart';
import '../game/game_engine.dart';
import '../models/domino_tile.dart';
import '../models/game_state.dart';
import '../services/preferences_service.dart';
import '../services/sfx_service.dart';
import '../widgets/domino_tile_widget.dart';

class GameScreen extends StatefulWidget {
  final Difficulty difficulty;
  const GameScreen({super.key, required this.difficulty});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late GameState _state;
  final AIPlayer _ai = AIPlayer();
  DominoTile? _selected;
  bool _processing = false;
  final ScrollController _boardCtrl = ScrollController();

  /// Generation token incremented on every reset / new round. Async game
  /// loops capture the current value at start and bail out if it changes,
  /// which guarantees only one active loop after a reset.
  int _loopId = 0;

  @override
  void initState() {
    super.initState();
    _state = GameEngine.newRound(difficulty: widget.difficulty);
    SfxService.instance.play(Sfx.shuffle);
    _scheduleAfterFirstFrame();
  }

  @override
  void dispose() {
    _loopId++; // invalidate any in-flight async loops
    _boardCtrl.dispose();
    super.dispose();
  }

  void _scheduleAfterFirstFrame() {
    final myLoop = _loopId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || myLoop != _loopId) return;
      if (_state.lastMover != null) {
        SfxService.instance.play(Sfx.tilePlace);
        SfxService.instance.hapticLight();
      }
      _scrollBoardToEnd();
      if (_state.turn == PlayerKind.ai && _state.status == GameStatus.ongoing) {
        _runAiTurn();
      } else {
        _autoActIfBlocked();
      }
    });
  }

  void _scrollBoardToEnd() {
    if (!_boardCtrl.hasClients) return;
    _boardCtrl.animateTo(
      _boardCtrl.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  /// Returns true if this loop is still the active one and the widget is
  /// still mounted; false means a reset/dispose happened and the caller must
  /// abort immediately without touching state.
  bool _alive(int myLoop) => mounted && myLoop == _loopId;

  Future<void> _runAiTurn() async {
    final myLoop = _loopId;
    if (_state.status != GameStatus.ongoing) return;
    if (!_alive(myLoop)) return;
    setState(() => _processing = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!_alive(myLoop)) return;

    var working = _state;
    // Draw if needed
    while (!GameEngine.hasPlayable(working.aiHand, working) &&
        working.boneyard.isNotEmpty) {
      working = GameEngine.drawTile(working, PlayerKind.ai);
      if (!_alive(myLoop)) return;
      setState(() => _state = working);
      await SfxService.instance.play(Sfx.draw);
      await SfxService.instance.hapticLight();
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!_alive(myLoop)) return;
    }

    if (!GameEngine.hasPlayable(working.aiHand, working)) {
      // pass
      working = GameEngine.pass(working, PlayerKind.ai);
      if (!_alive(myLoop)) return;
      setState(() {
        _state = working;
        _processing = false;
      });
      await _afterTurn();
      return;
    }

    final move = _ai.choose(working);
    if (move == null) {
      working = GameEngine.pass(working, PlayerKind.ai);
      if (!_alive(myLoop)) return;
      setState(() {
        _state = working;
        _processing = false;
      });
      await _afterTurn();
      return;
    }
    working = GameEngine.applyMove(working, move.tile, move.side, PlayerKind.ai);
    if (!_alive(myLoop)) return;
    setState(() => _state = working);
    await SfxService.instance.play(Sfx.tilePlace);
    await SfxService.instance.hapticMedium();
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!_alive(myLoop)) return;
    _scrollBoardToEnd();
    setState(() => _processing = false);
    await _afterTurn();
  }

  Future<void> _autoActIfBlocked() async {
    final myLoop = _loopId;
    // If it's the human's turn but they have no playable tile and the boneyard
    // is empty, auto-pass to keep things flowing.
    if (_state.status != GameStatus.ongoing) return;
    if (_state.turn != PlayerKind.human) return;
    if (GameEngine.hasPlayable(_state.humanHand, _state)) return;
    if (_state.boneyard.isEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!_alive(myLoop)) return;
      setState(() => _state = GameEngine.pass(_state, PlayerKind.human));
      await _afterTurn();
    }
  }

  Future<void> _afterTurn() async {
    if (!mounted) return;
    if (_state.status != GameStatus.ongoing) {
      await _handleRoundEnd();
      return;
    }
    if (_state.turn == PlayerKind.ai) {
      _runAiTurn();
    } else {
      _autoActIfBlocked();
    }
  }

  Future<void> _handleRoundEnd() async {
    final isWin = _state.status == GameStatus.humanWon;
    final isDraw = _state.status == GameStatus.draw;
    if (isWin) {
      await SfxService.instance.play(Sfx.win);
      await SfxService.instance.hapticHeavy();
    } else if (!isDraw) {
      await SfxService.instance.play(Sfx.lose);
      await SfxService.instance.hapticMedium();
    }

    // Save high score (only positive human scores for the winning player).
    if (isWin && _state.humanScore > 0) {
      await PreferencesService.instance.addHighScore(HighScore(
        name: PreferencesService.instance.playerName,
        score: _state.humanScore,
        difficulty: switch (widget.difficulty) {
          Difficulty.easy => 'easy',
          Difficulty.medium => 'medium',
          Difficulty.hard => 'hard',
        },
        date: DateTime.now(),
      ));
    }

    if (!mounted) return;
    final title = isWin
        ? '🎉 مبروك! كسبت'
        : isDraw
            ? 'تعادل'
            : 'الكمبيوتر كسب';
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(title, textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_state.lastEventMessage ?? '', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(
              'النتيجة: أنت ${_state.humanScore}  ⚔  ${_state.aiScore} الكمبيوتر',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('القائمة الرئيسية'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _resetRound();
            },
            child: const Text('جولة جديدة'),
          ),
        ],
      ),
    );
  }

  Future<void> _onTilePlaced(DominoTile tile, BoardSide side) async {
    final myLoop = _loopId;
    if (_processing || _state.status != GameStatus.ongoing) return;
    if (_state.turn != PlayerKind.human) return;
    setState(() {
      _state = GameEngine.applyMove(_state, tile, side, PlayerKind.human);
      _selected = null;
    });
    await SfxService.instance.play(Sfx.tilePlace);
    await SfxService.instance.hapticLight();
    if (!_alive(myLoop)) return;
    _scrollBoardToEnd();
    await _afterTurn();
  }

  Future<void> _drawForHuman() async {
    final myLoop = _loopId;
    if (_processing || _state.turn != PlayerKind.human) return;
    if (_state.boneyard.isEmpty) return;
    setState(() => _state = GameEngine.drawTile(_state, PlayerKind.human));
    await SfxService.instance.play(Sfx.draw);
    await SfxService.instance.hapticLight();
    if (!_alive(myLoop)) return;
    if (!GameEngine.hasPlayable(_state.humanHand, _state) &&
        _state.boneyard.isEmpty) {
      // forced pass
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (!_alive(myLoop)) return;
      setState(() => _state = GameEngine.pass(_state, PlayerKind.human));
      await _afterTurn();
    }
  }

  void _resetRound() {
    // Increment loop id BEFORE replacing state so any in-flight async loop
    // bails out at its next _alive() check rather than racing with the new
    // round.
    _loopId++;
    setState(() {
      _selected = null;
      _processing = false;
      _state = GameEngine.newRound(
        difficulty: widget.difficulty,
        humanRoundsWon: _state.humanRoundsWon,
        aiRoundsWon: _state.aiRoundsWon,
        humanScore: _state.humanScore,
        aiScore: _state.aiScore,
      );
    });
    SfxService.instance.play(Sfx.shuffle);
    _scheduleAfterFirstFrame();
  }

  bool _isPlayable(DominoTile t) {
    if (_state.board.isEmpty) return true;
    return t.hasValue(_state.leftEnd!) || t.hasValue(_state.rightEnd!);
  }

  List<BoardSide> _possibleSides(DominoTile t) {
    if (_state.board.isEmpty) return [BoardSide.right];
    final l = _state.leftEnd!, r = _state.rightEnd!;
    final res = <BoardSide>[];
    if (t.hasValue(l)) res.add(BoardSide.left);
    if (t.hasValue(r) && (l != r || !t.hasValue(l))) res.add(BoardSide.right);
    return res;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final feltColor = isDark ? const Color(0xFF0E5C3A) : const Color(0xFF1F7C50);

    final humanCanPlay = GameEngine.hasPlayable(_state.humanHand, _state);
    final mustDraw =
        !humanCanPlay && _state.boneyard.isNotEmpty && _state.turn == PlayerKind.human;

    return Scaffold(
      appBar: AppBar(
        title: const Text('دومينو'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'جولة جديدة',
            // Disabling while _processing prevents racing the AI's async
            // turn loop and corrupting state. _resetRound() also bumps
            // _loopId so any pending callbacks bail out cleanly.
            onPressed: _processing ? null : _resetRound,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [feltColor.withOpacity(0.9), feltColor],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _ScoreBar(
                playerName: PreferencesService.instance.playerName,
                humanScore: _state.humanScore,
                aiScore: _state.aiScore,
                humanRoundsWon: _state.humanRoundsWon,
                aiRoundsWon: _state.aiRoundsWon,
                turn: _state.turn,
                difficulty: widget.difficulty,
                boneyard: _state.boneyard.length,
              ),
              const SizedBox(height: 8),
              _OpponentHandRow(count: _state.aiHand.length),
              const Spacer(),
              _Board(
                state: _state,
                controller: _boardCtrl,
                selected: _selected,
                possibleSides: _selected == null
                    ? const []
                    : _possibleSides(_selected!),
                onSidePicked: (side) {
                  if (_selected != null) {
                    _onTilePlaced(_selected!, side);
                  }
                },
              ),
              const Spacer(),
              if (_state.lastEventMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _state.lastEventMessage!,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              _PlayerHandRow(
                hand: _state.humanHand,
                isPlayable: _isPlayable,
                selected: _selected,
                onTap: (t) async {
                  if (_processing) return;
                  if (_state.turn != PlayerKind.human) return;
                  if (!_isPlayable(t)) return;
                  await SfxService.instance.hapticLight();
                  final sides = _possibleSides(t);
                  if (sides.length == 1) {
                    _onTilePlaced(t, sides.first);
                  } else {
                    setState(() => _selected = _selected == t ? null : t);
                  }
                },
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: mustDraw ? _drawForHuman : null,
                        icon: const Icon(Icons.add),
                        label: Text(mustDraw
                            ? 'اسحب من البنك (${_state.boneyard.length})'
                            : (humanCanPlay
                                ? (_selected != null
                                    ? 'اختر طرف اللوحة'
                                    : 'اختر حجر تلعبه')
                                : 'البنك فاضي')),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  final String playerName;
  final int humanScore;
  final int aiScore;
  final int humanRoundsWon;
  final int aiRoundsWon;
  final PlayerKind turn;
  final Difficulty difficulty;
  final int boneyard;

  const _ScoreBar({
    required this.playerName,
    required this.humanScore,
    required this.aiScore,
    required this.humanRoundsWon,
    required this.aiRoundsWon,
    required this.turn,
    required this.difficulty,
    required this.boneyard,
  });

  String get _difficultyLabel => switch (difficulty) {
        Difficulty.easy => 'سهل',
        Difficulty.medium => 'متوسط',
        Difficulty.hard => 'صعب',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.black.withOpacity(0.25),
      child: Row(
        children: [
          _PlayerBadge(
            name: 'الكمبيوتر',
            score: aiScore,
            rounds: aiRoundsWon,
            active: turn == PlayerKind.ai,
            color: Colors.red.shade300,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              children: [
                Text(
                  _difficultyLabel,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                const Icon(Icons.style, color: Colors.white70, size: 16),
                Text('بنك: $boneyard',
                    style: const TextStyle(color: Colors.white, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _PlayerBadge(
            name: playerName,
            score: humanScore,
            rounds: humanRoundsWon,
            active: turn == PlayerKind.human,
            color: Colors.amber.shade300,
          ),
        ],
      ),
    );
  }
}

class _PlayerBadge extends StatelessWidget {
  final String name;
  final int score;
  final int rounds;
  final bool active;
  final Color color;
  const _PlayerBadge({
    required this.name,
    required this.score,
    required this.rounds,
    required this.active,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active ? color.withOpacity(0.85) : Colors.white24,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: active ? Colors.white : Colors.transparent,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(name,
              style: TextStyle(
                color: active ? Colors.black : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              )),
          Text('$score',
              style: TextStyle(
                color: active ? Colors.black : Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              )),
          Text('جولات: $rounds',
              style: TextStyle(
                color: active ? Colors.black87 : Colors.white70,
                fontSize: 11,
              )),
        ],
      ),
    );
  }
}

class _OpponentHandRow extends StatelessWidget {
  final int count;
  const _OpponentHandRow({required this.count});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(width: 4),
        itemBuilder: (_, __) => const DominoTileWidget(
          tile: DominoTile(0, 0),
          faceDown: true,
          width: 32,
          height: 48,
        ),
      ),
    );
  }
}

class _PlayerHandRow extends StatelessWidget {
  final List<DominoTile> hand;
  final bool Function(DominoTile) isPlayable;
  final DominoTile? selected;
  final ValueChanged<DominoTile> onTap;
  const _PlayerHandRow({
    required this.hand,
    required this.isPlayable,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: hand.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final t = hand[i];
          final playable = isPlayable(t);
          final isSelected = selected == t;
          return GestureDetector(
            onTap: () => onTap(t),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              transform: Matrix4.identity()
                ..translate(0.0, isSelected ? -10.0 : 0.0),
              child: DominoTileWidget(
                tile: t,
                width: 76,
                height: 38,
                highlight: isSelected,
                dimmed: !playable,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Board extends StatelessWidget {
  final GameState state;
  final ScrollController controller;
  final DominoTile? selected;
  final List<BoardSide> possibleSides;
  final ValueChanged<BoardSide> onSidePicked;

  const _Board({
    required this.state,
    required this.controller,
    required this.selected,
    required this.possibleSides,
    required this.onSidePicked,
  });

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    if (selected != null && possibleSides.contains(BoardSide.left)) {
      children.add(_DropZone(
        label: 'يسار',
        onTap: () => onSidePicked(BoardSide.left),
      ));
      children.add(const SizedBox(width: 4));
    }

    for (final bt in state.board) {
      final tile = bt.tile;
      // Highlight whichever end the tile was actually played on. Left-side
      // plays are inserted at index 0 (so they become board.first), not
      // board.last.
      final isHighlighted = state.lastPlayedTile != null &&
          tile.key == state.lastPlayedTile!.key &&
          (state.lastPlayedSide == BoardSide.left
              ? state.board.first == bt
              : state.board.last == bt);
      // Doubles are drawn vertical to look like real domino chains.
      if (tile.isDouble) {
        children.add(DominoTileVertical(
          tile: tile,
          width: 32,
          height: 64,
          highlight: isHighlighted,
        ));
      } else {
        children.add(DominoTileWidget(
          tile: DominoTile(bt.leftValue, bt.rightValue),
          width: 64,
          height: 32,
          highlight: isHighlighted,
        ));
      }
      children.add(const SizedBox(width: 2));
    }
    if (children.isNotEmpty && children.last is SizedBox) children.removeLast();

    if (selected != null && possibleSides.contains(BoardSide.right)) {
      children.add(const SizedBox(width: 4));
      children.add(_DropZone(
        label: 'يمين',
        onTap: () => onSidePicked(BoardSide.right),
      ));
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: SizedBox(
        height: 80,
        child: state.board.isEmpty
            ? const Center(
                child: Text(
                  'الطاولة فاضية — في انتظار أول حجر',
                  style: TextStyle(color: Colors.white70),
                ),
              )
            : ListView(
                controller: controller,
                scrollDirection: Axis.horizontal,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: children,
                  ),
                ],
              ),
      ),
    );
  }
}

class _DropZone extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _DropZone({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 70,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.amber.shade200.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.amber, width: 2, style: BorderStyle.solid),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../models/game_state.dart';
import '../services/preferences_service.dart';
import '../services/sfx_service.dart';
import 'game_screen.dart';
import 'hall_of_fame_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Difficulty _difficulty = Difficulty.medium;

  @override
  void initState() {
    super.initState();
    _difficulty = _parseDifficulty(PreferencesService.instance.difficulty);
  }

  Difficulty _parseDifficulty(String s) => switch (s) {
        'easy' => Difficulty.easy,
        'hard' => Difficulty.hard,
        _ => Difficulty.medium,
      };

  String _difficultyKey(Difficulty d) => switch (d) {
        Difficulty.easy => 'easy',
        Difficulty.medium => 'medium',
        Difficulty.hard => 'hard',
      };

  String _difficultyLabel(Difficulty d) => switch (d) {
        Difficulty.easy => 'سهل',
        Difficulty.medium => 'متوسط',
        Difficulty.hard => 'صعب',
      };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF1B3B2A), const Color(0xFF0E1E15)]
                : [const Color(0xFFE0C58A), const Color(0xFFC9A369)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                const _Logo(),
                const SizedBox(height: 28),
                Text(
                  'لعبة الدومينو',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.amber.shade200 : const Color(0xFF3B2A1A),
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'كلاسيكي 1 ضد 1 — العب ضد الكمبيوتر',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 36),
                _DifficultySelector(
                  current: _difficulty,
                  onChanged: (d) {
                    setState(() => _difficulty = d);
                    PreferencesService.instance.setDifficulty(_difficultyKey(d));
                  },
                  labelOf: _difficultyLabel,
                ),
                const SizedBox(height: 28),
                ElevatedButton.icon(
                  onPressed: () {
                    SfxService.instance.hapticLight();
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => GameScreen(difficulty: _difficulty),
                    ));
                  },
                  icon: const Icon(Icons.play_arrow_rounded, size: 28),
                  label: const Text('ابدأ اللعبة'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const HallOfFameScreen(),
                  )),
                  icon: const Icon(Icons.emoji_events),
                  label: const Text('لوحة الشرف'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const SettingsScreen(),
                  )),
                  icon: const Icon(Icons.settings),
                  label: const Text('الإعدادات'),
                ),
                const Spacer(),
                Text(
                  'مرحبا ${PreferencesService.instance.playerName}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isDark
                            ? Colors.white60
                            : Colors.black.withOpacity(0.55),
                      ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            colors: [Color(0xFFFFE6A8), Color(0xFFD9A65B)],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Center(
          child: Text(
            '🁫',
            style: TextStyle(fontSize: 88),
          ),
        ),
      ),
    );
  }
}

class _DifficultySelector extends StatelessWidget {
  final Difficulty current;
  final ValueChanged<Difficulty> onChanged;
  final String Function(Difficulty) labelOf;
  const _DifficultySelector({
    required this.current,
    required this.onChanged,
    required this.labelOf,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'مستوى الصعوبة:',
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final d in Difficulty.values)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: SizedBox(
                      width: double.infinity,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            labelOf(d),
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    ),
                    selected: current == d,
                    onSelected: (_) => onChanged(d),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import '../services/preferences_service.dart';

class HallOfFameScreen extends StatelessWidget {
  const HallOfFameScreen({super.key});

  String _difficultyLabel(String key) => switch (key) {
        'easy' => 'سهل',
        'medium' => 'متوسط',
        'hard' => 'صعب',
        _ => key,
      };

  @override
  Widget build(BuildContext context) {
    final p = PreferencesService.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('لوحة الشرف')),
      body: AnimatedBuilder(
        animation: p,
        builder: (context, _) {
          if (p.highScores.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'لسه مفيش نتائج محفوظة. ابدأ لعبة وكسبها عشان اسمك يظهر هنا!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: p.highScores.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (context, i) {
              final s = p.highScores[i];
              final isTop = i == 0;
              return Card(
                color: isTop ? Colors.amber.shade100 : null,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: switch (i) {
                      0 => Colors.amber,
                      1 => Colors.grey.shade400,
                      2 => Colors.brown.shade300,
                      _ => Theme.of(context).colorScheme.primaryContainer,
                    },
                    child: Text('${i + 1}',
                        style: const TextStyle(
                            color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(
                    s.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isTop ? Colors.black : null,
                    ),
                  ),
                  subtitle: Text(
                    'مستوى: ${_difficultyLabel(s.difficulty)} • ${intl.DateFormat('yyyy/MM/dd').format(s.date)}',
                    style: TextStyle(
                      color: isTop ? Colors.black87 : null,
                    ),
                  ),
                  trailing: Text(
                    '${s.score}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isTop ? Colors.black : null,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

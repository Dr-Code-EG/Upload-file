import 'package:flutter/material.dart';

import '../services/preferences_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: PreferencesService.instance.playerName);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = PreferencesService.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: AnimatedBuilder(
        animation: p,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('اسم اللاعب',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'اكتب اسمك',
                      ),
                      onSubmitted: (v) => p.setPlayerName(v),
                      onChanged: (v) => p.setPlayerName(v),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('المؤثرات الصوتية'),
                    secondary: const Icon(Icons.volume_up),
                    value: p.soundEnabled,
                    onChanged: p.setSoundEnabled,
                  ),
                  SwitchListTile(
                    title: const Text('الاهتزاز'),
                    secondary: const Icon(Icons.vibration),
                    value: p.hapticsEnabled,
                    onChanged: p.setHapticsEnabled,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('المظهر',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        _themeChip(context, p, 'فاتح', ThemeMode.light),
                        _themeChip(context, p, 'داكن', ThemeMode.dark),
                        _themeChip(context, p, 'النظام', ThemeMode.system),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('مسح لوحة الشرف'),
                onTap: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('تأكيد'),
                      content: const Text('هل تريد مسح كل النتائج المحفوظة؟'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('إلغاء')),
                        FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('مسح')),
                      ],
                    ),
                  );
                  if (ok == true) await p.clearHighScores();
                },
              ),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'إصدار 1.0.0',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _themeChip(BuildContext context, PreferencesService p, String label, ThemeMode mode) {
    return ChoiceChip(
      label: Text(label),
      selected: p.themeMode == mode,
      onSelected: (_) => p.setThemeMode(mode),
    );
  }
}

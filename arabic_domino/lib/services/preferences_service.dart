import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HighScore {
  final String name;
  final int score;
  final String difficulty;
  final DateTime date;

  HighScore({
    required this.name,
    required this.score,
    required this.difficulty,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'score': score,
        'difficulty': difficulty,
        'date': date.toIso8601String(),
      };

  factory HighScore.fromJson(Map<String, dynamic> j) => HighScore(
        name: j['name'] as String,
        score: j['score'] as int,
        difficulty: j['difficulty'] as String,
        date: DateTime.parse(j['date'] as String),
      );
}

/// Singleton for preferences (theme, sound, haptics, player name, hall of fame).
class PreferencesService extends ChangeNotifier {
  PreferencesService._();
  static final PreferencesService instance = PreferencesService._();

  static const _kTheme = 'theme_mode';
  static const _kSound = 'sound_enabled';
  static const _kHaptics = 'haptics_enabled';
  static const _kPlayerName = 'player_name';
  static const _kHighScores = 'high_scores';
  static const _kDifficulty = 'last_difficulty';

  late SharedPreferences _prefs;
  bool _initialized = false;

  ThemeMode _themeMode = ThemeMode.dark;
  bool _soundEnabled = true;
  bool _hapticsEnabled = true;
  String _playerName = 'لاعب';
  String _difficulty = 'medium';
  List<HighScore> _highScores = [];

  ThemeMode get themeMode => _themeMode;
  bool get soundEnabled => _soundEnabled;
  bool get hapticsEnabled => _hapticsEnabled;
  String get playerName => _playerName;
  String get difficulty => _difficulty;
  List<HighScore> get highScores => List.unmodifiable(_highScores);
  bool get initialized => _initialized;

  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    final t = _prefs.getString(_kTheme) ?? 'dark';
    _themeMode = switch (t) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };
    _soundEnabled = _prefs.getBool(_kSound) ?? true;
    _hapticsEnabled = _prefs.getBool(_kHaptics) ?? true;
    _playerName = _prefs.getString(_kPlayerName) ?? 'لاعب';
    _difficulty = _prefs.getString(_kDifficulty) ?? 'medium';
    final raw = _prefs.getStringList(_kHighScores) ?? [];
    _highScores = raw
        .map((e) => HighScore.fromJson(jsonDecode(e) as Map<String, dynamic>))
        .toList();
    _initialized = true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode m) async {
    _themeMode = m;
    await _prefs.setString(_kTheme, switch (m) {
      ThemeMode.light => 'light',
      ThemeMode.system => 'system',
      _ => 'dark',
    });
    notifyListeners();
  }

  Future<void> setSoundEnabled(bool v) async {
    _soundEnabled = v;
    await _prefs.setBool(_kSound, v);
    notifyListeners();
  }

  Future<void> setHapticsEnabled(bool v) async {
    _hapticsEnabled = v;
    await _prefs.setBool(_kHaptics, v);
    notifyListeners();
  }

  Future<void> setPlayerName(String name) async {
    _playerName = name.trim().isEmpty ? 'لاعب' : name.trim();
    await _prefs.setString(_kPlayerName, _playerName);
    notifyListeners();
  }

  Future<void> setDifficulty(String d) async {
    _difficulty = d;
    await _prefs.setString(_kDifficulty, d);
    notifyListeners();
  }

  Future<void> addHighScore(HighScore hs) async {
    _highScores.add(hs);
    _highScores.sort((a, b) => b.score.compareTo(a.score));
    if (_highScores.length > 20) {
      _highScores = _highScores.sublist(0, 20);
    }
    await _prefs.setStringList(
      _kHighScores,
      _highScores.map((e) => jsonEncode(e.toJson())).toList(),
    );
    notifyListeners();
  }

  Future<void> clearHighScores() async {
    _highScores = [];
    await _prefs.remove(_kHighScores);
    notifyListeners();
  }
}

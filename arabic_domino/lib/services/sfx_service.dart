import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import 'preferences_service.dart';

enum Sfx { tilePlace, draw, shuffle, win, lose }

/// Sound effects + haptic feedback. Falls back gracefully if audio fails.
class SfxService {
  SfxService._();
  static final SfxService instance = SfxService._();

  final AudioPlayer _player = AudioPlayer(playerId: 'sfx');
  bool _muted = false;

  Future<void> init() async {
    try {
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.setPlayerMode(PlayerMode.lowLatency);
    } catch (_) {
      _muted = true;
    }
  }

  String _asset(Sfx s) => switch (s) {
        Sfx.tilePlace => 'audio/tile_place.wav',
        Sfx.draw => 'audio/draw.wav',
        Sfx.shuffle => 'audio/shuffle.wav',
        Sfx.win => 'audio/win.wav',
        Sfx.lose => 'audio/lose.wav',
      };

  Future<void> play(Sfx s) async {
    if (_muted) return;
    if (!PreferencesService.instance.soundEnabled) return;
    try {
      await _player.stop();
      await _player.play(AssetSource(_asset(s)));
    } catch (_) {
      // ignore — keep silent on devices without audio
    }
  }

  Future<void> hapticLight() async {
    if (!PreferencesService.instance.hapticsEnabled) return;
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }

  Future<void> hapticMedium() async {
    if (!PreferencesService.instance.hapticsEnabled) return;
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  Future<void> hapticHeavy() async {
    if (!PreferencesService.instance.hapticsEnabled) return;
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }
}

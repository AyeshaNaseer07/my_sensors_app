import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';

class AlarmService {
  static final AlarmService _instance = AlarmService._internal();

  factory AlarmService() => _instance;

  AlarmService._internal();

  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;

  Future<void> init() async {
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(1.0);
      debugPrint('✅ Alarm service initialized');
    } catch (e) {
      debugPrint('❌ Error initializing alarm service: $e');
    }
  }

  Future<void> playAlarm() async {
    if (_isPlaying) return;

    try {
      _isPlaying = true;

      await _player.stop(); // safety
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(AssetSource('alarms/fire_alarm.mp3'), volume: 1.0);

      debugPrint('🚨 Alarm looping started');
    } catch (e) {
      _isPlaying = false;
      debugPrint('❌ Error playing alarm: $e');
    }
  }

  Future<void> stopAlarm() async {
    if (!_isPlaying) return;

    try {
      await _player.stop();
      _isPlaying = false;
      debugPrint('✅ Alarm stopped');
    } catch (e) {
      debugPrint('❌ Error stopping alarm: $e');
    }
  }

  bool get isPlaying => _isPlaying;

  void dispose() {
    if (_isPlaying) {
      _player.stop();
    }
    _player.dispose();
    debugPrint('✅ Alarm service disposed');
  }
}

import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart';

class SpeechService {
  final FlutterTts _tts = FlutterTts();

  Future<void> speak(
    String text, {
    bool enabled = true,
    double volume = 1.0,
  }) async {
    if (!enabled || text.trim().isEmpty) return;
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.46);
      await _tts.setVolume(volume);
      await _tts.speak(text);
    } catch (error) {
      debugPrint('Text-to-speech failed: $error');
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (error) {
      debugPrint('Could not stop text-to-speech: $error');
    }
  }
}

import 'dart:async';
import 'dart:collection';

import 'package:flutter_tts/flutter_tts.dart';

import 'app_settings_service.dart';

class SpeechService {
  static final SpeechService _instance = SpeechService._internal();

  factory SpeechService() => _instance;
  SpeechService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  final Queue<String> _queue = Queue<String>();
  final AppSettingsService _settingsService = AppSettingsService();

  bool _initialized = false;
  bool _isSpeaking = false;

  Future<void> ensureInitialized() async {
    if (_initialized) {
      return;
    }
    _initialized = true;

    await _settingsService.ensureInitialized();
    await _flutterTts.setLanguage('fil-PH');
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.awaitSpeakCompletion(false);

    _flutterTts.setStartHandler(() {
      _isSpeaking = true;
    });
    _flutterTts.setCompletionHandler(() {
      _isSpeaking = false;
      unawaited(_drainQueue());
    });
    _flutterTts.setCancelHandler(() {
      _isSpeaking = false;
      unawaited(_drainQueue());
    });
    _flutterTts.setErrorHandler((_) {
      _isSpeaking = false;
      unawaited(_drainQueue());
    });
  }

  Future<void> speak(String text, {bool prioritize = false}) async {
    await ensureInitialized();
    if (!_settingsService.settings.ttsEnabled) {
      return;
    }

    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }

    if (prioritize) {
      _queue.addFirst(trimmed);
    } else {
      if (_queue.isNotEmpty && _queue.last == trimmed) {
        return;
      }
      _queue.add(trimmed);
    }

    await _drainQueue();
  }

  Future<void> stop() async {
    _queue.clear();
    _isSpeaking = false;
    await _flutterTts.stop();
  }

  Future<void> _drainQueue() async {
    if (_isSpeaking || _queue.isEmpty) {
      return;
    }

    final next = _queue.removeFirst();
    _isSpeaking = true;
    final result = await _flutterTts.speak(next);
    if (result != 1) {
      _isSpeaking = false;
      if (_queue.isNotEmpty) {
        await _drainQueue();
      }
    }
  }
}

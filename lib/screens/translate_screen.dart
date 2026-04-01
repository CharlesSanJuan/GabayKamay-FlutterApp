import 'dart:async';

import 'package:flutter/material.dart';

import '../models/gesture_models.dart';
import '../services/app_settings_service.dart';
import '../services/ble_glove_service.dart';
import '../services/gesture_recognition_service.dart';
import '../services/speech_service.dart';

class TranslateScreen extends StatefulWidget {
  const TranslateScreen({super.key});

  @override
  State<TranslateScreen> createState() => _TranslateScreenState();
}

class _TranslateScreenState extends State<TranslateScreen> {
  final BleGloveService _bleService = BleGloveService();
  final GestureRecognitionService _gestureService = GestureRecognitionService();
  final SpeechService _speechService = SpeechService();
  final AppSettingsService _settingsService = AppSettingsService();

  StreamSubscription<GestureRecognitionState>? _stateSub;
  StreamSubscription<AppSettings>? _settingsSub;
  String? _lastSpokenGestureId;
  int _dotCount = 0;
  late Timer _dotTimer;

  @override
  void initState() {
    super.initState();
    _initialize();
    _dotTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      if (_gestureService.state.latestPrediction == null) {
        setState(() {
          _dotCount = (_dotCount + 1) % 4;
        });
      }
    });
  }

  Future<void> _initialize() async {
    await _gestureService.ensureInitialized();
    await _settingsService.ensureInitialized();
    await _speechService.ensureInitialized();

    _stateSub = _gestureService.states.listen((state) async {
      if (!mounted) {
        return;
      }

      final prediction = state.latestPrediction;
      final settings = _settingsService.settings;
      if (prediction != null &&
          settings.ttsEnabled &&
          prediction.gestureId != _lastSpokenGestureId) {
        _lastSpokenGestureId = prediction.gestureId;
        await _speakText(prediction.spokenText);
      }

      if (prediction == null) {
        _lastSpokenGestureId = null;
      }

      setState(() {});
    });

    _settingsSub = _settingsService.changes.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _speakText(String text) async {
    await _speechService.speak(text);
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _settingsSub?.cancel();
    _dotTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recognitionState = _gestureService.state;
    final settings = _settingsService.settings;
    final prediction = recognitionState.latestPrediction;
    final areBothConnected = _bleService.snapshot.areBothConnected;

    final displayedText = prediction == null
        ? 'Waiting for gesture${"." * _dotCount}'
        : prediction.spokenText;

    return Container(
      color: Colors.grey[200],
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 40,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: areBothConnected
                            ? Colors.green.shade50
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        areBothConnected
                            ? recognitionState.model == null
                                  ? 'Gloves connected. Train at least one gesture to start translating.'
                                  : recognitionState.isPresentationActive
                                  ? 'Gloves connected. Active signing position detected.'
                                  : 'Gloves connected. Hands currently look inactive.'
                            : 'Connect both gloves to start live translation.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: areBothConnected
                              ? Colors.green.shade900
                              : Colors.red.shade900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Translated Text:',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 120),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              displayedText,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton(
                          icon: const Icon(Icons.volume_up),
                          iconSize: 30,
                          onPressed: prediction == null || !settings.ttsEnabled
                              ? null
                              : () async {
                                  await _speakText(prediction.spokenText);
                                },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Status: ${recognitionState.statusMessage}'),
                            const SizedBox(height: 8),
                            Text(
                              'Hand state: ${recognitionState.isPresentationActive ? "Presented / active" : "Down or inactive"}',
                            ),
                            const SizedBox(height: 8),
                            Text(
                              prediction == null
                                  ? 'No confident prediction yet.'
                                  : 'Recognized label: ${prediction.label} (${(prediction.confidence * 100).toStringAsFixed(0)}%)',
                            ),
                            const SizedBox(height: 8),
                            Text(
                              recognitionState.model == null
                                  ? 'Model: not trained'
                                  : 'Model: ${recognitionState.model!.trainerType} | Gestures: ${recognitionState.gestures.length}',
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Repeated words are suppressed until the hand changes to a different sign first.',
                            ),
                            const SizedBox(height: 8),
                            Text(
                              settings.ttsEnabled
                                  ? 'Speech queue is enabled, so active words finish speaking instead of being cut off.'
                                  : 'Speech is disabled in Settings.',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        await _gestureService.clearPrediction();
                        setState(() {
                          _lastSpokenGestureId = null;
                        });
                      },
                      child: const Text('Clear Latest Translation'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

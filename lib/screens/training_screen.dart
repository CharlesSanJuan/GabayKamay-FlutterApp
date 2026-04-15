import 'dart:async';

import 'package:flutter/material.dart';

import '../models/gesture_models.dart';
import '../services/app_settings_service.dart';
import '../services/ble_glove_service.dart';
import '../services/gesture_recognition_service.dart';
import '../services/session_state_service.dart';

class TrainingScreen extends StatefulWidget {
  const TrainingScreen({super.key});

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  final TextEditingController _labelController = TextEditingController();
  final TextEditingController _spokenTextController = TextEditingController();
  final BleGloveService _bleService = BleGloveService();
  final GestureRecognitionService _gestureService = GestureRecognitionService();
  final AppSettingsService _settingsService = AppSettingsService();
  final SessionStateService _sessionStateService = SessionStateService();

  StreamSubscription<GestureRecognitionState>? _stateSub;
  StreamSubscription<AppSettings>? _settingsSub;
  int _targetSamples = 10;
  bool _isDynamicGesture = false;
  GestureHandUsage _handUsage = GestureHandUsage.bothHands;
  Timer? _autoCaptureTimer;

  @override
  void initState() {
    super.initState();
    _gestureService.ensureInitialized();
    _settingsService.ensureInitialized().then((_) {
      if (mounted) {
        setState(() {});
        _scheduleAutoCaptureIfNeeded(_gestureService.state);
      }
    });
    _sessionStateService.ensureInitialized().then((_) {
      if (!mounted) {
        return;
      }
      final session = _sessionStateService.snapshot;
      setState(() {
        _targetSamples = session.trainingTargetSamples;
        _isDynamicGesture = session.trainingIsDynamic;
        _handUsage = session.trainingHandUsage;
      });
      _labelController.text = session.trainingLabel;
      _spokenTextController.text = session.trainingSpokenText;
      _syncDraftFields(_gestureService.state.activeDraft);
    });
    _stateSub = _gestureService.states.listen((state) {
      if (mounted) {
        setState(() {});
      }
      _syncDraftFields(state.activeDraft);
      _scheduleAutoCaptureIfNeeded(state);
    });
    _settingsSub = _settingsService.changes.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _autoCaptureTimer?.cancel();
    _stateSub?.cancel();
    _settingsSub?.cancel();
    _labelController.dispose();
    _spokenTextController.dispose();
    super.dispose();
  }

  void _persistFormState() {
    _sessionStateService.save(
      _sessionStateService.snapshot.copyWith(
        trainingLabel: _labelController.text,
        trainingSpokenText: _spokenTextController.text,
        trainingTargetSamples: _targetSamples,
        trainingIsDynamic: _isDynamicGesture,
        trainingHandUsage: _handUsage,
      ),
    );
  }

  void _scheduleAutoCaptureIfNeeded(GestureRecognitionState state) {
    final settings = _settingsService.settings;
    final draft = state.activeDraft;
    if (!settings.trainingAutoCaptureEnabled ||
        draft == null ||
        state.isRecording ||
        draft.isComplete) {
      _autoCaptureTimer?.cancel();
      _autoCaptureTimer = null;
      return;
    }

    if (_autoCaptureTimer != null) {
      return;
    }

    _autoCaptureTimer = Timer(const Duration(milliseconds: 650), () async {
      _autoCaptureTimer = null;
      if (!mounted) {
        return;
      }

      final latestState = _gestureService.state;
      final latestDraft = latestState.activeDraft;
      final latestSettings = _settingsService.settings;
      if (!latestSettings.trainingAutoCaptureEnabled ||
          latestDraft == null ||
          latestDraft.gestureId != draft.gestureId ||
          latestDraft.isComplete ||
          latestState.isRecording) {
        return;
      }

      await _gestureService.captureTrainingSample(countdown: Duration.zero);
    });
  }

  void _syncDraftFields(TrainingDraft? draft) {
    if (draft == null) {
      return;
    }
    if (_labelController.text != draft.label) {
      _labelController.text = draft.label;
    }
    if (_spokenTextController.text != draft.spokenText) {
      _spokenTextController.text = draft.spokenText;
    }
    if (_targetSamples != draft.targetSamples ||
        _isDynamicGesture != draft.isDynamic ||
        _handUsage != draft.handUsage) {
      setState(() {
        _targetSamples = draft.targetSamples;
        _isDynamicGesture = draft.isDynamic;
        _handUsage = draft.handUsage;
      });
    }
    _persistFormState();
  }

  Future<void> _startDraft() async {
    if (!_bleService.snapshot.areBothConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connect both gloves before training.')),
      );
      return;
    }

    final label = _labelController.text.trim();
    if (label.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the gesture label first.')),
      );
      return;
    }

    await _gestureService.startTrainingDraft(
      label: label,
      spokenText: _spokenTextController.text.trim(),
      isDynamic: _isDynamicGesture,
      handUsage: _handUsage,
      targetSamples: _targetSamples,
    );
  }

  @override
  Widget build(BuildContext context) {
    final recognitionState = _gestureService.state;
    final settings = _settingsService.settings;
    final draft = recognitionState.activeDraft;
    final isSavingDraft = _gestureService.isSavingDraft;
    final lastSaveDiagnostics = _gestureService.lastSaveDiagnostics;
    final areBothConnected = _bleService.snapshot.areBothConnected;
    final draftProgress = draft == null || draft.targetSamples == 0
        ? 0.0
        : draft.capturedCount / draft.targetSamples;
    final remainingCount = draft == null
        ? 0
        : (draft.targetSamples - draft.capturedCount).clamp(
            0,
            draft.targetSamples,
          );
    final sampleOptions = <int>{5, 10, 15, 20, 30, 40, 50, _targetSamples}
      ..removeWhere((value) => value <= 0);
    final sortedSampleOptions = sampleOptions.toList()..sort();

    return SafeArea(
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: areBothConnected
                    ? Colors.green.shade50
                    : Colors.red.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: areBothConnected ? Colors.green : Colors.red,
                ),
              ),
              child: Text(
                areBothConnected
                    ? 'Both gloves are connected. Train with repeated capture windows so the random forest can learn a full motion pattern, not only one frozen frame.'
                    : 'Both gloves must stay connected before training.',
                style: TextStyle(
                  color: areBothConnected
                      ? Colors.green.shade800
                      : Colors.red.shade800,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _labelController,
              onChanged: (_) => _persistFormState(),
              decoration: InputDecoration(
                hintText: 'Gesture label, e.g. Magandang Umaga',
                labelText: 'Gesture Label',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _spokenTextController,
              onChanged: (_) => _persistFormState(),
              decoration: InputDecoration(
                hintText: 'Speech output, e.g. Magandang umaga po',
                labelText: 'Spoken Text',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile.adaptive(
              value: _isDynamicGesture,
              title: const Text('Movement Gesture'),
              subtitle: Text(
                _isDynamicGesture
                    ? 'Use this for gestures with travel, motion, or a sequence of poses.'
                    : 'Use this for held/static handshapes.',
              ),
              onChanged: draft == null
                  ? (value) {
                      setState(() {
                        _isDynamicGesture = value;
                      });
                      _persistFormState();
                    }
                  : null,
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              value: settings.trainingAutoCaptureEnabled,
              title: const Text('Auto-Capture Repetitions'),
              subtitle: Text(
                settings.trainingAutoCaptureEnabled
                    ? 'After each window, the next capture starts automatically.'
                    : 'Use the Capture button manually for each repetition.',
              ),
              onChanged: (value) async {
                await _settingsService.save(
                  settings.copyWith(trainingAutoCaptureEnabled: value),
                );
                _scheduleAutoCaptureIfNeeded(_gestureService.state);
              },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<GestureHandUsage>(
              initialValue: _handUsage,
              decoration: InputDecoration(
                labelText: 'Hand Usage',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              items: GestureHandUsage.values
                  .map(
                    (usage) => DropdownMenuItem<GestureHandUsage>(
                      value: usage,
                      child: Text(usage.displayLabel),
                    ),
                  )
                  .toList(),
              onChanged: draft == null
                  ? (value) {
                      if (value == null) return;
                      setState(() {
                        _handUsage = value;
                      });
                      _persistFormState();
                    }
                  : null,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Training windows:'),
                const SizedBox(width: 12),
                DropdownButton<int>(
                  value: _targetSamples,
                  items: sortedSampleOptions
                      .map(
                        (count) => DropdownMenuItem<int>(
                          value: count,
                          child: Text('$count'),
                        ),
                      )
                      .toList(),
                  onChanged: draft == null
                      ? (value) {
                          if (value == null) return;
                          setState(() {
                            _targetSamples = value;
                          });
                          _persistFormState();
                        }
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Countdown: ${settings.trainingCountdownSeconds}s | Translation muted during training: ${settings.muteTranslationWhileTraining ? "On" : "Off"}',
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Training Progress',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          draft == null
                              ? '0/0'
                              : '${draft.capturedCount}/${draft.targetSamples}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: draft == null ? 0 : draftProgress,
                    ),
                    const SizedBox(height: 12),
                    if (recognitionState.countdownValue > 0)
                      Text(
                        'Perform in ${recognitionState.countdownValue}...',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      )
                    else
                      Text(
                        recognitionState.isRecording
                            ? (draft?.isDynamic ?? _isDynamicGesture
                                  ? 'Move through the full gesture path now.'
                                  : 'Hold the sign steady now.')
                            : 'Remaining repetitions: $remainingCount',
                      ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: recognitionState.isRecording
                          ? recognitionState.captureProgress.clamp(0.0, 1.0)
                          : 0,
                      minHeight: 8,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      recognitionState.isRecording
                          ? '${(recognitionState.captureProgress * 100).toStringAsFixed(0)}% of the current window captured'
                          : draft == null
                          ? 'Create a draft to begin.'
                          : settings.trainingAutoCaptureEnabled
                          ? 'Auto-capture is on. The next repetition will begin automatically.'
                          : 'Tap capture when you are ready for the next repetition.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: draft == null && !isSavingDraft ? _startDraft : null,
              child: const Text('Create Training Draft'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: draft != null &&
                      !recognitionState.isRecording &&
                      !isSavingDraft
                  ? () async {
                      await _gestureService.captureTrainingSample(
                        countdown: Duration.zero,
                      );
                    }
                  : null,
              child: Text(
                recognitionState.isRecording
                    ? 'Capturing Window...'
                    : draft == null
                    ? 'Create draft first'
                    : 'Capture Next Window',
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: draft != null &&
                      draft.capturedSamples.isNotEmpty &&
                      !isSavingDraft
                  ? () async {
                      await _gestureService.saveDraftAndRetrain();
                    }
                  : null,
              child: Text(
                isSavingDraft
                    ? 'Saving Gesture Model...'
                    : 'Save Gesture and Retrain Model',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: draft != null && !isSavingDraft
                  ? () async {
                      await _gestureService.discardDraft();
                    }
                  : null,
              child: const Text('Discard Draft'),
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Training Status',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(recognitionState.statusMessage),
                    const SizedBox(height: 8),
                    Text(
                      draft == null
                          ? 'No active draft'
                          : 'Captured ${draft.capturedCount}/${draft.targetSamples} windows for "${draft.label}" (${draft.isDynamic ? "movement" : "static"}, ${draft.handUsage.displayLabel.toLowerCase()}).',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      recognitionState.model == null
                          ? 'No trained model saved yet.'
                          : 'Current model: ${recognitionState.model!.trainerType} with ${recognitionState.gestures.length} gestures.',
                    ),
                    if (lastSaveDiagnostics != null) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Last Save Diagnostics',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Gesture: ${lastSaveDiagnostics.gestureLabel} | Draft samples: ${lastSaveDiagnostics.draftSamples} | Total samples: ${lastSaveDiagnostics.totalSamplesAfterSave}',
                      ),
                      Text(
                        'Gestures: ${lastSaveDiagnostics.trainedGestureCount} | Feature length: ${lastSaveDiagnostics.featureLength}',
                      ),
                      Text(
                        'Load: ${lastSaveDiagnostics.loadRepositoryMs.toStringAsFixed(1)} ms | Prep: ${lastSaveDiagnostics.samplePreparationMs.toStringAsFixed(1)} ms',
                      ),
                      Text(
                        'Train: ${lastSaveDiagnostics.trainModelMs.toStringAsFixed(1)} ms | Write: ${lastSaveDiagnostics.writeRepositoryMs.toStringAsFixed(1)} ms',
                      ),
                      Text(
                        'Total: ${lastSaveDiagnostics.totalSaveMs.toStringAsFixed(1)} ms',
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How Capture Works',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('1. Tap capture and use the countdown to get ready.'),
                    Text(
                      '2. Static mode: hold the sign still until the bar fills.',
                    ),
                    Text(
                      '3. Movement mode: complete the whole path during the capture window.',
                    ),
                    Text(
                      '4. The model trains on a full time window, so movement signs are supported.',
                    ),
                    Text(
                      '5. Repeat until the progress bar reaches the target, then save.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}

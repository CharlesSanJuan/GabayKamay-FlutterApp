import 'dart:async';

import 'package:flutter/material.dart';

import '../models/gesture_models.dart';
import '../services/ble_glove_service.dart';
import '../services/gesture_recognition_service.dart';

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

  StreamSubscription<GestureRecognitionState>? _stateSub;
  int _targetSamples = 5;

  @override
  void initState() {
    super.initState();
    _gestureService.ensureInitialized();
    _stateSub = _gestureService.states.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _labelController.dispose();
    _spokenTextController.dispose();
    super.dispose();
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
      targetSamples: _targetSamples,
    );
  }

  @override
  Widget build(BuildContext context) {
    final recognitionState = _gestureService.state;
    final draft = recognitionState.activeDraft;
    final areBothConnected = _bleService.snapshot.areBothConnected;

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
                color: areBothConnected ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: areBothConnected ? Colors.green : Colors.red,
                ),
              ),
              child: Text(
                areBothConnected
                    ? 'Gloves connected. Calibrate first, then capture gesture repetitions.'
                    : 'Both gloves must stay connected before training.',
                style: TextStyle(
                  color: areBothConnected ? Colors.green.shade800 : Colors.red.shade800,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _labelController,
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
              decoration: InputDecoration(
                hintText: 'Speech output, e.g. Magandang umaga po',
                labelText: 'Spoken Text',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Repetitions per gesture:'),
                const SizedBox(width: 12),
                DropdownButton<int>(
                  value: _targetSamples,
                  items: const [3, 5, 7, 10]
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
                        }
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: draft == null ? _startDraft : null,
              child: const Text('Create Training Draft'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: draft != null && !recognitionState.isRecording
                  ? () async {
                      await _gestureService.captureTrainingSample();
                    }
                  : null,
              child: Text(
                recognitionState.isRecording
                    ? 'Capturing...'
                    : draft == null
                        ? 'Create draft first'
                        : 'Capture Next Repetition',
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: draft != null && draft.capturedSamples.isNotEmpty
                  ? () async {
                      await _gestureService.saveDraftAndRetrain();
                    }
                  : null,
              child: const Text('Save Gesture and Retrain Model'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: draft != null
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
                          : 'Captured ${draft.capturedCount}/${draft.targetSamples} repetitions for "${draft.label}".',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      recognitionState.model == null
                          ? 'No trained model saved yet.'
                          : 'Current model: ${recognitionState.model!.trainerType} with ${recognitionState.gestures.length} gestures.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Saved Gestures',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (recognitionState.gestures.isEmpty)
              const Text('No trained gestures saved yet.')
            else
              ...recognitionState.gestures.map(
                (gesture) => Card(
                  child: ListTile(
                    title: Text(gesture.label),
                    subtitle: Text(
                      '${gesture.sampleCount} repetitions saved | Speaks: ${gesture.spokenText}',
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

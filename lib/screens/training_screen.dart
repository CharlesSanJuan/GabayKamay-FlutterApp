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
  int _targetSamples = 10;

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
                    ? 'Windowed capture is active. Create a draft, get ready, then perform the sign naturally during the capture window.'
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
                const Text('Training windows:'),
                const SizedBox(width: 12),
                DropdownButton<int>(
                  value: _targetSamples,
                  items: const [5, 10, 15, 20, 30, 40, 50]
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
                    ? 'Capturing Window...'
                    : draft == null
                        ? 'Create draft first'
                        : 'Capture Next Window',
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
                          : 'Captured ${draft.capturedCount}/${draft.targetSamples} windows for "${draft.label}".',
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
                    Text('1. Tap capture and use the 3-second countdown to get ready.'),
                    Text('2. Perform the sign naturally during the capture window.'),
                    Text('3. The app saves a full motion window, not one frozen snapshot.'),
                    Text('4. Repeat until you have enough windows, then save and retrain.'),
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

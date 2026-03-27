import 'dart:async';

import 'package:flutter/material.dart';

import '../models/gesture_models.dart';
import '../services/gesture_recognition_service.dart';

class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key});

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  final GestureRecognitionService _gestureService = GestureRecognitionService();
  StreamSubscription<GestureRecognitionState>? _stateSub;

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
    super.dispose();
  }

  Future<void> _confirmDelete(GestureDefinition gesture) async {
    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Gesture'),
            content: Text('Delete "${gesture.label}" and remove its samples?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldDelete) {
      return;
    }

    await _gestureService.deleteGesture(gesture.id);
  }

  @override
  Widget build(BuildContext context) {
    final state = _gestureService.state;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Trained Gesture Dictionary',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(state.statusMessage),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (state.gestures.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No trained gestures saved yet. Train gestures from the Training tab.'),
            ),
          )
        else
          ...state.gestures.map(
            (gesture) => Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(
                  gesture.label,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Windows: ${gesture.sampleCount}\nSpeaks: ${gesture.spokenText}',
                ),
                isThreeLine: true,
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Delete Gesture',
                  onPressed: () async {
                    await _confirmDelete(gesture);
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}

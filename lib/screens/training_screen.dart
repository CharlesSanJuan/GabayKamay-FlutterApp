import 'package:flutter/material.dart';

class TrainingScreen extends StatefulWidget {
  const TrainingScreen({super.key});

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  final TextEditingController wordController = TextEditingController();
  int samples = 0;

  void startRecording() {
    setState(() {
      samples = 120; // fake number for now
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Training Mode")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: wordController,
              decoration: const InputDecoration(
                labelText: "Enter word",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: startRecording,
              child: const Text("Start Recording Gesture"),
            ),
            const SizedBox(height: 20),
            Text("Samples recorded: $samples"),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {},
              child: const Text("Save Gesture"),
            ),
          ],
        ),
      ),
    );
  }
}

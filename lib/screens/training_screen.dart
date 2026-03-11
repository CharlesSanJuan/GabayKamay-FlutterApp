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
      samples = 120;
    });
  }

  void saveGesture() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Gesture saved successfully!")),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: const [
              Icon(Icons.back_hand, size: 50),
              Icon(Icons.pan_tool_alt, size: 50),
              Icon(Icons.front_hand, size: 50),
            ],
          ),

          const SizedBox(height: 40),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: TextField(
              controller: wordController,
              decoration: InputDecoration(
                hintText: "Enter word",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),

          const SizedBox(height: 25),

          ElevatedButton(
            onPressed: startRecording,
            child: const Text("Start recording gestures"),
          ),

          const SizedBox(height: 20),

          Text("Samples Recorded : $samples"),

          const SizedBox(height: 25),

          ElevatedButton(
            onPressed: saveGesture,
            child: const Text("Save gesture"),
          ),
        ],
      ),
    );
  }
}
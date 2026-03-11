import 'dart:async';
import 'package:flutter/material.dart';

class TranslateScreen extends StatefulWidget {
  const TranslateScreen({super.key});

  @override
  State<TranslateScreen> createState() => _TranslateScreenState();
}

class _TranslateScreenState extends State<TranslateScreen> {

  String translatedText = "Waiting for gesture";

  int dotCount = 0;
  late Timer dotTimer;

  @override
  void initState() {
    super.initState();

    dotTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (timer) {
        if (translatedText == "Waiting for gesture") {
          setState(() {
            dotCount = (dotCount + 1) % 4;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    dotTimer.cancel();
    super.dispose();
  }

  void simulateGesture() {
    setState(() {
      translatedText = "HELLO";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            const Text(
              "Translated Text:",
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 20),

            Text(
              translatedText == "Waiting for gesture"
                  ? "$translatedText${"." * dotCount}"
                  : translatedText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 50),

            ElevatedButton(
              onPressed: simulateGesture,
              child: const Text("Simulate Gesture"),
            ),
          ],
        ),
      ),
    );
  }
}
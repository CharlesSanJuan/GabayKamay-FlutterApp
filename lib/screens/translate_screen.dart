import 'package:flutter/material.dart';

class TranslateScreen extends StatefulWidget {
  const TranslateScreen({super.key});

  @override
  State<TranslateScreen> createState() => _TranslateScreenState();
}

class _TranslateScreenState extends State<TranslateScreen> {
  String translatedText = "Waiting for gesture...";

  void fakeTranslate() {
    setState(() {
      translatedText = "HELLO";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Translate Mode")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Translated Text:", style: TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            Text(
              translatedText,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: fakeTranslate,
              child: const Text("Simulate Gesture"),
            ),
          ],
        ),
      ),
    );
  }
}

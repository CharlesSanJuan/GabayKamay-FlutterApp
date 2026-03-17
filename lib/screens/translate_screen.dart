import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TranslateScreen extends StatefulWidget {
  const TranslateScreen({super.key});

  @override
  State<TranslateScreen> createState() => _TranslateScreenState();
}

class _TranslateScreenState extends State<TranslateScreen> {

  String translatedText = "Waiting for gesture";

  int dotCount = 0;
  late Timer dotTimer;

  final FlutterTts flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();

    // animation for waiting text
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

    initTTS();
  }

  Future initTTS() async {
    await flutterTts.setLanguage("fil-PH");
    await flutterTts.setPitch(1.1);
    await flutterTts.setSpeechRate(0.50);
    await flutterTts.setVolume(1.0);
  }

  @override
  void dispose() {
    dotTimer.cancel();
    flutterTts.stop();
    super.dispose();
  }

  // ⭐ Improve Filipino pronunciation
  String formatForSpeech(String text) {

    if (text.isEmpty) return text;

    text = text.toLowerCase();

    // capitalize first letter
    text = text[0].toUpperCase() + text.substring(1);

    // add pause for natural speaking
    if (!text.endsWith(".")) {
      text = "$text.";
    }

    return text;
  }

  // 🔊 speak function
  Future speakText(String text) async {

    String cleanText = formatForSpeech(text);

    await flutterTts.speak(cleanText);
  }

  // 🤟 simulated gesture
  void simulateGesture() {

    String detectedWord = "hello ako nga pala si natoy, nandito"; // change to test

    setState(() {
      translatedText = detectedWord;
    });

    speakText(detectedWord);
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

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                Text(
                  translatedText == "Waiting for gesture"
                      ? "$translatedText${"." * dotCount}"
                      : translatedText,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(width: 10),

                
                

              ],
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
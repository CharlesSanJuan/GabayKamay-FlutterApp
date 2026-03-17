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

    initTTS();

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

  Future<void> initTTS() async {
    await flutterTts.setLanguage("fil-PH");
    await flutterTts.setPitch(1.1);
    await flutterTts.setSpeechRate(0.45);
    await flutterTts.setVolume(1.0);
  }

  Future<void> speakText(String text) async {
    await flutterTts.stop();
    await flutterTts.speak(text);
  }

  @override
  void dispose() {
    dotTimer.cancel();
    flutterTts.stop();
    super.dispose();
  }

  void simulateGesture() {
    setState(() {
      translatedText =
          "Ang hindi marunong lumingon sa pinanggalingan ay hindi makararating sa paroroonan.";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[200],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [

          const Text(
            "Translated Text:",
            style: TextStyle(fontSize: 16),
          ),

          const SizedBox(height: 20),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              height: 120,
              child: Row(
                children: [

                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        translatedText == "Waiting for gesture"
                            ? "$translatedText${"." * dotCount}"
                            : translatedText,
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
                    onPressed: () {
                      if (translatedText != "Waiting for gesture") {
                        speakText(translatedText);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 40),

          ElevatedButton(
            onPressed: simulateGesture,
            child: const Text("Simulate Gesture"),
          ),
        ],
      ),
    );
  }
}
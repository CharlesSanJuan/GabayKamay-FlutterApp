import 'dart:async';
import 'package:flutter/material.dart';
// import 'package:flutter_tts/flutter_tts.dart';  // 🔊 Enable when adding speech output
// import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart'; // 🔌 Example if using Bluetooth
import 'home_screen.dart'; // ✅ Added for Home navigation

class TranslateScreen extends StatefulWidget {
  const TranslateScreen({super.key});

  @override
  State<TranslateScreen> createState() => _TranslateScreenState();
}

int currentIndex = 1; // 0 = Training, 1 = Translation, 2 = Dictionary

class _TranslateScreenState extends State<TranslateScreen>
    with SingleTickerProviderStateMixin {
  static const Color primaryOrange = Color(0xFFFF8C1A);

  /// ===============================
  /// STATE VARIABLES
  /// ===============================

  // This will display the translated word coming from the smart gloves
  String translatedText = "Waiting for gesture";

  // Animated dots for "Waiting..."
  int dotCount = 0;
  late Timer dotTimer;

  // 🔊 Text-to-Speech placeholder
  // final FlutterTts tts = FlutterTts();

  /// ===============================
  /// INIT
  /// ===============================
  @override
  void initState() {
    super.initState();

    // Animated dots while waiting for glove input
    dotTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (translatedText == "Waiting for gesture") {
        setState(() {
          dotCount = (dotCount + 1) % 4;
        });
      }
    });

    // 🔌 Future: Initialize Bluetooth / Serial connection here
    // initializeGloveConnection();
  }

  @override
  void dispose() {
    dotTimer.cancel();
    super.dispose();
  }

  /// ===============================
  /// PLACEHOLDER: GLOVE DATA RECEIVER
  /// ===============================
  /// This function will be triggered when:
  /// - The user performs a sign gesture
  /// - The glove sensors capture finger bend + motion
  /// - Microcontroller processes the data
  /// - The word prediction model returns a result
  ///
  /// The final translated word will be passed here.
  void onGestureDetected(String detectedWord) {
    setState(() {
      translatedText = detectedWord;
    });

    // 🔊 Convert text to speech (future implementation)
    // tts.speak(detectedWord);
  }

  /// ===============================
  /// TEMPORARY SIMULATION FUNCTION
  /// ===============================
  /// This is used while gloves are not yet built.
  /// It simulates receiving gesture data.
  void simulateGesture() {
    onGestureDetected("HELLO");
  }

  /// ===============================
  /// UI
  /// ===============================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      body: Column(
        children: [
          // 🔶 Custom Header
          Container(
            padding: const EdgeInsets.only(
              top: 50,
              left: 20,
              right: 20,
              bottom: 25,
            ),
            decoration: const BoxDecoration(
              color: primaryOrange,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
            ),
            child: Row(
              children: [
                /// ✅ CLICKABLE HAND ICON (Now goes to Home Screen)
                GestureDetector(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HomeScreen(),
                      ),
                    );
                  },
                  child: const Icon(
                    Icons.waving_hand_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "GabayKamay",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      "Filipino Sign Language",
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 60),

          // 🔤 Label
          const Text(
            "Translated Text:",
            style: TextStyle(fontSize: 16, letterSpacing: 1),
          ),

          const SizedBox(height: 20),

          /// ===============================
          /// TRANSLATED OUTPUT DISPLAY
          /// ===============================
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: Text(
              translatedText == "Waiting for gesture"
                  ? "$translatedText${"." * dotCount}"
                  : translatedText,
              key: ValueKey(translatedText + dotCount.toString()),
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),
          ),

          const SizedBox(height: 50),

          /// ===============================
          /// SIMULATION BUTTON (FOR DEMO)
          /// Remove when glove hardware is ready
          /// ===============================
          GestureDetector(
            onTap: simulateGesture,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.blue.shade200,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Text(
                "Simulate Gesture (Demo Mode)",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),

          const Spacer(),

          /// ===============================
          /// CLICKABLE BOTTOM NAVIGATION
          /// ===============================
          Container(
            height: 75,
            decoration: const BoxDecoration(
              color: primaryOrange,
              borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(Icons.psychology, "Training", 0),
                _navItem(Icons.translate, "Translation", 1),
                _navItem(Icons.menu_book, "Dictionary", 2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    final bool active = currentIndex == index;

    return GestureDetector(
      onTap: () {
        if (index == currentIndex) return; // prevent reload

        switch (index) {
          case 0:
            Navigator.pushReplacementNamed(context, '/training');
            break;
          case 1:
            Navigator.pushReplacementNamed(context, '/translate');
            break;
          case 2:
            Navigator.pushReplacementNamed(context, '/dictionary');
            break;
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              duration: const Duration(milliseconds: 200),
              scale: active ? 1.2 : 1.0,
              child: Icon(icon, color: active ? primaryOrange : Colors.black),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
                color: active ? primaryOrange : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
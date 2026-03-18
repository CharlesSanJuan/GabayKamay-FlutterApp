import 'dart:async';
import 'package:flutter/material.dart';

class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({super.key});

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen>
    with TickerProviderStateMixin {

  int step = 0;
  double progress = 0.0;
  bool isCalibrating = false;
  bool isComplete = false;

  late AnimationController pulseController;
  late AnimationController completeController;

  late Animation<double> pulseAnimation;
  late Animation<double> completeAnimation;

  final List<String> stepsText = [
    "Wear both gloves properly",
    "Keep both hands relaxed",
    "Close both hands (fist)",
    "Open both hands fully",
    "Move fingers slightly",
    "Calibration complete!"
  ];

  @override
  void initState() {
    super.initState();

    // 🔵 Pulsing animation
    pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: pulseController, curve: Curves.easeInOut),
    );

    // 🟢 Completion animation
    completeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    completeAnimation = Tween<double>(begin: 1.0, end: 1.4).animate(
      CurvedAnimation(parent: completeController, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    pulseController.dispose();
    completeController.dispose();
    super.dispose();
  }

  void startCalibration() {
    setState(() {
      isCalibrating = true;
      isComplete = false;
      step = 0;
      progress = 0.0;
    });

    Timer.periodic(const Duration(seconds: 2), (timer) {
      if (step < stepsText.length - 1) {
        setState(() {
          step++;
          progress += 1 / (stepsText.length - 1);
        });
      } else {
        timer.cancel();

        setState(() {
          progress = 1.0;
          isCalibrating = false;
          isComplete = true;
        });

        completeController.forward();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Calibration Completed!")),
        );
      }
    });
  }

  Widget buildHands() {
    Widget hands = Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Transform(
          alignment: Alignment.center,
          transform: Matrix4.rotationY(3.14),
          child: const Icon(Icons.back_hand, size: 70),
        ),
        const Icon(Icons.back_hand, size: 70),
      ],
    );

    // 🎉 COMPLETED EFFECT
    if (isComplete) {
      return ScaleTransition(
        scale: completeAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          padding: const EdgeInsets.all(20),
          child: hands,
        ),
      );
    }

    // 🔵 PULSING EFFECT
    if (isCalibrating) {
      return ScaleTransition(
        scale: pulseAnimation,
        child: hands,
      );
    }

    return hands;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[100],
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            const Text(
              "Glove Calibration",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 30),

            // 🧤 HAND DISPLAY
            Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(child: buildHands()),
            ),

            const SizedBox(height: 30),

            // 📊 Progress
            LinearProgressIndicator(
              value: progress,
              minHeight: 8,
            ),

            const SizedBox(height: 20),

            // 📝 Text
            Text(
              stepsText[step],
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 40),

            ElevatedButton(
              onPressed: isCalibrating ? null : startCalibration,
              child: Text(
                isCalibrating ? "Calibrating..." : "Start Calibration",
              ),
            ),
          ],
        ),
      ),
    );
  }
}
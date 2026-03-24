import 'package:flutter/material.dart';

import '../services/glove_calibration_service.dart';

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

  final GloveCalibrationService _calibration = GloveCalibrationService();
  final List<String> _calibrationStages = [
    'Relax both hands',
    'Make a fist',
    'Open both hands wide',
    'Move fingers slightly',
  ];

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
    _calibration.reset();

    setState(() {
      isCalibrating = true;
      isComplete = false;
      step = 0;
      progress = 1.0 / _calibrationStages.length;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Calibration started. Follow instructions and press Capture.')),
    );
  }

  void _captureCalibrationSample() {
    final leftRaw = _calibration.leftRaw;
    final rightRaw = _calibration.rightRaw;

    final fingers = ['thumb', 'index', 'middle', 'ring', 'pinky'];

    // Validate we have actual readings from gloves
    if (leftRaw['flex_thumb_raw'] == 0 && rightRaw['flex_thumb_raw'] == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No raw data available yet. Connect gloves and wait for data.')),
      );
      return;
    }

    // Step 0: calibrate IMU zero/bias when hands are relaxed
    if (step == 0) {
      _calibration.left.updateImuBias(
        leftRaw['ax_raw'] ?? 0.0,
        leftRaw['ay_raw'] ?? 0.0,
        leftRaw['az_raw'] ?? 0.0,
        leftRaw['gx_raw'] ?? 0.0,
        leftRaw['gy_raw'] ?? 0.0,
        leftRaw['gz_raw'] ?? 0.0,
      );
      _calibration.right.updateImuBias(
        rightRaw['ax_raw'] ?? 0.0,
        rightRaw['ay_raw'] ?? 0.0,
        rightRaw['az_raw'] ?? 0.0,
        rightRaw['gx_raw'] ?? 0.0,
        rightRaw['gy_raw'] ?? 0.0,
        rightRaw['gz_raw'] ?? 0.0,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('IMU bias captured for both gloves')), 
      );
    }

    for (var i = 0; i < fingers.length; i++) {
      final key = 'flex_${fingers[i]}_raw';
      _calibration.left.updateStepMinMax(i, leftRaw[key] ?? 0.0);
      _calibration.right.updateStepMinMax(i, rightRaw[key] ?? 0.0);
    }

    setState(() {
      if (step < _calibrationStages.length - 1) {
        step += 1;
        progress = (step + 1) / _calibrationStages.length;
      } else {
        isCalibrating = false;
        isComplete = true;
        progress = 1.0;
      }
    });

    if (isComplete) {
      completeController.forward();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Calibration Complete. Using per-user ranges for 0-100 flex.')),
      );
    }
  }

  double _getCalibratedFlex(String gloveName, String finger) {
    final idx = ['thumb', 'index', 'middle', 'ring', 'pinky'].indexOf(finger);
    if (idx == -1) return 0.0;

    final calibration = _calibration.getCalibration(gloveName);
    final rawValue = (gloveName == 'GLOVE_LEFT' ? _calibration.leftRaw : _calibration.rightRaw)['flex_${finger}_raw'] ?? 0.0;
    if (!calibration.isComplete) {
      return rawValue;
    }
    return calibration.mapToPercent(idx, rawValue);
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
            color: Colors.green.withValues(alpha: 0.2),
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
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: StreamBuilder<void>(
            stream: _calibration.updates,
            builder: (context, snapshot) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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

            // Current calibration step
            Text(
              isComplete ? 'Calibration complete' : _calibrationStages[step],
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 12),

            // Live sampled values
            if (!isComplete) ...[
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text('Finger'),
                          Text('LEFT raw'),
                          Text('RIGHT raw'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      for (final finger in ['thumb', 'index', 'middle', 'ring', 'pinky'])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(finger.toUpperCase()),
                              Text(_calibration.leftRaw['flex_${finger}_raw']?.toStringAsFixed(0) ?? '0'),
                              Text(_calibration.rightRaw['flex_${finger}_raw']?.toStringAsFixed(0) ?? '0'),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),

            if (!isCalibrating && !isComplete) ...[
              ElevatedButton(
                onPressed: startCalibration,
                child: const Text('Start Calibration'),
              ),
            ] else if (isCalibrating) ...[
              ElevatedButton(
                onPressed: _captureCalibrationSample,
                child: Text('Capture "${_calibrationStages[step]}"'),
              ),
            ] else if (isComplete) ...[
              ElevatedButton(
                onPressed: () {
                  _calibration.reset();
                  setState(() {
                    isCalibrating = false;
                    isComplete = false;
                    step = 0;
                    progress = 0.0;
                  });
                },
                child: const Text('Reset Calibration'),
              ),

              const SizedBox(height: 16),
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Calibrated values (0-100):', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      for (final finger in ['thumb', 'index', 'middle', 'ring', 'pinky'])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text('${finger.toUpperCase()}: LEFT=${_getCalibratedFlex('GLOVE_LEFT', finger).toStringAsFixed(1)}%, RIGHT=${_getCalibratedFlex('GLOVE_RIGHT', finger).toStringAsFixed(1)}%'),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
              );
            },
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../services/ble_glove_service.dart';
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
  final BleGloveService _bleService = BleGloveService();
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

  @override
  void initState() {
    super.initState();

    pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: pulseController, curve: Curves.easeInOut),
    );

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
    if (!_bleService.snapshot.areBothConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connect both gloves before starting calibration.'),
        ),
      );
      return;
    }

    _calibration.reset();
    setState(() {
      isCalibrating = true;
      isComplete = false;
      step = 0;
      progress = 1.0 / _calibrationStages.length;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Calibration started. Follow instructions and press Capture.'),
      ),
    );
  }

  void _captureCalibrationSample() {
    final leftRaw = _calibration.leftRaw;
    final rightRaw = _calibration.rightRaw;
    const fingers = ['thumb', 'index', 'middle', 'ring', 'pinky'];

    if (leftRaw['flex_thumb_raw'] == 0 && rightRaw['flex_thumb_raw'] == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No raw data available yet. Connect gloves and wait for data.'),
        ),
      );
      return;
    }

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
        const SnackBar(
          content: Text('Calibration complete. Using per-user ranges for 0-100 flex.'),
        ),
      );
    }
  }

  double _getCalibratedFlex(String gloveName, String finger) {
    final idx = ['thumb', 'index', 'middle', 'ring', 'pinky'].indexOf(finger);
    if (idx == -1) {
      return 0.0;
    }

    final calibration = _calibration.getCalibration(gloveName);
    final rawValue = (gloveName == leftGloveName
            ? _calibration.leftRaw
            : _calibration.rightRaw)['flex_${finger}_raw'] ??
        0.0;
    if (!calibration.isComplete) {
      return rawValue;
    }
    return calibration.mapToPercent(idx, rawValue);
  }

  Widget buildHands() {
    final hands = Row(
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
    return StreamBuilder<BleGloveSnapshot>(
      stream: _bleService.snapshots,
      initialData: _bleService.snapshot,
      builder: (context, bleSnapshot) {
        final bleState = bleSnapshot.data ?? _bleService.snapshot;

        return Scaffold(
          backgroundColor: Colors.grey[100],
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: StreamBuilder<void>(
                stream: _calibration.updates,
                builder: (context, _) {
                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Glove Calibration',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          bleState.areBothConnected
                              ? 'Both gloves connected'
                              : 'Waiting for both gloves to connect',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: bleState.areBothConnected ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Packets: LEFT ${bleState.leftPacketCount} | RIGHT ${bleState.rightPacketCount}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 30),
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
                        LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          isComplete ? 'Calibration complete' : _calibrationStages[step],
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 12),
                        if (!isComplete)
                          Card(
                            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                children: [
                                  const Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Finger'),
                                      Text('LEFT raw'),
                                      Text('RIGHT raw'),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  for (final finger in const [
                                    'thumb',
                                    'index',
                                    'middle',
                                    'ring',
                                    'pinky',
                                  ])
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(finger.toUpperCase()),
                                          Text(
                                            _calibration.leftRaw['flex_${finger}_raw']
                                                    ?.toStringAsFixed(0) ??
                                                '0',
                                          ),
                                          Text(
                                            _calibration.rightRaw['flex_${finger}_raw']
                                                    ?.toStringAsFixed(0) ??
                                                '0',
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 20),
                        if (!isCalibrating && !isComplete)
                          ElevatedButton(
                            onPressed: bleState.areBothConnected ? startCalibration : null,
                            child: const Text('Start Calibration'),
                          )
                        else if (isCalibrating)
                          ElevatedButton(
                            onPressed: _captureCalibrationSample,
                            child: Text('Capture "${_calibrationStages[step]}"'),
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
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
                                      const Text(
                                        'Calibrated values (0-100):',
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 8),
                                      for (final finger in const [
                                        'thumb',
                                        'index',
                                        'middle',
                                        'ring',
                                        'pinky',
                                      ])
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 3),
                                          child: Text(
                                            '${finger.toUpperCase()}: LEFT=${_getCalibratedFlex(leftGloveName, finger).toStringAsFixed(1)}%, RIGHT=${_getCalibratedFlex(rightGloveName, finger).toStringAsFixed(1)}%',
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

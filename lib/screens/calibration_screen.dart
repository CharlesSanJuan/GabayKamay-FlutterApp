import 'dart:async';

import 'package:flutter/material.dart';

import '../services/app_settings_service.dart';
import '../services/ble_glove_service.dart';
import '../services/glove_calibration_service.dart';

class _CalibrationStage {
  final String title;
  final String instruction;
  final bool captureImuBias;

  const _CalibrationStage({
    required this.title,
    required this.instruction,
    this.captureImuBias = false,
  });
}

class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({super.key});

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen>
    with TickerProviderStateMixin {
  final GloveCalibrationService _calibration = GloveCalibrationService();
  final BleGloveService _bleService = BleGloveService();
  final AppSettingsService _settingsService = AppSettingsService();
  final List<_CalibrationStage> _stages = const [
    _CalibrationStage(
      title: 'Open Hands at Waist Level',
      instruction:
          'Hold both hands open, relaxed, and steady at waist level.',
      captureImuBias: true,
    ),
    _CalibrationStage(
      title: 'Closed Fist',
      instruction: 'Make a firm fist with both hands and hold still.',
    ),
    _CalibrationStage(
      title: 'Open Wide',
      instruction: 'Open both hands as wide as possible and hold still.',
    ),
    _CalibrationStage(
      title: 'Slow Finger Motion',
      instruction: 'Slowly flex and extend the fingers to capture drift range.',
    ),
  ];

  int _stageIndex = 0;
  bool _isRunning = false;
  bool _isComplete = false;
  double _progress = 0.0;
  String _statusText = 'Connect both gloves to begin calibration.';
  int _countdown = 0;
  double _captureProgress = 0.0;

  late AnimationController pulseController;
  late AnimationController completeController;
  late Animation<double> pulseAnimation;
  late Animation<double> completeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeCalibrationState();

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

  Future<void> _initializeCalibrationState() async {
    await _settingsService.ensureInitialized();
    await _calibration.ensureInitialized();
    if (!mounted) {
      return;
    }
    final hasSavedCalibration =
        _calibration.left.isComplete && _calibration.right.isComplete;
    setState(() {
      _isComplete = hasSavedCalibration;
      _statusText = hasSavedCalibration
          ? 'Saved calibration loaded.'
          : 'Connect both gloves to begin calibration.';
      _progress = hasSavedCalibration ? 1.0 : 0.0;
      _captureProgress = hasSavedCalibration ? 1.0 : 0.0;
    });
  }

  @override
  void dispose() {
    pulseController.dispose();
    completeController.dispose();
    super.dispose();
  }

  Future<void> _startCalibration() async {
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
      _isRunning = true;
      _isComplete = false;
      _stageIndex = 0;
      _progress = 0.0;
      _captureProgress = 0.0;
      _statusText = 'Preparing calibration...';
    });

    try {
      for (var i = 0; i < _stages.length; i++) {
        final stage = _stages[i];
        setState(() {
          _stageIndex = i;
          _statusText = stage.instruction;
          _progress = i / _stages.length;
        });

        await _runCountdown(3);
        final windows = <_CalibrationWindow>[];
        final captureRounds = stage.captureImuBias ? 2 : 2;

        for (var round = 0; round < captureRounds; round++) {
          setState(() {
            _statusText = '${stage.instruction}\nCapture ${round + 1} of $captureRounds';
            _captureProgress = 0.0;
          });

          windows.add(
            await _collectCalibrationWindow(
              const Duration(seconds: 5),
            ),
          );
        }

        _applyCalibrationStage(stage, windows);
        setState(() {
          _progress = (i + 1) / _stages.length;
        });
      }

      setState(() {
        _isRunning = false;
        _isComplete = true;
        _countdown = 0;
        _captureProgress = 1.0;
        _statusText = 'Calibration complete.';
      });
      await _calibration.save();
      await completeController.forward();
    } catch (e) {
      setState(() {
        _isRunning = false;
        _statusText = 'Calibration failed: $e';
      });
    }
  }

  Future<void> _runCountdown(int seconds) async {
    for (var remaining = seconds; remaining > 0; remaining--) {
      if (!mounted) {
        return;
      }
      setState(() {
        _countdown = remaining;
      });
      await Future.delayed(const Duration(seconds: 1));
    }
    if (mounted) {
      setState(() {
        _countdown = 0;
      });
    }
  }

  Future<_CalibrationWindow> _collectCalibrationWindow(Duration duration) async {
    final leftFrames = <Map<String, double>>[];
    final rightFrames = <Map<String, double>>[];
    final completer = Completer<_CalibrationWindow>();

    void addSnapshot(BleGloveSnapshot snapshot) {
      if (snapshot.leftData == null || snapshot.rightData == null) {
        return;
      }
      leftFrames.add(Map<String, double>.from(snapshot.leftData!));
      rightFrames.add(Map<String, double>.from(snapshot.rightData!));
    }

    final current = _bleService.snapshot;
    addSnapshot(current);

    final start = DateTime.now();
    final sub = _bleService.snapshots.listen((snapshot) {
      addSnapshot(snapshot);
      if (!mounted) {
        return;
      }
      final elapsedMs = DateTime.now().difference(start).inMilliseconds;
      setState(() {
        _captureProgress = (elapsedMs / duration.inMilliseconds).clamp(0.0, 1.0);
      });
    });

    Timer(duration, () {
      if (!completer.isCompleted) {
        completer.complete(
          _CalibrationWindow(leftFrames: leftFrames, rightFrames: rightFrames),
        );
      }
    });

    final result = await completer.future;
    await sub.cancel();
    return result;
  }

  void _applyCalibrationStage(
    _CalibrationStage stage,
    List<_CalibrationWindow> windows,
  ) {
    const fingers = ['thumb', 'index', 'middle', 'ring', 'pinky'];

    if (stage.captureImuBias) {
      final leftImu = _averageImu(
        windows.expand((window) => window.leftFrames).toList(),
      );
      final rightImu = _averageImu(
        windows.expand((window) => window.rightFrames).toList(),
      );

      _calibration.left.updateImuBias(
        leftImu['ax_raw'] ?? 0.0,
        leftImu['ay_raw'] ?? 0.0,
        leftImu['az_raw'] ?? 0.0,
        leftImu['gx_raw'] ?? 0.0,
        leftImu['gy_raw'] ?? 0.0,
        leftImu['gz_raw'] ?? 0.0,
      );
      _calibration.right.updateImuBias(
        rightImu['ax_raw'] ?? 0.0,
        rightImu['ay_raw'] ?? 0.0,
        rightImu['az_raw'] ?? 0.0,
        rightImu['gx_raw'] ?? 0.0,
        rightImu['gy_raw'] ?? 0.0,
        rightImu['gz_raw'] ?? 0.0,
      );
    }

    for (var fingerIndex = 0; fingerIndex < fingers.length; fingerIndex++) {
      final key = 'flex_${fingers[fingerIndex]}_raw';

      for (final window in windows) {
        for (final frame in window.leftFrames) {
          _calibration.left.updateStepMinMax(fingerIndex, frame[key] ?? 0.0);
        }
        for (final frame in window.rightFrames) {
          _calibration.right.updateStepMinMax(fingerIndex, frame[key] ?? 0.0);
        }
      }
    }
  }

  Map<String, double> _averageImu(List<Map<String, double>> frames) {
    if (frames.isEmpty) {
      return const {
        'ax_raw': 0.0,
        'ay_raw': 0.0,
        'az_raw': 0.0,
        'gx_raw': 0.0,
        'gy_raw': 0.0,
        'gz_raw': 0.0,
      };
    }

    const keys = ['ax_raw', 'ay_raw', 'az_raw', 'gx_raw', 'gy_raw', 'gz_raw'];
    final totals = <String, double>{for (final key in keys) key: 0.0};

    for (final frame in frames) {
      for (final key in keys) {
        totals[key] = totals[key]! + (frame[key] ?? 0.0);
      }
    }

    return {
      for (final key in keys) key: totals[key]! / frames.length,
    };
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
    return calibration.mapToPercent(
      idx,
      rawValue,
      thumbMinimumSpan: idx == 0
          ? _settingsService.settings.thumbFlexMinimumSpan
          : null,
    );
  }

  Widget _buildHands() {
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

    if (_isComplete) {
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

    if (_isRunning) {
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
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
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
                        const SizedBox(height: 20),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _stages[_stageIndex].title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(_statusText),
                                if (_countdown > 0) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Starting in $_countdown...',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ],
                                if (_isRunning) ...[
                                  const SizedBox(height: 12),
                                  LinearProgressIndicator(value: _captureProgress),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          height: 220,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Center(child: _buildHands()),
                        ),
                        const SizedBox(height: 24),
                        LinearProgressIndicator(value: _progress, minHeight: 8),
                        const SizedBox(height: 20),
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
                        if (!_isRunning && !_isComplete)
                          ElevatedButton(
                            onPressed: bleState.areBothConnected ? _startCalibration : null,
                            child: const Text('Start Automatic Calibration'),
                          )
                        else if (_isComplete)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  _calibration.reset();
                                  setState(() {
                                    _isRunning = false;
                                    _isComplete = false;
                                    _stageIndex = 0;
                                    _progress = 0.0;
                                    _captureProgress = 0.0;
                                    _statusText =
                                        'Connect both gloves to begin calibration.';
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

class _CalibrationWindow {
  final List<Map<String, double>> leftFrames;
  final List<Map<String, double>> rightFrames;

  const _CalibrationWindow({
    required this.leftFrames,
    required this.rightFrames,
  });
}

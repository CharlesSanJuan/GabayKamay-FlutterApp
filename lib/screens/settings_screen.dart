import 'dart:async';

import 'package:flutter/material.dart';

import '../services/app_settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AppSettingsService _settingsService = AppSettingsService();
  StreamSubscription<AppSettings>? _settingsSub;

  @override
  void initState() {
    super.initState();
    _settingsService.ensureInitialized().then((_) {
      if (mounted) {
        setState(() {});
      }
    });
    _settingsSub = _settingsService.changes.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _settingsSub?.cancel();
    super.dispose();
  }

  Future<void> _save(AppSettings settings) async {
    await _settingsService.save(settings);
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settingsService.settings;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recognition Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Section(
            title: 'Recognition',
            children: [
              _SliderTile(
                label: 'Confidence Threshold',
                value: settings.confidenceThreshold,
                min: 0.40,
                max: 0.95,
                divisions: 55,
                valueText: settings.confidenceThreshold.toStringAsFixed(2),
                onChanged: (value) async {
                  await _save(settings.copyWith(confidenceThreshold: value));
                },
              ),
              _SliderTile(
                label: 'Dynamic Motion Threshold',
                value: settings.dynamicMotionThreshold,
                min: 0.4,
                max: 4.0,
                divisions: 36,
                valueText: settings.dynamicMotionThreshold.toStringAsFixed(2),
                onChanged: (value) async {
                  await _save(settings.copyWith(dynamicMotionThreshold: value));
                },
              ),
              _SliderTile(
                label: 'Presentation Gyro Threshold',
                value: settings.presentationGyroThreshold,
                min: 0.02,
                max: 1.0,
                divisions: 49,
                valueText: settings.presentationGyroThreshold.toStringAsFixed(2),
                onChanged: (value) async {
                  await _save(settings.copyWith(presentationGyroThreshold: value));
                },
              ),
              _SliderTile(
                label: 'Presentation Accel Threshold',
                value: settings.presentationAccelerationThreshold,
                min: 0.02,
                max: 1.0,
                divisions: 49,
                valueText: settings.presentationAccelerationThreshold
                    .toStringAsFixed(2),
                onChanged: (value) async {
                  await _save(
                    settings.copyWith(presentationAccelerationThreshold: value),
                  );
                },
              ),
              _SliderTile(
                label: 'Presentation Flex Threshold',
                value: settings.presentationFlexThreshold,
                min: 1.0,
                max: 20.0,
                divisions: 38,
                valueText: settings.presentationFlexThreshold.toStringAsFixed(1),
                onChanged: (value) async {
                  await _save(settings.copyWith(presentationFlexThreshold: value));
                },
              ),
            ],
          ),
          _Section(
            title: 'Sensor Smoothing',
            children: [
              _SliderTile(
                label: 'Flex Smoothing Alpha',
                value: settings.flexSmoothingAlpha,
                min: 0.10,
                max: 0.95,
                divisions: 85,
                valueText: settings.flexSmoothingAlpha.toStringAsFixed(2),
                onChanged: (value) async {
                  await _save(settings.copyWith(flexSmoothingAlpha: value));
                },
              ),
              _SliderTile(
                label: 'IMU Smoothing Alpha',
                value: settings.imuSmoothingAlpha,
                min: 0.10,
                max: 0.95,
                divisions: 85,
                valueText: settings.imuSmoothingAlpha.toStringAsFixed(2),
                onChanged: (value) async {
                  await _save(settings.copyWith(imuSmoothingAlpha: value));
                },
              ),
              _SliderTile(
                label: 'Flex Deadband',
                value: settings.flexDeadband,
                min: 0.0,
                max: 2.0,
                divisions: 40,
                valueText: settings.flexDeadband.toStringAsFixed(2),
                onChanged: (value) async {
                  await _save(settings.copyWith(flexDeadband: value));
                },
              ),
              _SliderTile(
                label: 'IMU Deadband',
                value: settings.imuDeadband,
                min: 0.0,
                max: 0.08,
                divisions: 40,
                valueText: settings.imuDeadband.toStringAsFixed(3),
                onChanged: (value) async {
                  await _save(settings.copyWith(imuDeadband: value));
                },
              ),
            ],
          ),
          _Section(
            title: 'Training And Speech',
            children: [
              SwitchListTile.adaptive(
                value: settings.trainingAutoCaptureEnabled,
                title: const Text('Auto-Capture Training'),
                subtitle: const Text(
                  'Automatically move through repeated capture windows.',
                ),
                onChanged: (value) async {
                  await _save(
                    settings.copyWith(trainingAutoCaptureEnabled: value),
                  );
                },
              ),
              SwitchListTile.adaptive(
                value: settings.muteTranslationWhileTraining,
                title: const Text('Mute Translation While Training'),
                subtitle: const Text(
                  'Prevents live recognition and speech from firing during training.',
                ),
                onChanged: (value) async {
                  await _save(
                    settings.copyWith(muteTranslationWhileTraining: value),
                  );
                },
              ),
              SwitchListTile.adaptive(
                value: settings.ttsEnabled,
                title: const Text('Text To Speech'),
                subtitle: const Text(
                  'Keeps recognized phrases in a queue so they finish speaking.',
                ),
                onChanged: (value) async {
                  await _save(settings.copyWith(ttsEnabled: value));
                },
              ),
              ListTile(
                title: const Text('Training Countdown'),
                subtitle: Text('${settings.trainingCountdownSeconds} seconds'),
                trailing: DropdownButton<int>(
                  value: settings.trainingCountdownSeconds,
                  items: const [0, 1, 2, 3, 4, 5]
                      .map(
                        (count) => DropdownMenuItem<int>(
                          value: count,
                          child: Text('$count s'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) async {
                    if (value == null) {
                      return;
                    }
                    await _save(settings.copyWith(trainingCountdownSeconds: value));
                  },
                ),
              ),
              TextButton(
                onPressed: () async {
                  await _settingsService.reset();
                },
                child: const Text('Reset Settings To Defaults'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _SliderTile extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String valueText;
  final ValueChanged<double> onChanged;

  const _SliderTile({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.valueText,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        divisions: divisions,
        label: valueText,
        onChanged: onChanged,
      ),
      trailing: SizedBox(
        width: 52,
        child: Text(
          valueText,
          textAlign: TextAlign.end,
        ),
      ),
    );
  }
}

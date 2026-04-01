import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  final double confidenceThreshold;
  final double dynamicMotionThreshold;
  final double presentationGyroThreshold;
  final double presentationFlexThreshold;
  final double presentationAccelerationThreshold;
  final double presentationPoseThreshold;
  final double flexSmoothingAlpha;
  final double imuSmoothingAlpha;
  final double flexDeadband;
  final double imuDeadband;
  final bool trainingAutoCaptureEnabled;
  final int trainingCountdownSeconds;
  final bool muteTranslationWhileTraining;
  final bool ttsEnabled;

  const AppSettings({
    required this.confidenceThreshold,
    required this.dynamicMotionThreshold,
    required this.presentationGyroThreshold,
    required this.presentationFlexThreshold,
    required this.presentationAccelerationThreshold,
    required this.presentationPoseThreshold,
    required this.flexSmoothingAlpha,
    required this.imuSmoothingAlpha,
    required this.flexDeadband,
    required this.imuDeadband,
    required this.trainingAutoCaptureEnabled,
    required this.trainingCountdownSeconds,
    required this.muteTranslationWhileTraining,
    required this.ttsEnabled,
  });

  factory AppSettings.defaults() {
    return const AppSettings(
      confidenceThreshold: 0.62,
      dynamicMotionThreshold: 1.35,
      presentationGyroThreshold: 0.18,
      presentationFlexThreshold: 6.0,
      presentationAccelerationThreshold: 0.12,
      presentationPoseThreshold: 35.0,
      flexSmoothingAlpha: 0.62,
      imuSmoothingAlpha: 0.68,
      flexDeadband: 0.35,
      imuDeadband: 0.012,
      trainingAutoCaptureEnabled: false,
      trainingCountdownSeconds: 3,
      muteTranslationWhileTraining: true,
      ttsEnabled: true,
    );
  }

  AppSettings copyWith({
    double? confidenceThreshold,
    double? dynamicMotionThreshold,
    double? presentationGyroThreshold,
    double? presentationFlexThreshold,
    double? presentationAccelerationThreshold,
    double? presentationPoseThreshold,
    double? flexSmoothingAlpha,
    double? imuSmoothingAlpha,
    double? flexDeadband,
    double? imuDeadband,
    bool? trainingAutoCaptureEnabled,
    int? trainingCountdownSeconds,
    bool? muteTranslationWhileTraining,
    bool? ttsEnabled,
  }) {
    return AppSettings(
      confidenceThreshold: confidenceThreshold ?? this.confidenceThreshold,
      dynamicMotionThreshold: dynamicMotionThreshold ?? this.dynamicMotionThreshold,
      presentationGyroThreshold:
          presentationGyroThreshold ?? this.presentationGyroThreshold,
      presentationFlexThreshold:
          presentationFlexThreshold ?? this.presentationFlexThreshold,
      presentationAccelerationThreshold: presentationAccelerationThreshold ??
          this.presentationAccelerationThreshold,
      presentationPoseThreshold:
          presentationPoseThreshold ?? this.presentationPoseThreshold,
      flexSmoothingAlpha: flexSmoothingAlpha ?? this.flexSmoothingAlpha,
      imuSmoothingAlpha: imuSmoothingAlpha ?? this.imuSmoothingAlpha,
      flexDeadband: flexDeadband ?? this.flexDeadband,
      imuDeadband: imuDeadband ?? this.imuDeadband,
      trainingAutoCaptureEnabled:
          trainingAutoCaptureEnabled ?? this.trainingAutoCaptureEnabled,
      trainingCountdownSeconds:
          trainingCountdownSeconds ?? this.trainingCountdownSeconds,
      muteTranslationWhileTraining:
          muteTranslationWhileTraining ?? this.muteTranslationWhileTraining,
      ttsEnabled: ttsEnabled ?? this.ttsEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'confidenceThreshold': confidenceThreshold,
        'dynamicMotionThreshold': dynamicMotionThreshold,
        'presentationGyroThreshold': presentationGyroThreshold,
        'presentationFlexThreshold': presentationFlexThreshold,
        'presentationAccelerationThreshold': presentationAccelerationThreshold,
        'presentationPoseThreshold': presentationPoseThreshold,
        'flexSmoothingAlpha': flexSmoothingAlpha,
        'imuSmoothingAlpha': imuSmoothingAlpha,
        'flexDeadband': flexDeadband,
        'imuDeadband': imuDeadband,
        'trainingAutoCaptureEnabled': trainingAutoCaptureEnabled,
        'trainingCountdownSeconds': trainingCountdownSeconds,
        'muteTranslationWhileTraining': muteTranslationWhileTraining,
        'ttsEnabled': ttsEnabled,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final defaults = AppSettings.defaults();
    return AppSettings(
      confidenceThreshold:
          (json['confidenceThreshold'] as num?)?.toDouble() ??
              defaults.confidenceThreshold,
      dynamicMotionThreshold:
          (json['dynamicMotionThreshold'] as num?)?.toDouble() ??
              defaults.dynamicMotionThreshold,
      presentationGyroThreshold:
          (json['presentationGyroThreshold'] as num?)?.toDouble() ??
              defaults.presentationGyroThreshold,
      presentationFlexThreshold:
          (json['presentationFlexThreshold'] as num?)?.toDouble() ??
              defaults.presentationFlexThreshold,
      presentationAccelerationThreshold:
          (json['presentationAccelerationThreshold'] as num?)?.toDouble() ??
              defaults.presentationAccelerationThreshold,
      presentationPoseThreshold:
          (json['presentationPoseThreshold'] as num?)?.toDouble() ??
              defaults.presentationPoseThreshold,
      flexSmoothingAlpha:
          (json['flexSmoothingAlpha'] as num?)?.toDouble() ??
              defaults.flexSmoothingAlpha,
      imuSmoothingAlpha:
          (json['imuSmoothingAlpha'] as num?)?.toDouble() ??
              defaults.imuSmoothingAlpha,
      flexDeadband:
          (json['flexDeadband'] as num?)?.toDouble() ?? defaults.flexDeadband,
      imuDeadband:
          (json['imuDeadband'] as num?)?.toDouble() ?? defaults.imuDeadband,
      trainingAutoCaptureEnabled:
          json['trainingAutoCaptureEnabled'] as bool? ??
              defaults.trainingAutoCaptureEnabled,
      trainingCountdownSeconds:
          json['trainingCountdownSeconds'] as int? ??
              defaults.trainingCountdownSeconds,
      muteTranslationWhileTraining:
          json['muteTranslationWhileTraining'] as bool? ??
              defaults.muteTranslationWhileTraining,
      ttsEnabled: json['ttsEnabled'] as bool? ?? defaults.ttsEnabled,
    );
  }
}

class AppSettingsService {
  static const _storageKey = 'app_settings_v1';
  static final AppSettingsService _instance = AppSettingsService._internal();

  factory AppSettingsService() => _instance;
  AppSettingsService._internal();

  final StreamController<AppSettings> _controller =
      StreamController<AppSettings>.broadcast();

  AppSettings _settings = AppSettings.defaults();
  bool _initialized = false;

  AppSettings get settings => _settings;
  Stream<AppSettings> get changes => _controller.stream;

  Future<void> ensureInitialized() async {
    if (_initialized) {
      return;
    }
    _initialized = true;

    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_storageKey);
    if (encoded == null || encoded.isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;
      _settings = AppSettings.fromJson(decoded);
    } catch (_) {
      _settings = AppSettings.defaults();
    }
  }

  Future<void> save(AppSettings settings) async {
    await ensureInitialized();
    _settings = settings;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(settings.toJson()));
    if (!_controller.isClosed) {
      _controller.add(_settings);
    }
  }

  Future<void> reset() async {
    await save(AppSettings.defaults());
  }
}

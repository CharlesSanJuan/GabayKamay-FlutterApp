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
  final double activeHandFlexTolerance;
  final double inactiveHandFlexAllowance;
  final double inactiveHandFlexCap;
  final double flexSmoothingAlpha;
  final double imuSmoothingAlpha;
  final double flexDeadband;
  final double imuDeadband;
  final bool trainingAutoCaptureEnabled;
  final int trainingCountdownSeconds;
  final bool muteTranslationWhileTraining;
  final bool ttsEnabled;
  final bool showThesisMetrics;
  final double thumbFlexMinimumSpan;
  final List<String> disabledGestureIds;

  const AppSettings({
    required this.confidenceThreshold,
    required this.dynamicMotionThreshold,
    required this.presentationGyroThreshold,
    required this.presentationFlexThreshold,
    required this.presentationAccelerationThreshold,
    required this.presentationPoseThreshold,
    required this.activeHandFlexTolerance,
    required this.inactiveHandFlexAllowance,
    required this.inactiveHandFlexCap,
    required this.flexSmoothingAlpha,
    required this.imuSmoothingAlpha,
    required this.flexDeadband,
    required this.imuDeadband,
    required this.trainingAutoCaptureEnabled,
    required this.trainingCountdownSeconds,
    required this.muteTranslationWhileTraining,
    required this.ttsEnabled,
    required this.showThesisMetrics,
    required this.thumbFlexMinimumSpan,
    required this.disabledGestureIds,
  });

  factory AppSettings.defaults() {
    return const AppSettings(
      confidenceThreshold: 0.62,
      dynamicMotionThreshold: 1.35,
      presentationGyroThreshold: 0.18,
      presentationFlexThreshold: 6.0,
      presentationAccelerationThreshold: 0.12,
      presentationPoseThreshold: 35.0,
      activeHandFlexTolerance: 30.0,
      inactiveHandFlexAllowance: 32.0,
      inactiveHandFlexCap: 68.0,
      flexSmoothingAlpha: 0.62,
      imuSmoothingAlpha: 0.68,
      flexDeadband: 0.35,
      imuDeadband: 0.012,
      trainingAutoCaptureEnabled: false,
      trainingCountdownSeconds: 3,
      muteTranslationWhileTraining: true,
      ttsEnabled: true,
      showThesisMetrics: false,
      thumbFlexMinimumSpan: 70.0,
      disabledGestureIds: [],
    );
  }

  AppSettings copyWith({
    double? confidenceThreshold,
    double? dynamicMotionThreshold,
    double? presentationGyroThreshold,
    double? presentationFlexThreshold,
    double? presentationAccelerationThreshold,
    double? presentationPoseThreshold,
    double? activeHandFlexTolerance,
    double? inactiveHandFlexAllowance,
    double? inactiveHandFlexCap,
    double? flexSmoothingAlpha,
    double? imuSmoothingAlpha,
    double? flexDeadband,
    double? imuDeadband,
    bool? trainingAutoCaptureEnabled,
    int? trainingCountdownSeconds,
    bool? muteTranslationWhileTraining,
    bool? ttsEnabled,
    bool? showThesisMetrics,
    double? thumbFlexMinimumSpan,
    List<String>? disabledGestureIds,
  }) {
    return AppSettings(
      confidenceThreshold: confidenceThreshold ?? this.confidenceThreshold,
      dynamicMotionThreshold:
          dynamicMotionThreshold ?? this.dynamicMotionThreshold,
      presentationGyroThreshold:
          presentationGyroThreshold ?? this.presentationGyroThreshold,
      presentationFlexThreshold:
          presentationFlexThreshold ?? this.presentationFlexThreshold,
      presentationAccelerationThreshold:
          presentationAccelerationThreshold ??
          this.presentationAccelerationThreshold,
      presentationPoseThreshold:
          presentationPoseThreshold ?? this.presentationPoseThreshold,
      activeHandFlexTolerance:
          activeHandFlexTolerance ?? this.activeHandFlexTolerance,
      inactiveHandFlexAllowance:
          inactiveHandFlexAllowance ?? this.inactiveHandFlexAllowance,
      inactiveHandFlexCap:
          inactiveHandFlexCap ?? this.inactiveHandFlexCap,
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
      showThesisMetrics: showThesisMetrics ?? this.showThesisMetrics,
      thumbFlexMinimumSpan: thumbFlexMinimumSpan ?? this.thumbFlexMinimumSpan,
      disabledGestureIds: disabledGestureIds ?? this.disabledGestureIds,
    );
  }

  Map<String, dynamic> toJson() => {
    'confidenceThreshold': confidenceThreshold,
    'dynamicMotionThreshold': dynamicMotionThreshold,
    'presentationGyroThreshold': presentationGyroThreshold,
    'presentationFlexThreshold': presentationFlexThreshold,
    'presentationAccelerationThreshold': presentationAccelerationThreshold,
    'presentationPoseThreshold': presentationPoseThreshold,
    'activeHandFlexTolerance': activeHandFlexTolerance,
    'inactiveHandFlexAllowance': inactiveHandFlexAllowance,
    'inactiveHandFlexCap': inactiveHandFlexCap,
    'flexSmoothingAlpha': flexSmoothingAlpha,
    'imuSmoothingAlpha': imuSmoothingAlpha,
    'flexDeadband': flexDeadband,
    'imuDeadband': imuDeadband,
    'trainingAutoCaptureEnabled': trainingAutoCaptureEnabled,
    'trainingCountdownSeconds': trainingCountdownSeconds,
    'muteTranslationWhileTraining': muteTranslationWhileTraining,
    'ttsEnabled': ttsEnabled,
    'showThesisMetrics': showThesisMetrics,
    'thumbFlexMinimumSpan': thumbFlexMinimumSpan,
    'disabledGestureIds': disabledGestureIds,
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
      activeHandFlexTolerance:
          (json['activeHandFlexTolerance'] as num?)?.toDouble() ??
          defaults.activeHandFlexTolerance,
      inactiveHandFlexAllowance:
          (json['inactiveHandFlexAllowance'] as num?)?.toDouble() ??
          defaults.inactiveHandFlexAllowance,
      inactiveHandFlexCap:
          (json['inactiveHandFlexCap'] as num?)?.toDouble() ??
          defaults.inactiveHandFlexCap,
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
      showThesisMetrics:
          json['showThesisMetrics'] as bool? ?? defaults.showThesisMetrics,
      thumbFlexMinimumSpan:
          (json['thumbFlexMinimumSpan'] as num?)?.toDouble() ??
          defaults.thumbFlexMinimumSpan,
      disabledGestureIds:
          (json['disabledGestureIds'] as List<dynamic>? ?? const [])
              .map((item) => item as String)
              .toList(),
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

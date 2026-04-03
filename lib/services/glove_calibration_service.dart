import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class GloveCalibration {
  static const double minimumReliableFlexSpan = 140.0;

  /// Per-finger min/max from a real person (raw ADC 0-4095 or similar)
  final List<double> minRaw = List<double>.filled(5, double.maxFinite);
  final List<double> maxRaw = List<double>.filled(5, double.minPositive);

  // IMU bias values captured during calibration (at rest)
  double axBias = 0.0;
  double ayBias = 0.0;
  double azBias = 0.0;
  double gxBias = 0.0;
  double gyBias = 0.0;
  double gzBias = 0.0;

  bool get isFlexCalibrated => minRaw.any((v) => v < double.maxFinite) && maxRaw.any((v) => v > double.minPositive);
  bool get isImuCalibrated => true; // always have some values; set by updateImuBias

  bool get isComplete => isFlexCalibrated && isImuCalibrated;

  void updateStepMinMax(int fingerIndex, double rawValue) {
    if (fingerIndex < 0 || fingerIndex >= 5) return;
    minRaw[fingerIndex] = rawValue < minRaw[fingerIndex] ? rawValue : minRaw[fingerIndex];
    maxRaw[fingerIndex] = rawValue > maxRaw[fingerIndex] ? rawValue : maxRaw[fingerIndex];
  }

  void updateImuBias(double ax, double ay, double az, double gx, double gy, double gz) {
    axBias = ax;
    ayBias = ay;
    azBias = az;
    gxBias = gx;
    gyBias = gy;
    gzBias = gz;
  }

  double accelG(double raw, double bias, {double scale = 16384.0}) {
    return (raw - bias) / scale;
  }

  double gyroDps(double raw, double bias, {double scale = 131.0}) {
    return (raw - bias) / scale;
  }

  double accelGx(double raw) => accelG(raw, axBias);
  double accelGy(double raw) => accelG(raw, ayBias);
  double accelGz(double raw) => accelG(raw, azBias);

  double gyroDpsX(double raw) => gyroDps(raw, gxBias);
  double gyroDpsY(double raw) => gyroDps(raw, gyBias);
  double gyroDpsZ(double raw) => gyroDps(raw, gzBias);

  double mapToPercent(
    int fingerIndex,
    double rawValue, {
    double? thumbMinimumSpan,
  }) {
    if (fingerIndex < 0 || fingerIndex >= 5) return 0.0;
    final minVal = minRaw[fingerIndex];
    final maxVal = maxRaw[fingerIndex];
    if (minVal >= maxVal) return 0.0;
    final minimumSpan = fingerIndex == 0
        ? (thumbMinimumSpan ?? minimumReliableFlexSpan)
        : minimumReliableFlexSpan;
    final effectiveSpan = (maxVal - minVal) < minimumSpan
        ? minimumSpan
        : (maxVal - minVal);
    final normalized = ((rawValue - minVal) / effectiveSpan) * 100.0;
    return normalized.clamp(0.0, 100.0);
  }

  Map<String, dynamic> toJson() => {
        'minRaw': minRaw,
        'maxRaw': maxRaw,
        'axBias': axBias,
        'ayBias': ayBias,
        'azBias': azBias,
        'gxBias': gxBias,
        'gyBias': gyBias,
        'gzBias': gzBias,
      };

  void restoreFromJson(Map<String, dynamic> json) {
    final minValues = (json['minRaw'] as List<dynamic>? ?? const [])
        .map((item) => (item as num).toDouble())
        .toList();
    final maxValues = (json['maxRaw'] as List<dynamic>? ?? const [])
        .map((item) => (item as num).toDouble())
        .toList();
    for (var i = 0; i < 5; i++) {
      minRaw[i] = i < minValues.length ? minValues[i] : double.maxFinite;
      maxRaw[i] = i < maxValues.length ? maxValues[i] : double.minPositive;
    }
    axBias = (json['axBias'] as num?)?.toDouble() ?? 0.0;
    ayBias = (json['ayBias'] as num?)?.toDouble() ?? 0.0;
    azBias = (json['azBias'] as num?)?.toDouble() ?? 0.0;
    gxBias = (json['gxBias'] as num?)?.toDouble() ?? 0.0;
    gyBias = (json['gyBias'] as num?)?.toDouble() ?? 0.0;
    gzBias = (json['gzBias'] as num?)?.toDouble() ?? 0.0;
  }
}

class GloveCalibrationService {
  static const _storageKey = 'glove_calibration_v1';
  static final GloveCalibrationService _instance = GloveCalibrationService._internal();
  factory GloveCalibrationService() => _instance;
  GloveCalibrationService._internal();

  final GloveCalibration left = GloveCalibration();
  final GloveCalibration right = GloveCalibration();

  // Stream for real-time updates
  final _updateController = StreamController<void>.broadcast();
  Stream<void> get updates => _updateController.stream;
  bool _initialized = false;

  Map<String, double> leftRaw = {
    'flex_thumb_raw': 0,
    'flex_index_raw': 0,
    'flex_middle_raw': 0,
    'flex_ring_raw': 0,
    'flex_pinky_raw': 0,
    'ax_raw': 0,
    'ay_raw': 0,
    'az_raw': 0,
    'gx_raw': 0,
    'gy_raw': 0,
    'gz_raw': 0,
  };

  Map<String, double> rightRaw = {
    'flex_thumb_raw': 0,
    'flex_index_raw': 0,
    'flex_middle_raw': 0,
    'flex_ring_raw': 0,
    'flex_pinky_raw': 0,
    'ax_raw': 0,
    'ay_raw': 0,
    'az_raw': 0,
    'gx_raw': 0,
    'gy_raw': 0,
    'gz_raw': 0,
  };

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
      left.restoreFromJson(decoded['left'] as Map<String, dynamic>? ?? const {});
      right.restoreFromJson(decoded['right'] as Map<String, dynamic>? ?? const {});
      _updateController.add(null);
    } catch (_) {}
  }

  Future<void> save() async {
    await ensureInitialized();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode({
        'left': left.toJson(),
        'right': right.toJson(),
      }),
    );
  }

  void updateLatest(String gloveName, Map<String, double> parsed) {
    if (gloveName == 'GLOVE_LEFT') {
      leftRaw = Map<String, double>.from(parsed);
    } else {
      rightRaw = Map<String, double>.from(parsed);
    }
    // Emit update event so listeners are notified
    _updateController.add(null);
  }

  void reset() {
    for (var i = 0; i < 5; i++) {
      left.minRaw[i] = double.maxFinite;
      left.maxRaw[i] = double.minPositive;
      right.minRaw[i] = double.maxFinite;
      right.maxRaw[i] = double.minPositive;
    }

    leftRaw = {
      'flex_thumb_raw': 0,
      'flex_index_raw': 0,
      'flex_middle_raw': 0,
      'flex_ring_raw': 0,
      'flex_pinky_raw': 0,
      'ax_raw': 0,
      'ay_raw': 0,
      'az_raw': 0,
      'gx_raw': 0,
      'gy_raw': 0,
      'gz_raw': 0,
    };

    rightRaw = Map<String, double>.from(leftRaw);
    unawaited(save());
    _updateController.add(null);
  }

  GloveCalibration getCalibration(String gloveName) {
    if (gloveName == 'GLOVE_LEFT') return left;
    return right;
  }

  void dispose() {
    _updateController.close();
  }
}

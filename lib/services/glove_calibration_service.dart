import 'dart:async';

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

  double mapToPercent(int fingerIndex, double rawValue) {
    if (fingerIndex < 0 || fingerIndex >= 5) return 0.0;
    final minVal = minRaw[fingerIndex];
    final maxVal = maxRaw[fingerIndex];
    if (minVal >= maxVal) return 0.0;
    final effectiveSpan = (maxVal - minVal) < minimumReliableFlexSpan
        ? minimumReliableFlexSpan
        : (maxVal - minVal);
    final normalized = ((rawValue - minVal) / effectiveSpan) * 100.0;
    return normalized.clamp(0.0, 100.0);
  }
}

class GloveCalibrationService {
  static final GloveCalibrationService _instance = GloveCalibrationService._internal();
  factory GloveCalibrationService() => _instance;
  GloveCalibrationService._internal();

  final GloveCalibration left = GloveCalibration();
  final GloveCalibration right = GloveCalibration();

  // Stream for real-time updates
  final _updateController = StreamController<void>.broadcast();
  Stream<void> get updates => _updateController.stream;

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
  }

  GloveCalibration getCalibration(String gloveName) {
    if (gloveName == 'GLOVE_LEFT') return left;
    return right;
  }

  void dispose() {
    _updateController.close();
  }
}

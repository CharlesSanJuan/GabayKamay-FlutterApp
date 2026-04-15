import 'dart:math';

import '../models/gesture_models.dart';

class GestureFeatureExtractor {
  static const List<String> _orderedKeys = [
    'flex_thumb',
    'flex_index',
    'flex_middle',
    'flex_ring',
    'flex_pinky',
    'ax_g',
    'ay_g',
    'az_g',
    'gx_dps',
    'gy_dps',
    'gz_dps',
    'pitch_deg',
    'roll_deg',
    'tilt_deg',
  ];

  static const int _gloveStride = 14;
  static const int _flexCount = 5;
  static const int _accelStart = 5;
  static const int _gyroStart = 8;
  static const int _orientationStart = 11;
  static const int _leftHandOffset = 0;
  static const int _rightHandOffset = _gloveStride;

  int get rawFeatureCount => _orderedKeys.length * 2;
  int get aggregatedFeatureCount => rawFeatureCount * 12;

  List<double> buildFrameVector({
    required Map<String, double> left,
    required Map<String, double> right,
  }) {
    return [
      ..._orderedKeys.map((key) => left[key] ?? 0.0),
      ..._orderedKeys.map((key) => right[key] ?? 0.0),
    ];
  }

  List<List<double>> applyHandUsageMask(
    List<List<double>> frames, {
    required GestureHandUsage handUsage,
  }) {
    if (frames.isEmpty || handUsage == GestureHandUsage.bothHands) {
      return frames.map((frame) => List<double>.from(frame)).toList();
    }

    return frames.map((frame) {
      final masked = List<double>.from(frame);
      if (handUsage == GestureHandUsage.leftOnly) {
        for (var i = _rightHandOffset; i < _rightHandOffset + _gloveStride; i++) {
          masked[i] = 0.0;
        }
      } else if (handUsage == GestureHandUsage.rightOnly) {
        for (var i = _leftHandOffset; i < _leftHandOffset + _gloveStride; i++) {
          masked[i] = 0.0;
        }
      }
      return masked;
    }).toList();
  }

  List<double> aggregateWindow(List<List<double>> frames) {
    if (frames.isEmpty) {
      return [];
    }

    final featureLength = frames.first.length;
    final means = List<double>.filled(featureLength, 0);
    final minimums = List<double>.filled(featureLength, double.infinity);
    final maximums = List<double>.filled(
      featureLength,
      double.negativeInfinity,
    );
    final sumsOfSquares = List<double>.filled(featureLength, 0);
    final meanAbsoluteDeltas = List<double>.filled(featureLength, 0);
    final starts = List<double>.from(frames.first);
    final ends = List<double>.from(frames.last);
    final earlyMeans = List<double>.filled(featureLength, 0);
    final middleMeans = List<double>.filled(featureLength, 0);
    final lateMeans = List<double>.filled(featureLength, 0);

    final third = (frames.length / 3).ceil();

    for (var frameIndex = 0; frameIndex < frames.length; frameIndex++) {
      final frame = frames[frameIndex];
      for (var i = 0; i < featureLength; i++) {
        final value = frame[i];
        means[i] += value;
        sumsOfSquares[i] += value * value;
        if (value < minimums[i]) {
          minimums[i] = value;
        }
        if (value > maximums[i]) {
          maximums[i] = value;
        }

        if (frameIndex < third) {
          earlyMeans[i] += value;
        } else if (frameIndex < third * 2) {
          middleMeans[i] += value;
        } else {
          lateMeans[i] += value;
        }

        if (frameIndex > 0) {
          meanAbsoluteDeltas[i] += (value - frames[frameIndex - 1][i]).abs();
        }
      }
    }

    final count = frames.length.toDouble();
    final earlyCount = third.clamp(1, frames.length).toDouble();
    final middleCount =
        (frames.length > third ? (frames.length - third).clamp(1, third) : 1)
            .toDouble();
    final lateCount = (frames.length - (third * 2))
        .clamp(1, frames.length)
        .toDouble();
    final deltas = List<double>.filled(featureLength, 0);
    final ranges = List<double>.filled(featureLength, 0);
    final standardDeviations = List<double>.filled(featureLength, 0);

    for (var i = 0; i < featureLength; i++) {
      means[i] = means[i] / count;
      deltas[i] = ends[i] - starts[i];
      ranges[i] = maximums[i] - minimums[i];
      final variance = (sumsOfSquares[i] / count) - (means[i] * means[i]);
      standardDeviations[i] = sqrt(max(0, variance));
      meanAbsoluteDeltas[i] = meanAbsoluteDeltas[i] / max(1, frames.length - 1);
      earlyMeans[i] = earlyMeans[i] / earlyCount;
      middleMeans[i] = middleMeans[i] / middleCount;
      lateMeans[i] = lateMeans[i] / lateCount;
    }

    return [
      ...means,
      ...minimums,
      ...maximums,
      ...ranges,
      ...starts,
      ...ends,
      ...deltas,
      ...standardDeviations,
      ...meanAbsoluteDeltas,
      ...earlyMeans,
      ...middleMeans,
      ...lateMeans,
    ];
  }

  double movementScore(List<double> previous, List<double> current) {
    if (previous.length != current.length || previous.isEmpty) {
      return 0.0;
    }

    var total = 0.0;
    for (var i = 0; i < previous.length; i++) {
      total += (current[i] - previous[i]).abs();
    }
    return total / previous.length;
  }

  List<List<double>> trimWindowByActivity(
    List<List<double>> frames, {
    double startThreshold = 1.6,
    double stopThreshold = 0.65,
    int paddingFrames = 6,
    int minimumFrames = 15,
  }) {
    if (frames.length <= minimumFrames) {
      return frames;
    }

    final movement = <double>[];
    for (var i = 1; i < frames.length; i++) {
      movement.add(movementScore(frames[i - 1], frames[i]));
    }

    int? firstActive;
    int? lastActive;
    for (var i = 0; i < movement.length; i++) {
      if (movement[i] >= startThreshold) {
        firstActive ??= i;
        lastActive = i;
      }
    }

    if (firstActive == null || lastActive == null) {
      return frames.length > minimumFrames
          ? frames.sublist(frames.length - minimumFrames)
          : frames;
    }

    var start = max(0, firstActive - paddingFrames);
    var end = min(frames.length, lastActive + paddingFrames + 2);

    while (end - start < minimumFrames && end < frames.length) {
      end += 1;
    }
    while (end - start < minimumFrames && start > 0) {
      start -= 1;
    }

    final trimmed = frames.sublist(start, end);
    final recentMovement = movement.isNotEmpty ? movement.last : 0.0;
    if (recentMovement < stopThreshold && trimmed.length > minimumFrames) {
      return trimmed.sublist(max(0, trimmed.length - minimumFrames));
    }
    return trimmed;
  }

  bool isPresentationActive(
    List<List<double>> frames, {
    double gyroThreshold = 0.18,
    double flexThreshold = 6.0,
    double accelerationThreshold = 0.12,
    double poseThreshold = 35.0,
  }) {
    if (frames.length < 6) {
      return false;
    }

    final aggregated = aggregateWindow(frames);
    if (aggregated.length != aggregatedFeatureCount) {
      return false;
    }

    final meansOffset = 0;
    final rangesOffset = rawFeatureCount * 3;
    final stdOffset = rawFeatureCount * 7;
    final absDeltaOffset = rawFeatureCount * 8;

    double gyroActivity = 0.0;
    double flexActivity = 0.0;
    double accelerationActivity = 0.0;
    double poseEnergy = 0.0;

    for (
      var gloveOffset = 0;
      gloveOffset < rawFeatureCount;
      gloveOffset += _gloveStride
    ) {
      for (var i = 0; i < _flexCount; i++) {
        poseEnergy += aggregated[meansOffset + gloveOffset + i].abs();
        flexActivity += aggregated[rangesOffset + gloveOffset + i];
      }

      for (var i = 0; i < 3; i++) {
        accelerationActivity +=
            aggregated[stdOffset + gloveOffset + _accelStart + i].abs();
        gyroActivity +=
            aggregated[absDeltaOffset + gloveOffset + _gyroStart + i].abs();
        poseEnergy +=
            aggregated[meansOffset + gloveOffset + _orientationStart + i]
                .abs() *
            0.12;
      }
    }

    return gyroActivity >= gyroThreshold ||
        flexActivity >= flexThreshold ||
        accelerationActivity >= accelerationThreshold ||
        poseEnergy >= poseThreshold;
  }

  double estimateDynamicMotionScore(List<List<double>> frames) {
    if (frames.length < 6) {
      return 0.0;
    }

    final aggregated = aggregateWindow(frames);
    if (aggregated.length != aggregatedFeatureCount) {
      return 0.0;
    }

    final rangesOffset = rawFeatureCount * 3;
    final deltasOffset = rawFeatureCount * 6;
    final stdOffset = rawFeatureCount * 7;
    final absDeltaOffset = rawFeatureCount * 8;

    var score = 0.0;
    for (
      var gloveOffset = 0;
      gloveOffset < rawFeatureCount;
      gloveOffset += _gloveStride
    ) {
      final accelRange =
          aggregated[rangesOffset + gloveOffset + _accelStart].abs() +
          aggregated[rangesOffset + gloveOffset + _accelStart + 1].abs() +
          aggregated[rangesOffset + gloveOffset + _accelStart + 2].abs();
      final gyroRange =
          aggregated[rangesOffset + gloveOffset + _gyroStart].abs() +
          aggregated[rangesOffset + gloveOffset + _gyroStart + 1].abs() +
          aggregated[rangesOffset + gloveOffset + _gyroStart + 2].abs();
      final accelDelta =
          aggregated[deltasOffset + gloveOffset + _accelStart].abs() +
          aggregated[deltasOffset + gloveOffset + _accelStart + 1].abs() +
          aggregated[deltasOffset + gloveOffset + _accelStart + 2].abs();
      final gyroDelta =
          aggregated[deltasOffset + gloveOffset + _gyroStart].abs() +
          aggregated[deltasOffset + gloveOffset + _gyroStart + 1].abs() +
          aggregated[deltasOffset + gloveOffset + _gyroStart + 2].abs();
      final accelStd =
          aggregated[stdOffset + gloveOffset + _accelStart].abs() +
          aggregated[stdOffset + gloveOffset + _accelStart + 1].abs() +
          aggregated[stdOffset + gloveOffset + _accelStart + 2].abs();
      final gyroCadence =
          aggregated[absDeltaOffset + gloveOffset + _gyroStart].abs() +
          aggregated[absDeltaOffset + gloveOffset + _gyroStart + 1].abs() +
          aggregated[absDeltaOffset + gloveOffset + _gyroStart + 2].abs();

      score +=
          (accelRange * 1.6) +
          (gyroRange * 0.05) +
          (accelDelta * 0.8) +
          (gyroDelta * 0.02) +
          (accelStd * 2.2) +
          (gyroCadence * 3.4);
    }

    return score;
  }

  bool hasDynamicMotion(
    List<List<double>> frames, {
    required double threshold,
  }) {
    return estimateDynamicMotionScore(frames) >= threshold;
  }

  double estimateHandActivityScore(
    List<List<double>> frames, {
    required GestureHandUsage hand,
  }) {
    if (frames.length < 3) {
      return 0.0;
    }

    final aggregated = aggregateWindow(frames);
    if (aggregated.length != aggregatedFeatureCount) {
      return 0.0;
    }

    final offset = hand == GestureHandUsage.rightOnly
        ? _rightHandOffset
        : _leftHandOffset;
    final meansOffset = 0;
    final rangesOffset = rawFeatureCount * 3;
    final stdOffset = rawFeatureCount * 7;
    final absDeltaOffset = rawFeatureCount * 8;

    var score = 0.0;
    for (var i = 0; i < _flexCount; i++) {
      score += aggregated[meansOffset + offset + i].abs() * 0.08;
      score += aggregated[rangesOffset + offset + i].abs() * 1.8;
    }
    for (var i = 0; i < 3; i++) {
      score += aggregated[stdOffset + offset + _accelStart + i].abs() * 1.8;
      score += aggregated[absDeltaOffset + offset + _gyroStart + i].abs() * 2.8;
      score += aggregated[meansOffset + offset + _orientationStart + i].abs() * 0.04;
    }
    return score;
  }

  GestureHandUsage inferDominantHandUsage(
    List<List<double>> frames, {
    double activeThreshold = 2.2,
    double dominanceRatio = 1.45,
  }) {
    final leftScore = estimateHandActivityScore(
      frames,
      hand: GestureHandUsage.leftOnly,
    );
    final rightScore = estimateHandActivityScore(
      frames,
      hand: GestureHandUsage.rightOnly,
    );

    final leftActive = leftScore >= activeThreshold;
    final rightActive = rightScore >= activeThreshold;

    if (leftActive && rightActive) {
      if (leftScore >= rightScore * dominanceRatio) {
        return GestureHandUsage.leftOnly;
      }
      if (rightScore >= leftScore * dominanceRatio) {
        return GestureHandUsage.rightOnly;
      }
      return GestureHandUsage.bothHands;
    }
    if (leftActive) {
      return GestureHandUsage.leftOnly;
    }
    if (rightActive) {
      return GestureHandUsage.rightOnly;
    }
    return GestureHandUsage.bothHands;
  }
}

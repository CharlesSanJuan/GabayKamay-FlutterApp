import 'dart:math';

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
  ];

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

  List<double> aggregateWindow(List<List<double>> frames) {
    if (frames.isEmpty) {
      return [];
    }

    final featureLength = frames.first.length;
    final means = List<double>.filled(featureLength, 0);
    final minimums = List<double>.filled(featureLength, double.infinity);
    final maximums = List<double>.filled(featureLength, double.negativeInfinity);
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
        (frames.length > third ? (frames.length - third).clamp(1, third) : 1).toDouble();
    final lateCount = (frames.length - (third * 2)).clamp(1, frames.length).toDouble();
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

    for (var gloveOffset = 0; gloveOffset < rawFeatureCount; gloveOffset += 11) {
      poseEnergy += aggregated[meansOffset + gloveOffset].abs();
      poseEnergy += aggregated[meansOffset + gloveOffset + 1].abs();
      poseEnergy += aggregated[meansOffset + gloveOffset + 2].abs();
      poseEnergy += aggregated[meansOffset + gloveOffset + 3].abs();
      poseEnergy += aggregated[meansOffset + gloveOffset + 4].abs();

      flexActivity += aggregated[rangesOffset + gloveOffset];
      flexActivity += aggregated[rangesOffset + gloveOffset + 1];
      flexActivity += aggregated[rangesOffset + gloveOffset + 2];
      flexActivity += aggregated[rangesOffset + gloveOffset + 3];
      flexActivity += aggregated[rangesOffset + gloveOffset + 4];

      accelerationActivity += aggregated[stdOffset + gloveOffset + 5].abs();
      accelerationActivity += aggregated[stdOffset + gloveOffset + 6].abs();
      accelerationActivity += aggregated[stdOffset + gloveOffset + 7].abs();

      gyroActivity += aggregated[absDeltaOffset + gloveOffset + 8].abs();
      gyroActivity += aggregated[absDeltaOffset + gloveOffset + 9].abs();
      gyroActivity += aggregated[absDeltaOffset + gloveOffset + 10].abs();
    }

    return gyroActivity >= gyroThreshold ||
        flexActivity >= flexThreshold ||
        accelerationActivity >= accelerationThreshold ||
        poseEnergy >= poseThreshold;
  }
}

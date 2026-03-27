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
  int get aggregatedFeatureCount => rawFeatureCount * 7;

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
    final starts = List<double>.from(frames.first);
    final ends = List<double>.from(frames.last);

    for (final frame in frames) {
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
      }
    }

    final count = frames.length.toDouble();
    final deltas = List<double>.filled(featureLength, 0);
    final standardDeviations = List<double>.filled(featureLength, 0);

    for (var i = 0; i < featureLength; i++) {
      means[i] = means[i] / count;
      deltas[i] = ends[i] - starts[i];
      final variance = (sumsOfSquares[i] / count) - (means[i] * means[i]);
      standardDeviations[i] = sqrt(max(0, variance));
    }

    return [
      ...means,
      ...minimums,
      ...maximums,
      ...starts,
      ...ends,
      ...deltas,
      ...standardDeviations,
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
    double startThreshold = 2.5,
    double stopThreshold = 1.1,
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
}

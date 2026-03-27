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

    for (final frame in frames) {
      for (var i = 0; i < featureLength; i++) {
        final value = frame[i];
        means[i] += value;
        if (value < minimums[i]) {
          minimums[i] = value;
        }
        if (value > maximums[i]) {
          maximums[i] = value;
        }
      }
    }

    final count = frames.length.toDouble();
    for (var i = 0; i < featureLength; i++) {
      means[i] = means[i] / count;
    }

    return [...means, ...minimums, ...maximums];
  }
}

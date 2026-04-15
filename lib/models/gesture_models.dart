import 'dart:convert';

enum GestureHandUsage {
  leftOnly,
  rightOnly,
  bothHands;

  String get storageValue => switch (this) {
    GestureHandUsage.leftOnly => 'left_only',
    GestureHandUsage.rightOnly => 'right_only',
    GestureHandUsage.bothHands => 'both_hands',
  };

  String get displayLabel => switch (this) {
    GestureHandUsage.leftOnly => 'Left hand only',
    GestureHandUsage.rightOnly => 'Right hand only',
    GestureHandUsage.bothHands => 'Both hands',
  };

  static GestureHandUsage fromStorageValue(String? value) {
    return switch (value) {
      'left_only' => GestureHandUsage.leftOnly,
      'right_only' => GestureHandUsage.rightOnly,
      _ => GestureHandUsage.bothHands,
    };
  }
}

class GestureTrainingSample {
  final String gestureId;
  final String label;
  final String spokenText;
  final bool isDynamic;
  final GestureHandUsage handUsage;
  final List<double> featureVector;
  final DateTime createdAt;

  const GestureTrainingSample({
    required this.gestureId,
    required this.label,
    required this.spokenText,
    required this.isDynamic,
    required this.handUsage,
    required this.featureVector,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'gestureId': gestureId,
        'label': label,
        'spokenText': spokenText,
        'isDynamic': isDynamic,
        'handUsage': handUsage.storageValue,
        'featureVector': featureVector,
        'createdAt': createdAt.toIso8601String(),
      };

  factory GestureTrainingSample.fromJson(Map<String, dynamic> json) {
    return GestureTrainingSample(
      gestureId: json['gestureId'] as String,
      label: json['label'] as String,
      spokenText: json['spokenText'] as String,
      isDynamic: json['isDynamic'] as bool? ?? false,
      handUsage: GestureHandUsage.fromStorageValue(
        json['handUsage'] as String?,
      ),
      featureVector: (json['featureVector'] as List<dynamic>)
          .map((value) => (value as num).toDouble())
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class GestureDefinition {
  final String id;
  final String label;
  final String spokenText;
  final bool isDynamic;
  final GestureHandUsage handUsage;
  final int sampleCount;
  final DateTime updatedAt;

  const GestureDefinition({
    required this.id,
    required this.label,
    required this.spokenText,
    required this.isDynamic,
    required this.handUsage,
    required this.sampleCount,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'spokenText': spokenText,
        'isDynamic': isDynamic,
        'handUsage': handUsage.storageValue,
        'sampleCount': sampleCount,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory GestureDefinition.fromJson(Map<String, dynamic> json) {
    return GestureDefinition(
      id: json['id'] as String,
      label: json['label'] as String,
      spokenText: json['spokenText'] as String,
      isDynamic: json['isDynamic'] as bool? ?? false,
      handUsage: GestureHandUsage.fromStorageValue(
        json['handUsage'] as String?,
      ),
      sampleCount: json['sampleCount'] as int,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

class RandomForestNodeSnapshot {
  final bool isLeaf;
  final int featureIndex;
  final double threshold;
  final Map<String, double> probabilities;
  final RandomForestNodeSnapshot? left;
  final RandomForestNodeSnapshot? right;

  const RandomForestNodeSnapshot({
    required this.isLeaf,
    required this.featureIndex,
    required this.threshold,
    required this.probabilities,
    this.left,
    this.right,
  });

  Map<String, dynamic> toJson() => {
        'isLeaf': isLeaf,
        'featureIndex': featureIndex,
        'threshold': threshold,
        'probabilities': probabilities,
        'left': left?.toJson(),
        'right': right?.toJson(),
      };

  factory RandomForestNodeSnapshot.fromJson(Map<String, dynamic> json) {
    return RandomForestNodeSnapshot(
      isLeaf: json['isLeaf'] as bool? ?? false,
      featureIndex: json['featureIndex'] as int? ?? -1,
      threshold: (json['threshold'] as num?)?.toDouble() ?? 0,
      probabilities: (json['probabilities'] as Map<String, dynamic>? ?? const {})
          .map((key, value) => MapEntry(key, (value as num).toDouble())),
      left: json['left'] == null
          ? null
          : RandomForestNodeSnapshot.fromJson(json['left'] as Map<String, dynamic>),
      right: json['right'] == null
          ? null
          : RandomForestNodeSnapshot.fromJson(json['right'] as Map<String, dynamic>),
    );
  }
}

class RandomForestTreeSnapshot {
  final RandomForestNodeSnapshot root;

  const RandomForestTreeSnapshot({
    required this.root,
  });

  Map<String, dynamic> toJson() => {
        'root': root.toJson(),
      };

  factory RandomForestTreeSnapshot.fromJson(Map<String, dynamic> json) {
    return RandomForestTreeSnapshot(
      root: RandomForestNodeSnapshot.fromJson(json['root'] as Map<String, dynamic>),
    );
  }
}

class GestureModelProfile {
  final String gestureId;
  final String label;
  final String spokenText;
  final bool isDynamic;
  final GestureHandUsage handUsage;
  final double expectedLeftFlexMean;
  final double expectedRightFlexMean;

  const GestureModelProfile({
    required this.gestureId,
    required this.label,
    required this.spokenText,
    required this.isDynamic,
    required this.handUsage,
    required this.expectedLeftFlexMean,
    required this.expectedRightFlexMean,
  });

  Map<String, dynamic> toJson() => {
        'gestureId': gestureId,
        'label': label,
        'spokenText': spokenText,
        'isDynamic': isDynamic,
        'handUsage': handUsage.storageValue,
        'expectedLeftFlexMean': expectedLeftFlexMean,
        'expectedRightFlexMean': expectedRightFlexMean,
      };

  factory GestureModelProfile.fromJson(Map<String, dynamic> json) {
    return GestureModelProfile(
      gestureId: json['gestureId'] as String,
      label: json['label'] as String,
      spokenText: json['spokenText'] as String,
      isDynamic: json['isDynamic'] as bool? ?? false,
      handUsage: GestureHandUsage.fromStorageValue(
        json['handUsage'] as String?,
      ),
      expectedLeftFlexMean:
          (json['expectedLeftFlexMean'] as num?)?.toDouble() ?? 0.0,
      expectedRightFlexMean:
          (json['expectedRightFlexMean'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class GestureModelSnapshot {
  final String trainerType;
  final int featureLength;
  final double decisionThreshold;
  final DateTime trainedAt;
  final List<GestureModelProfile> profiles;
  final List<RandomForestTreeSnapshot> trees;

  const GestureModelSnapshot({
    required this.trainerType,
    required this.featureLength,
    required this.decisionThreshold,
    required this.trainedAt,
    required this.profiles,
    required this.trees,
  });

  bool get hasProfiles => trees.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'trainerType': trainerType,
        'featureLength': featureLength,
        'decisionThreshold': decisionThreshold,
        'trainedAt': trainedAt.toIso8601String(),
        'profiles': profiles.map((profile) => profile.toJson()).toList(),
        'trees': trees.map((tree) => tree.toJson()).toList(),
      };

  factory GestureModelSnapshot.fromJson(Map<String, dynamic> json) {
    return GestureModelSnapshot(
      trainerType: json['trainerType'] as String,
      featureLength: json['featureLength'] as int,
      decisionThreshold: (json['decisionThreshold'] as num).toDouble(),
      trainedAt: DateTime.parse(json['trainedAt'] as String),
      profiles: (json['profiles'] as List<dynamic>? ?? const [])
          .map((item) => GestureModelProfile.fromJson(item as Map<String, dynamic>))
          .toList(),
      trees: (json['trees'] as List<dynamic>? ?? const [])
          .map((item) => RandomForestTreeSnapshot.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class GesturePrediction {
  final String gestureId;
  final String label;
  final String spokenText;
  final double confidence;
  final DateTime predictedAt;

  const GesturePrediction({
    required this.gestureId,
    required this.label,
    required this.spokenText,
    required this.confidence,
    required this.predictedAt,
  });
}

class TrainingDraft {
  final String gestureId;
  final String label;
  final String spokenText;
  final bool isDynamic;
  final GestureHandUsage handUsage;
  final int targetSamples;
  final List<GestureTrainingSample> capturedSamples;

  const TrainingDraft({
    required this.gestureId,
    required this.label,
    required this.spokenText,
    required this.isDynamic,
    required this.handUsage,
    required this.targetSamples,
    required this.capturedSamples,
  });

  int get capturedCount => capturedSamples.length;
  bool get isComplete => capturedCount >= targetSamples;

  TrainingDraft copyWith({
    String? gestureId,
    String? label,
    String? spokenText,
    bool? isDynamic,
    GestureHandUsage? handUsage,
    int? targetSamples,
    List<GestureTrainingSample>? capturedSamples,
  }) {
    return TrainingDraft(
      gestureId: gestureId ?? this.gestureId,
      label: label ?? this.label,
      spokenText: spokenText ?? this.spokenText,
      isDynamic: isDynamic ?? this.isDynamic,
      handUsage: handUsage ?? this.handUsage,
      targetSamples: targetSamples ?? this.targetSamples,
      capturedSamples: capturedSamples ?? this.capturedSamples,
    );
  }
}

class GestureRepositorySnapshot {
  final List<GestureTrainingSample> samples;
  final List<GestureDefinition> gestures;
  final GestureModelSnapshot? model;

  const GestureRepositorySnapshot({
    required this.samples,
    required this.gestures,
    required this.model,
  });

  String toEncodedJson() {
    return jsonEncode({
      'samples': samples.map((sample) => sample.toJson()).toList(),
      'gestures': gestures.map((gesture) => gesture.toJson()).toList(),
      'model': model?.toJson(),
    });
  }

  factory GestureRepositorySnapshot.fromEncodedJson(String encoded) {
    final decoded = jsonDecode(encoded) as Map<String, dynamic>;
    return GestureRepositorySnapshot(
      samples: (decoded['samples'] as List<dynamic>)
          .map((item) => GestureTrainingSample.fromJson(item as Map<String, dynamic>))
          .toList(),
      gestures: (decoded['gestures'] as List<dynamic>)
          .map((item) => GestureDefinition.fromJson(item as Map<String, dynamic>))
          .toList(),
      model: decoded['model'] == null
          ? null
          : GestureModelSnapshot.fromJson(decoded['model'] as Map<String, dynamic>),
    );
  }
}

class GestureRecognitionState {
  final bool isReady;
  final bool isRecording;
  final double captureProgress;
  final int countdownValue;
  final bool isPresentationActive;
  final String statusMessage;
  final TrainingDraft? activeDraft;
  final List<GestureDefinition> gestures;
  final GestureModelSnapshot? model;
  final GesturePrediction? latestPrediction;

  const GestureRecognitionState({
    required this.isReady,
    required this.isRecording,
    required this.captureProgress,
    required this.countdownValue,
    required this.isPresentationActive,
    required this.statusMessage,
    required this.activeDraft,
    required this.gestures,
    required this.model,
    required this.latestPrediction,
  });

  GestureRecognitionState copyWith({
    bool? isReady,
    bool? isRecording,
    double? captureProgress,
    int? countdownValue,
    bool? isPresentationActive,
    String? statusMessage,
    TrainingDraft? activeDraft,
    bool clearDraft = false,
    List<GestureDefinition>? gestures,
    GestureModelSnapshot? model,
    GesturePrediction? latestPrediction,
    bool clearPrediction = false,
  }) {
    return GestureRecognitionState(
      isReady: isReady ?? this.isReady,
      isRecording: isRecording ?? this.isRecording,
      captureProgress: captureProgress ?? this.captureProgress,
      countdownValue: countdownValue ?? this.countdownValue,
      isPresentationActive: isPresentationActive ?? this.isPresentationActive,
      statusMessage: statusMessage ?? this.statusMessage,
      activeDraft: clearDraft ? null : (activeDraft ?? this.activeDraft),
      gestures: gestures ?? this.gestures,
      model: model ?? this.model,
      latestPrediction:
          clearPrediction ? null : (latestPrediction ?? this.latestPrediction),
    );
  }

  factory GestureRecognitionState.initial() {
    return const GestureRecognitionState(
      isReady: false,
      isRecording: false,
      captureProgress: 0,
      countdownValue: 0,
      isPresentationActive: false,
      statusMessage: 'Model not initialized',
      activeDraft: null,
      gestures: [],
      model: null,
      latestPrediction: null,
    );
  }
}

import 'dart:convert';

class GestureTrainingSample {
  final String gestureId;
  final String label;
  final String spokenText;
  final List<double> featureVector;
  final DateTime createdAt;

  const GestureTrainingSample({
    required this.gestureId,
    required this.label,
    required this.spokenText,
    required this.featureVector,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'gestureId': gestureId,
        'label': label,
        'spokenText': spokenText,
        'featureVector': featureVector,
        'createdAt': createdAt.toIso8601String(),
      };

  factory GestureTrainingSample.fromJson(Map<String, dynamic> json) {
    return GestureTrainingSample(
      gestureId: json['gestureId'] as String,
      label: json['label'] as String,
      spokenText: json['spokenText'] as String,
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
  final int sampleCount;
  final DateTime updatedAt;

  const GestureDefinition({
    required this.id,
    required this.label,
    required this.spokenText,
    required this.sampleCount,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'spokenText': spokenText,
        'sampleCount': sampleCount,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory GestureDefinition.fromJson(Map<String, dynamic> json) {
    return GestureDefinition(
      id: json['id'] as String,
      label: json['label'] as String,
      spokenText: json['spokenText'] as String,
      sampleCount: json['sampleCount'] as int,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

class GestureModelProfile {
  final String gestureId;
  final String label;
  final String spokenText;
  final List<double> centroid;

  const GestureModelProfile({
    required this.gestureId,
    required this.label,
    required this.spokenText,
    required this.centroid,
  });

  Map<String, dynamic> toJson() => {
        'gestureId': gestureId,
        'label': label,
        'spokenText': spokenText,
        'centroid': centroid,
      };

  factory GestureModelProfile.fromJson(Map<String, dynamic> json) {
    return GestureModelProfile(
      gestureId: json['gestureId'] as String,
      label: json['label'] as String,
      spokenText: json['spokenText'] as String,
      centroid:
          (json['centroid'] as List<dynamic>).map((v) => (v as num).toDouble()).toList(),
    );
  }
}

class GestureModelSnapshot {
  final String trainerType;
  final int featureLength;
  final double decisionThreshold;
  final DateTime trainedAt;
  final List<GestureModelProfile> profiles;

  const GestureModelSnapshot({
    required this.trainerType,
    required this.featureLength,
    required this.decisionThreshold,
    required this.trainedAt,
    required this.profiles,
  });

  bool get hasProfiles => profiles.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'trainerType': trainerType,
        'featureLength': featureLength,
        'decisionThreshold': decisionThreshold,
        'trainedAt': trainedAt.toIso8601String(),
        'profiles': profiles.map((profile) => profile.toJson()).toList(),
      };

  factory GestureModelSnapshot.fromJson(Map<String, dynamic> json) {
    return GestureModelSnapshot(
      trainerType: json['trainerType'] as String,
      featureLength: json['featureLength'] as int,
      decisionThreshold: (json['decisionThreshold'] as num).toDouble(),
      trainedAt: DateTime.parse(json['trainedAt'] as String),
      profiles: (json['profiles'] as List<dynamic>)
          .map((item) => GestureModelProfile.fromJson(item as Map<String, dynamic>))
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
  final int targetSamples;
  final List<GestureTrainingSample> capturedSamples;

  const TrainingDraft({
    required this.gestureId,
    required this.label,
    required this.spokenText,
    required this.targetSamples,
    required this.capturedSamples,
  });

  int get capturedCount => capturedSamples.length;
  bool get isComplete => capturedCount >= targetSamples;

  TrainingDraft copyWith({
    String? gestureId,
    String? label,
    String? spokenText,
    int? targetSamples,
    List<GestureTrainingSample>? capturedSamples,
  }) {
    return TrainingDraft(
      gestureId: gestureId ?? this.gestureId,
      label: label ?? this.label,
      spokenText: spokenText ?? this.spokenText,
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
  final String statusMessage;
  final TrainingDraft? activeDraft;
  final List<GestureDefinition> gestures;
  final GestureModelSnapshot? model;
  final GesturePrediction? latestPrediction;

  const GestureRecognitionState({
    required this.isReady,
    required this.isRecording,
    required this.statusMessage,
    required this.activeDraft,
    required this.gestures,
    required this.model,
    required this.latestPrediction,
  });

  GestureRecognitionState copyWith({
    bool? isReady,
    bool? isRecording,
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
      statusMessage: 'Model not initialized',
      activeDraft: null,
      gestures: [],
      model: null,
      latestPrediction: null,
    );
  }
}

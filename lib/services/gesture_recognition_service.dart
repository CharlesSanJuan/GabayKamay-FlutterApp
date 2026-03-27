import 'dart:async';
import 'dart:math';

import '../models/gesture_models.dart';
import 'ble_glove_service.dart';
import 'gesture_feature_extractor.dart';
import 'gesture_storage_service.dart';
import 'glove_calibration_service.dart';

abstract class GestureTrainer {
  GestureModelSnapshot train(List<GestureTrainingSample> samples);
  GesturePrediction? predict(
    GestureModelSnapshot model,
    List<double> featureVector,
  );
}

class PrototypeGestureTrainer implements GestureTrainer {
  @override
  GestureModelSnapshot train(List<GestureTrainingSample> samples) {
    if (samples.isEmpty) {
      return GestureModelSnapshot(
        trainerType: 'prototype_window_classifier',
        featureLength: 0,
        decisionThreshold: 0.48,
        trainedAt: DateTime.now(),
        profiles: const [],
      );
    }

    final samplesByGesture = <String, List<GestureTrainingSample>>{};
    for (final sample in samples) {
      samplesByGesture.putIfAbsent(sample.gestureId, () => []).add(sample);
    }

    final profiles = samplesByGesture.entries.map((entry) {
      final gestureSamples = entry.value;
      final first = gestureSamples.first;
      final featureLength = first.featureVector.length;
      final centroid = List<double>.filled(featureLength, 0);

      for (final sample in gestureSamples) {
        for (var i = 0; i < featureLength; i++) {
          centroid[i] += sample.featureVector[i];
        }
      }

      for (var i = 0; i < featureLength; i++) {
        centroid[i] = centroid[i] / gestureSamples.length;
      }

      return GestureModelProfile(
        gestureId: first.gestureId,
        label: first.label,
        spokenText: first.spokenText,
        centroid: centroid,
      );
    }).toList();

    return GestureModelSnapshot(
      trainerType: 'prototype_window_classifier',
      featureLength: samples.first.featureVector.length,
      decisionThreshold: 0.48,
      trainedAt: DateTime.now(),
      profiles: profiles,
    );
  }

  @override
  GesturePrediction? predict(
    GestureModelSnapshot model,
    List<double> featureVector,
  ) {
    if (!model.hasProfiles || featureVector.length != model.featureLength) {
      return null;
    }

    GestureModelProfile? bestProfile;
    double? bestDistance;
    double? secondBestDistance;

    for (final profile in model.profiles) {
      final distance = _euclideanDistance(profile.centroid, featureVector);
      if (bestDistance == null || distance < bestDistance) {
        secondBestDistance = bestDistance;
        bestDistance = distance;
        bestProfile = profile;
      } else if (secondBestDistance == null || distance < secondBestDistance) {
        secondBestDistance = distance;
      }
    }

    if (bestProfile == null || bestDistance == null) {
      return null;
    }

    final normalizedDistance = bestDistance / model.featureLength;
    final margin = secondBestDistance == null
        ? 1.0
        : ((secondBestDistance - bestDistance) / max(secondBestDistance, 1));
    final confidence = (1 / (1 + normalizedDistance)) * (0.7 + (0.3 * margin));
    if (confidence < model.decisionThreshold) {
      return null;
    }

    return GesturePrediction(
      gestureId: bestProfile.gestureId,
      label: bestProfile.label,
      spokenText: bestProfile.spokenText,
      confidence: confidence.clamp(0.0, 1.0),
      predictedAt: DateTime.now(),
    );
  }

  double _euclideanDistance(List<double> a, List<double> b) {
    var sum = 0.0;
    for (var i = 0; i < a.length; i++) {
      final delta = a[i] - b[i];
      sum += delta * delta;
    }
    return sqrt(sum);
  }
}

class GestureRecognitionService {
  static final GestureRecognitionService _instance =
      GestureRecognitionService._internal();

  factory GestureRecognitionService() => _instance;
  GestureRecognitionService._internal();

  final BleGloveService _bleService = BleGloveService();
  final GestureFeatureExtractor _featureExtractor = GestureFeatureExtractor();
  final GestureStorageService _storageService = GestureStorageService();
  final GestureTrainer _trainer = PrototypeGestureTrainer();
  final GloveCalibrationService _calibrationService = GloveCalibrationService();
  final StreamController<GestureRecognitionState> _stateController =
      StreamController<GestureRecognitionState>.broadcast();

  GestureRecognitionState _state = GestureRecognitionState.initial();
  StreamSubscription<BleGloveSnapshot>? _bleSub;
  DateTime? _lastPredictionAt;
  String? _lastPredictedGestureId;
  bool _initialized = false;
  final List<List<double>> _inferenceFrames = [];

  Stream<GestureRecognitionState> get states => _stateController.stream;
  GestureRecognitionState get state => _state;

  Future<void> ensureInitialized() async {
    if (_initialized) {
      _emit();
      return;
    }

    _initialized = true;
    final repository = await _storageService.loadRepository();
    final compatibleSamples = _compatibleSamples(repository.samples);
    final compatibleModel = repository.model != null &&
            repository.model!.featureLength == _featureExtractor.aggregatedFeatureCount
        ? repository.model
        : null;

    _state = _state.copyWith(
      isReady: true,
      statusMessage: compatibleModel == null
          ? 'Ready. Connect gloves, calibrate, then collect training windows.'
          : 'Ready. ${repository.gestures.length} trained gestures loaded.',
      gestures: repository.gestures,
      model: compatibleModel,
    );

    if (compatibleSamples.length != repository.samples.length) {
      final cleaned = GestureRepositorySnapshot(
        samples: compatibleSamples,
        gestures: repository.gestures,
        model: compatibleModel,
      );
      await _storageService.saveRepository(cleaned);
    }

    await _bleService.ensureInitialized();
    _bleSub = _bleService.snapshots.listen(_handleBleSnapshot);
    _emit();
  }

  Future<void> startTrainingDraft({
    required String label,
    required String spokenText,
    int targetSamples = 5,
  }) async {
    await ensureInitialized();
    if (!_isCalibrationReady()) {
      _setStatus('Calibration must be completed for both gloves before training.');
      return;
    }

    final trimmedLabel = label.trim();
    final trimmedSpokenText =
        spokenText.trim().isEmpty ? trimmedLabel : spokenText.trim();
    final gestureId =
        '${trimmedLabel.toLowerCase().replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}';

    _state = _state.copyWith(
      statusMessage:
          'Training draft created for "$trimmedLabel". Capture $targetSamples windows.',
      activeDraft: TrainingDraft(
        gestureId: gestureId,
        label: trimmedLabel,
        spokenText: trimmedSpokenText,
        targetSamples: max(1, targetSamples),
        capturedSamples: const [],
      ),
    );
    _emit();
  }

  Future<void> captureTrainingSample({
    Duration countdown = const Duration(seconds: 3),
    Duration maxWindow = const Duration(seconds: 8),
    int minimumFrames = 20,
  }) async {
    final draft = _state.activeDraft;
    if (draft == null) {
      _setStatus('Start a training draft before capturing.');
      return;
    }
    if (!_bleService.snapshot.areBothConnected) {
      _setStatus('Both gloves must stay connected before capture.');
      return;
    }

    _state = _state.copyWith(
      isRecording: true,
      statusMessage:
          'Get ready for repetition ${draft.capturedCount + 1}. Capture starts soon.',
    );
    _emit();

    await _runCountdown(countdown, prefix: 'Prepare gesture window');

    try {
      final frames = await _collectGestureWindowFrames(
        maxWindow: maxWindow,
        minimumFrames: minimumFrames,
      );
      final trimmedFrames = _featureExtractor.trimWindowByActivity(
        frames,
        minimumFrames: minimumFrames,
      );
      final aggregated = _featureExtractor.aggregateWindow(trimmedFrames);

      if (aggregated.isEmpty) {
        _state = _state.copyWith(
          isRecording: false,
          statusMessage: 'No BLE frames were captured. Try again.',
        );
        _emit();
        return;
      }

      final sample = GestureTrainingSample(
        gestureId: draft.gestureId,
        label: draft.label,
        spokenText: draft.spokenText,
        featureVector: aggregated,
        createdAt: DateTime.now(),
      );

      final updatedDraft = draft.copyWith(
        capturedSamples: [...draft.capturedSamples, sample],
      );
      _state = _state.copyWith(
        isRecording: false,
        activeDraft: updatedDraft,
        statusMessage: updatedDraft.isComplete
            ? 'Capture complete. Save and retrain the model.'
            : 'Captured window ${updatedDraft.capturedCount} of ${updatedDraft.targetSamples}.',
      );
      _emit();
    } catch (e) {
      _state = _state.copyWith(
        isRecording: false,
        statusMessage: 'Capture failed: $e',
      );
      _emit();
    }
  }

  Future<void> saveDraftAndRetrain() async {
    final draft = _state.activeDraft;
    if (draft == null) {
      _setStatus('Nothing to save yet.');
      return;
    }
    if (draft.capturedSamples.isEmpty) {
      _setStatus('Capture at least one training window before saving.');
      return;
    }

    final repository = await _storageService.loadRepository();
    final compatibleExistingSamples = _compatibleSamples(repository.samples);
    final retainedSamples = compatibleExistingSamples
        .where((sample) => sample.gestureId != draft.gestureId)
        .toList();
    final updatedSamples = [...retainedSamples, ...draft.capturedSamples];
    final compatibleUpdatedSamples = _compatibleSamples(updatedSamples);

    final updatedDefinitions =
        repository.gestures.where((gesture) => gesture.id != draft.gestureId).toList()
          ..add(
            GestureDefinition(
              id: draft.gestureId,
              label: draft.label,
              spokenText: draft.spokenText,
              sampleCount: draft.capturedSamples.length,
              updatedAt: DateTime.now(),
            ),
          );

    final model = compatibleUpdatedSamples.isEmpty
        ? null
        : _trainer.train(compatibleUpdatedSamples);
    final updatedRepository = GestureRepositorySnapshot(
      samples: compatibleUpdatedSamples,
      gestures: updatedDefinitions,
      model: model,
    );
    await _storageService.saveRepository(updatedRepository);

    _state = _state.copyWith(
      statusMessage:
          'Saved "${draft.label}" with ${draft.capturedSamples.length} windows. Model retrained.',
      gestures: updatedDefinitions,
      model: model,
      clearDraft: true,
    );
    _emit();
  }

  Future<void> deleteGesture(String gestureId) async {
    final repository = await _storageService.loadRepository();
    final remainingSamples =
        repository.samples.where((sample) => sample.gestureId != gestureId).toList();
    final remainingGestures =
        repository.gestures.where((gesture) => gesture.id != gestureId).toList();

    final compatibleRemainingSamples = _compatibleSamples(remainingSamples);
    final model = compatibleRemainingSamples.isEmpty
        ? null
        : _trainer.train(compatibleRemainingSamples);
    final updatedRepository = GestureRepositorySnapshot(
      samples: compatibleRemainingSamples,
      gestures: remainingGestures,
      model: model,
    );
    await _storageService.saveRepository(updatedRepository);

    _state = _state.copyWith(
      gestures: remainingGestures,
      model: model,
      statusMessage: 'Gesture deleted and model retrained.',
      clearPrediction: true,
    );
    _emit();
  }

  Future<void> discardDraft() async {
    _state = _state.copyWith(
      statusMessage: 'Training draft discarded.',
      clearDraft: true,
      isRecording: false,
    );
    _emit();
  }

  Future<void> clearPrediction() async {
    _state = _state.copyWith(clearPrediction: true);
    _emit();
  }

  void dispose() {
    _bleSub?.cancel();
    _stateController.close();
  }

  Future<void> _runCountdown(Duration duration, {required String prefix}) async {
    for (var seconds = duration.inSeconds; seconds > 0; seconds--) {
      _state = _state.copyWith(
        isRecording: true,
        statusMessage: '$prefix in $seconds...',
      );
      _emit();
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  Future<List<List<double>>> _collectGestureWindowFrames({
    required Duration maxWindow,
    required int minimumFrames,
  }) async {
    final frames = <List<double>>[];
    final completer = Completer<List<List<double>>>();
    final startedAt = DateTime.now();

    void pushSnapshot(BleGloveSnapshot snapshot) {
      if (snapshot.leftData == null || snapshot.rightData == null) {
        return;
      }

      final frame = _featureExtractor.buildFrameVector(
        left: snapshot.leftData!,
        right: snapshot.rightData!,
      );
      frames.add(frame);

      final elapsed = DateTime.now().difference(startedAt);
      if (elapsed >= maxWindow && !completer.isCompleted) {
        completer.complete(List<List<double>>.from(frames));
      }
    }

    final current = _bleService.snapshot;
    if (current.leftData != null && current.rightData != null) {
      pushSnapshot(current);
    }

    final sub = _bleService.snapshots.listen(pushSnapshot);
    final timer = Timer(maxWindow + const Duration(milliseconds: 250), () {
      if (!completer.isCompleted) {
        completer.complete(List<List<double>>.from(frames));
      }
    });

    final result = await completer.future;
    await sub.cancel();
    timer.cancel();

    if (result.length < minimumFrames) {
      return result;
    }
    return result;
  }

  void _handleBleSnapshot(BleGloveSnapshot snapshot) {
    final model = _state.model;
    if (model == null || !snapshot.areBothConnected) {
      _inferenceFrames.clear();
      return;
    }
    if (snapshot.leftData == null || snapshot.rightData == null) {
      return;
    }

    final frame = _featureExtractor.buildFrameVector(
      left: snapshot.leftData!,
      right: snapshot.rightData!,
    );
    _inferenceFrames.add(frame);
    if (_inferenceFrames.length > 40) {
      _inferenceFrames.removeAt(0);
    }

    if (_state.isRecording || _inferenceFrames.length < 20) {
      return;
    }

    final now = DateTime.now();
    if (_lastPredictionAt != null &&
        now.difference(_lastPredictionAt!) < const Duration(milliseconds: 700)) {
      return;
    }

    final activeWindow = _featureExtractor.trimWindowByActivity(
      List<List<double>>.from(_inferenceFrames),
      minimumFrames: 18,
    );
    final featureVector = _featureExtractor.aggregateWindow(activeWindow);
    final prediction = _trainer.predict(model, featureVector);
    if (prediction == null) {
      return;
    }

    if (_lastPredictedGestureId == prediction.gestureId &&
        _lastPredictionAt != null &&
        now.difference(_lastPredictionAt!) < const Duration(seconds: 1)) {
      return;
    }

    _lastPredictionAt = now;
    _lastPredictedGestureId = prediction.gestureId;
    _state = _state.copyWith(
      latestPrediction: prediction,
      statusMessage:
          'Recognized "${prediction.label}" (${(prediction.confidence * 100).toStringAsFixed(0)}%).',
    );
    _emit();
  }

  void _setStatus(String message) {
    _state = _state.copyWith(statusMessage: message);
    _emit();
  }

  bool _isCalibrationReady() {
    return _calibrationService.getCalibration(leftGloveName).isComplete &&
        _calibrationService.getCalibration(rightGloveName).isComplete;
  }

  List<GestureTrainingSample> _compatibleSamples(
    List<GestureTrainingSample> samples,
  ) {
    return samples
        .where(
          (sample) =>
              sample.featureVector.length == _featureExtractor.aggregatedFeatureCount,
        )
        .toList();
  }

  void _emit() {
    if (!_stateController.isClosed) {
      _stateController.add(_state);
    }
  }
}

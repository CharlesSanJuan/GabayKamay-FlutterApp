import 'dart:async';
import 'dart:math';

import '../models/gesture_models.dart';
import 'app_settings_service.dart';
import 'ble_glove_service.dart';
import 'gesture_feature_extractor.dart';
import 'gesture_storage_service.dart';
import 'glove_calibration_service.dart';

abstract class GestureTrainer {
  GestureModelSnapshot train(List<GestureTrainingSample> samples);
  GesturePrediction? predict(
    GestureModelSnapshot model,
    List<double> featureVector,
    double decisionThreshold,
  );
}

class RandomForestGestureTrainer implements GestureTrainer {
  RandomForestGestureTrainer({
    this.treeCount = 21,
    this.maxDepth = 10,
    this.minSamplesSplit = 4,
    this.seed = 42,
  }) : _random = Random(seed);

  final int treeCount;
  final int maxDepth;
  final int minSamplesSplit;
  final int seed;
  final Random _random;

  @override
  GestureModelSnapshot train(List<GestureTrainingSample> samples) {
    if (samples.isEmpty) {
      return GestureModelSnapshot(
        trainerType: 'random_forest',
        featureLength: 0,
        decisionThreshold: 0.56,
        trainedAt: DateTime.now(),
        profiles: const [],
        trees: const [],
      );
    }

    final featureLength = samples.first.featureVector.length;
    final labels = <String>{
      for (final sample in samples) sample.gestureId,
    }.toList()
      ..sort();
    final maxFeatures = max(1, sqrt(featureLength).round());
    final profiles = <GestureModelProfile>[
      for (final gestureId in labels)
        GestureModelProfile(
          gestureId: gestureId,
          label: samples.firstWhere((sample) => sample.gestureId == gestureId).label,
          spokenText:
              samples.firstWhere((sample) => sample.gestureId == gestureId).spokenText,
          isDynamic:
              samples.firstWhere((sample) => sample.gestureId == gestureId).isDynamic,
        ),
    ];

    final trees = List<RandomForestTreeSnapshot>.generate(
      treeCount,
      (_) {
        final bootstrapped = List<GestureTrainingSample>.generate(
          samples.length,
          (_) => samples[_random.nextInt(samples.length)],
        );
        final root = _buildNode(
          bootstrapped,
          depth: 0,
          maxFeatures: maxFeatures,
          labels: labels,
        );
        return RandomForestTreeSnapshot(root: root);
      },
    );

    return GestureModelSnapshot(
      trainerType: 'random_forest',
      featureLength: featureLength,
      decisionThreshold: 0.56,
      trainedAt: DateTime.now(),
      profiles: profiles,
      trees: trees,
    );
  }

  @override
  GesturePrediction? predict(
    GestureModelSnapshot model,
    List<double> featureVector,
    double decisionThreshold,
  ) {
    if (!model.hasProfiles || featureVector.length != model.featureLength) {
      return null;
    }

    final probabilities = <String, double>{};
    for (final tree in model.trees) {
      final treeVote = _traverseTree(tree.root, featureVector);
      for (final entry in treeVote.entries) {
        probabilities[entry.key] = (probabilities[entry.key] ?? 0) + entry.value;
      }
    }

    if (probabilities.isEmpty) {
      return null;
    }

    final normalized = probabilities.map(
      (gestureId, score) => MapEntry(gestureId, score / model.trees.length),
    );
    final ranked = normalized.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (ranked.isEmpty) {
      return null;
    }

    final best = ranked.first;
    final second = ranked.length > 1 ? ranked[1].value : 0.0;
    final confidence = (best.value * 0.82) + ((best.value - second).clamp(0.0, 1.0) * 0.18);
    if (confidence < decisionThreshold) {
      return null;
    }

    GestureModelProfile? representative;
    for (final profile in model.profiles) {
      if (profile.gestureId == best.key) {
        representative = profile;
        break;
      }
    }
    if (representative == null) {
      return null;
    }

    return GesturePrediction(
      gestureId: representative.gestureId,
      label: representative.label,
      spokenText: representative.spokenText,
      confidence: confidence.clamp(0.0, 1.0),
      predictedAt: DateTime.now(),
    );
  }

  RandomForestNodeSnapshot _buildNode(
    List<GestureTrainingSample> samples, {
    required int depth,
    required int maxFeatures,
    required List<String> labels,
  }) {
    final labelCounts = _countLabels(samples);
    if (depth >= maxDepth || samples.length < minSamplesSplit || labelCounts.length == 1) {
      return RandomForestNodeSnapshot(
        isLeaf: true,
        featureIndex: -1,
        threshold: 0,
        probabilities: _normalizeCounts(labelCounts, labels),
      );
    }

    final featureIndices = List<int>.generate(
      samples.first.featureVector.length,
      (index) => index,
    )..shuffle(_random);

    double? bestGain;
    int? bestFeatureIndex;
    double? bestThreshold;
    List<GestureTrainingSample>? bestLeft;
    List<GestureTrainingSample>? bestRight;
    final parentImpurity = _gini(labelCounts, samples.length);

    for (final featureIndex in featureIndices.take(maxFeatures)) {
      final values = [
        for (final sample in samples) sample.featureVector[featureIndex],
      ]..sort();

      final thresholds = <double>[];
      for (var i = 1; i < values.length; i++) {
        if (values[i] != values[i - 1]) {
          thresholds.add((values[i] + values[i - 1]) / 2);
        }
      }
      thresholds.shuffle(_random);

      for (final threshold in thresholds.take(14)) {
        final left = <GestureTrainingSample>[];
        final right = <GestureTrainingSample>[];
        for (final sample in samples) {
          if (sample.featureVector[featureIndex] <= threshold) {
            left.add(sample);
          } else {
            right.add(sample);
          }
        }
        if (left.isEmpty || right.isEmpty) {
          continue;
        }

        final gain = parentImpurity -
            ((left.length / samples.length) * _gini(_countLabels(left), left.length)) -
            ((right.length / samples.length) * _gini(_countLabels(right), right.length));

        if (bestGain == null || gain > bestGain) {
          bestGain = gain;
          bestFeatureIndex = featureIndex;
          bestThreshold = threshold;
          bestLeft = left;
          bestRight = right;
        }
      }
    }

    if (bestGain == null ||
        bestFeatureIndex == null ||
        bestThreshold == null ||
        bestLeft == null ||
        bestRight == null ||
        bestGain <= 0) {
      return RandomForestNodeSnapshot(
        isLeaf: true,
        featureIndex: -1,
        threshold: 0,
        probabilities: _normalizeCounts(labelCounts, labels),
      );
    }

    return RandomForestNodeSnapshot(
      isLeaf: false,
      featureIndex: bestFeatureIndex,
      threshold: bestThreshold,
      probabilities: _normalizeCounts(labelCounts, labels),
      left: _buildNode(
        bestLeft,
        depth: depth + 1,
        maxFeatures: maxFeatures,
        labels: labels,
      ),
      right: _buildNode(
        bestRight,
        depth: depth + 1,
        maxFeatures: maxFeatures,
        labels: labels,
      ),
    );
  }

  Map<String, double> _traverseTree(
    RandomForestNodeSnapshot node,
    List<double> featureVector,
  ) {
    if (node.isLeaf || node.left == null || node.right == null || node.featureIndex < 0) {
      return node.probabilities;
    }

    if (featureVector[node.featureIndex] <= node.threshold) {
      return _traverseTree(node.left!, featureVector);
    }
    return _traverseTree(node.right!, featureVector);
  }

  Map<String, int> _countLabels(List<GestureTrainingSample> samples) {
    final counts = <String, int>{};
    for (final sample in samples) {
      counts[sample.gestureId] = (counts[sample.gestureId] ?? 0) + 1;
    }
    return counts;
  }

  Map<String, double> _normalizeCounts(
    Map<String, int> counts,
    List<String> labels,
  ) {
    final total = counts.values.fold<int>(0, (sum, value) => sum + value);
    return {
      for (final label in labels)
        label: total == 0 ? 0 : (counts[label] ?? 0) / total,
    };
  }

  double _gini(Map<String, int> counts, int total) {
    if (total == 0) {
      return 0;
    }
    var impurity = 1.0;
    for (final count in counts.values) {
      final probability = count / total;
      impurity -= probability * probability;
    }
    return impurity;
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
  final GestureTrainer _trainer = RandomForestGestureTrainer();
  final GloveCalibrationService _calibrationService = GloveCalibrationService();
  final AppSettingsService _settingsService = AppSettingsService();
  final StreamController<GestureRecognitionState> _stateController =
      StreamController<GestureRecognitionState>.broadcast();

  GestureRecognitionState _state = GestureRecognitionState.initial();
  StreamSubscription<BleGloveSnapshot>? _bleSub;
  DateTime? _lastPredictionAt;
  bool _initialized = false;
  final List<List<double>> _inferenceFrames = [];
  String? _lastCommittedGestureId;
  String? _lastCandidateGestureId;
  int _candidateCount = 0;

  Stream<GestureRecognitionState> get states => _stateController.stream;
  GestureRecognitionState get state => _state;

  Future<void> ensureInitialized() async {
    if (_initialized) {
      _emit();
      return;
    }

    _initialized = true;
    await _settingsService.ensureInitialized();
    final repository = await _storageService.loadRepository();
    final compatibleSamples = _compatibleSamples(repository.samples);
    final retrainedModel =
        compatibleSamples.isEmpty ? null : _trainer.train(compatibleSamples);

    _state = _state.copyWith(
      isReady: true,
      statusMessage: retrainedModel == null
          ? 'Ready. Connect gloves, calibrate, then collect training windows.'
          : 'Ready. ${repository.gestures.length} trained gestures loaded.',
      gestures: repository.gestures,
      model: retrainedModel,
    );

    if (compatibleSamples.length != repository.samples.length) {
      final cleaned = GestureRepositorySnapshot(
        samples: compatibleSamples,
        gestures: repository.gestures,
        model: retrainedModel,
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
    required bool isDynamic,
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
        isDynamic: isDynamic,
        targetSamples: max(1, targetSamples),
        capturedSamples: const [],
      ),
    );
    _emit();
  }

  Future<void> captureTrainingSample({
    Duration countdown = const Duration(seconds: 3),
    Duration? maxWindow,
    int? minimumFrames,
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
      captureProgress: 0,
      statusMessage:
          'Get ready for repetition ${draft.capturedCount + 1}. Capture starts soon.',
    );
    _emit();

    final settings = _settingsService.settings;
    final effectiveCountdown = countdown.inSeconds > 0
        ? countdown
        : Duration(seconds: settings.trainingCountdownSeconds);
    await _runCountdown(effectiveCountdown, prefix: 'Prepare gesture window');

    try {
      final effectiveWindow =
          maxWindow ?? Duration(milliseconds: draft.isDynamic ? 2200 : 900);
      final effectiveMinimumFrames = minimumFrames ?? (draft.isDynamic ? 24 : 12);
      final frames = await _collectGestureWindowFrames(
        maxWindow: effectiveWindow,
        minimumFrames: effectiveMinimumFrames,
      );
      if (!_featureExtractor.isPresentationActive(frames)) {
        _state = _state.copyWith(
          isRecording: false,
          captureProgress: 0,
          statusMessage:
              'Hands looked inactive during the capture window. Present the sign higher and try again.',
        );
        _emit();
        return;
      }

      final trimmedFrames = _featureExtractor.trimWindowByActivity(
        frames,
        minimumFrames: effectiveMinimumFrames,
      );
      final aggregated = _featureExtractor.aggregateWindow(trimmedFrames);

      if (aggregated.isEmpty) {
        _state = _state.copyWith(
          isRecording: false,
          captureProgress: 0,
          statusMessage: 'No BLE frames were captured. Try again.',
        );
        _emit();
        return;
      }

      final sample = GestureTrainingSample(
        gestureId: draft.gestureId,
        label: draft.label,
        spokenText: draft.spokenText,
        isDynamic: draft.isDynamic,
        featureVector: aggregated,
        createdAt: DateTime.now(),
      );

      final updatedDraft = draft.copyWith(
        capturedSamples: [...draft.capturedSamples, sample],
      );
      _state = _state.copyWith(
        isRecording: false,
        captureProgress: 1,
        activeDraft: updatedDraft,
        statusMessage: updatedDraft.isComplete
            ? 'Capture complete. Save and retrain the model.'
            : 'Captured window ${updatedDraft.capturedCount} of ${updatedDraft.targetSamples}. ${draft.isDynamic ? "Movement path recorded." : "Static sign recorded."}',
      );
      _emit();
    } catch (e) {
      _state = _state.copyWith(
        isRecording: false,
        captureProgress: 0,
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
              isDynamic: draft.isDynamic,
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
      captureProgress: 0,
      countdownValue: 0,
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
      captureProgress: 0,
      countdownValue: 0,
    );
    _emit();
  }

  Future<void> clearPrediction() async {
    _lastCommittedGestureId = null;
    _lastCandidateGestureId = null;
    _candidateCount = 0;
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
        countdownValue: seconds,
        captureProgress: 0,
        statusMessage: '$prefix in $seconds...',
      );
      _emit();
      await Future.delayed(const Duration(seconds: 1));
    }
    _state = _state.copyWith(countdownValue: 0);
    _emit();
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
      _state = _state.copyWith(
        captureProgress: (elapsed.inMilliseconds / maxWindow.inMilliseconds)
            .clamp(0.0, 1.0),
      );
      _emit();
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
    final settings = _settingsService.settings;

    if (_state.activeDraft != null && settings.muteTranslationWhileTraining) {
      _inferenceFrames.clear();
      if (_state.latestPrediction != null || _state.isPresentationActive) {
        _state = _state.copyWith(
          clearPrediction: true,
          isPresentationActive: false,
        );
        _emit();
      }
      return;
    }

    if (model == null || !snapshot.areBothConnected) {
      _inferenceFrames.clear();
      if (_state.latestPrediction != null || _state.isPresentationActive) {
        _state = _state.copyWith(
          clearPrediction: true,
          isPresentationActive: false,
        );
        _emit();
      }
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
    if (_inferenceFrames.length > 56) {
      _inferenceFrames.removeAt(0);
    }

    if (_state.isRecording || _inferenceFrames.length < 14) {
      return;
    }

    final now = DateTime.now();
    if (_lastPredictionAt != null &&
        now.difference(_lastPredictionAt!) < const Duration(milliseconds: 220)) {
      return;
    }

    final activeWindow = _featureExtractor.trimWindowByActivity(
      List<List<double>>.from(_inferenceFrames),
      minimumFrames: 12,
    );
    final presentationActive = _featureExtractor.isPresentationActive(
      List<List<double>>.from(_inferenceFrames),
      gyroThreshold: settings.presentationGyroThreshold,
      flexThreshold: settings.presentationFlexThreshold,
      accelerationThreshold: settings.presentationAccelerationThreshold,
      poseThreshold: settings.presentationPoseThreshold,
    );
    if (!presentationActive) {
      _lastPredictionAt = now;
      _lastCandidateGestureId = null;
      _candidateCount = 0;
      _lastCommittedGestureId = null;
      _state = _state.copyWith(
        clearPrediction: true,
        isPresentationActive: false,
        statusMessage: 'Hands inactive. Raise them to signing position to translate.',
      );
      _emit();
      return;
    }

    final featureVector = _featureExtractor.aggregateWindow(activeWindow);
    final prediction = _trainer.predict(
      model,
      featureVector,
      settings.confidenceThreshold,
    );
    if (prediction == null) {
      _lastPredictionAt = now;
      _lastCandidateGestureId = null;
      _candidateCount = 0;
      _lastCommittedGestureId = null;
      _state = _state.copyWith(
        isPresentationActive: true,
        clearPrediction: true,
        statusMessage: 'Watching for a confident sign...',
      );
      _emit();
      return;
    }

    final predictedProfile = _profileForGesture(model, prediction.gestureId);
    final isDynamicGesture = predictedProfile?.isDynamic ?? false;
    final hasDynamicMotion = _featureExtractor.hasDynamicMotion(
      activeWindow,
      threshold: settings.dynamicMotionThreshold,
    );
    if (isDynamicGesture && !hasDynamicMotion) {
      _lastPredictionAt = now;
      _lastCandidateGestureId = null;
      _candidateCount = 0;
      _state = _state.copyWith(
        isPresentationActive: true,
        clearPrediction: true,
        statusMessage: 'Matching handshape found, but the movement was too weak.',
      );
      _emit();
      return;
    }
    if (!isDynamicGesture &&
        hasDynamicMotion &&
        prediction.confidence < (settings.confidenceThreshold + 0.12)) {
      _lastPredictionAt = now;
      _lastCandidateGestureId = null;
      _candidateCount = 0;
      _state = _state.copyWith(
        isPresentationActive: true,
        clearPrediction: true,
        statusMessage: 'Movement detected. Waiting for a confident motion gesture.',
      );
      _emit();
      return;
    }

    _lastPredictionAt = now;
    if (_lastCandidateGestureId == prediction.gestureId) {
      _candidateCount += 1;
    } else {
      _lastCandidateGestureId = prediction.gestureId;
      _candidateCount = 1;
    }

    if (_candidateCount < 2) {
      _state = _state.copyWith(
        isPresentationActive: true,
        statusMessage:
            'Tracking "${prediction.label}"... ${(prediction.confidence * 100).toStringAsFixed(0)}%',
      );
      _emit();
      return;
    }

    if (_lastCommittedGestureId == prediction.gestureId) {
      _state = _state.copyWith(
        isPresentationActive: true,
        statusMessage:
            'Holding "${prediction.label}". Move to another sign before repeating.',
      );
      _emit();
      return;
    }

    _lastCommittedGestureId = prediction.gestureId;
    _state = _state.copyWith(
      isPresentationActive: true,
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

  GestureModelProfile? _profileForGesture(
    GestureModelSnapshot model,
    String gestureId,
  ) {
    for (final profile in model.profiles) {
      if (profile.gestureId == gestureId) {
        return profile;
      }
    }
    return null;
  }

  void _emit() {
    if (!_stateController.isClosed) {
      _stateController.add(_state);
    }
  }
}

import 'dart:async';
import 'dart:math';

import '../models/gesture_models.dart';
import 'app_settings_service.dart';
import 'ble_glove_service.dart';
import 'gesture_feature_extractor.dart';
import 'session_state_service.dart';
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

class RecognitionMetricRecord {
  final String gestureId;
  final String label;
  final double confidence;
  final double latencyMs;
  final double inferenceTimeMs;
  final DateTime recognizedAt;

  const RecognitionMetricRecord({
    required this.gestureId,
    required this.label,
    required this.confidence,
    required this.latencyMs,
    required this.inferenceTimeMs,
    required this.recognizedAt,
  });
}

class SaveDiagnosticsRecord {
  final String gestureLabel;
  final int draftSamples;
  final int totalSamplesAfterSave;
  final int trainedGestureCount;
  final int featureLength;
  final double loadRepositoryMs;
  final double samplePreparationMs;
  final double trainModelMs;
  final double writeRepositoryMs;
  final double totalSaveMs;
  final DateTime completedAt;

  const SaveDiagnosticsRecord({
    required this.gestureLabel,
    required this.draftSamples,
    required this.totalSamplesAfterSave,
    required this.trainedGestureCount,
    required this.featureLength,
    required this.loadRepositoryMs,
    required this.samplePreparationMs,
    required this.trainModelMs,
    required this.writeRepositoryMs,
    required this.totalSaveMs,
    required this.completedAt,
  });
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
    }.toList()..sort();
    final maxFeatures = max(1, sqrt(featureLength).round());
    final profiles = <GestureModelProfile>[];
    for (final gestureId in labels) {
      final representative = _representativeSample(samples, gestureId);
      if (representative == null) {
        continue;
      }
      profiles.add(
        GestureModelProfile(
          gestureId: representative.gestureId,
          label: representative.label,
          spokenText: representative.spokenText,
          isDynamic: representative.isDynamic,
          handUsage: representative.handUsage,
          expectedLeftFlexMean: _averageHandFlexMean(
            samples,
            gestureId: gestureId,
            handUsage: GestureHandUsage.leftOnly,
          ),
          expectedRightFlexMean: _averageHandFlexMean(
            samples,
            gestureId: gestureId,
            handUsage: GestureHandUsage.rightOnly,
          ),
        ),
      );
    }

    final trees = List<RandomForestTreeSnapshot>.generate(treeCount, (_) {
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
    });

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
        probabilities[entry.key] =
            (probabilities[entry.key] ?? 0) + entry.value;
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
    final confidence =
        (best.value * 0.82) + ((best.value - second).clamp(0.0, 1.0) * 0.18);
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
    if (depth >= maxDepth ||
        samples.length < minSamplesSplit ||
        labelCounts.length == 1) {
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

        final gain =
            parentImpurity -
            ((left.length / samples.length) *
                _gini(_countLabels(left), left.length)) -
            ((right.length / samples.length) *
                _gini(_countLabels(right), right.length));

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
    if (node.isLeaf ||
        node.left == null ||
        node.right == null ||
        node.featureIndex < 0) {
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

  GestureTrainingSample? _representativeSample(
    List<GestureTrainingSample> samples,
    String gestureId,
  ) {
    for (final sample in samples) {
      if (sample.gestureId == gestureId) {
        return sample;
      }
    }
    return null;
  }

  double _averageHandFlexMean(
    List<GestureTrainingSample> samples, {
    required String gestureId,
    required GestureHandUsage handUsage,
  }) {
    var total = 0.0;
    var count = 0;
    final startIndex = handUsage == GestureHandUsage.rightOnly ? 14 : 0;
    for (final sample in samples) {
      if (sample.gestureId != gestureId || sample.featureVector.length < 19) {
        continue;
      }
      var handTotal = 0.0;
      for (var i = 0; i < 5; i++) {
        handTotal += sample.featureVector[startIndex + i];
      }
      total += handTotal / 5.0;
      count += 1;
    }
    if (count == 0) {
      return 0.0;
    }
    return total / count;
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
  final SessionStateService _sessionStateService = SessionStateService();
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
  int _captureOperationId = 0;
  double? _latestLatencyMs;
  double? _latestInferenceTimeMs;
  final List<RecognitionMetricRecord> _recognitionHistory = [];
  bool _isSavingDraft = false;
  SaveDiagnosticsRecord? _lastSaveDiagnostics;

  Stream<GestureRecognitionState> get states => _stateController.stream;
  GestureRecognitionState get state => _state;
  double? get latestLatencyMs => _latestLatencyMs;
  double? get latestInferenceTimeMs => _latestInferenceTimeMs;
  List<RecognitionMetricRecord> get recognitionHistory =>
      List.unmodifiable(_recognitionHistory);
  bool get isSavingDraft => _isSavingDraft;
  SaveDiagnosticsRecord? get lastSaveDiagnostics => _lastSaveDiagnostics;

  Future<void> reloadRepository() async {
    await ensureInitialized();
    await _loadRepositoryIntoState();
  }

  Future<void> importRepositoryFromEncodedJson(String encoded) async {
    final imported = GestureRepositorySnapshot.fromEncodedJson(encoded);
    await _storageService.saveRepository(imported);
    await reloadRepository();
  }

  Future<void> toggleGestureEnabled(String gestureId, bool enabled) async {
    await ensureInitialized();
    final settings = _settingsService.settings;
    final disabledGestureIds = settings.disabledGestureIds.toSet();
    if (enabled) {
      disabledGestureIds.remove(gestureId);
    } else {
      disabledGestureIds.add(gestureId);
    }
    await _settingsService.save(
      settings.copyWith(disabledGestureIds: disabledGestureIds.toList()..sort()),
    );
    await _loadRepositoryIntoState();
    _state = _state.copyWith(
      statusMessage: enabled
          ? 'Gesture enabled for inference.'
          : 'Gesture disabled for inference.',
    );
    _emit();
  }

  Future<void> ensureInitialized() async {
    if (_initialized) {
      _emit();
      return;
    }

    _initialized = true;
    await _settingsService.ensureInitialized();
    await _sessionStateService.ensureInitialized();
    await _loadRepositoryIntoState();

    await _bleService.ensureInitialized();
    _bleSub = _bleService.snapshots.listen(_handleBleSnapshot);
    _emit();
  }

  Future<void> startTrainingDraft({
    required String label,
    required String spokenText,
    required bool isDynamic,
    required GestureHandUsage handUsage,
    int targetSamples = 5,
  }) async {
    await ensureInitialized();
    if (!_isCalibrationReady()) {
      _setStatus(
        'Calibration must be completed for both gloves before training.',
      );
      return;
    }

    final trimmedLabel = label.trim();
    final trimmedSpokenText = spokenText.trim().isEmpty
        ? trimmedLabel
        : spokenText.trim();
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
        handUsage: handUsage,
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

    final operationId = ++_captureOperationId;
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
    final countdownCompleted = await _runCountdown(
      effectiveCountdown,
      prefix: 'Prepare gesture window',
      operationId: operationId,
    );
    if (!countdownCompleted ||
        !_isCaptureOperationActive(operationId, draft.gestureId)) {
      return;
    }

    try {
      final effectiveWindow =
          maxWindow ?? Duration(milliseconds: draft.isDynamic ? 2200 : 900);
      final effectiveMinimumFrames =
          minimumFrames ?? (draft.isDynamic ? 24 : 12);
      final frames = await _collectGestureWindowFrames(
        maxWindow: effectiveWindow,
        minimumFrames: effectiveMinimumFrames,
        operationId: operationId,
        draftGestureId: draft.gestureId,
      );
      if (!_isCaptureOperationActive(operationId, draft.gestureId)) {
        return;
      }
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
      final observedHandUsage = _featureExtractor.inferDominantHandUsage(
        trimmedFrames,
      );
      if (!_handUsageMatchesExpectation(draft.handUsage, observedHandUsage)) {
        _state = _state.copyWith(
          isRecording: false,
          captureProgress: 0,
          statusMessage:
              'Capture looked like ${observedHandUsage.displayLabel.toLowerCase()}, but this gesture is set to ${draft.handUsage.displayLabel.toLowerCase()}. Keep the inactive glove neutral and try again.',
        );
        _emit();
        return;
      }

      final maskedFrames = _featureExtractor.applyHandUsageMask(
        trimmedFrames,
        handUsage: draft.handUsage,
      );
      final aggregated = _featureExtractor.aggregateWindow(maskedFrames);

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
        handUsage: draft.handUsage,
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
    if (_isSavingDraft) {
      _setStatus('Save already in progress. Please wait.');
      return;
    }
    final draft = _state.activeDraft;
    if (draft == null) {
      _setStatus('Nothing to save yet.');
      return;
    }
    if (draft.capturedSamples.isEmpty) {
      _setStatus('Capture at least one training window before saving.');
      return;
    }

    _isSavingDraft = true;
    _lastSaveDiagnostics = null;
    _state = _state.copyWith(
      statusMessage: 'Saving "${draft.label}" and retraining model...',
    );
    _emit();

    try {
      final totalStopwatch = Stopwatch()..start();
      final loadStopwatch = Stopwatch()..start();
      final repository = await _storageService.loadRepository();
      loadStopwatch.stop();

      final samplePrepStopwatch = Stopwatch()..start();
      final compatibleExistingSamples = _compatibleSamples(repository.samples);
      final retainedSamples = compatibleExistingSamples
          .where((sample) => sample.gestureId != draft.gestureId)
          .toList();
      final updatedSamples = [...retainedSamples, ...draft.capturedSamples];
      final compatibleUpdatedSamples = _compatibleSamples(updatedSamples);

      final updatedDefinitions =
          repository.gestures
              .where((gesture) => gesture.id != draft.gestureId)
              .toList()
            ..add(
              GestureDefinition(
                id: draft.gestureId,
                label: draft.label,
                spokenText: draft.spokenText,
                isDynamic: draft.isDynamic,
                handUsage: draft.handUsage,
                sampleCount: draft.capturedSamples.length,
                updatedAt: DateTime.now(),
              ),
            );
      samplePrepStopwatch.stop();

      final trainStopwatch = Stopwatch()..start();
      final model = _trainModelForCurrentSettings(compatibleUpdatedSamples);
      trainStopwatch.stop();
      final updatedRepository = GestureRepositorySnapshot(
        samples: compatibleUpdatedSamples,
        gestures: updatedDefinitions,
        model: model,
      );

      final writeStopwatch = Stopwatch()..start();
      await _storageService.saveRepository(updatedRepository);
      writeStopwatch.stop();
      totalStopwatch.stop();

      _lastSaveDiagnostics = SaveDiagnosticsRecord(
        gestureLabel: draft.label,
        draftSamples: draft.capturedSamples.length,
        totalSamplesAfterSave: compatibleUpdatedSamples.length,
        trainedGestureCount: updatedDefinitions.length,
        featureLength: compatibleUpdatedSamples.isEmpty
            ? 0
            : compatibleUpdatedSamples.first.featureVector.length,
        loadRepositoryMs: loadStopwatch.elapsedMicroseconds / 1000.0,
        samplePreparationMs: samplePrepStopwatch.elapsedMicroseconds / 1000.0,
        trainModelMs: trainStopwatch.elapsedMicroseconds / 1000.0,
        writeRepositoryMs: writeStopwatch.elapsedMicroseconds / 1000.0,
        totalSaveMs: totalStopwatch.elapsedMicroseconds / 1000.0,
        completedAt: DateTime.now(),
      );

      _state = _state.copyWith(
        statusMessage:
            'Saved "${draft.label}" with ${draft.capturedSamples.length} windows. Model retrained in ${_lastSaveDiagnostics!.totalSaveMs.toStringAsFixed(0)} ms.',
        gestures: updatedDefinitions,
        model: model,
        clearDraft: true,
        captureProgress: 0,
        countdownValue: 0,
      );
      _emit();
    } catch (e) {
      _state = _state.copyWith(
        statusMessage: 'Save failed: $e',
      );
      _emit();
    } finally {
      _isSavingDraft = false;
    }
  }

  Future<void> deleteGesture(String gestureId) async {
    final repository = await _storageService.loadRepository();
    final remainingSamples = repository.samples
        .where((sample) => sample.gestureId != gestureId)
        .toList();
    final remainingGestures = repository.gestures
        .where((gesture) => gesture.id != gestureId)
        .toList();

    final compatibleRemainingSamples = _compatibleSamples(remainingSamples);
    final model = _trainModelForCurrentSettings(compatibleRemainingSamples);
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

  Future<void> updateGestureDetails({
    required String gestureId,
    required String label,
    required String spokenText,
  }) async {
    final trimmedLabel = label.trim();
    final trimmedSpokenText = spokenText.trim().isEmpty
        ? trimmedLabel
        : spokenText.trim();
    if (trimmedLabel.isEmpty) {
      _setStatus('Gesture label cannot be empty.');
      return;
    }

    final repository = await _storageService.loadRepository();
    final updatedSamples = repository.samples
        .map(
          (sample) => sample.gestureId != gestureId
              ? sample
              : GestureTrainingSample(
                  gestureId: sample.gestureId,
                  label: trimmedLabel,
                  spokenText: trimmedSpokenText,
                  isDynamic: sample.isDynamic,
                  handUsage: sample.handUsage,
                  featureVector: sample.featureVector,
                  createdAt: sample.createdAt,
                ),
        )
        .toList();

    final updatedGestures = repository.gestures
        .map(
          (gesture) => gesture.id != gestureId
              ? gesture
              : GestureDefinition(
                  id: gesture.id,
                  label: trimmedLabel,
                  spokenText: trimmedSpokenText,
                  isDynamic: gesture.isDynamic,
                  handUsage: gesture.handUsage,
                  sampleCount: gesture.sampleCount,
                  updatedAt: DateTime.now(),
                ),
        )
        .toList();

    final compatibleUpdatedSamples = _compatibleSamples(updatedSamples);
    final model = _trainModelForCurrentSettings(compatibleUpdatedSamples);

    final updatedRepository = GestureRepositorySnapshot(
      samples: updatedSamples,
      gestures: updatedGestures,
      model: model,
    );
    await _storageService.saveRepository(updatedRepository);

    final currentPrediction = _state.latestPrediction;
    final updatedPrediction =
        currentPrediction == null || currentPrediction.gestureId != gestureId
        ? currentPrediction
        : GesturePrediction(
            gestureId: currentPrediction.gestureId,
            label: trimmedLabel,
            spokenText: trimmedSpokenText,
            confidence: currentPrediction.confidence,
            predictedAt: currentPrediction.predictedAt,
          );

    _state = _state.copyWith(
      gestures: updatedGestures,
      model: model,
      latestPrediction: updatedPrediction,
      statusMessage: 'Updated "$trimmedLabel".',
    );
    _emit();
  }

  Future<void> discardDraft() async {
    _captureOperationId += 1;
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

  Future<void> _loadRepositoryIntoState() async {
    final repository = await _storageService.loadRepository();
    final compatibleSamples = _compatibleSamples(repository.samples);
    final retrainedModel = _trainModelForCurrentSettings(compatibleSamples);

    _lastPredictionAt = null;
    _lastCommittedGestureId = null;
    _lastCandidateGestureId = null;
    _candidateCount = 0;
    _latestLatencyMs = null;
    _latestInferenceTimeMs = null;
    _recognitionHistory.clear();
    _inferenceFrames.clear();

    final restoredDraft = _sessionStateService.snapshot.activeDraft;

    _state = _state.copyWith(
      isReady: true,
      statusMessage: restoredDraft != null
          ? 'Restored unsaved training draft after reopening the app.'
          : retrainedModel == null
          ? 'Ready. Connect gloves, calibrate, then collect training windows.'
          : 'Ready. ${repository.gestures.length} trained gestures loaded.',
      gestures: repository.gestures,
      model: retrainedModel,
      activeDraft: restoredDraft,
      clearPrediction: true,
      isPresentationActive: false,
      captureProgress: 0,
      countdownValue: 0,
    );

    if (compatibleSamples.length != repository.samples.length) {
      final cleaned = GestureRepositorySnapshot(
        samples: compatibleSamples,
        gestures: repository.gestures,
        model: retrainedModel,
      );
      await _storageService.saveRepository(cleaned);
    }
  }

  void dispose() {
    _bleSub?.cancel();
    _stateController.close();
  }

  Future<bool> _runCountdown(
    Duration duration, {
    required String prefix,
    required int operationId,
  }) async {
    for (var seconds = duration.inSeconds; seconds > 0; seconds--) {
      if (!_isCaptureOperationActive(
        operationId,
        _state.activeDraft?.gestureId,
      )) {
        return false;
      }
      _state = _state.copyWith(
        isRecording: true,
        countdownValue: seconds,
        captureProgress: 0,
        statusMessage: '$prefix in $seconds...',
      );
      _emit();
      await Future.delayed(const Duration(seconds: 1));
    }
    if (!_isCaptureOperationActive(
      operationId,
      _state.activeDraft?.gestureId,
    )) {
      return false;
    }
    _state = _state.copyWith(countdownValue: 0);
    _emit();
    return true;
  }

  Future<List<List<double>>> _collectGestureWindowFrames({
    required Duration maxWindow,
    required int minimumFrames,
    required int operationId,
    required String draftGestureId,
  }) async {
    final frames = <List<double>>[];
    final completer = Completer<List<List<double>>>();
    final startedAt = DateTime.now();

    void pushSnapshot(BleGloveSnapshot snapshot) {
      if (!_isCaptureOperationActive(operationId, draftGestureId)) {
        if (!completer.isCompleted) {
          completer.complete(List<List<double>>.from(frames));
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
    if (_isCaptureOperationActive(operationId, draftGestureId) &&
        current.leftData != null &&
        current.rightData != null) {
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
        now.difference(_lastPredictionAt!) <
            const Duration(milliseconds: 220)) {
      return;
    }

    final activeWindow = _featureExtractor.trimWindowByActivity(
      List<List<double>>.from(_inferenceFrames),
      minimumFrames: 12,
    );
    final detectedHandUsage = _featureExtractor.inferDominantHandUsage(
      activeWindow,
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
        statusMessage:
            'Hands inactive. Raise them to signing position to translate.',
      );
      _emit();
      return;
    }

    final inferenceStopwatch = Stopwatch()..start();
    final maskedWindow = _featureExtractor.applyHandUsageMask(
      activeWindow,
      handUsage: detectedHandUsage,
    );
    final featureVector = _featureExtractor.aggregateWindow(maskedWindow);
    final rawFeatureVector = _featureExtractor.aggregateWindow(activeWindow);
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
    if (predictedProfile != null &&
        !_handUsageMatchesExpectation(
          predictedProfile.handUsage,
          detectedHandUsage,
        )) {
      _lastPredictionAt = now;
      _lastCandidateGestureId = null;
      _candidateCount = 0;
      _state = _state.copyWith(
        isPresentationActive: true,
        clearPrediction: true,
        statusMessage:
            'Rejected "${prediction.label}" because the live hand usage looked like ${detectedHandUsage.displayLabel.toLowerCase()}.',
      );
      _emit();
      return;
    }
    if (predictedProfile != null &&
        !_passesFlexSanityCheck(predictedProfile, rawFeatureVector)) {
      _lastPredictionAt = now;
      _lastCandidateGestureId = null;
      _candidateCount = 0;
      _state = _state.copyWith(
        isPresentationActive: true,
        clearPrediction: true,
        statusMessage:
            'Rejected "${prediction.label}" because the finger closure did not match the trained handshape yet.',
      );
      _emit();
      return;
    }
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
        statusMessage:
            'Matching handshape found, but the movement was too weak.',
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
        statusMessage:
            'Movement detected. Waiting for a confident motion gesture.',
      );
      _emit();
      return;
    }

    inferenceStopwatch.stop();
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
    final synchronizedInputAt =
        snapshot.leftLastPacketAt == null || snapshot.rightLastPacketAt == null
        ? null
        : snapshot.leftLastPacketAt!.isBefore(snapshot.rightLastPacketAt!)
        ? snapshot.leftLastPacketAt!
        : snapshot.rightLastPacketAt!;
    final latencyMs = synchronizedInputAt == null
        ? null
        : prediction.predictedAt
                  .difference(synchronizedInputAt)
                  .inMicroseconds /
              1000.0;
    _latestLatencyMs = latencyMs == null ? null : max(0.0, latencyMs);
    _latestInferenceTimeMs = inferenceStopwatch.elapsedMicroseconds / 1000.0;
    _recognitionHistory.insert(
      0,
      RecognitionMetricRecord(
        gestureId: prediction.gestureId,
        label: prediction.label,
        confidence: prediction.confidence,
        latencyMs: _latestLatencyMs ?? 0.0,
        inferenceTimeMs: _latestInferenceTimeMs ?? 0.0,
        recognizedAt: prediction.predictedAt,
      ),
    );
    if (_recognitionHistory.length > 25) {
      _recognitionHistory.removeRange(25, _recognitionHistory.length);
    }
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
              sample.featureVector.length ==
              _featureExtractor.aggregatedFeatureCount,
        )
        .toList();
  }

  GestureModelSnapshot? _trainModelForCurrentSettings(
    List<GestureTrainingSample> compatibleSamples,
  ) {
    final disabledGestureIds = _settingsService.settings.disabledGestureIds.toSet();
    final enabledSamples = compatibleSamples
        .where((sample) => !disabledGestureIds.contains(sample.gestureId))
        .toList();
    if (enabledSamples.isEmpty) {
      return null;
    }
    return _trainer.train(enabledSamples);
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

  bool _isCaptureOperationActive(int operationId, String? draftGestureId) {
    final currentDraft = _state.activeDraft;
    if (operationId != _captureOperationId) {
      return false;
    }
    if (currentDraft == null) {
      return false;
    }
    if (draftGestureId != null && currentDraft.gestureId != draftGestureId) {
      return false;
    }
    return true;
  }

  void _emit() {
    if (!_stateController.isClosed) {
      _stateController.add(_state);
    }
    final activeDraft = _state.activeDraft;
    final lightweightDraft = activeDraft == null
        ? null
        : TrainingDraft(
            gestureId: activeDraft.gestureId,
            label: activeDraft.label,
            spokenText: activeDraft.spokenText,
            isDynamic: activeDraft.isDynamic,
            handUsage: activeDraft.handUsage,
            targetSamples: activeDraft.targetSamples,
            capturedSamples: const [],
          );
    unawaited(
      _sessionStateService.save(
        _sessionStateService.snapshot.copyWith(
          activeDraft: lightweightDraft,
          clearActiveDraft: lightweightDraft == null,
        ),
      ),
    );
  }

  bool _handUsageMatchesExpectation(
    GestureHandUsage expected,
    GestureHandUsage observed,
  ) {
    if (expected == GestureHandUsage.bothHands) {
      return observed == GestureHandUsage.bothHands;
    }
    return expected == observed;
  }

  bool _passesFlexSanityCheck(
    GestureModelProfile profile,
    List<double> rawFeatureVector,
  ) {
    if (rawFeatureVector.length < 19) {
      return true;
    }

    final leftFlexMean = _mean(rawFeatureVector.sublist(0, 5));
    final rightFlexMean = _mean(rawFeatureVector.sublist(14, 19));
    const activeTolerance = 22.0;
    const inactiveTolerance = 18.0;

    switch (profile.handUsage) {
      case GestureHandUsage.leftOnly:
        return (leftFlexMean - profile.expectedLeftFlexMean).abs() <=
                activeTolerance &&
            rightFlexMean <= profile.expectedRightFlexMean + inactiveTolerance;
      case GestureHandUsage.rightOnly:
        return (rightFlexMean - profile.expectedRightFlexMean).abs() <=
                activeTolerance &&
            leftFlexMean <= profile.expectedLeftFlexMean + inactiveTolerance;
      case GestureHandUsage.bothHands:
        return (leftFlexMean - profile.expectedLeftFlexMean).abs() <=
                activeTolerance &&
            (rightFlexMean - profile.expectedRightFlexMean).abs() <=
                activeTolerance;
    }
  }

  double _mean(List<double> values) {
    if (values.isEmpty) {
      return 0.0;
    }
    var total = 0.0;
    for (final value in values) {
      total += value;
    }
    return total / values.length;
  }
}

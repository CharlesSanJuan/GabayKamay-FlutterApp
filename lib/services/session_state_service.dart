import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/gesture_models.dart';

class AppSessionSnapshot {
  final int homeTabIndex;
  final String trainingLabel;
  final String trainingSpokenText;
  final int trainingTargetSamples;
  final bool trainingIsDynamic;
  final GestureHandUsage trainingHandUsage;
  final TrainingDraft? activeDraft;

  const AppSessionSnapshot({
    required this.homeTabIndex,
    required this.trainingLabel,
    required this.trainingSpokenText,
    required this.trainingTargetSamples,
    required this.trainingIsDynamic,
    required this.trainingHandUsage,
    required this.activeDraft,
  });

  factory AppSessionSnapshot.defaults() {
    return const AppSessionSnapshot(
      homeTabIndex: 1,
      trainingLabel: '',
      trainingSpokenText: '',
      trainingTargetSamples: 10,
      trainingIsDynamic: false,
      trainingHandUsage: GestureHandUsage.bothHands,
      activeDraft: null,
    );
  }

  AppSessionSnapshot copyWith({
    int? homeTabIndex,
    String? trainingLabel,
    String? trainingSpokenText,
    int? trainingTargetSamples,
    bool? trainingIsDynamic,
    GestureHandUsage? trainingHandUsage,
    TrainingDraft? activeDraft,
    bool clearActiveDraft = false,
  }) {
    return AppSessionSnapshot(
      homeTabIndex: homeTabIndex ?? this.homeTabIndex,
      trainingLabel: trainingLabel ?? this.trainingLabel,
      trainingSpokenText: trainingSpokenText ?? this.trainingSpokenText,
      trainingTargetSamples:
          trainingTargetSamples ?? this.trainingTargetSamples,
      trainingIsDynamic: trainingIsDynamic ?? this.trainingIsDynamic,
      trainingHandUsage: trainingHandUsage ?? this.trainingHandUsage,
      activeDraft: clearActiveDraft ? null : (activeDraft ?? this.activeDraft),
    );
  }

  Map<String, dynamic> toJson() => {
    'homeTabIndex': homeTabIndex,
    'trainingLabel': trainingLabel,
    'trainingSpokenText': trainingSpokenText,
    'trainingTargetSamples': trainingTargetSamples,
    'trainingIsDynamic': trainingIsDynamic,
    'trainingHandUsage': trainingHandUsage.storageValue,
    'activeDraft': activeDraft == null ? null : _draftToJson(activeDraft!),
  };

  factory AppSessionSnapshot.fromJson(Map<String, dynamic> json) {
    final defaults = AppSessionSnapshot.defaults();
    return AppSessionSnapshot(
      homeTabIndex: json['homeTabIndex'] as int? ?? defaults.homeTabIndex,
      trainingLabel: json['trainingLabel'] as String? ?? defaults.trainingLabel,
      trainingSpokenText:
          json['trainingSpokenText'] as String? ?? defaults.trainingSpokenText,
      trainingTargetSamples:
          json['trainingTargetSamples'] as int? ??
          defaults.trainingTargetSamples,
      trainingIsDynamic:
          json['trainingIsDynamic'] as bool? ?? defaults.trainingIsDynamic,
      trainingHandUsage: GestureHandUsage.fromStorageValue(
        json['trainingHandUsage'] as String?,
      ),
      activeDraft: json['activeDraft'] == null
          ? null
          : _draftFromJson(json['activeDraft'] as Map<String, dynamic>),
    );
  }

  static Map<String, dynamic> _draftToJson(TrainingDraft draft) => {
    'gestureId': draft.gestureId,
    'label': draft.label,
    'spokenText': draft.spokenText,
    'isDynamic': draft.isDynamic,
    'handUsage': draft.handUsage.storageValue,
    'targetSamples': draft.targetSamples,
    'capturedSamples': draft.capturedSamples
        .map((sample) => sample.toJson())
        .toList(),
  };

  static TrainingDraft _draftFromJson(Map<String, dynamic> json) {
    return TrainingDraft(
      gestureId: json['gestureId'] as String,
      label: json['label'] as String,
      spokenText: json['spokenText'] as String,
      isDynamic: json['isDynamic'] as bool? ?? false,
      handUsage: GestureHandUsage.fromStorageValue(
        json['handUsage'] as String?,
      ),
      targetSamples: json['targetSamples'] as int? ?? 1,
      capturedSamples: (json['capturedSamples'] as List<dynamic>? ?? const [])
          .map(
            (item) =>
                GestureTrainingSample.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class SessionStateService {
  static const _storageKey = 'app_session_state_v1';
  static final SessionStateService _instance = SessionStateService._internal();

  factory SessionStateService() => _instance;
  SessionStateService._internal();

  final StreamController<AppSessionSnapshot> _controller =
      StreamController<AppSessionSnapshot>.broadcast();

  AppSessionSnapshot _snapshot = AppSessionSnapshot.defaults();
  bool _initialized = false;

  AppSessionSnapshot get snapshot => _snapshot;
  Stream<AppSessionSnapshot> get changes => _controller.stream;

  Future<void> ensureInitialized() async {
    if (_initialized) {
      return;
    }
    _initialized = true;

    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_storageKey);
    if (encoded == null || encoded.isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;
      _snapshot = AppSessionSnapshot.fromJson(decoded);
    } catch (_) {
      _snapshot = AppSessionSnapshot.defaults();
    }
  }

  Future<void> save(AppSessionSnapshot snapshot) async {
    await ensureInitialized();
    _snapshot = snapshot;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(snapshot.toJson()));
    if (!_controller.isClosed) {
      _controller.add(_snapshot);
    }
  }
}

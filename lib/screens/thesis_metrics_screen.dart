import 'dart:async';

import 'package:flutter/material.dart';

import '../models/gesture_models.dart';
import '../services/ble_glove_service.dart';
import '../services/gesture_recognition_service.dart';

class ThesisMetricsScreen extends StatefulWidget {
  const ThesisMetricsScreen({super.key});

  @override
  State<ThesisMetricsScreen> createState() => _ThesisMetricsScreenState();
}

class _ThesisMetricsScreenState extends State<ThesisMetricsScreen> {
  final BleGloveService _bleService = BleGloveService();
  final GestureRecognitionService _gestureService = GestureRecognitionService();

  StreamSubscription<GestureRecognitionState>? _recognitionSub;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _bleService.ensureInitialized();
    _gestureService.ensureInitialized();
    _recognitionSub = _gestureService.states.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _recognitionSub?.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<BleGloveSnapshot>(
      stream: _bleService.snapshots,
      initialData: _bleService.snapshot,
      builder: (context, snapshot) {
        final bleState = snapshot.data ?? _bleService.snapshot;
        final recognitionState = _gestureService.state;
        final latestPrediction = recognitionState.latestPrediction;
        final latestLatencyMs = _gestureService.latestLatencyMs;
        final latestInferenceTimeMs = _gestureService.latestInferenceTimeMs;
        final recognitionHistory = _gestureService.recognitionHistory;
        final saveDiagnostics = _gestureService.lastSaveDiagnostics;
        final uptime = bleState.bothConnectedSince == null
            ? 'Not connected'
            : _formatDuration(
                DateTime.now().difference(bleState.bothConnectedSince!),
              );

        return Scaffold(
          appBar: AppBar(
            title: const Text('Thesis Metrics'),
            actions: [
              IconButton(
                icon: const Icon(Icons.restart_alt),
                tooltip: 'Reset Session Metrics',
                onPressed: () {
                  _bleService.resetSessionMetrics();
                },
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _MetricSection(
                title: 'BLE Stability',
                children: [
                  _MetricRow(
                    label: 'Both gloves connected',
                    value: bleState.areBothConnected ? 'Yes' : 'No',
                  ),
                  _MetricRow(label: 'Connected uptime', value: uptime),
                  _MetricRow(
                    label: 'Left disconnect count',
                    value: bleState.leftDisconnectCount.toString(),
                  ),
                  _MetricRow(
                    label: 'Right disconnect count',
                    value: bleState.rightDisconnectCount.toString(),
                  ),
                  _MetricRow(
                    label: 'Packet gap',
                    value: '${bleState.packetGap} packets',
                  ),
                  _MetricRow(
                    label: 'Packet balance',
                    value: _packetBalanceLabel(bleState),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _MetricSection(
                title: 'Packet Throughput',
                children: [
                  _MetricRow(
                    label: 'Left total packets',
                    value: bleState.leftPacketCount.toString(),
                  ),
                  _MetricRow(
                    label: 'Right total packets',
                    value: bleState.rightPacketCount.toString(),
                  ),
                  _MetricRow(
                    label: 'Left packet rate',
                    value: '${bleState.leftPacketRateHz.toStringAsFixed(1)} Hz',
                  ),
                  _MetricRow(
                    label: 'Right packet rate',
                    value:
                        '${bleState.rightPacketRateHz.toStringAsFixed(1)} Hz',
                  ),
                  _MetricRow(
                    label: 'Left avg interval',
                    value:
                        '${bleState.leftAverageIntervalMs.toStringAsFixed(1)} ms',
                  ),
                  _MetricRow(
                    label: 'Right avg interval',
                    value:
                        '${bleState.rightAverageIntervalMs.toStringAsFixed(1)} ms',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _MetricSection(
                title: 'Recognition Snapshot',
                children: [
                  _MetricRow(
                    label: 'Model loaded',
                    value: recognitionState.model == null ? 'No' : 'Yes',
                  ),
                  _MetricRow(
                    label: 'Trained gestures',
                    value: recognitionState.gestures.length.toString(),
                  ),
                  _MetricRow(
                    label: 'Presentation active',
                    value: recognitionState.isPresentationActive ? 'Yes' : 'No',
                  ),
                  _MetricRow(
                    label: 'Latest label',
                    value: latestPrediction?.label ?? 'None',
                  ),
                  _MetricRow(
                    label: 'Latest confidence',
                    value: latestPrediction == null
                        ? 'N/A'
                        : '${(latestPrediction.confidence * 100).toStringAsFixed(1)}%',
                  ),
                  _MetricRow(
                    label: 'Estimated latency',
                    value: latestLatencyMs == null
                        ? 'N/A'
                        : '${latestLatencyMs.toStringAsFixed(1)} ms',
                  ),
                  _MetricRow(
                    label: 'Inference time',
                    value: latestInferenceTimeMs == null
                        ? 'N/A'
                        : '${latestInferenceTimeMs.toStringAsFixed(1)} ms',
                  ),
                  _MetricRow(
                    label: 'Status',
                    value: recognitionState.statusMessage,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _MetricSection(
                title: 'Recognition History',
                children: recognitionHistory.isEmpty
                    ? const [
                        Text('No recognized gestures yet for this session.'),
                      ]
                    : [
                        for (final record in recognitionHistory)
                          _RecognitionHistoryTile(record: record),
                      ],
              ),
              const SizedBox(height: 12),
              _MetricSection(
                title: 'Training Save Diagnostics',
                children: saveDiagnostics == null
                    ? const [
                        Text('No training save diagnostics recorded yet.'),
                      ]
                    : [
                        _MetricRow(
                          label: 'Gesture',
                          value: saveDiagnostics.gestureLabel,
                        ),
                        _MetricRow(
                          label: 'Draft samples',
                          value: saveDiagnostics.draftSamples.toString(),
                        ),
                        _MetricRow(
                          label: 'Total samples',
                          value: saveDiagnostics.totalSamplesAfterSave.toString(),
                        ),
                        _MetricRow(
                          label: 'Trained gestures',
                          value: saveDiagnostics.trainedGestureCount.toString(),
                        ),
                        _MetricRow(
                          label: 'Feature length',
                          value: saveDiagnostics.featureLength.toString(),
                        ),
                        _MetricRow(
                          label: 'Load repository',
                          value:
                              '${saveDiagnostics.loadRepositoryMs.toStringAsFixed(1)} ms',
                        ),
                        _MetricRow(
                          label: 'Sample preparation',
                          value:
                              '${saveDiagnostics.samplePreparationMs.toStringAsFixed(1)} ms',
                        ),
                        _MetricRow(
                          label: 'Train model',
                          value:
                              '${saveDiagnostics.trainModelMs.toStringAsFixed(1)} ms',
                        ),
                        _MetricRow(
                          label: 'Write repository',
                          value:
                              '${saveDiagnostics.writeRepositoryMs.toStringAsFixed(1)} ms',
                        ),
                        _MetricRow(
                          label: 'Total save',
                          value:
                              '${saveDiagnostics.totalSaveMs.toStringAsFixed(1)} ms',
                        ),
                      ],
              ),
              const SizedBox(height: 12),
              _MetricSection(
                title: 'Notes For Thesis',
                children: const [
                  Text(
                    'Use BLE Stability and Packet Throughput for reliability discussion.',
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Use packet rate and average interval when describing transmission consistency.',
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Accuracy, precision, recall, and F1-score still need controlled test runs with labeled gestures.',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _packetBalanceLabel(BleGloveSnapshot snapshot) {
    if (snapshot.leftPacketCount == 0 && snapshot.rightPacketCount == 0) {
      return 'No packets yet';
    }
    final smaller = snapshot.leftPacketCount < snapshot.rightPacketCount
        ? snapshot.leftPacketCount
        : snapshot.rightPacketCount;
    final larger = snapshot.leftPacketCount > snapshot.rightPacketCount
        ? snapshot.leftPacketCount
        : snapshot.rightPacketCount;
    if (larger == 0) {
      return '0.0%';
    }
    return '${((smaller / larger) * 100).toStringAsFixed(1)}%';
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
}

class _RecognitionHistoryTile extends StatelessWidget {
  final RecognitionMetricRecord record;

  const _RecognitionHistoryTile({required this.record});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            record.label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Confidence: ${(record.confidence * 100).toStringAsFixed(1)}% | Inference: ${record.inferenceTimeMs.toStringAsFixed(1)} ms | Latency: ${record.latencyMs.toStringAsFixed(1)} ms',
          ),
          const SizedBox(height: 4),
          Text(
            'Recognized at: ${record.recognizedAt.toLocal().toString().split('.').first}',
          ),
        ],
      ),
    );
  }
}

class _MetricSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _MetricSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetricRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(flex: 3, child: Text(value)),
        ],
      ),
    );
  }
}

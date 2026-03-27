import 'dart:async';

import 'package:flutter/material.dart';

import '../services/ble_glove_service.dart';

class BleDebugScreen extends StatefulWidget {
  const BleDebugScreen({super.key});

  @override
  State<BleDebugScreen> createState() => _BleDebugScreenState();
}

class _BleDebugScreenState extends State<BleDebugScreen> {
  final BleGloveService _bleService = BleGloveService();
  final List<String> _debugLogs = [];
  final ScrollController _logScrollController = ScrollController();

  StreamSubscription<BleGloveSnapshot>? _snapshotSub;
  int _lastLoggedLeftPackets = 0;
  int _lastLoggedRightPackets = 0;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _bleService.ensureInitialized();
    _appendSnapshotLog(_bleService.snapshot);
    _snapshotSub = _bleService.snapshots.listen(_appendSnapshotLog);
    await _bleService.reconnectMissingDevices();
  }

  @override
  void dispose() {
    _snapshotSub?.cancel();
    _logScrollController.dispose();
    super.dispose();
  }

  void _appendSnapshotLog(BleGloveSnapshot state) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    final message =
        '[$timestamp] left=${state.leftConnected} right=${state.rightConnected} packets=L${state.leftPacketCount}/R${state.rightPacketCount} scanning=${state.isScanning}';

    if (!mounted) {
      _debugLogs.add(message);
      return;
    }

    setState(() {
      _debugLogs.add(message);

      if (state.leftPacketCount != _lastLoggedLeftPackets && state.leftData != null) {
        _debugLogs.add(
          '[$timestamp] LEFT data thumb=${state.leftData!['flex_thumb']?.toStringAsFixed(1)} ax=${state.leftData!['ax_g']?.toStringAsFixed(2)}',
        );
        _lastLoggedLeftPackets = state.leftPacketCount;
      }

      if (state.rightPacketCount != _lastLoggedRightPackets && state.rightData != null) {
        _debugLogs.add(
          '[$timestamp] RIGHT data thumb=${state.rightData!['flex_thumb']?.toStringAsFixed(1)} ax=${state.rightData!['ax_g']?.toStringAsFixed(2)}',
        );
        _lastLoggedRightPackets = state.rightPacketCount;
      }

      if (state.lastError != null) {
        _debugLogs.add('[$timestamp] error=${state.lastError}');
      }
      if (_debugLogs.length > 120) {
        _debugLogs.removeRange(0, _debugLogs.length - 120);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScrollController.hasClients) {
        _logScrollController.jumpTo(_logScrollController.position.maxScrollExtent);
      }
    });
  }

  Widget _buildDataCard(
    String title,
    Map<String, double>? data,
    bool connected,
    String? deviceLabel,
    int packetCount,
  ) {
    return Card(
      margin: const EdgeInsets.all(8),
      color: connected ? Colors.green.shade50 : Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Icon(
                  connected ? Icons.check_circle : Icons.error,
                  color: connected ? Colors.green : Colors.red,
                ),
              ],
            ),
            if (deviceLabel != null)
              Text(
                'Device: $deviceLabel',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            Text(
              'Packets received: $packetCount',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            if (data != null) ...[
              Text('Flex Sensors (0-100%):'),
              Text('Thumb: ${data['flex_thumb']?.toStringAsFixed(1) ?? 'N/A'}'),
              Text('Index: ${data['flex_index']?.toStringAsFixed(1) ?? 'N/A'}'),
              Text('Middle: ${data['flex_middle']?.toStringAsFixed(1) ?? 'N/A'}'),
              Text('Ring: ${data['flex_ring']?.toStringAsFixed(1) ?? 'N/A'}'),
              Text('Pinky: ${data['flex_pinky']?.toStringAsFixed(1) ?? 'N/A'}'),
              const SizedBox(height: 8),
              Text('Accelerometer (g):'),
              Text('X: ${data['ax_g']?.toStringAsFixed(2) ?? 'N/A'}'),
              Text('Y: ${data['ay_g']?.toStringAsFixed(2) ?? 'N/A'}'),
              Text('Z: ${data['az_g']?.toStringAsFixed(2) ?? 'N/A'}'),
              const SizedBox(height: 8),
              Text('Gyroscope (deg/s):'),
              Text('X: ${data['gx_dps']?.toStringAsFixed(1) ?? 'N/A'}'),
              Text('Y: ${data['gy_dps']?.toStringAsFixed(1) ?? 'N/A'}'),
              Text('Z: ${data['gz_dps']?.toStringAsFixed(1) ?? 'N/A'}'),
            ] else
              const Text('No data received yet'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<BleGloveSnapshot>(
      stream: _bleService.snapshots,
      initialData: _bleService.snapshot,
      builder: (context, snapshot) {
        final state = snapshot.data ?? _bleService.snapshot;

        return Scaffold(
          appBar: AppBar(
            title: const Text('BLE Debug - Real-time Data'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Reconnect Missing Gloves',
                onPressed: () async {
                  await _bleService.reconnectMissingDevices();
                },
              ),
            ],
          ),
          body: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.blue.shade50,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          state.areBothConnected ? Icons.check_circle : Icons.warning,
                          color: state.areBothConnected ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          state.areBothConnected
                              ? 'Both gloves connected - receiving data'
                              : 'Waiting for glove connection',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Packets: LEFT ${state.leftPacketCount} | RIGHT ${state.rightPacketCount}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: _buildDataCard(
                          'LEFT GLOVE',
                          state.leftData,
                          state.leftConnected,
                          state.leftDevice?.remoteId.toString(),
                          state.leftPacketCount,
                        ),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        child: _buildDataCard(
                          'RIGHT GLOVE',
                          state.rightData,
                          state.rightConnected,
                          state.rightDevice?.remoteId.toString(),
                          state.rightPacketCount,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 220,
                decoration: BoxDecoration(
                  color: Colors.black87,
                  border: Border(top: BorderSide(color: Colors.grey.shade600)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: Colors.grey.shade800,
                      child: Row(
                        children: [
                          const Text(
                            'DEBUG LOG',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              setState(() => _debugLogs.clear());
                            },
                            child: const Text(
                              'CLEAR',
                              style: TextStyle(color: Colors.red, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: _logScrollController,
                        padding: const EdgeInsets.all(8),
                        itemCount: _debugLogs.length,
                        itemBuilder: (context, index) {
                          return Text(
                            _debugLogs[index],
                            style: const TextStyle(
                              color: Colors.green,
                              fontSize: 10,
                              fontFamily: 'monospace',
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

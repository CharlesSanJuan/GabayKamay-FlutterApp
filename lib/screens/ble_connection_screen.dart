import 'package:flutter/material.dart';

import '../services/ble_glove_service.dart';

class BleConnectionScreen extends StatefulWidget {
  const BleConnectionScreen({super.key});

  @override
  State<BleConnectionScreen> createState() => _BleConnectionScreenState();
}

class _BleConnectionScreenState extends State<BleConnectionScreen> {
  final BleGloveService _bleService = BleGloveService();

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _bleService.ensureInitialized();
  }

  Future<void> _scan() async {
    await _bleService.scanForGloves();
    if (!mounted) return;

    final error = _bleService.snapshot.lastError;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _connectBoth() async {
    await _bleService.connectBothDevices();
    if (!mounted) return;

    final state = _bleService.snapshot;
    final message = state.areBothConnected
        ? 'Both gloves are connected.'
        : (state.lastError ?? 'Connection incomplete. Check both gloves and try again.');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _disconnectAll() async {
    await _bleService.disconnectAll();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Both gloves disconnected.')),
    );
  }

  String _deviceLabel(String gloveName, BleGloveSnapshot state) {
    final device = gloveName == leftGloveName ? state.leftDevice : state.rightDevice;
    return device?.remoteId.toString() ?? 'Not found yet';
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
            title: const Text('BLE Gloves Connection'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ElevatedButton(
                  onPressed: state.isScanning ? null : _scan,
                  child: Text(
                    state.isScanning
                        ? 'Scanning...'
                        : 'Scan for GLOVE_LEFT/GLOVE_RIGHT',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Found devices: ${state.foundDevices.map((d) => d.platformName).where((name) => name.isNotEmpty).join(', ')}',
                ),
                if (state.lastError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    state.lastError!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
                const SizedBox(height: 16),
                ListTile(
                  leading: Icon(
                    state.leftConnected ? Icons.check_circle : Icons.circle_outlined,
                    color: state.leftConnected ? Colors.green : Colors.grey,
                  ),
                  title: const Text('Left Glove (GLOVE_LEFT)'),
                  subtitle: Text(_deviceLabel(leftGloveName, state)),
                ),
                ListTile(
                  leading: Icon(
                    state.rightConnected ? Icons.check_circle : Icons.circle_outlined,
                    color: state.rightConnected ? Colors.green : Colors.grey,
                  ),
                  title: const Text('Right Glove (GLOVE_RIGHT)'),
                  subtitle: Text(_deviceLabel(rightGloveName, state)),
                ),
                const Spacer(),
                Center(
                  child: Column(
                    children: [
                      ElevatedButton(
                        onPressed: state.isScanning ? null : _connectBoth,
                        child: const Text('Connect Both Devices'),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Status: ${state.areBothConnected ? "Ready" : "Waiting for both connections"}',
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _disconnectAll,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                        ),
                        child: const Text('Disconnect All'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

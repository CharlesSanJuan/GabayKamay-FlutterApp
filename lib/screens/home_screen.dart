import 'dart:async';

import 'package:flutter/material.dart';

import '../services/ble_connection_state.dart';
import '../services/ble_glove_service.dart';
import 'calibration_screen.dart';
import 'dictionary_screen.dart';
import 'training_screen.dart';
import 'translate_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int currentIndex = 1;

  final Color primaryOrange = Colors.orange;
  final BleConnectionState _bleState = BleConnectionState();
  final BleGloveService _bleService = BleGloveService();
  bool _disconnectDialogOpen = false;

  late StreamSubscription<BleConnectionUpdate> _connectionSubscription;

  @override
  void initState() {
    super.initState();
    _bleService.ensureInitialized();

    _connectionSubscription = _bleState.connectionStateUpdates.listen((update) {
      if (mounted) {
        setState(() {});
      }

      if (!update.isConnected && !_disconnectDialogOpen) {
        _showDisconnectDialog(update.gloveName);
      }
    });
  }

  @override
  void dispose() {
    _connectionSubscription.cancel();
    super.dispose();
  }

  void _showDisconnectDialog(String gloveName) {
    _disconnectDialogOpen = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Glove Disconnected'),
        content: Text(
          '$gloveName has been disconnected.\n\nPlease reconnect the glove to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              _disconnectDialogOpen = false;
              Navigator.pop(context);
              Navigator.pushNamed(context, '/ble_connection');
            },
            child: const Text('Go to BLE Setup'),
          ),
        ],
      ),
    ).then((_) {
      _disconnectDialogOpen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<BleGloveSnapshot>(
      stream: _bleService.snapshots,
      initialData: _bleService.snapshot,
      builder: (context, snapshot) {
        final bleState = snapshot.data ?? _bleService.snapshot;

        return Scaffold(
          backgroundColor: Colors.grey[200],
          body: SafeArea(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.waving_hand, color: Colors.white),
                      const SizedBox(width: 10),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'GabayKamay',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Filipino Sign Language',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () {
                          Navigator.of(context).pushNamed('/settings');
                        },
                        icon: const Icon(Icons.settings, color: Colors.white),
                        tooltip: 'Settings',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.bluetooth),
                              label: const Text('BLE Setup'),
                              onPressed: () {
                                Navigator.of(
                                  context,
                                ).pushNamed('/ble_connection');
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.monitor),
                              label: const Text('BLE Debug'),
                              onPressed: () {
                                Navigator.of(context).pushNamed('/ble_debug');
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.analytics),
                          label: const Text('Thesis Metrics'),
                          onPressed: () {
                            Navigator.of(context).pushNamed('/thesis_metrics');
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        bleState.areBothConnected
                            ? 'Gloves connected | Packets: L ${bleState.leftPacketCount} R ${bleState.rightPacketCount}'
                            : 'Waiting for both gloves to connect',
                        style: TextStyle(
                          color: bleState.areBothConnected
                              ? Colors.green
                              : Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: IndexedStack(
                    index: currentIndex,
                    children: const [
                      TrainingScreen(),
                      TranslateScreen(),
                      DictionaryScreen(),
                      CalibrationScreen(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: const BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(25),
                topRight: Radius.circular(25),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                navItem(
                  Icons.fitness_center,
                  'Training',
                  0,
                  !bleState.areBothConnected,
                ),
                navItem(
                  Icons.translate,
                  'Translate',
                  1,
                  !bleState.areBothConnected,
                ),
                navItem(Icons.book, 'Dictionary', 2, false),
                navItem(Icons.tune, 'Calibrate', 3, !bleState.areBothConnected),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget navItem(IconData icon, String label, int index, bool isDisabled) {
    final active = currentIndex == index;

    return GestureDetector(
      onTap: isDisabled
          ? () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please connect both gloves first.'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          : () {
              setState(() {
                currentIndex = index;
              });
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active && !isDisabled ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              transform: Matrix4.translationValues(
                0,
                active && !isDisabled ? -6 : 0,
                0,
              ),
              child: AnimatedScale(
                scale: active && !isDisabled ? 1.2 : 1,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutBack,
                child: Opacity(
                  opacity: isDisabled ? 0.5 : 1.0,
                  child: Icon(
                    icon,
                    color: active && !isDisabled ? primaryOrange : Colors.black,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: active && !isDisabled
                    ? FontWeight.bold
                    : FontWeight.normal,
                color: active && !isDisabled ? primaryOrange : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

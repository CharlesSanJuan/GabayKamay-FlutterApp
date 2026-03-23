import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

const String leftGloveName = 'GLOVE_LEFT';
const String rightGloveName = 'GLOVE_RIGHT';
const String serviceUuidString = '12345678-1234-1234-1234-1234567890ab';
const String characteristicUuidString = 'abcd1234-5678-1234-5678-abcdef123456';

class BleConnectionScreen extends StatefulWidget {
  const BleConnectionScreen({super.key});

  @override
  State<BleConnectionScreen> createState() => _BleConnectionScreenState();
}

class _BleConnectionScreenState extends State<BleConnectionScreen> {
  final List<BluetoothDevice> _foundDevices = [];
  BluetoothDevice? _leftDevice;
  BluetoothDevice? _rightDevice;

  String _getName(BluetoothDevice device) {
    final platformName = device.platformName;
    if (platformName.isNotEmpty) return platformName;
    if (device.name.isNotEmpty) return device.name;
    return 'Unknown';
  }

  bool _isScanning = false;
  bool _leftConnected = false;
  bool _rightConnected = false;

  Map<String, dynamic>? _leftData;
  Map<String, dynamic>? _rightData;

  StreamSubscription<List<ScanResult>>? _scanSub;

  @override
  void initState() {
    super.initState();
    _checkExistingConnections();
  }

  Future<void> _checkExistingConnections() async {
    // Check if we have previously connected devices
    if (_leftDevice != null) {
      try {
        final state = await _leftDevice!.connectionState.first;
        if (state == BluetoothConnectionState.connected) {
          setState(() => _leftConnected = true);
          _setupNotifications(_leftDevice!);
        }
      } catch (_) {}
    }

    if (_rightDevice != null) {
      try {
        final state = await _rightDevice!.connectionState.first;
        if (state == BluetoothConnectionState.connected) {
          setState(() => _rightConnected = true);
          _setupNotifications(_rightDevice!);
        }
      } catch (_) {}
    }
  }

  Future<void> _setupNotifications(BluetoothDevice device) async {
    try {
      final services = await device.discoverServices();
      for (final service in services) {
        if (service.uuid.toString().toLowerCase() == serviceUuidString.toLowerCase()) {
          for (final c in service.characteristics) {
            if (c.uuid.toString().toLowerCase() == characteristicUuidString.toLowerCase()) {
              await c.setNotifyValue(true);
              c.lastValueStream.listen((value) {
                _onDataReceived(_getName(device), value);
              });
            }
          }
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    // Don't disconnect here - keep connections persistent
    super.dispose();
  }

  Future<void> _scanForGloves() async {
    setState(() {
      _foundDevices.clear();
      _isScanning = true;
      // Don't reset connected devices - preserve their state
      if (!_leftConnected) _leftDevice = null;
      if (!_rightConnected) _rightDevice = null;
    });

    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        final name = _getName(r.device);
        if (name == leftGloveName || name == rightGloveName) {
          if (!_foundDevices.any((d) => d.remoteId == r.device.remoteId)) {
            setState(() {
              _foundDevices.add(r.device);
            });
          }
        }
      }
    });

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 6));

    await Future.delayed(const Duration(milliseconds: 500));

    setState(() {
      _isScanning = false;
      final leftMatches = _foundDevices.where((d) => _getName(d) == leftGloveName);
      final rightMatches = _foundDevices.where((d) => _getName(d) == rightGloveName);

      // Only update device references if not already connected
      if (!_leftConnected) {
        _leftDevice = leftMatches.isNotEmpty ? leftMatches.first : null;
      }
      if (!_rightConnected) {
        _rightDevice = rightMatches.isNotEmpty ? rightMatches.first : null;
      }
    });

    await FlutterBluePlus.stopScan();
  }

  Future<void> _connectDevice(BluetoothDevice device) async {
    try {
      await device.connect(timeout: const Duration(seconds: 20), autoConnect: false);
    } catch (e) {
      // If already connected sometimes throws; ignore.
    }

    final services = await device.discoverServices();

    for (final service in services) {
      if (service.uuid.toString().toLowerCase() == serviceUuidString.toLowerCase()) {
        for (final c in service.characteristics) {
          if (c.uuid.toString().toLowerCase() == characteristicUuidString.toLowerCase()) {
            await c.setNotifyValue(true);
            c.lastValueStream.listen((value) {
              _onDataReceived(_getName(device), value);
            });
          }
        }
      }
    }

    final deviceName = _getName(device);
    if (deviceName == leftGloveName) {
      setState(() => _leftConnected = true);
    } else if (deviceName == rightGloveName) {
      setState(() => _rightConnected = true);
    }
  }

  Future<void> _connectBothDevices() async {
    final left = _leftDevice;
    final right = _rightDevice;

    if (left == null || right == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Both GLOVE_LEFT and GLOVE_RIGHT must be found before connecting.'),
      ));
      return;
    }

    // Only connect devices that aren't already connected
    if (!_leftConnected) {
      await _connectDevice(left);
      await Future.delayed(const Duration(seconds: 1));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Left glove already connected'),
      ));
    }

    if (!_rightConnected) {
      await _connectDevice(right);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Right glove already connected'),
      ));
    }
  }

  void _onDataReceived(String deviceName, List<int> value) {
    final String csv = String.fromCharCodes(value);

    final parsed = _parseData(csv);

    if (deviceName == leftGloveName) {
      _leftData = parsed;
    } else if (deviceName == rightGloveName) {
      _rightData = parsed;
    }

    if (_leftData != null && _rightData != null) {
      _processCombinedData(_leftData!, _rightData!);
    }
  }

  Map<String, double>? _parseData(String data) {
    try {
      final parts = data.split(',');
      if (parts.length < 11) return null;
      return {
        'flex_thumb': double.tryParse(parts[0]) ?? 0.0,
        'flex_index': double.tryParse(parts[1]) ?? 0.0,
        'flex_middle': double.tryParse(parts[2]) ?? 0.0,
        'flex_ring': double.tryParse(parts[3]) ?? 0.0,
        'flex_pinky': double.tryParse(parts[4]) ?? 0.0,
        'ax_g': double.tryParse(parts[5]) ?? 0.0,
        'ay_g': double.tryParse(parts[6]) ?? 0.0,
        'az_g': double.tryParse(parts[7]) ?? 0.0,
        'gx_dps': double.tryParse(parts[8]) ?? 0.0,
        'gy_dps': double.tryParse(parts[9]) ?? 0.0,
        'gz_dps': double.tryParse(parts[10]) ?? 0.0,
      };
    } catch (_) {
      return null;
    }
  }

  void _processCombinedData(Map<String, dynamic> left, Map<String, dynamic> right) {
    debugPrint('Combined data: left=$left right=$right');
  }

  Future<void> _disconnectAll() async {
    if (_leftDevice != null) {
      await _leftDevice!.disconnect();
    }
    if (_rightDevice != null) {
      await _rightDevice!.disconnect();
    }
    setState(() {
      _leftConnected = false;
      _rightConnected = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isReady = _leftConnected && _rightConnected;

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
              onPressed: _isScanning ? null : _scanForGloves,
              child: Text(_isScanning ? 'Scanning...' : 'Scan for GLOVE_LEFT/GLOVE_RIGHT'),
            ),
            const SizedBox(height: 12),
            Text('Found devices: ${_foundDevices.map((d) => _getName(d)).join(', ')}'),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(_leftConnected ? Icons.check_circle : Icons.circle_outlined,
                  color: _leftConnected ? Colors.green : Colors.grey),
              title: const Text('Left Glove (GLOVE_LEFT)'),
              subtitle: Text(_leftDevice != null ? _leftDevice!.remoteId.toString() : 'Not found'),
            ),
            ListTile(
              leading: Icon(_rightConnected ? Icons.check_circle : Icons.circle_outlined,
                  color: _rightConnected ? Colors.green : Colors.grey),
              title: const Text('Right Glove (GLOVE_RIGHT)'),
              subtitle: Text(_rightDevice != null ? _rightDevice!.remoteId.toString() : 'Not found'),
            ),
            const Spacer(),
            Center(
              child: Column(
                children: [
                  ElevatedButton(
                    onPressed: (_leftDevice != null && _rightDevice != null) && !_isScanning
                        ? _connectBothDevices
                        : null,
                    child: const Text('Connect Both Devices'),
                  ),
                  const SizedBox(height: 8),
                  Text('Status: ${isReady ? "Ready ✅" : "Waiting for both connections"}'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _disconnectAll,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                    child: const Text('Disconnect All'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

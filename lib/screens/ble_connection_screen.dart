import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../services/glove_calibration_service.dart';
import '../services/ble_connection_state.dart';

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
    return 'Unknown';
  }

  bool _isScanning = false;
  bool _leftConnected = false;
  bool _rightConnected = false;

  final GloveCalibrationService _calibration = GloveCalibrationService();

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
          BleConnectionState().updateConnectionState(leftGloveName, true);
          _setupNotifications(_leftDevice!);
        }
      } catch (_) {}
    }

    if (_rightDevice != null) {
      try {
        final state = await _rightDevice!.connectionState.first;
        if (state == BluetoothConnectionState.connected) {
          setState(() => _rightConnected = true);
          BleConnectionState().updateConnectionState(rightGloveName, true);
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
      BleConnectionState().updateConnectionState(leftGloveName, true);
    } else if (deviceName == rightGloveName) {
      setState(() => _rightConnected = true);
      BleConnectionState().updateConnectionState(rightGloveName, true);
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Left glove connected'),
      ));
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Left glove already connected'),
      ));
    }

    if (!_rightConnected) {
      await _connectDevice(right);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Right glove connected'),
      ));
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Right glove already connected'),
      ));
    }
  }

  void _onDataReceived(String deviceName, List<int> value) {
    final String csv = String.fromCharCodes(value);

    final parsed = _parseData(csv, deviceName);

    if (parsed != null) {
      _calibration.updateLatest(deviceName, parsed);
    }

    if (deviceName == leftGloveName) {
      _leftData = parsed;
    } else if (deviceName == rightGloveName) {
      _rightData = parsed;
    }

    if (_leftData != null && _rightData != null) {
      _processCombinedData(_leftData!, _rightData!);
    }
  }

  Map<String, double>? _parseData(String data, String gloveName) {
    try {
      final parts = data.split(',');
      if (parts.length < 11) return null;

      final rawFlex = List<double>.generate(5, (i) => double.tryParse(parts[i]) ?? 0.0);
      final rawAccel = List<double>.generate(3, (i) => double.tryParse(parts[5 + i]) ?? 0.0);
      final rawGyro = List<double>.generate(3, (i) => double.tryParse(parts[8 + i]) ?? 0.0);

      final calibration = _calibration.getCalibration(gloveName);
      final calibratedFlex = List<double>.generate(5, (i) {
        if (calibration.isComplete) {
          return calibration.mapToPercent(i, rawFlex[i]);
        }
        return rawFlex[i];
      });

      return {
        'flex_thumb_raw': rawFlex[0],
        'flex_index_raw': rawFlex[1],
        'flex_middle_raw': rawFlex[2],
        'flex_ring_raw': rawFlex[3],
        'flex_pinky_raw': rawFlex[4],
        'flex_thumb': calibratedFlex[0],
        'flex_index': calibratedFlex[1],
        'flex_middle': calibratedFlex[2],
        'flex_ring': calibratedFlex[3],
        'flex_pinky': calibratedFlex[4],
        'ax_raw': rawAccel[0],
        'ay_raw': rawAccel[1],
        'az_raw': rawAccel[2],
        'gx_raw': rawGyro[0],
        'gy_raw': rawGyro[1],
        'gz_raw': rawGyro[2],
        'ax_g': calibration.accelGx(rawAccel[0]),
        'ay_g': calibration.accelGy(rawAccel[1]),
        'az_g': calibration.accelGz(rawAccel[2]),
        'gx_dps': calibration.gyroDpsX(rawGyro[0]),
        'gy_dps': calibration.gyroDpsY(rawGyro[1]),
        'gz_dps': calibration.gyroDpsZ(rawGyro[2]),
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
      BleConnectionState().updateConnectionState(leftGloveName, false);
    }
    if (_rightDevice != null) {
      await _rightDevice!.disconnect();
      BleConnectionState().updateConnectionState(rightGloveName, false);
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

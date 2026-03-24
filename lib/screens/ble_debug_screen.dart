import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../services/glove_calibration_service.dart';
import '../services/ble_connection_state.dart';

const String leftGloveName = 'GLOVE_LEFT';
const String rightGloveName = 'GLOVE_RIGHT';
const String serviceUuidString = '12345678-1234-1234-1234-1234567890ab';
const String characteristicUuidString = 'abcd1234-5678-1234-5678-abcdef123456';

class BleDebugScreen extends StatefulWidget {
  const BleDebugScreen({super.key});

  @override
  State<BleDebugScreen> createState() => _BleDebugScreenState();
}

class _BleDebugScreenState extends State<BleDebugScreen> {
  BluetoothDevice? _leftDevice;
  BluetoothDevice? _rightDevice;

  // Separate characteristic references (CRITICAL FIX)
  BluetoothCharacteristic? _leftCharacteristic;
  BluetoothCharacteristic? _rightCharacteristic;

  // Separate stream subscriptions (CRITICAL - prevent garbage collection)
  StreamSubscription<List<int>>? _leftSubscription;
  StreamSubscription<List<int>>? _rightSubscription;

  Map<String, dynamic>? _leftData;
  Map<String, dynamic>? _rightData;

  bool _leftConnected = false;
  bool _rightConnected = false;

  final GloveCalibrationService _calibration = GloveCalibrationService();

  StreamSubscription<List<ScanResult>>? _scanSub;
  Timer? _connectionCheckTimer;

  // Debug log for displaying in app
  final List<String> _debugLogs = [];
  final ScrollController _logScrollController = ScrollController();
  
  // CRITICAL: Only initialize connections once
  bool _hasInitialized = false;

  void _addDebugLog(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19); // HH:MM:SS
    final logMessage = '[$timestamp] $message';
    setState(() {
      _debugLogs.add(logMessage);
      if (_debugLogs.length > 100) {
        _debugLogs.removeAt(0); // Keep only last 100 logs
      }
    });

    // Auto-scroll to bottom
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_logScrollController.hasClients) {
        _logScrollController.animateTo(
          _logScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });

    debugPrint(logMessage); // Also print to console for development
  }

  String _getName(BluetoothDevice device) {
    final platformName = device.platformName;

    _addDebugLog('Device name check - platformName: "$platformName"');

    if (platformName.isNotEmpty) return platformName;
    return 'Unknown';
  }

  @override
  void initState() {
    super.initState();
    // CRITICAL: Only initialize once to prevent reconnection on screen revisit
    if (!_hasInitialized) {
      _hasInitialized = true;
      _findAndConnectDevices();
      _connectionCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        _checkConnections();
      });
    } else {
      _addDebugLog('✅ Already initialized, skipping reconnection attempt');
    }
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _connectionCheckTimer?.cancel();
    _leftSubscription?.cancel();
    _rightSubscription?.cancel();
    super.dispose();
  }

  Future<void> _findAndConnectDevices() async {
    _addDebugLog('Starting BLE scan for gloves...');

    // Check if we already have connected devices
    if (_leftDevice != null && _leftConnected) {
      _addDebugLog('LEFT glove already connected, skipping scan for it');
    }
    if (_rightDevice != null && _rightConnected) {
      _addDebugLog('RIGHT glove already connected, skipping scan for it');
    }

    // Only scan if we don't have both devices connected
    if (!(_leftConnected && _rightConnected)) {
      _scanSub = FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          final name = _getName(r.device);
          _addDebugLog('Found device: $name (ID: ${r.device.remoteId})');

          if (name == leftGloveName && _leftDevice == null && !_leftConnected) {
            _addDebugLog('Found LEFT glove: $name');
            _leftDevice = r.device;
            // Don't connect immediately - wait for scan to complete
            _addDebugLog('LEFT glove found, will connect after scan');
          } else if (name == rightGloveName && _rightDevice == null && !_rightConnected) {
            _addDebugLog('Found RIGHT glove: $name');
            _rightDevice = r.device;
            // Don't connect immediately - wait for scan to complete
            _addDebugLog('RIGHT glove found, will connect after scan');
          }
        }
      });

      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
      await FlutterBluePlus.stopScan();

      _addDebugLog('Scan complete. Left device: ${_leftDevice != null}, Right device: ${_rightDevice != null}');

      // Connect devices sequentially to avoid BLE stack conflicts
      if (_leftDevice != null && !_leftConnected) {
        _addDebugLog('Connecting to LEFT glove...');
        await _connectDevice(_leftDevice!);
        await Future.delayed(const Duration(seconds: 2)); // Wait between connections
      }

      if (_rightDevice != null && !_rightConnected) {
        _addDebugLog('Connecting to RIGHT glove...');
        await _connectDevice(_rightDevice!);
      }

      // CRITICAL FIX #2: Verify both characteristics are notifying
      await Future.delayed(const Duration(milliseconds: 500));
      await _verifyBothNotifications();
    // Check for duplicate device names
    if (_leftDevice != null && _rightDevice != null) {
      final leftName = _getName(_leftDevice!);
      final rightName = _getName(_rightDevice!);
      if (leftName == rightName) {
        _addDebugLog('WARNING: Both devices have the same name "$leftName"! One should be GLOVE_LEFT, the other GLOVE_RIGHT');
      }
    }    } else {
      _addDebugLog('Both gloves already connected, skipping scan');
    }
  }

  Future<void> _connectDevice(BluetoothDevice device) async {
    final deviceName = _getName(device);
    _addDebugLog('=== CONNECTING TO: $deviceName ===');

    try {
      await device.connect(timeout: const Duration(seconds: 10), autoConnect: false);
      _addDebugLog('✅ Successfully connected to: $deviceName');

      final services = await device.discoverServices();
      _addDebugLog('📋 Discovered ${services.length} services for $deviceName');

      bool foundService = false;
      bool foundCharacteristic = false;

      for (final service in services) {
        _addDebugLog('🔍 [$deviceName] Checking service: ${service.uuid}');
        if (service.uuid.toString().toLowerCase() == serviceUuidString.toLowerCase()) {
          _addDebugLog('✅ [$deviceName] Found matching service!');
          foundService = true;

          _addDebugLog('📋 [$deviceName] Service has ${service.characteristics.length} characteristics');
          for (final c in service.characteristics) {
            _addDebugLog('🔍 [$deviceName] Checking characteristic: ${c.uuid}');
            if (c.uuid.toString().toLowerCase() == characteristicUuidString.toLowerCase()) {
              _addDebugLog('✅ [$deviceName] Found matching characteristic!');
              foundCharacteristic = true;

              // Store separate characteristic reference (CRITICAL FIX #1)
              if (deviceName == leftGloveName) {
                _leftCharacteristic = c;
                _addDebugLog('📌 [$deviceName] Stored as LEFT characteristic');
              } else if (deviceName == rightGloveName) {
                _rightCharacteristic = c;
                _addDebugLog('📌 [$deviceName] Stored as RIGHT characteristic');
              }

              // Check characteristic properties
              _addDebugLog('📊 [$deviceName] Properties: notify=${c.isNotifying}, readable=${c.properties.read}, writable=${c.properties.write}');

              await c.setNotifyValue(true);
              _addDebugLog('📡 [$deviceName] Called setNotifyValue(true)');

              // Check if notify was actually enabled
              await Future.delayed(const Duration(milliseconds: 100));
              final isNotifyingNow = c.isNotifying;
              _addDebugLog('📊 [$deviceName] After setNotifyValue - isNotifying: $isNotifyingNow');

              // Set up SEPARATE stream listeners ONLY (no duplicate listeners!)
              if (deviceName == leftGloveName) {
                _addDebugLog('🔗 [$deviceName] Setting up LEFT subscription...');
                _leftSubscription?.cancel();
                _addDebugLog('📌 [$deviceName] Cleared old LEFT subscription');
                _leftSubscription = _leftCharacteristic!.lastValueStream.listen((value) {
                  final dataString = String.fromCharCodes(value);
                  _addDebugLog('📨 [LEFT] Received ${value.length} bytes: $dataString');
                  _onDataReceived(leftGloveName, value);
                }, onError: (error) {
                  _addDebugLog('❌ [LEFT] Stream error: $error');
                }, onDone: () {
                  _addDebugLog('🔚 [LEFT] Stream closed');
                });
                _addDebugLog('✅ [LEFT] Subscription created successfully');
              } else if (deviceName == rightGloveName) {
                _addDebugLog('🔗 [$deviceName] Setting up RIGHT subscription...');
                _rightSubscription?.cancel();
                _addDebugLog('📌 [$deviceName] Cleared old RIGHT subscription');
                _rightSubscription = _rightCharacteristic!.lastValueStream.listen((value) {
                  final dataString = String.fromCharCodes(value);
                  _addDebugLog('📨 [RIGHT] Received ${value.length} bytes: $dataString');
                  _onDataReceived(rightGloveName, value);
                }, onError: (error) {
                  _addDebugLog('❌ [RIGHT] Stream error: $error');
                }, onDone: () {
                  _addDebugLog('🔚 [RIGHT] Stream closed');
                });
                _addDebugLog('✅ [RIGHT] Subscription created successfully');
              }

              break;
            }
          }
          // do not break here; allow checking next service if current service
          // was not the one with the required characteristic
        }
      }

      if (!foundService) {
        _addDebugLog('❌ WARNING: No matching service found for $deviceName');
      }
      if (!foundCharacteristic) {
        _addDebugLog('❌ WARNING: No matching characteristic found for $deviceName');
      }

      if (deviceName == leftGloveName) {
        setState(() => _leftConnected = true);
        BleConnectionState().updateConnectionState(leftGloveName, true);
      } else if (deviceName == rightGloveName) {
        setState(() => _rightConnected = true);
        BleConnectionState().updateConnectionState(rightGloveName, true);
      }

    } catch (e) {
      _addDebugLog('❌ Failed to connect to $deviceName: $e');
    }
  }

  void _onDataReceived(String deviceName, List<int> value) {
    final String csv = String.fromCharCodes(value);
    _addDebugLog('Raw data from $deviceName: $csv');

    final parsed = _parseData(csv, deviceName);
    _addDebugLog('Parsed data from $deviceName: $parsed');

    if (parsed != null) {
      _calibration.updateLatest(deviceName, parsed);
    }

    if (deviceName == leftGloveName) {
      setState(() => _leftData = parsed);
    } else if (deviceName == rightGloveName) {
      setState(() => _rightData = parsed);
    }
  }

  Map<String, double>? _parseData(String data, String gloveName) {
    try {
      final parts = data.split(',');
      if (parts.length < 11) return null;

      // Expect raw ADC values from ESP32: 5 flex + 3 accel + 3 gyro
      final rawFlex = List<double>.generate(5, (i) => double.tryParse(parts[i]) ?? 0.0);
      final rawAccel = List<double>.generate(3, (i) => double.tryParse(parts[5 + i]) ?? 0.0);
      final rawGyro = List<double>.generate(3, (i) => double.tryParse(parts[8 + i]) ?? 0.0);

      final calibration = _calibration.getCalibration(gloveName);
      final calibratedFlex = List<double>.generate(5, (i) {
        if (calibration.isComplete) {
          return calibration.mapToPercent(i, rawFlex[i]);
        }
        return rawFlex[i]; // raw fallback until calibration is done
      });

      final parsed = {
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
        'is_test_mode': 0.0,
      };

      return parsed;
    } catch (_) {
      return null;
    }
  }

  // Test individual device connections
  Future<void> _verifyBothNotifications() async {
    _addDebugLog('🔍 VERIFICATION: Checking both characteristics...');

    if (_leftCharacteristic != null) {
      try {
        final isNotifying = _leftCharacteristic!.isNotifying;
        _addDebugLog('📊 LEFT characteristic isNotifying: $isNotifying');
        if (!isNotifying) {
          _addDebugLog('⚠️ LEFT characteristic not notifying - attempting to fix...');
          await _leftCharacteristic!.setNotifyValue(true);
          await Future.delayed(const Duration(milliseconds: 100));
          _addDebugLog('📊 LEFT after retry: ${_leftCharacteristic!.isNotifying}');
        }
      } catch (e) {
        _addDebugLog('❌ Error checking LEFT characteristic: $e');
      }
    } else {
      _addDebugLog('❌ LEFT characteristic is null!');
    }

    if (_rightCharacteristic != null) {
      try {
        final isNotifying = _rightCharacteristic!.isNotifying;
        _addDebugLog('📊 RIGHT characteristic isNotifying: $isNotifying');
        if (!isNotifying) {
          _addDebugLog('⚠️ RIGHT characteristic not notifying - attempting to fix...');
          await _rightCharacteristic!.setNotifyValue(true);
          await Future.delayed(const Duration(milliseconds: 100));
          _addDebugLog('📊 RIGHT after retry: ${_rightCharacteristic!.isNotifying}');
        }
      } catch (e) {
        _addDebugLog('❌ Error checking RIGHT characteristic: $e');
      }
    } else {
      _addDebugLog('❌ RIGHT characteristic is null!');
    }

    _addDebugLog('✅ VERIFICATION COMPLETE');
  }

  // Test individual device connections
  Future<void> _testDeviceConnection(BluetoothDevice device, String expectedName) async {
    _addDebugLog('🧪 Testing individual connection to $expectedName...');

    try {
      // Disconnect if already connected
      if (_leftDevice == device && _leftConnected) {
        await _leftDevice!.disconnect();
        _leftConnected = false;
        await Future.delayed(const Duration(seconds: 1));
      }
      if (_rightDevice == device && _rightConnected) {
        await _rightDevice!.disconnect();
        _rightConnected = false;
        await Future.delayed(const Duration(seconds: 1));
      }

      // Connect and test
      await device.connect(timeout: const Duration(seconds: 10), autoConnect: false);
      _addDebugLog('✅ Connected to $expectedName for testing');

      final services = await device.discoverServices();
      _addDebugLog('📋 $expectedName has ${services.length} services');

      // Look for our service
      for (final service in services) {
        if (service.uuid.toString().toLowerCase() == serviceUuidString.toLowerCase()) {
          _addDebugLog('✅ $expectedName has our service');

          for (final c in service.characteristics) {
            if (c.uuid.toString().toLowerCase() == characteristicUuidString.toLowerCase()) {
              _addDebugLog('✅ $expectedName has our characteristic');

              await c.setNotifyValue(true);
              _addDebugLog('📡 $expectedName notifications enabled');

              // Listen for 5 seconds
              final subscription = c.lastValueStream.listen((value) {
                _addDebugLog('📨 $expectedName TEST DATA: ${String.fromCharCodes(value)}');
              });

              await Future.delayed(const Duration(seconds: 5));
              subscription.cancel();

              _addDebugLog('🧪 Test complete for $expectedName');
              break;
            }
          }
          break;
        }
      }

      await device.disconnect();
      _addDebugLog('🔌 Disconnected $expectedName after test');

    } catch (e) {
      _addDebugLog('❌ Test failed for $expectedName: $e');
    }
  }

  Future<void> _checkConnections() async {
    if (_leftDevice != null) {
      try {
        final state = await _leftDevice!.connectionState.first;
        final isConnected = state == BluetoothConnectionState.connected;
        setState(() => _leftConnected = isConnected);
        BleConnectionState().updateConnectionState(leftGloveName, isConnected);
      } catch (_) {
        setState(() => _leftConnected = false);
        BleConnectionState().updateConnectionState(leftGloveName, false);
      }
    }

    if (_rightDevice != null) {
      try {
        final state = await _rightDevice!.connectionState.first;
        final isConnected = state == BluetoothConnectionState.connected;
        setState(() => _rightConnected = isConnected);
        BleConnectionState().updateConnectionState(rightGloveName, isConnected);
      } catch (_) {
        setState(() => _rightConnected = false);
        BleConnectionState().updateConnectionState(rightGloveName, false);
      }
    }
  }

  Widget _buildDataCard(String title, Map<String, dynamic>? data, bool connected, String? deviceName) {
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
            if (deviceName != null) ...[
              Text(
                'Device: $deviceName',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
            if (data != null && data['is_test_mode'] == 1.0) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.orange),
                ),
                child: const Text(
                  'TEST MODE DETECTED',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            if (data != null) ...[
              Text('Flex Sensors (0-100%):'),
              Text('  Thumb: ${data['flex_thumb']?.toStringAsFixed(1) ?? 'N/A'}'),
              Text('  Index: ${data['flex_index']?.toStringAsFixed(1) ?? 'N/A'}'),
              Text('  Middle: ${data['flex_middle']?.toStringAsFixed(1) ?? 'N/A'}'),
              Text('  Ring: ${data['flex_ring']?.toStringAsFixed(1) ?? 'N/A'}'),
              Text('  Pinky: ${data['flex_pinky']?.toStringAsFixed(1) ?? 'N/A'}'),
              const SizedBox(height: 8),
              Text('Accelerometer (g\'s):'),
              Text('  X: ${data['ax_g']?.toStringAsFixed(2) ?? 'N/A'}'),
              Text('  Y: ${data['ay_g']?.toStringAsFixed(2) ?? 'N/A'}'),
              Text('  Z: ${data['az_g']?.toStringAsFixed(2) ?? 'N/A'}'),
              const SizedBox(height: 8),
              Text('Gyroscope (°/s):'),
              Text('  X: ${data['gx_dps']?.toStringAsFixed(1) ?? 'N/A'}'),
              Text('  Y: ${data['gy_dps']?.toStringAsFixed(1) ?? 'N/A'}'),
              Text('  Z: ${data['gz_dps']?.toStringAsFixed(1) ?? 'N/A'}'),
            ] else ...[
              const Text('No data received yet'),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE Debug - Real-time Data'),
        actions: [
          IconButton(
            icon: const Icon(Icons.verified),
            tooltip: 'Verify Notifications',
            onPressed: () async {
              _addDebugLog('🔍 Manual notification verification...');
              await _verifyBothNotifications();
            },
          ),
          IconButton(
            icon: const Icon(Icons.bug_report),
            tooltip: 'Test Individual Devices',
            onPressed: () async {
              _addDebugLog('🧪 Starting individual device tests...');

              if (_leftDevice != null) {
                await _testDeviceConnection(_leftDevice!, 'GLOVE_LEFT');
                await Future.delayed(const Duration(seconds: 2));
              }

              if (_rightDevice != null) {
                await _testDeviceConnection(_rightDevice!, 'GLOVE_RIGHT');
              }

              _addDebugLog('🧪 All device tests completed');
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              _addDebugLog('Manual refresh requested');

              // Check current connection states
              await _checkConnections();

              // Only reset devices that aren't connected
              if (!_leftConnected) {
                _leftDevice = null;
                _leftData = null;
              }
              if (!_rightConnected) {
                _rightDevice = null;
                _rightData = null;
              }

              // Try to reconnect missing devices
              if (_leftDevice == null || _rightDevice == null) {
                _findAndConnectDevices();
              } else {
                _addDebugLog('All devices still connected, no need to rescan');
              }
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
                      _leftConnected && _rightConnected ? Icons.check_circle : Icons.warning,
                      color: _leftConnected && _rightConnected ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _leftConnected && _rightConnected
                          ? 'Both gloves connected - receiving data'
                          : 'Connecting to gloves...',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Found: ${_leftDevice != null ? "LEFT (${_getName(_leftDevice!)})" : "No LEFT"} | ${_rightDevice != null ? "RIGHT (${_getName(_rightDevice!)})" : "No RIGHT"}',
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
                    child: _buildDataCard('LEFT GLOVE', _leftData, _leftConnected, _leftDevice != null ? _getName(_leftDevice!) : null),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: _buildDataCard('RIGHT GLOVE', _rightData, _rightConnected, _rightDevice != null ? _getName(_rightDevice!) : null),
                  ),
                ),
              ],
            ),
          ),
          // Debug Log Section
          Container(
            height: 200,
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
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
  }
}

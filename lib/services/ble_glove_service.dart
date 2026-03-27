import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'ble_connection_state.dart';
import 'glove_calibration_service.dart';

const String leftGloveName = 'GLOVE_LEFT';
const String rightGloveName = 'GLOVE_RIGHT';
const String serviceUuidString = '12345678-1234-1234-1234-1234567890ab';
const String characteristicUuidString = 'abcd1234-5678-1234-5678-abcdef123456';

class BleGloveSnapshot {
  final bool isScanning;
  final BluetoothDevice? leftDevice;
  final BluetoothDevice? rightDevice;
  final bool leftConnected;
  final bool rightConnected;
  final Map<String, double>? leftData;
  final Map<String, double>? rightData;
  final int leftPacketCount;
  final int rightPacketCount;
  final List<BluetoothDevice> foundDevices;
  final String? lastError;
  final DateTime updatedAt;

  const BleGloveSnapshot({
    required this.isScanning,
    required this.leftDevice,
    required this.rightDevice,
    required this.leftConnected,
    required this.rightConnected,
    required this.leftData,
    required this.rightData,
    required this.leftPacketCount,
    required this.rightPacketCount,
    required this.foundDevices,
    required this.lastError,
    required this.updatedAt,
  });

  bool get areBothConnected => leftConnected && rightConnected;
}

class BleGloveService {
  static final BleGloveService _instance = BleGloveService._internal();

  factory BleGloveService() => _instance;
  BleGloveService._internal();

  final GloveCalibrationService _calibration = GloveCalibrationService();
  final BleConnectionState _connectionState = BleConnectionState();
  final StreamController<BleGloveSnapshot> _snapshotController =
      StreamController<BleGloveSnapshot>.broadcast();

  final List<BluetoothDevice> _foundDevices = [];

  BluetoothDevice? _leftDevice;
  BluetoothDevice? _rightDevice;
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothConnectionState>? _leftConnectionSub;
  StreamSubscription<BluetoothConnectionState>? _rightConnectionSub;
  StreamSubscription<List<int>>? _leftDataSub;
  StreamSubscription<List<int>>? _rightDataSub;

  bool _isScanning = false;
  bool _leftConnected = false;
  bool _rightConnected = false;
  bool _scanResultsAttached = false;
  String? _lastError;

  String _leftBuffer = '';
  String _rightBuffer = '';
  int _leftPacketCount = 0;
  int _rightPacketCount = 0;

  Map<String, double>? _leftData;
  Map<String, double>? _rightData;

  Stream<BleGloveSnapshot> get snapshots => _snapshotController.stream;

  BleGloveSnapshot get snapshot => BleGloveSnapshot(
        isScanning: _isScanning,
        leftDevice: _leftDevice,
        rightDevice: _rightDevice,
        leftConnected: _leftConnected,
        rightConnected: _rightConnected,
        leftData: _leftData,
        rightData: _rightData,
        leftPacketCount: _leftPacketCount,
        rightPacketCount: _rightPacketCount,
        foundDevices: List.unmodifiable(_foundDevices),
        lastError: _lastError,
        updatedAt: DateTime.now(),
      );

  bool get areBothConnected => _leftConnected && _rightConnected;

  Future<void> ensureInitialized() async {
    _attachScanResultsListener();
    await refreshConnectionStates();
    _emit();
  }

  Future<void> scanForGloves({
    Duration timeout = const Duration(seconds: 4),
  }) async {
    await ensureInitialized();
    if (_isScanning) {
      return;
    }

    _lastError = null;
    _isScanning = true;
    _foundDevices.clear();
    _emit();

    try {
      await FlutterBluePlus.stopScan();
      await FlutterBluePlus.startScan(timeout: timeout);
      await _waitForScanCompletion(timeout);
    } catch (e) {
      _lastError = 'Failed to scan for gloves: $e';
    } finally {
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {}
      _isScanning = false;
      _emit();
    }
  }

  Future<void> connectBothDevices() async {
    await ensureInitialized();
    await refreshConnectionStates();

    if (_leftDevice == null || _rightDevice == null) {
      await scanForGloves();
    }

    final left = _leftDevice;
    final right = _rightDevice;
    if (left == null || right == null) {
      _lastError = 'Both gloves must be discovered before connecting.';
      _emit();
      return;
    }

    if (!_leftConnected) {
      await _connectDevice(left, leftGloveName);
    }
    if (!_rightConnected) {
      await _connectDevice(right, rightGloveName);
    }

    await refreshConnectionStates();
  }

  Future<void> reconnectMissingDevices() async {
    await ensureInitialized();
    await refreshConnectionStates();

    if (_leftDevice == null || _rightDevice == null) {
      await scanForGloves();
    }

    if (_leftDevice != null && (!_leftConnected || _leftDataSub == null)) {
      await _connectDevice(_leftDevice!, leftGloveName);
    }
    if (_rightDevice != null && (!_rightConnected || _rightDataSub == null)) {
      await _connectDevice(_rightDevice!, rightGloveName);
    }

    await refreshConnectionStates();
  }

  Future<void> refreshConnectionStates() async {
    _leftConnected = await _isDeviceConnected(_leftDevice);
    _rightConnected = await _isDeviceConnected(_rightDevice);

    _connectionState.updateConnectionState(leftGloveName, _leftConnected);
    _connectionState.updateConnectionState(rightGloveName, _rightConnected);
    _emit();
  }

  Future<void> disconnectAll() async {
    if (_leftDataSub != null) {
      await _leftDataSub!.cancel();
    }
    if (_rightDataSub != null) {
      await _rightDataSub!.cancel();
    }
    _leftDataSub = null;
    _rightDataSub = null;

    try {
      await _leftDevice?.disconnect();
    } catch (_) {}
    try {
      await _rightDevice?.disconnect();
    } catch (_) {}

    _leftConnected = false;
    _rightConnected = false;
    _leftData = null;
    _rightData = null;
    _leftBuffer = '';
    _rightBuffer = '';
    _leftPacketCount = 0;
    _rightPacketCount = 0;

    _connectionState.updateConnectionState(leftGloveName, false);
    _connectionState.updateConnectionState(rightGloveName, false);
    _emit();
  }

  void dispose() {
    _scanSub?.cancel();
    _leftConnectionSub?.cancel();
    _rightConnectionSub?.cancel();
    _leftDataSub?.cancel();
    _rightDataSub?.cancel();
    _snapshotController.close();
  }

  void _attachScanResultsListener() {
    if (_scanResultsAttached) {
      return;
    }

    _scanResultsAttached = true;
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      var changed = false;

      for (final result in results) {
        final device = result.device;
        final name = _getName(device);
        if (name != leftGloveName && name != rightGloveName) {
          continue;
        }

        if (!_foundDevices.any((existing) => existing.remoteId == device.remoteId)) {
          _foundDevices.add(device);
          changed = true;
        }

        if (name == leftGloveName && _leftDevice?.remoteId != device.remoteId) {
          _leftDevice = device;
          _bindConnectionListener(device, leftGloveName);
          changed = true;
        }

        if (name == rightGloveName && _rightDevice?.remoteId != device.remoteId) {
          _rightDevice = device;
          _bindConnectionListener(device, rightGloveName);
          changed = true;
        }
      }

      if (changed) {
        _emit();
      }
    });
  }

  Future<void> _connectDevice(BluetoothDevice device, String expectedName) async {
    _lastError = null;

    try {
      await device.connect(timeout: const Duration(seconds: 20), autoConnect: false);
    } catch (_) {
      // FlutterBluePlus can throw if the device is already connected.
    }

    final services = await device.discoverServices();
    for (final service in services) {
      if (service.uuid.toString().toLowerCase() != serviceUuidString.toLowerCase()) {
        continue;
      }

      for (final characteristic in service.characteristics) {
        if (characteristic.uuid.toString().toLowerCase() !=
            characteristicUuidString.toLowerCase()) {
          continue;
        }

        _bindCharacteristic(device, expectedName, characteristic);
        await characteristic.setNotifyValue(true);
        await refreshConnectionStates();
        return;
      }
    }

    _lastError = 'Connected to $expectedName but could not find the BLE characteristic.';
    _emit();
  }

  void _bindCharacteristic(
    BluetoothDevice device,
    String gloveName,
    BluetoothCharacteristic characteristic,
  ) {
    if (gloveName == leftGloveName) {
      _leftDataSub?.cancel();
      _leftDataSub = characteristic.lastValueStream.listen((value) {
        _handleIncomingData(gloveName, value);
      });
    } else {
      _rightDataSub?.cancel();
      _rightDataSub = characteristic.lastValueStream.listen((value) {
        _handleIncomingData(gloveName, value);
      });
    }

    _bindConnectionListener(device, gloveName);
  }

  void _bindConnectionListener(BluetoothDevice device, String gloveName) {
    if (gloveName == leftGloveName) {
      _leftConnectionSub?.cancel();
      _leftConnectionSub = device.connectionState.listen((state) {
        _updateConnection(gloveName, state == BluetoothConnectionState.connected);
      });
    } else {
      _rightConnectionSub?.cancel();
      _rightConnectionSub = device.connectionState.listen((state) {
        _updateConnection(gloveName, state == BluetoothConnectionState.connected);
      });
    }
  }

  void _updateConnection(String gloveName, bool isConnected) {
    if (gloveName == leftGloveName) {
      _leftConnected = isConnected;
      if (!isConnected) {
        _leftDataSub?.cancel();
        _leftDataSub = null;
        _leftData = null;
        _leftBuffer = '';
      }
    } else {
      _rightConnected = isConnected;
      if (!isConnected) {
        _rightDataSub?.cancel();
        _rightDataSub = null;
        _rightData = null;
        _rightBuffer = '';
      }
    }

    _connectionState.updateConnectionState(gloveName, isConnected);
    _emit();
  }

  Future<bool> _isDeviceConnected(BluetoothDevice? device) async {
    if (device == null) {
      return false;
    }

    try {
      return await device.connectionState
          .map((state) => state == BluetoothConnectionState.connected)
          .first;
    } catch (_) {
      return false;
    }
  }

  void _handleIncomingData(String gloveName, List<int> value) {
    final chunk = String.fromCharCodes(value);
    if (gloveName == leftGloveName) {
      _leftBuffer += chunk;
    } else {
      _rightBuffer += chunk;
    }
    _consumeBufferedFrames(gloveName);
  }

  Map<String, double>? _parseData(String data, String gloveName) {
    try {
      final parts = data.trim().split(',');
      if (parts.length < 11) {
        return null;
      }

      final rawFlex = List<double>.generate(5, (i) => double.tryParse(parts[i]) ?? 0.0);
      final rawAccel =
          List<double>.generate(3, (i) => double.tryParse(parts[5 + i]) ?? 0.0);
      final rawGyro =
          List<double>.generate(3, (i) => double.tryParse(parts[8 + i]) ?? 0.0);

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
        'is_test_mode': 0.0,
      };
    } catch (_) {
      return null;
    }
  }

  String _getName(BluetoothDevice device) {
    final platformName = device.platformName;
    if (platformName.isNotEmpty) {
      return platformName;
    }
    return 'Unknown';
  }

  void _emit() {
    if (!_snapshotController.isClosed) {
      _snapshotController.add(snapshot);
    }
  }

  Future<void> _waitForScanCompletion(Duration timeout) async {
    final startedAt = DateTime.now();
    while (DateTime.now().difference(startedAt) < timeout) {
      final hasLeft = _leftDevice != null ||
          _foundDevices.any((device) => _getName(device) == leftGloveName);
      final hasRight = _rightDevice != null ||
          _foundDevices.any((device) => _getName(device) == rightGloveName);
      if (hasLeft && hasRight) {
        await Future.delayed(const Duration(milliseconds: 250));
        return;
      }
      await Future.delayed(const Duration(milliseconds: 150));
    }
  }

  void _consumeBufferedFrames(String gloveName) {
    final normalized = (gloveName == leftGloveName ? _leftBuffer : _rightBuffer)
        .replaceAll('\r', '\n');
    final segments = normalized.split('\n');

    if (!normalized.contains('\n')) {
      final parsed = _parseData(
        gloveName == leftGloveName ? _leftBuffer : _rightBuffer,
        gloveName,
      );
      if (parsed != null) {
        _applyParsedData(gloveName, parsed);
        if (gloveName == leftGloveName) {
          _leftBuffer = '';
        } else {
          _rightBuffer = '';
        }
      }
      return;
    }

    for (var i = 0; i < segments.length - 1; i++) {
      final parsed = _parseData(segments[i], gloveName);
      if (parsed != null) {
        _applyParsedData(gloveName, parsed);
      }
    }

    final remainder = segments.isEmpty ? '' : segments.last;
    if (gloveName == leftGloveName) {
      _leftBuffer = remainder;
    } else {
      _rightBuffer = remainder;
    }
  }

  void _applyParsedData(String gloveName, Map<String, double> parsed) {
    final smoothed = _smoothParsedData(
      previous: gloveName == leftGloveName ? _leftData : _rightData,
      incoming: parsed,
    );
    _calibration.updateLatest(gloveName, parsed);

    if (gloveName == leftGloveName) {
      _leftData = smoothed;
      _leftPacketCount += 1;
    } else {
      _rightData = smoothed;
      _rightPacketCount += 1;
    }

    _emit();
  }

  Map<String, double> _smoothParsedData({
    required Map<String, double>? previous,
    required Map<String, double> incoming,
  }) {
    if (previous == null) {
      return Map<String, double>.from(incoming);
    }

    const flexAlpha = 0.35;
    const imuAlpha = 0.22;

    final smoothed = <String, double>{};
    for (final entry in incoming.entries) {
      final key = entry.key;
      final current = entry.value;
      final prior = previous[key] ?? current;
      final alpha = key.startsWith('flex_') ? flexAlpha : imuAlpha;
      smoothed[key] = (alpha * current) + ((1 - alpha) * prior);
    }
    return smoothed;
  }
}

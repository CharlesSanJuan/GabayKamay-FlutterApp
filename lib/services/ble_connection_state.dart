import 'dart:async';

/// Global service to track BLE glove connection status
class BleConnectionState {
  static final BleConnectionState _instance = BleConnectionState._internal();

  factory BleConnectionState() => _instance;
  BleConnectionState._internal();

  // Track connection states
  bool _leftConnected = false;
  bool _rightConnected = false;

  // Stream controller for connection state changes
  final _connectionStateController = StreamController<BleConnectionUpdate>.broadcast();
  
  Stream<BleConnectionUpdate> get connectionStateUpdates => _connectionStateController.stream;

  /// Check if both gloves are connected
  bool get areBothConnected => _leftConnected && _rightConnected;
  
  bool get isLeftConnected => _leftConnected;
  bool get isRightConnected => _rightConnected;

  /// Update connection state for a glove
  void updateConnectionState(String gloveName, bool isConnected) {
    if (gloveName == 'GLOVE_LEFT') {
      final wasConnected = _leftConnected;
      _leftConnected = isConnected;
      
      if (wasConnected && !isConnected) {
        // Left glove disconnected
        _connectionStateController.add(BleConnectionUpdate(
          gloveName: 'GLOVE_LEFT',
          isConnected: false,
          timestamp: DateTime.now(),
        ));
      } else if (!wasConnected && isConnected) {
        // Left glove connected
        _connectionStateController.add(BleConnectionUpdate(
          gloveName: 'GLOVE_LEFT',
          isConnected: true,
          timestamp: DateTime.now(),
        ));
      }
    } else if (gloveName == 'GLOVE_RIGHT') {
      final wasConnected = _rightConnected;
      _rightConnected = isConnected;
      
      if (wasConnected && !isConnected) {
        // Right glove disconnected
        _connectionStateController.add(BleConnectionUpdate(
          gloveName: 'GLOVE_RIGHT',
          isConnected: false,
          timestamp: DateTime.now(),
        ));
      } else if (!wasConnected && isConnected) {
        // Right glove connected
        _connectionStateController.add(BleConnectionUpdate(
          gloveName: 'GLOVE_RIGHT',
          isConnected: true,
          timestamp: DateTime.now(),
        ));
      }
    }
  }

  /// Reset connection states (e.g., when user logs out)
  void reset() {
    _leftConnected = false;
    _rightConnected = false;
  }

  void dispose() {
    _connectionStateController.close();
  }
}

/// Model for connection state updates
class BleConnectionUpdate {
  final String gloveName;
  final bool isConnected;
  final DateTime timestamp;

  BleConnectionUpdate({
    required this.gloveName,
    required this.isConnected,
    required this.timestamp,
  });
}

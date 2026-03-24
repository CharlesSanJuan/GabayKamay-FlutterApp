import 'dart:async';

import 'package:flutter/material.dart';
import 'training_screen.dart';
import 'translate_screen.dart';
import 'dictionary_screen.dart';
import 'calibration_screen.dart';
import '../services/ble_connection_state.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  int currentIndex = 1; // default = Translate

  final Color primaryOrange = Colors.orange;
  final BleConnectionState _bleState = BleConnectionState();
  
  late StreamSubscription<BleConnectionUpdate> _connectionSubscription;

  @override
  void initState() {
    super.initState();
    
    // Listen for BLE connection state changes
    _connectionSubscription = _bleState.connectionStateUpdates.listen((update) {
      if (!update.isConnected) {
        // Show disconnect popup
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Glove Disconnected'),
        content: Text(
          '$gloveName has been disconnected.\n\n'
          'Please reconnect the glove to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to BLE connection screen
              Navigator.pushNamed(context, '/ble_connection');
            },
            child: const Text('Go to BLE Setup'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.grey[200],

      body: SafeArea(
        child: Column(
          children: [

            // 🔶 HEADER
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
              child: const Row(
                children: [
                  Icon(Icons.waving_hand, color: Colors.white),
                  SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "GabayKamay",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "Filipino Sign Language",
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  )
                ],
              ),
            ),

            const SizedBox(height: 10),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.bluetooth),
                      label: const Text('BLE Setup'),
                      onPressed: () {
                        Navigator.of(context).pushNamed('/ble_connection');
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
            ),

            const SizedBox(height: 10),

            // 🔄 PAGES (NO RELOAD)
            Expanded(
              child: IndexedStack(
                index: currentIndex,
                children: const [
                  TrainingScreen(),
                  TranslateScreen(),
                  DictionaryScreen(),
                  CalibrationScreen(), // ✅ NEW PAGE
                ],
              ),
            ),
          ],
        ),
      ),

      // 🔻 BOTTOM NAVBAR
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

            navItem(Icons.fitness_center, "Training", 0, !_bleState.areBothConnected),
            navItem(Icons.translate, "Translate", 1, !_bleState.areBothConnected),
            navItem(Icons.book, "Dictionary", 2, !_bleState.areBothConnected),
            navItem(Icons.tune, "Calibrate", 3, !_bleState.areBothConnected), // ✅ NEW ICON

          ],
        ),
      ),
    );
  }

  // 🔹 NAV ITEM WITH ANIMATION
  Widget navItem(IconData icon, String label, int index, bool isDisabled) {

    final active = currentIndex == index;

    return GestureDetector(
      onTap: isDisabled
          ? () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('⚠️ Please connect both gloves first!'),
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

            // 🔼 LIFT + SCALE EFFECT (with opacity when disabled)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              transform: Matrix4.translationValues(0, active && !isDisabled ? -6 : 0, 0),
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
                fontWeight: active && !isDisabled ? FontWeight.bold : FontWeight.normal,
                color: active && !isDisabled ? primaryOrange : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
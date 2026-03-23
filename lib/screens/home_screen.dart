import 'package:flutter/material.dart';
import 'training_screen.dart';
import 'translate_screen.dart';
import 'dictionary_screen.dart';
import 'calibration_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  int currentIndex = 1; // default = Translate

  final Color primaryOrange = Colors.orange;

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

            navItem(Icons.fitness_center, "Training", 0),
            navItem(Icons.translate, "Translate", 1),
            navItem(Icons.book, "Dictionary", 2),
            navItem(Icons.tune, "Calibrate", 3), // ✅ NEW ICON

          ],
        ),
      ),
    );
  }

  // 🔹 NAV ITEM WITH ANIMATION
  Widget navItem(IconData icon, String label, int index) {

    final active = currentIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          currentIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            // 🔼 LIFT + SCALE EFFECT
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              transform: Matrix4.translationValues(0, active ? -6 : 0, 0),
              child: AnimatedScale(
                scale: active ? 1.2 : 1,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutBack,
                child: Icon(
                  icon,
                  color: active ? primaryOrange : Colors.black,
                ),
              ),
            ),

            const SizedBox(height: 4),

            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
                color: active ? primaryOrange : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
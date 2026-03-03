import 'package:flutter/material.dart';
import 'home_screen.dart';

class TrainingScreen extends StatefulWidget {
  const TrainingScreen({super.key});

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

int currentIndex = 0; // 0 = Training, 1 = Translation, 2 = Dictionary

class _TrainingScreenState extends State<TrainingScreen> {
  static const Color primaryOrange = Color(0xFFFF8C1A);

  final TextEditingController wordController = TextEditingController();
  int samples = 0;

  void startRecording() {
    setState(() {
      samples = 120; // fake number for now
    });
  }

  void saveGesture() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Gesture saved successfully!")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      body: Column(
        children: [
          /// 🔶 Custom Header (Same as Translate Screen)
          Container(
            padding: const EdgeInsets.only(
              top: 50,
              left: 20,
              right: 20,
              bottom: 25,
            ),
            decoration: const BoxDecoration(
              color: primaryOrange,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
            ),
            child: Row(
              children: [
                /// Clickable Hand → Home
                GestureDetector(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HomeScreen(),
                      ),
                    );
                  },
                  child: const Icon(
                    Icons.waving_hand_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "GabayKamay",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      "Filipino Sign Language",
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          /// 🖐 Gesture Illustration Placeholder
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: const [
              Icon(Icons.back_hand, size: 50),
              Icon(Icons.pan_tool_alt, size: 50),
              Icon(Icons.front_hand, size: 50),
            ],
          ),

          const SizedBox(height: 40),

          /// 📝 Word Input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: TextField(
              controller: wordController,
              decoration: InputDecoration(
                hintText: "Enter word",
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),

          const SizedBox(height: 25),

          /// 🔵 Start Recording Button
          GestureDetector(
            onTap: startRecording,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.blue.shade200,
                borderRadius: BorderRadius.circular(25),
              ),
              child: const Text(
                "Start recording gestures",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),

          const SizedBox(height: 20),

          Text(
            "Samples Recorded : $samples",
            style: const TextStyle(letterSpacing: 1),
          ),

          const SizedBox(height: 25),

          /// 🔵 Save Gesture Button
          GestureDetector(
            onTap: saveGesture,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.blue.shade200,
                borderRadius: BorderRadius.circular(25),
              ),
              child: const Text(
                "Save gesture",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),

          const Spacer(),

          /// 🔶 Same Bottom Navigation as Translation Screen
          Container(
            height: 75,
            decoration: const BoxDecoration(
              color: primaryOrange,
              borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(Icons.psychology, "Training", 0),
                _navItem(Icons.translate, "Translation", 1),
                _navItem(Icons.menu_book, "Dictionary", 2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    final bool active = currentIndex == index;

    return GestureDetector(
      onTap: () {
        if (index == currentIndex) return;

        switch (index) {
          case 0:
            Navigator.pushReplacementNamed(context, '/training');
            break;
          case 1:
            Navigator.pushReplacementNamed(context, '/translate');
            break;
          case 2:
            Navigator.pushReplacementNamed(context, '/dictionary');
            break;
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: active ? primaryOrange : Colors.black,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight:
                    active ? FontWeight.bold : FontWeight.normal,
                color: active ? primaryOrange : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
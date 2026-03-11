import 'package:flutter/material.dart';
import 'training_screen.dart';
import 'translate_screen.dart';
import 'dictionary_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  static const Color primaryOrange = Color(0xFFFF8C1A);

  int currentIndex = 1;

  final List<Widget> pages = const [
    TrainingScreen(),
    TranslateScreen(),
    DictionaryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade200,

      body: Column(
        children: [

          /// HEADER
          Container(
            padding: const EdgeInsets.only(
              top: 50,
              left: 20,
              right: 20,
              bottom: 25,
            ),
            decoration: const BoxDecoration(
              color: primaryOrange,
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(30),
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.waving_hand_rounded,
                  color: Colors.white,
                  size: 32,
                ),
                SizedBox(width: 12),
                Column(
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
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          /// PAGES
          Expanded(
            child: IndexedStack(
              index: currentIndex,
              children: pages,
            ),
          ),

          /// NAVBAR
          Container(
            height: 70,
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: primaryOrange,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                navItem(Icons.fitness_center, "Training", 0),
                navItem(Icons.translate, "Translate", 1),
                navItem(Icons.menu_book, "Dictionary", 2),
              ],
            ),
          )
        ],
      ),
    );
  }

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
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),

      decoration: BoxDecoration(
        color: active ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
      ),

      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [

          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            transform: Matrix4.translationValues(
              0,
              active ? -8 : 0,
              0,
            ),

            child: AnimatedScale(
              duration: const Duration(milliseconds: 250),
              scale: active ? 1.2 : 1,
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
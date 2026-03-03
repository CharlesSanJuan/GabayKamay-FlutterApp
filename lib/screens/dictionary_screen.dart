import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_screen.dart';

class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key});

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

int currentIndex = 2; // 0 = Training, 1 = Translation, 2 = Dictionary

class _DictionaryScreenState extends State<DictionaryScreen> {
  static const Color primaryOrange = Color(0xFFFF8C1A);

  late Future<List<Map<String, dynamic>>> _gesturesFuture;

  @override
  void initState() {
    super.initState();
    _gesturesFuture = fetchGestures();
  }

  Future<List<Map<String, dynamic>>> fetchGestures() async {
    try {
      final response = await Supabase.instance.client
          .from('gesture_dictionary')
          .select()
          .order('created_at', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      body: Column(
        children: [
          /// 🔶 Custom Header
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
                      style:
                          TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
              ],
            ),
          ),

          /// 📖 Dictionary List
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _gesturesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(
                      child: Text('Error: ${snapshot.error}'));
                } else if (!snapshot.hasData ||
                    snapshot.data!.isEmpty) {
                  return const Center(
                      child: Text('No gestures found.'));
                }

                final gestures = snapshot.data!;

                return ListView.builder(
                  itemCount: gestures.length,
                  itemBuilder: (context, index) {
                    final gesture = gestures[index];

                    return InkWell(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: Text(
                                gesture['gesture_label'] ?? ''),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                    'Spoken Word: ${gesture['spoken_word'] ?? ''}'),
                                Text(
                                    'Language: ${gesture['language'] ?? ''}'),
                                if ((gesture['description'] ?? '')
                                    .isNotEmpty)
                                  Text(
                                      'Description: ${gesture['description']}'),
                              ],
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 20),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.black26,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              gesture['gesture_label'] ?? '',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              gesture['spoken_word'] ?? '',
                              style: const TextStyle(
                                fontSize: 14,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          /// 🔶 Bottom Navigation (Same Style)
          Container(
            height: 75,
            decoration: const BoxDecoration(
              color: primaryOrange,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(25),
              ),
            ),
            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceAround,
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
            Navigator.pushReplacementNamed(
                context, '/training');
            break;
          case 1:
            Navigator.pushReplacementNamed(
                context, '/translate');
            break;
          case 2:
            Navigator.pushReplacementNamed(
                context, '/dictionary');
            break;
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color:
              active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: active
                  ? primaryOrange
                  : Colors.black,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: active
                    ? FontWeight.bold
                    : FontWeight.normal,
                color: active
                    ? primaryOrange
                    : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
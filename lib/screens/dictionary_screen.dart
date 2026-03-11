import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key});

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {

  late Future<List<Map<String, dynamic>>> gestures;

  @override
  void initState() {
    super.initState();
    gestures = fetchGestures();
  }

  Future<List<Map<String, dynamic>>> fetchGestures() async {

    final response = await Supabase.instance.client
        .from('gesture_dictionary')
        .select()
        .order('created_at', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  @override
  Widget build(BuildContext context) {

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: gestures,
      builder: (context, snapshot) {

        /// Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        /// Error
        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        /// No Data
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text("No gestures found"),
          );
        }

        final data = snapshot.data!;

        return ListView.builder(
          itemCount: data.length,
          itemBuilder: (context, index) {

            final gesture = data[index];

            return InkWell(
              onTap: () {

                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text(gesture['gesture_label'] ?? ''),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        Text(
                          "Spoken Word: ${gesture['spoken_word'] ?? ''}",
                        ),

                        const SizedBox(height: 6),

                        Text(
                          "Language: ${gesture['language'] ?? ''}",
                        ),

                        const SizedBox(height: 6),

                        if ((gesture['description'] ?? '').isNotEmpty)
                          Text(
                            "Description: ${gesture['description']}",
                          ),
                      ],
                    ),
                  ),
                );

              },

              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.black26,
                    ),
                  ),
                ),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
    );
  }
}
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key});

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
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
      print('Supabase response: $response');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Supabase fetch error: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Dictionary")),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _gesturesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No gestures found.'));
          }
          final gestures = snapshot.data!;
          return ListView.builder(
            itemCount: gestures.length,
            itemBuilder: (context, index) {
              final gesture = gestures[index];
              return ListTile(
                title: Text(gesture['gesture_label'] ?? ''),
                subtitle: Text(gesture['spoken_word'] ?? ''),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text(gesture['gesture_label'] ?? ''),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Spoken Word: ${gesture['spoken_word'] ?? ''}'),
                          Text('Language: ${gesture['language'] ?? ''}'),
                          if ((gesture['description'] ?? '').isNotEmpty)
                            Text('Description: ${gesture['description']}'),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
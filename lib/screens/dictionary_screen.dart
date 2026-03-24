import 'package:flutter/material.dart';

class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key});

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  // Local gesture dictionary (no longer using Supabase)
  final List<Map<String, String>> gestures = [
    {'word': 'Hello', 'meaning': 'A greeting gesture'},
    {'word': 'Thank You', 'meaning': 'Expression of gratitude'},
    {'word': 'Yes', 'meaning': 'Affirmative response'},
    {'word': 'No', 'meaning': 'Negative response'},
    {'word': 'Please', 'meaning': 'Polite request'},
    {'word': 'Sorry', 'meaning': 'Expression of apology'},
    {'word': 'Goodbye', 'meaning': 'Farewell gesture'},
    {'word': 'Love', 'meaning': 'Expression of affection'},
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: gestures.length,
      itemBuilder: (context, index) {
        final gesture = gestures[index];

        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(
              gesture['word'] ?? 'Unknown',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              gesture['meaning'] ?? 'No description',
            ),
          ),
        );
      },
    );
  }
}
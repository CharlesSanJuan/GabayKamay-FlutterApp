import 'package:flutter/material.dart';

class DictionaryScreen extends StatelessWidget {
  const DictionaryScreen({super.key});

  final List<String> words = const [
    "HELLO",
    "THANK YOU",
    "YES",
    "NO",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Dictionary")),
      body: ListView.builder(
        itemCount: words.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(words[index]),
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text(words[index]),
                  content: const Text(
                    "Finger positions and gesture description here.",
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

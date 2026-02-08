import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Smart Glove Translator")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/translate'),
              child: const Text("Translate Mode"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/training'),
              child: const Text("Training Mode"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/dictionary'),
              child: const Text("Dictionary"),
            ),
          ],
        ),
      ),
    );
  }
}

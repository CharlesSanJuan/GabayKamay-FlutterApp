import 'package:flutter/material.dart';

import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/translate_screen.dart';
import 'screens/training_screen.dart';
import 'screens/dictionary_screen.dart';
import 'screens/ble_connection_screen.dart';
import 'screens/ble_debug_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GabayKamay',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/home': (context) => const HomeScreen(),
        '/translate': (context) => const TranslateScreen(),
        '/training': (context) => const TrainingScreen(),
        '/dictionary': (context) => const DictionaryScreen(),
        '/ble_connection': (context) => const BleConnectionScreen(),
        '/ble_debug': (context) => const BleDebugScreen(),
      },
    );
  }
}

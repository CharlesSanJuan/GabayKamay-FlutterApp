import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/translate_screen.dart';
import 'screens/training_screen.dart';
import 'screens/dictionary_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://ptpddajvnigunaxaaddy.supabase.co',
    anonKey: 'sb_publishable_UXEG3bJJCfdfS63kACDpjw_ffYPkfeg',
  );

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
      },
    );
  }
}
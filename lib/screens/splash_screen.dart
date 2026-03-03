import 'package:flutter/material.dart';
import 'package:gabay_kamay/animated_splash_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _waveController;
  late AnimationController _screenController;

  late Animation<double> _waveRotation;
  late Animation<Offset> _screenSlide;

  @override
  void initState() {
    super.initState();

    // 🖐 Hand wave
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _waveRotation = Tween<double>(begin: 0.1, end: -0.1).animate(
      CurvedAnimation(parent: _waveController, curve: Curves.easeInOut),
    );

    // Screen exit animation
    _screenController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _screenSlide = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -1),
    ).animate(
      CurvedAnimation(
        parent: _screenController,
        curve: Curves.easeInOutQuart,
      ),
    );

    _startSequence();
  }

  Future<void> _startSequence() async {
    await Future.delayed(const Duration(milliseconds: 300));

    // Wave 4 times
    for (int i = 0; i < 4; i++) {
      await _waveController.forward();
      await _waveController.reverse();
    }

    await Future.delayed(const Duration(seconds: 1));

    await _screenController.forward();
    if (mounted) Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  void dispose() {
    _waveController.dispose();
    _screenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _screenSlide,
      child: Scaffold(
        backgroundColor: const Color(0xFFFF8C1A),
        body: Center(
          child: AnimatedSplashLogo(
            waveRotation: _waveRotation,
          ),
        ),
      ),
    );
  }
}
import 'dart:ui';

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
  late AnimationController _moveController;
  late AnimationController _screenController;

  late Animation<double> _waveRotation;
  late Animation<double> _textOpacity;
  late Animation<Offset> _screenSlide;
  
  @override
  void initState() {
    super.initState();

    // 1. Hand Waving - Snappy but smooth
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _waveRotation = Tween<double>(begin: 0.1, end: -0.1).animate(
      CurvedAnimation(parent: _waveController, curve: Curves.easeInOut),
    );

    // 2. Movement - Using a "Cubic" curve for that premium feel
    _moveController = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 1000,
      ), // Slightly longer for smoothness
    );

    _textOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _moveController,
        // Text starts fading in halfway through the move
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );

    // 3. Screen Exit
    _screenController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _screenSlide = Tween<Offset>(begin: Offset.zero, end: const Offset(0, -1))
        .animate(
          CurvedAnimation(
            parent: _screenController,
            curve: Curves.easeInOutQuart,
          ),
        );

    _startSequence();
  }

  Future<void> _startSequence() async {
    // Initial delay for the user to settle in
    await Future.delayed(const Duration(milliseconds: 300));

    // Wave 3 times
    for (int i = 0; i < 3; i++) {
      await _waveController.forward();
      await _waveController.reverse();
    }

    // Smooth transition: Hand moves and text fades
    await _moveController.forward();

    await Future.delayed(const Duration(seconds: 2));

    // Slide away
    await _screenController.forward();
    if (mounted) Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  void dispose() {
    _waveController.dispose();
    _moveController.dispose();
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
        child: AnimatedBuilder(
          animation: _moveController,
          builder: (context, child) {
            return AnimatedSplashLogo(
              waveRotation: _waveRotation,
              textOpacity: _textOpacity,
              moveProgress: _moveController,
            );
          },
        ),
      ),
    ),
  );
}
}

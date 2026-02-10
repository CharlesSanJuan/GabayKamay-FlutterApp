import 'dart:ui';
import 'package:flutter/material.dart';

class AnimatedSplashLogo extends StatelessWidget {
  final Animation<double> waveRotation;
  final Animation<double> textOpacity;
  final Animation<double> moveProgress;

  const AnimatedSplashLogo({
    super.key,
    required this.waveRotation,
    required this.textOpacity,
    required this.moveProgress,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    final double logoWidth = screenWidth.clamp(280, 420);
    final double handSize = logoWidth * 0.24;

    return SizedBox(
      width: logoWidth,
      height: handSize,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center, // ✅ FIX
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 🖐 HAND
          // 🖐 HAND (faces left, natural wave)
          Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..scale(-1.0, 1.0), // 👈 flip horizontally
            child: RotationTransition(
              turns: waveRotation,
              child: Image.asset(
                'assets/hand.png',
                width: handSize,
                height: handSize,
              ),
            ),
          ),

          const SizedBox(width: 12),

          // 📝 TEXT (center-safe reveal)
          FadeTransition(
            opacity: textOpacity,
            child: ClipRect(
              child: Align(
                alignment: Alignment.centerLeft,
                widthFactor: moveProgress.value,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GabayKamay',
                      style: TextStyle(
                        fontSize: logoWidth * 0.09,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Filipino Sign Language',
                      style: TextStyle(
                        fontSize: logoWidth * 0.045,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

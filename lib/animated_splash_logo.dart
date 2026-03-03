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

    // 🔥 Reduced hand size for tighter look
    final double handSize = logoWidth * 0.22;

    return Center(
      child: SizedBox(
        width: logoWidth,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 🖐 HAND
            Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()..scale(-1.0, 1.0),
              child: RotationTransition(
                turns: waveRotation,
                child: Image.asset(
                  'assets/hand.png',
                  width: handSize,
                  height: handSize,
                ),
              ),
            ),

            // 🔥 Very tight spacing
            const SizedBox(width: 0),

            // 📝 TEXT
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
                          fontSize: logoWidth * 0.075,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                          height: 1.0,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Filipino Sign Language',
                        style: TextStyle(
                          fontSize: logoWidth * 0.038,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                          height: 1.1,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

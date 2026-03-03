import 'package:flutter/material.dart';

class AnimatedSplashLogo extends StatelessWidget {
  final Animation<double> waveRotation;

  const AnimatedSplashLogo({
    super.key,
    required this.waveRotation,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final double logoSize = screenWidth.clamp(200, 300);

    return SizedBox(
      width: logoSize,
      height: logoSize,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..scale(-1.0, 1.0), // Flip horizontally
        child: RotationTransition(
          turns: waveRotation,
          child: Image.asset(
            'assets/hand.png',
            width: logoSize,
            height: logoSize,
          ),
        ),
      ),
    );
  }
}
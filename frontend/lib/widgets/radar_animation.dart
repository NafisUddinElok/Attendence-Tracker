import 'package:flutter/material.dart';

/// Basic static GPS Icon / Logo (no fancy animation)
class RadarAnimation extends StatelessWidget {
  final double size;
  final Color color;
  final int rings;

  const RadarAnimation({
    super.key,
    this.size = 80,
    this.color = Colors.blue,
    this.rings = 3,
  });

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.location_on,
      size: size * 0.7,
      color: color,
    );
  }
}

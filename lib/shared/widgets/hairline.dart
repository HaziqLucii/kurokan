import 'package:flutter/material.dart';

class Hairline extends StatelessWidget {
  final Color color;
  final double thickness;

  const Hairline({super.key, required this.color, this.thickness = 1});

  @override
  Widget build(BuildContext context) => Container(height: thickness, color: color);
}

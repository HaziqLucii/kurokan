import 'package:flutter/material.dart';

class SkeletonBlock extends StatelessWidget {
  final double width;
  final double height;
  final Color color;

  const SkeletonBlock({
    super.key,
    required this.width,
    required this.height,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: height,
    child: ColoredBox(color: color),
  );
}

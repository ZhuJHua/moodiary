import 'dart:math';

import 'package:flutter/material.dart';

class MoodiaryLoading extends StatelessWidget {
  const MoodiaryLoading({super.key, this.size = 24, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Center(child: CircularProgressIndicator(color: color));
  }
}

class MoodiarySyncing extends StatefulWidget {
  const MoodiarySyncing({super.key});

  @override
  State<MoodiarySyncing> createState() => _MoodiarySyncingState();
}

class _MoodiarySyncingState extends State<MoodiarySyncing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Transform.rotate(
            angle: _animation.value * 2 * pi,
            child: child,
          );
        },
        child: const Icon(Icons.sync_rounded),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

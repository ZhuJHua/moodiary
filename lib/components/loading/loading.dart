import 'package:flutter/material.dart';
import 'package:rive_animated_icon/rive_animated_icon.dart';

class Processing extends StatelessWidget {
  const Processing({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return LoopingRiveIcon(
      riveIcon: RiveIcon.reload,
      width: 80,
      height: 80,
      color: colorScheme.onSurface,
      strokeWidth: 4.0,
    );
  }
}

class SearchLoading extends StatelessWidget {
  const SearchLoading({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return LoopingRiveIcon(
      riveIcon: RiveIcon.search,
      width: 80,
      height: 80,
      color: colorScheme.onSurface,
      strokeWidth: 4.0,
    );
  }
}

class EditingLoading extends StatelessWidget {
  const EditingLoading({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return LoopingRiveIcon(
      riveIcon: RiveIcon.edit,
      width: 80,
      height: 80,
      color: colorScheme.onSurface,
      strokeWidth: 4.0,
    );
  }
}

class NetworkLoading1 extends StatelessWidget {
  const NetworkLoading1({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return LoopingRiveIcon(
      riveIcon: RiveIcon.wifi,
      width: 80,
      height: 80,
      color: colorScheme.onSurface,
      strokeWidth: 4.0,
    );
  }
}

class NetworkLoading2 extends StatelessWidget {
  const NetworkLoading2({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return LoopingRiveIcon(
      riveIcon: RiveIcon.globe,
      width: 80,
      height: 80,
      color: colorScheme.onSurface,
      strokeWidth: 4.0,
    );
  }
}

class MediaLoading extends StatelessWidget {
  final Color? color;

  final double? size;

  const MediaLoading({super.key, this.color, this.size});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return LoopingRiveIcon(
      riveIcon: RiveIcon.gallery,
      width: size ?? 80,
      height: size ?? 80,
      color: color ?? colorScheme.onSurface,
      strokeWidth: 4.0,
    );
  }
}

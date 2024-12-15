import 'package:flutter/material.dart';
import 'package:rive_animated_icon/rive_animated_icon.dart';

class Processing extends StatelessWidget {
  const Processing({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return RiveAnimatedIcon(
      riveIcon: RiveIcon.reload,
      width: 80,
      height: 80,
      color: colorScheme.onSurface,
      loopAnimation: true,
      splashFactory: NoSplash.splashFactory,
      mouseCursor: SystemMouseCursors.move,
      strokeWidth: 4.0,
    );
  }
}

class SearchLoading extends StatelessWidget {
  const SearchLoading({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return RiveAnimatedIcon(
      riveIcon: RiveIcon.search,
      width: 80,
      height: 80,
      color: colorScheme.onSurface,
      loopAnimation: true,
      splashFactory: NoSplash.splashFactory,
      mouseCursor: SystemMouseCursors.move,
      strokeWidth: 4.0,
    );
  }
}

class EditingLoading extends StatelessWidget {
  const EditingLoading({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return RiveAnimatedIcon(
      riveIcon: RiveIcon.edit,
      width: 80,
      height: 80,
      color: colorScheme.onSurface,
      loopAnimation: true,
      splashFactory: NoSplash.splashFactory,
      mouseCursor: SystemMouseCursors.move,
      strokeWidth: 4.0,
    );
  }
}

class NetworkLoading extends StatelessWidget {
  const NetworkLoading({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return RiveAnimatedIcon(
      riveIcon: RiveIcon.wifi,
      width: 80,
      height: 80,
      color: colorScheme.onSurface,
      loopAnimation: true,
      splashFactory: NoSplash.splashFactory,
      mouseCursor: SystemMouseCursors.move,
      strokeWidth: 4.0,
    );
  }
}

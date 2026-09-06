import 'package:material_ui/material_ui.dart';
import 'package:mui/src/foundation/back_gesture.dart';
import 'package:mui/src/themes/tokens.dart';
import 'package:mui/src/themes/value.dart';

const double _kParallaxFraction = 1 / 3;

const double _kScrimOpacity = 0.32;

const double _kFadeForwardsShift = 0.25;

class MuiPageTransitionsBuilder extends PageTransitionsBuilder with MuiValue {
  MuiPageTransitionsBuilder({
    required this.motion,
    required this.scrim,
    required this.radius,
  });

  final MuiMotion motion;

  final Color scrim;

  final double radius;

  static const Duration _kDuration = Duration(
    milliseconds: FadeForwardsPageTransitionsBuilder.kTransitionMilliseconds,
  );

  @override
  Duration get transitionDuration => _kDuration;

  @override
  List<Object?> get props => [motion, scrim, radius];

  static final Tween<Offset> _enter = Tween<Offset>(
    begin: const Offset(1, 0),
    end: Offset.zero,
  );

  static final Tween<Offset> _parallax = Tween<Offset>(
    begin: Offset.zero,
    end: const Offset(-_kParallaxFraction, 0),
  );

  static final Tween<double> _scrimAlpha = Tween<double>(
    begin: 0,
    end: _kScrimOpacity,
  );

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return MPredictiveBack(
      route: route,
      motion: motion,
      renderCurve: const _FadeForwardsShift(),
      child: route.popGestureInProgress
          ? _gestureTransition(animation, secondaryAnimation, child)
          : const FadeForwardsPageTransitionsBuilder().buildTransitions(
              route,
              context,
              animation,
              secondaryAnimation,
              child,
            ),
    );
  }

  Widget _gestureTransition(
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return SlideTransition(
      position: _parallax.animate(secondaryAnimation),
      transformHitTests: false,
      child: SlideTransition(
        position: _enter.animate(animation),
        child: ClipRRect(
          borderRadius: BorderRadius.horizontal(left: Radius.circular(radius)),
          child: _Scrim(
            color: scrim,
            opacity: _scrimAlpha.animate(secondaryAnimation),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _FadeForwardsShift extends Curve {
  const _FadeForwardsShift();

  @override
  double transformInternal(double t) =>
      1 -
      _kFadeForwardsShift * (1 - Curves.easeInOutCubicEmphasized.transform(t));
}

class _Scrim extends AnimatedWidget {
  const _Scrim({
    required Animation<double> opacity,
    required this.color,
    required this.child,
  }) : super(listenable: opacity);

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final opacity = (listenable as Animation<double>).value;
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: opacity <= 0
          ? const BoxDecoration()
          : BoxDecoration(color: color.withValues(alpha: opacity)),
      child: child,
    );
  }
}

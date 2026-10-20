import 'package:flutter/services.dart';
import 'package:mui/mui.dart';

/// Marks every Alpha route and overlay without intercepting input.
class BuildBadge extends StatelessWidget {
  const BuildBadge({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (appFlavor != 'alpha') return child;

    return Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: SafeArea(
                bottom: false,
                child: Banner(
                  message: 'ALPHA',
                  textDirection: TextDirection.ltr,
                  layoutDirection: TextDirection.ltr,
                  location: BannerLocation.topStart,
                  color: context.theme.colors.tertiary,
                  textStyle: context.theme.typography.labelSmall.onTertiary
                      .copyWith(height: 1),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

class Tutorial {
  static TutorialCoachMark getTutorial({required List<TargetFocus> targets}) {
    final colorScheme = Theme.of(Get.context!).colorScheme;
    return TutorialCoachMark(
        targets: targets,
        colorShadow: colorScheme.surfaceContainer.withValues(alpha: 0.8),
        // alignSkip: Alignment.bottomRight,
        // textSkip: "SKIP",
        // paddingFocus: 10,
        // focusAnimationDuration: Duration(milliseconds: 500),
        // unFocusAnimationDuration: Duration(milliseconds: 500),
        // pulseAnimationDuration: Duration(milliseconds: 500),
        // pulseVariation: Tween(begin: 1.0, end: 0.99),
        // showSkipInLastTarget: true,
        // imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        // initialFocus: 0,
        // useSafeArea: true,
        showSkipInLastTarget: false,
        hideSkip: true,
        onFinish: () {},
        onClickTargetWithTapPosition: (target, tapDetails) {},
        onClickTarget: (target) {},
        onSkip: () {
          return true;
        });

    // tutorial.skip();
    // tutorial.finish();
    // tutorial.next(); // call next target programmatically
    // tutorial.previous(); // call previous target programmatically
    // tutorial.goTo(3); // call target programmatically by index
  }

  static TargetContent buildTargetContent({
    required String title,
    String? description,
    ContentAlign align = ContentAlign.bottom,
  }) {
    final colorScheme = Theme.of(Get.context!).colorScheme;
    return TargetContent(
        align: align,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: 10,
          children: [
            Text(
              title,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (description != null)
              Text(
                description,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              )
          ],
        ));
  }
}

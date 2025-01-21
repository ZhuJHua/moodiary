import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:moodiary/main.dart';
import 'package:refreshed/refreshed.dart';

import 'start_logic.dart';

class StartPage extends StatelessWidget {
  const StartPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Bind.find<StartLogic>();

    final colorScheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(),
      extendBodyBehindAppBar: true,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 320,
              padding: const EdgeInsets.all(10.0),
              child: RichText(
                text: TextSpan(
                    children: [
                      TextSpan(text: l10n.startTitle1),
                      TextSpan(
                          text: l10n.startTitle2,
                          style: TextStyle(color: colorScheme.primary)),
                    ],
                    style: textStyle.titleLarge!
                        .copyWith(fontWeight: FontWeight.bold)),
                textAlign: TextAlign.center,
              ),
            ),
            Container(
              width: 320,
              padding: const EdgeInsets.all(10.0),
              child: Text(
                l10n.startTitle3,
                textAlign: TextAlign.center,
              ),
            ),
            Container(
                width: 320,
                padding: const EdgeInsets.all(10.0),
                child: RichText(
                  text: TextSpan(children: [
                    TextSpan(text: l10n.welcome1),
                    TextSpan(
                        text: l10n.welcome2,
                        style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            logic.toPrivacy();
                          }),
                    TextSpan(text: l10n.welcome3),
                    TextSpan(
                        text: l10n.welcome4,
                        style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            logic.toAgreement();
                          }),
                    TextSpan(text: l10n.welcome5)
                  ], style: textStyle.bodyLarge),
                )),
            Container(
              width: 320,
              padding: const EdgeInsets.all(10.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  FilledButton.tonal(
                      onPressed: () {
                        exit(0);
                      },
                      child: Text(l10n.startChoice1)),
                  FilledButton(
                      onPressed: () {
                        logic.toHome();
                      },
                      child: Text(l10n.startChoice2))
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

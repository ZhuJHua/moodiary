import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:get/get.dart';

import 'start_logic.dart';

class StartPage extends StatelessWidget {
  const StartPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Bind.find<StartLogic>();
    //final state = Bind.find<StartLogic>().state;
    final i18n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme;
    return GetBuilder<StartLogic>(
      init: logic,
      assignId: true,
      builder: (logic) {
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
                    text: TextSpan(children: [
                      TextSpan(text: i18n.startTitle1),
                      TextSpan(text: i18n.startTitle2, style: TextStyle(color: colorScheme.primary)),
                    ], style: textStyle.titleLarge!.copyWith(fontWeight: FontWeight.bold)),
                    textAlign: TextAlign.center,
                  ),
                ),
                Container(
                  width: 320,
                  padding: const EdgeInsets.all(10.0),
                  child: Text(
                    i18n.startTitle3,
                    textAlign: TextAlign.center,
                  ),
                ),
                Container(
                    width: 320,
                    padding: const EdgeInsets.all(10.0),
                    child: RichText(
                      text: TextSpan(children: [
                        TextSpan(text: i18n.welcome1),
                        TextSpan(
                            text: i18n.welcome2,
                            style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                logic.toPrivacy();
                              }),
                        TextSpan(text: i18n.welcome3),
                        TextSpan(
                            text: i18n.welcome4,
                            style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                logic.toAgreement();
                              }),
                        TextSpan(text: i18n.welcome5)
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
                          child: Text(i18n.startChoice1)),
                      FilledButton(
                          onPressed: () {
                            logic.toHome();
                          },
                          child: Text(i18n.startChoice2))
                    ],
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }
}

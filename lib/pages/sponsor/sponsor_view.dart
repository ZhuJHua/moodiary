import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:moodiary/components/base/button.dart';
import 'package:moodiary/l10n/l10n.dart';

import 'sponsor_logic.dart';

class SponsorPage extends StatelessWidget {
  const SponsorPage({super.key});

  Widget _buildWechat() {
    return Image.asset('res/sponsor/wechat.jpg');
  }

  @override
  Widget build(BuildContext context) {
    final SponsorLogic logic = Get.put(SponsorLogic());

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.aboutDonate),
        leading: const PageBackButton(),
      ),
      body: Stack(
        children: [
          Align(
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 24.0,
              children: [
                _buildWechat(),
                Text(context.l10n.hopeYouHappyToday),
                const FaIcon(FontAwesomeIcons.weixin),
              ],
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: logic.confettiController,
              blastDirectionality: BlastDirectionality.directional,
              blastDirection: pi / 2,
              emissionFrequency: 0.1,
              colors: const [
                Colors.green,
                Colors.blue,
                Colors.yellow,
                Colors.red,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

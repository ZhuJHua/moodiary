import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

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
        title: const Text('捐助'),
      ),
      body: Center(
        child: ConfettiWidget(
          confettiController:
              ConfettiController(duration: Duration(seconds: 1)),
          blastDirectionality: BlastDirectionality.explosive,
          shouldLoop: true,
          colors: const [
            Colors.green,
            Colors.blue,
            Colors.yellow,
            Colors.red,
          ],
          child: Container(
            child: Text('庆祝一下！'),
          ),
        ),
      ),
    );
  }
}

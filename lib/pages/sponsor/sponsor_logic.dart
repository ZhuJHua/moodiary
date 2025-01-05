import 'package:confetti/confetti.dart';
import 'package:get/get.dart';

class SponsorLogic extends GetxController {
  late final ConfettiController confettiController =
      ConfettiController(duration: const Duration(seconds: 2));

  @override
  void onReady() {
    confettiController.play();
    super.onReady();
  }

  @override
  void onClose() {
    confettiController.dispose();
    super.onClose();
  }
}

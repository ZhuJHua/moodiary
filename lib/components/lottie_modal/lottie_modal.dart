import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:moodiary/gen/assets.gen.dart';

enum LoadingType { material, fileProcess, cat }

class LottieModal extends StatelessWidget {
  final LoadingType type;

  const LottieModal({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        ModalBarrier(
          barrierSemanticsDismissible: false,
          dismissible: false,
          color: context.theme.colorScheme.surface.withAlpha(150),
        ),
        Lottie.asset(
          switch (type) {
            LoadingType.material => Assets.lottie.loadingMaterial,
            LoadingType.fileProcess => Assets.lottie.fileProcess,
            LoadingType.cat => Assets.lottie.loadingCat,
          },
          width: 250,
          height: 250,
          frameRate: FrameRate.max,
        ),
      ],
    );
  }
}

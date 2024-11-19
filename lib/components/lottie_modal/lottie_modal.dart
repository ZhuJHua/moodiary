import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

enum LoadingType {
  material('assets/lottie/loading_material.json'),
  fileProcess('assets/lottie/file_process.json'),
  cat('assets/lottie/loading_cat.json');

  final String value;

  const LoadingType(this.value);
}

class LottieModal extends StatelessWidget {
  final LoadingType type;

  const LottieModal({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Stack(
      alignment: Alignment.center,
      children: [
        ModalBarrier(
          barrierSemanticsDismissible: false,
          dismissible: false,
          color: colorScheme.surface.withAlpha(150),
        ),
        Lottie.asset(
          type.value,
          width: 250,
          height: 250,
          frameRate: FrameRate.max,
        ),
      ],
    );
  }
}

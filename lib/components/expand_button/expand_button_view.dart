import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'expand_button_logic.dart';

class ExpandButtonComponent extends StatelessWidget {
  final Map<IconData, Function()> operatorMap;

  const ExpandButtonComponent({super.key, required this.operatorMap});

  Widget _buildAnimatedIcon({
    required Animation<double> animation,
    required Function() onTap,
    required IconData icon,
    required int index,
    required Color color,
  }) {
    const double mainButtonHeight = 40.0;
    const double mainButtonSpacing = 8.0;

    double calculateVerticalTranslation(int index, double animationValue) {
      const double baseOffset = mainButtonHeight + mainButtonSpacing;
      return baseOffset * index * animationValue;
    }

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Positioned(
          left: calculateVerticalTranslation(index + 1, animation.value),
          child: Opacity(opacity: animation.value, child: child!),
        );
      },
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: color),
        style: const ButtonStyle(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ExpandButtonLogic logic = Get.put(ExpandButtonLogic());

    return AnimatedBuilder(
      animation: logic.animation,
      builder: (context, child) {
        return SizedBox(
          height: 40,
          width: 40 + ((operatorMap.length * 48) * logic.animation.value),
          child: child,
        );
      },
      child: Stack(
        children: [
          ...operatorMap.entries.map(
            (entry) => _buildAnimatedIcon(
              animation: logic.animation,
              onTap: entry.value,
              icon: entry.key,
              color: context.theme.colorScheme.secondary,
              index: operatorMap.keys.toList().indexOf(entry.key),
            ),
          ),
          IconButton.filled(
            onPressed: logic.animatedIcon,
            style: const ButtonStyle(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: AnimatedIcon(
              icon: AnimatedIcons.menu_close,
              progress: logic.animation,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:moodiary_core/moodiary_core.dart';

class ExpandButtonComponent extends StatefulWidget {
  final Map<IconData, Function()> operatorMap;

  const ExpandButtonComponent({super.key, required this.operatorMap});

  @override
  State<ExpandButtonComponent> createState() => _ExpandButtonComponentState();
}

class _ExpandButtonComponentState extends State<ExpandButtonComponent>
    with SingleTickerProviderStateMixin {
  late final AnimationController animationController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  late final Animation<double> animation = CurvedAnimation(
    parent: animationController,
    curve: Curves.easeInOutQuart,
  );

  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
  }

  void animatedIcon() {
    if (animationController.isCompleted) {
      animationController.reverse();
    } else {
      animationController.forward();
    }
  }

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
        style: const ButtonStyle(tapTargetSize: .shrinkWrap),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return SizedBox(
          height: 40,
          width: 40 + ((widget.operatorMap.length * 48) * animation.value),
          child: child,
        );
      },
      child: Stack(
        children: [
          ...widget.operatorMap.entries.map(
            (entry) => _buildAnimatedIcon(
              animation: animation,
              onTap: entry.value,
              icon: entry.key,
              color: context.theme.colorScheme.secondary,
              index: widget.operatorMap.keys.toList().indexOf(entry.key),
            ),
          ),
          IconButton.filled(
            onPressed: animatedIcon,
            style: const ButtonStyle(tapTargetSize: .shrinkWrap),
            icon: AnimatedIcon(
              icon: AnimatedIcons.menu_close,
              progress: animation,
            ),
          ),
        ],
      ),
    );
  }
}

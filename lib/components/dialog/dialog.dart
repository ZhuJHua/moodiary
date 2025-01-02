import 'package:flutter/material.dart';

import '../../common/values/border.dart';

class OptionDialog extends StatelessWidget {
  final String title;

  final Map<String, Function> options;

  const OptionDialog({super.key, required this.title, required this.options});

  Widget _buildOption(
      {required String option,
      required Function onTap,
      required ColorScheme colorScheme}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: AppBorderRadius.mediumBorderRadius,
          color: colorScheme.secondaryContainer,
        ),
        child: InkWell(
          borderRadius: AppBorderRadius.mediumBorderRadius,
          onTap: () {
            onTap.call();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(option,
                style: TextStyle(color: colorScheme.onSecondaryContainer)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SimpleDialog(
      title: Text(title),
      children: options.entries
          .map((entry) => _buildOption(
              option: entry.key, onTap: entry.value, colorScheme: colorScheme))
          .toList(),
    );
  }
}

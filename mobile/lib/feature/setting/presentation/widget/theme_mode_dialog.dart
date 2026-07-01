import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary/feature/setting/application/app_settings_controller.dart';

class ThemeModeDialog extends ConsumerWidget {
  const ThemeModeDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ValueListenableBuilder<int>(
      valueListenable: MoodiaryKVs.themeMode.getNotifier(),
      builder: (context, mode, _) {
        return SimpleDialog(
          title: const Text('主题模式'),
          children: [
            _Option(
              selected: mode == 0,
              icon: Icons.brightness_auto_outlined,
              label: '跟随系统',
              onTap: () => _select(context, ref, 0),
            ),
            _Option(
              selected: mode == 1,
              icon: Icons.light_mode_outlined,
              label: '浅色',
              onTap: () => _select(context, ref, 1),
            ),
            _Option(
              selected: mode == 2,
              icon: Icons.dark_mode_outlined,
              label: '深色',
              onTap: () => _select(context, ref, 2),
            ),
          ],
        );
      },
    );
  }

  /// 写 KV 后必须调 [AppSettingsController.bumpTheme] 让控制器重读 themeMode 并刷新
  /// MaterialApp（state 不是直接 watch KV，详见 app_settings_controller.dart）。
  Future<void> _select(BuildContext context, WidgetRef ref, int value) async {
    await MoodiaryKVs.themeMode.set(value);
    await ref.read(appSettingsControllerProvider.notifier).bumpTheme();
    if (context.mounted) Navigator.of(context).pop();
  }
}

class _Option extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _Option({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SimpleDialogOption(
      onPressed: onTap,
      child: Row(
        children: [
          Icon(selected ? Icons.check : icon),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_preferences/moodiary_preferences.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:mui/mui.dart';

class ThemeModeDialog extends ConsumerWidget {
  const ThemeModeDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ValueListenableBuilder<int>(
      valueListenable: MoodiaryKVs.themeMode.getNotifier(),
      builder: (context, mode, _) {
        return SimpleDialog(
          title: Text(context.l10n.app.themeMode),
          children: [
            _Option(
              selected: mode == 0,
              icon: LucideIcons.sunMoon,
              label: context.l10n.app.themeModeSystem,
              onTap: () => _select(context, ref, 0),
            ),
            _Option(
              selected: mode == 1,
              icon: LucideIcons.sun,
              label: context.l10n.app.themeModeLight,
              onTap: () => _select(context, ref, 1),
            ),
            _Option(
              selected: mode == 2,
              icon: LucideIcons.moon,
              label: context.l10n.app.themeModeDark,
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
    MoodiaryKVs.themeMode.set(value);
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
          Icon(selected ? LucideIcons.check : icon),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}

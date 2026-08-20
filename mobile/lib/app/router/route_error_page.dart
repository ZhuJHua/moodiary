import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:gap/gap.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_router/moodiary_router.dart';
import 'package:mui/mui.dart';

/// 路由解析失败时的兜底页。
///
/// go_router 自带的错误页也是按宿主类型选的，而它认不出 material_ui 的 `MaterialApp`
/// （详见 moodiary_router 的 route_page.dart），默认落到无样式的 widgets 版
/// `ErrorScreen`，所以这里自己给一个，走 `errorPageBuilder` 连转场一起带上。
class RouteErrorPage extends StatelessWidget {
  final Uri uri;
  final Exception? error;

  const RouteErrorPage({super.key, required this.uri, this.error});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const .symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: .min,
            children: [
              Icon(
                LucideIcons.compass,
                size: 48,
                color: theme.colors.onSurfaceVariant,
              ),
              const Gap(16),
              Text(
                l10n.app.routeErrorTitle,
                style: theme.typography.titleMedium.emphasized.onSurface,
              ),
              const Gap(8),
              Text(
                uri.toString(),
                textAlign: .center,
                style: theme.typography.bodySmall.onSurfaceVariant,
              ),
              if (kDebugMode && error != null) ...[
                const Gap(8),
                Text(
                  '$error',
                  textAlign: .center,
                  style: theme.typography.bodySmall.error,
                ),
              ],
              const Gap(24),
              FilledButton(
                onPressed: () => const DiaryHomeRoute().go(context),
                child: Text(l10n.app.routeErrorBackHome),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

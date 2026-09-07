import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:mui/mui.dart';

extension AsyncValueExtension<T> on AsyncValue<T> {
  Widget buildLoading({
    required Widget Function(T data) data,
    bool skipLoadingOnReload = true,
    Widget Function()? loading,
    Widget Function(Object error)? error,
  }) {
    return when(
      data: data,
      skipLoadingOnReload: skipLoadingOnReload,
      error: (e, s) {
        logger.e('async value error', error: e, stackTrace: s);
        if (error != null) return error(e);
        return Center(
          child: Builder(
            builder: (context) => Column(
              mainAxisSize: .min,
              children: [
                Icon(
                  LucideIcons.circleAlert,
                  color: context.theme.colors.outline,
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.common.loadFailed,
                  style: context.theme.typography.bodyMedium.secondary,
                ),
              ],
            ),
          ),
        );
      },
      loading: loading ?? () => const MLoading(),
    );
  }

  Widget buildEmpty({
    required Widget Function(T data) data,
    bool skipLoadingOnReload = true,
  }) {
    return when(
      data: data,
      skipLoadingOnReload: skipLoadingOnReload,
      error: (e, s) {
        return const SizedBox.shrink();
      },
      loading: () => const SizedBox.shrink(),
    );
  }
}

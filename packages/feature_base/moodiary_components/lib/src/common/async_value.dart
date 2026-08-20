import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:mui/mui.dart';

extension AsyncValueExtension<T> on AsyncValue<T> {
  Widget buildLoading({
    required Widget Function(T data) data,
    bool skipLoadingOnReload = true,
    // 传 `() => const SizedBox.shrink()` 可避免与下游遮罩出现两次 loading。
    Widget Function()? loading,
  }) {
    return when(
      data: data,
      skipLoadingOnReload: skipLoadingOnReload,
      error: (e, s) {
        logger.e('Error', error: e, stackTrace: s);
        return Center(child: Text('Error: $e'));
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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:mui/mui.dart';

import '../controllers/diary_filter.dart';

mixin DiaryPageScroll<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  final scrollController = ScrollController(keepScrollOffset: false);
  (DiaryFilter, DiarySort)? _query;

  void commitQuery(DiaryFilter filter, DiarySort sort) {
    final next = (filter, sort);
    final previous = _query;
    _query = next;
    if (previous == null || previous == next) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _query == next && scrollController.hasClients) {
        scrollController.jumpTo(0);
      }
    });
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }
}

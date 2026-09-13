import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_router/moodiary_router.dart';

const double _kRailCardWidth = 148;

class DiaryCitations extends StatefulWidget {
  final List<String> ids;
  final String? header;
  final bool raised;
  final VoidCallback? onRemove;

  const DiaryCitations({
    super.key,
    required this.ids,
    this.header,
    this.raised = false,
    this.onRemove,
  });

  @override
  State<DiaryCitations> createState() => _DiaryCitationsState();
}

// 折叠行每次展开都重建这个 widget，没有缓存就每次闪一帧 loading
final Map<String, Diary?> _diaryCache = {};

class _DiaryCitationsState extends State<DiaryCitations> {
  final Map<String, Diary?> _diaries = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    for (final id in widget.ids) {
      if (_diaryCache.containsKey(id)) _diaries[id] = _diaryCache[id];
    }
    _loaded = widget.ids.every(_diaries.containsKey);
    _load();
  }

  @override
  void didUpdateWidget(DiaryCitations oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ids.any((id) => !_diaries.containsKey(id))) _load();
  }

  Future<void> _load() async {
    final repo = getIt<DiaryRepository>();
    final ids = widget.ids;
    final found = await Future.wait(ids.map(repo.getDiaryByBusinessId));
    if (!mounted) return;
    var changed = !_loaded;
    for (final (i, id) in ids.indexed) {
      _diaryCache[id] = found[i];
      if (_diaries[id] != found[i]) changed = true;
      _diaries[id] = found[i];
    }
    if (!changed) return;
    setState(() => _loaded = true);
  }

  Widget _card(String id, {double? width}) {
    final diary = _diaries[id];
    final state = !_loaded && !_diaries.containsKey(id)
        ? DiaryCitationState.loading
        : diary == null
        ? DiaryCitationState.missing
        : diary.show
        ? DiaryCitationState.ready
        : DiaryCitationState.recycled;
    return DiaryCitationCard(
      state: state,
      time: diary?.time,
      title: diary?.title ?? '',
      mood: diary?.mood,
      weatherIcon: diary?.weather?.icon,
      width: width,
      color: widget.raised
          ? context.theme.colors.surfaceContainerHighest
          : null,
      onRemove: widget.onRemove,
      onTap: () => DiaryRoute(diaryId: id).push(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ids = widget.ids;
    if (ids.isEmpty) return const SizedBox.shrink();
    final header = widget.header;
    // 版式看篇数，标题看有没有传：两者各管各的
    if (ids.length == 1 && header == null) return _card(ids.single);

    final scheme = context.theme.colors;
    final typography = context.theme.typography;
    return Column(
      crossAxisAlignment: .start,
      mainAxisSize: .min,
      children: [
        if (header != null)
          Padding(
            padding: const .symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(
                  LucideIcons.bookOpenText,
                  size: 13,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  header,
                  style: typography.labelMedium.emphasized.onSurfaceVariant,
                ),
              ],
            ),
          ),
        SingleChildScrollView(
          scrollDirection: .horizontal,
          clipBehavior: .none,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: .stretch,
              children: [
                for (final (i, id) in ids.indexed) ...[
                  if (i > 0) const SizedBox(width: 8),
                  _card(id, width: _kRailCardWidth),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

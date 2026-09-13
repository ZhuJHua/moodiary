import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_router/moodiary_router.dart';

const double _kRailCardWidth = 148;

class DiaryCitations extends StatefulWidget {
  final List<String> ids;
  final bool raised;
  final VoidCallback? onRemove;

  const DiaryCitations({
    super.key,
    required this.ids,
    this.raised = false,
    this.onRemove,
  });

  @override
  State<DiaryCitations> createState() => _DiaryCitationsState();
}

class _DiaryCitationsState extends State<DiaryCitations> {
  final Map<String, Diary?> _diaries = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(DiaryCitations oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ids.any((id) => !_diaries.containsKey(id))) _load();
  }

  Future<void> _load() async {
    final repo = getIt<DiaryRepository>();
    final missing = [
      for (final id in widget.ids)
        if (!_diaries.containsKey(id)) id,
    ];
    final found = await Future.wait(missing.map(repo.getDiaryByBusinessId));
    if (!mounted) return;
    setState(() {
      for (final (i, id) in missing.indexed) {
        _diaries[id] = found[i];
      }
      _loaded = true;
    });
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
    if (ids.length == 1) return _card(ids.single);

    return Column(
      crossAxisAlignment: .start,
      mainAxisSize: .min,
      children: [
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

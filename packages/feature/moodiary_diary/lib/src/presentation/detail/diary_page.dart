import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_editor/moodiary_editor.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_ml/moodiary_ml.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_router/moodiary_router.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

import '../../application/mood_suggester.dart';
import '../place/place_editor.dart';
import 'hop_history.dart';

enum _Mode { read, edit }

class DiaryPage extends ConsumerStatefulWidget {
  final String? diaryId;

  final DiaryType initialType;

  final String? initialCategoryId;

  final bool startInEdit;

  const DiaryPage({
    super.key,
    this.diaryId,
    this.initialType = .markdown,
    this.initialCategoryId,
    this.startInEdit = false,
  });

  @override
  ConsumerState<DiaryPage> createState() => _DiaryPageState();
}

class _DiaryPageState extends ConsumerState<DiaryPage>
    with WidgetsBindingObserver, RouteAware {
  static const _autoSaveDebounce = Duration(seconds: 2);

  EditorFocusTarget _restoreFocusTarget = .none;

  _Mode _mode = .read;

  bool _dirty = false;

  bool _moodTouched = false;

  bool _autoFillTried = false;

  bool _weatherTouched = false;
  bool _placeTouched = false;

  LatLng? _fix;

  String? _suggestedForContent;

  Timer? _autoSaveTimer;

  String _saveStatus = 'idle';

  final ValueNotifier<int> _elapsed = ValueNotifier<int>(0);
  Timer? _writingTimer;

  late EditController _notifier;

  String? _guardId;

  ProviderSubscription<AsyncValue<Diary>>? _guardSub;

  final HopHistory _hops = HopHistory();

  bool _hopping = false;

  bool _selfReplace = false;

  Diary? _hopTarget;

  List<Diary> _outLinks = const [];
  List<Diary> _inLinks = const [];
  StreamSubscription<DiaryEvent>? _linksSub;
  Timer? _linksDebounce;

  int _linksToken = 0;

  String? _linksFor;

  final _scaffoldKey = GlobalKey<ScaffoldState>();

  final _editorController = MoodiaryEditorController();

  final ValueNotifier<int> _activeHeading = ValueNotifier<int>(-1);

  String? _headingsContent;
  List<({int level, String text})> _headings = const [];

  List<({int level, String text})> _headingsOf(String content) {
    if (content != _headingsContent) {
      _headingsContent = content;
      _headings = TiptapContent.parse(content).headings;
    }
    return _headings;
  }

  EditControllerProvider get _provider => editControllerProvider(
    widget.diaryId,
    defaultType: widget.initialType,
    defaultCategoryId: widget.initialCategoryId,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _writingTimer = .periodic(
      const Duration(seconds: 1),
      (_) => _elapsed.value++,
    );
    _notifier = ref.read(_provider.notifier);
    _mode = widget.startInEdit ? .edit : .read;
    final id = widget.diaryId;
    if (id != null) {
      _guardId = id;
      getIt<OpenDiaryRegistry>().open(id);
      _hops.reset(id);
    } else {
      _guardSub = ref.listenManual(_provider, (_, next) {
        final diary = next.value;
        if (diary != null && _guardId == null) {
          _guardId = diary.id;
          getIt<OpenDiaryRegistry>().open(diary.id);
        }
      });
    }
    _linksSub = getIt<DiaryRepository>().diaryEvents.listen((_) {
      _linksDebounce?.cancel();
      _linksDebounce = Timer(const Duration(milliseconds: 400), _loadLinks);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) moodiaryRouteObserver.subscribe(this, route);
  }

  @override
  void didPushNext() {
    _restoreFocusTarget = _mode == .edit
        ? _editorController.focusTarget
        : .none;
    unawaited(_editorController.blur());
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  void didPopNext() {
    final target = _restoreFocusTarget;
    _restoreFocusTarget = .none;
    if (target == .none || _mode != .edit) return;
    unawaited(
      target == .title
          ? _editorController.focusTitle()
          : _editorController.focus(),
    );
  }

  @override
  void didPop() {
    unawaited(_editorController.blur());
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  void didUpdateWidget(covariant DiaryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.diaryId == widget.diaryId) return;
    final self = _selfReplace;
    _selfReplace = false;
    final newId = widget.diaryId;
    if (newId == null) return;
    if (!self) {
      _hops.reset(newId);
      unawaited(_applyExternalSwap(newId));
    }
    _onDiaryChanged(newId);
  }

  void _onDiaryChanged(String newId) {
    final oldId = _guardId;
    _guardSub?.close();
    _guardSub = null;
    if (oldId != null && oldId != newId) {
      getIt<OpenDiaryRegistry>().close(oldId);
    }
    _guardId = newId;
    if (oldId != newId) getIt<OpenDiaryRegistry>().open(newId);
    _notifier = ref.read(_provider.notifier);
    _mode = widget.startInEdit ? .edit : .read;
    _dirty = false;
    _saveStatus = 'idle';
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
    _elapsed.value = 0;
    _activeHeading.value = -1;
  }

  Future<void> _applyExternalSwap(String id) async {
    final target = await getIt<DiaryRepository>().getDiaryByBusinessId(id);
    if (!mounted || target == null) return;
    setState(() => _hopTarget = target);
    await _editorController.swapDocument(
      content: target.content,
      title: target.title,
    );
  }

  @override
  void dispose() {
    moodiaryRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _activeHeading.dispose();
    _autoSaveTimer?.cancel();
    _writingTimer?.cancel();
    _elapsed.dispose();
    _linksDebounce?.cancel();
    _linksSub?.cancel();
    final guardSub = _guardSub;
    final guardId = _guardId;
    // ignore: discarded_futures
    () async {
      try {
        if (_dirty) await _notifier.autoSave();
      } finally {
        guardSub?.close();
        if (guardId != null) getIt<OpenDiaryRegistry>().close(guardId);
      }
    }();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final shouldFlush =
        state == .paused || state == .inactive || state == .hidden;
    if (shouldFlush && _dirty) _flushAutoSave();
  }

  void _onContentChanged(String content, String plain) {
    ref.read(_provider.notifier).changeContent(content, contentText: plain);
    _dirty = true;
    _scheduleAutoSave();
  }

  void _onTitleChanged(String value) {
    ref.read(_provider.notifier).changeTitle(value);
    _dirty = true;
    _scheduleAutoSave();
  }

  void _scheduleAutoSave() {
    if (_mode != .edit) return;
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(_autoSaveDebounce, _flushAutoSave);
  }

  Future<void> _flushAutoSave() async {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
    if (mounted) setState(() => _saveStatus = 'saving');
    final result = await ref.read(_provider.notifier).autoSave();
    final ok = result == .saved;
    if (ok) _dirty = false;
    if (!mounted) return;
    setState(() => _saveStatus = ok ? 'saved' : 'failed');
    if (ok) {
      unawaited(_maybeSuggestMood());
      unawaited(_maybeAutoFill());
    }
  }

  Future<void> _maybeSuggestMood() async {
    if (_moodTouched || widget.diaryId != null) return;
    final engine = getIt<MoodLlmEngine>();
    if (!engine.ready) return;
    final text = ref.read(_provider).value?.contentText.trim() ?? '';
    if (text.isEmpty || text == _suggestedForContent) return;
    _suggestedForContent = text;
    try {
      final mood = await suggestMood(engine, text);
      if (!mounted || _moodTouched) return;
      ref.read(_provider.notifier).changeMood(mood);
      _dirty = true;
      _scheduleAutoSave();
    } catch (e, s) {
      logger.e('suggest mood failed', error: e, stackTrace: s);
    }
  }

  Future<void> _onPickDate(Diary current) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current.time.toLocal(),
      firstDate: DateTime(1949, 10, 1),
      lastDate: .now(),
      switchToInputEntryModeIcon: const Icon(LucideIcons.keyboard),
      switchToCalendarEntryModeIcon: const Icon(LucideIcons.calendarDays),
    );
    if (picked == null || !mounted) return;
    ref.read(_provider.notifier).changeDate(picked);
    _dirty = true;
    _scheduleAutoSave();
  }

  Future<void> _onPickTime(Diary current) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: .fromDateTime(current.time.toLocal()),
      switchToInputEntryModeIcon: const Icon(LucideIcons.keyboard),
      switchToTimerEntryModeIcon: const Icon(LucideIcons.clock),
    );
    if (picked == null || !mounted) return;
    ref.read(_provider.notifier).changeTime(picked);
    _dirty = true;
    _scheduleAutoSave();
  }

  Future<void> _onPickCategory(Diary current) async {
    final (picked, category) = await CategoryPickerSheet.show(
      context: context,
      currentCategoryId: current.categoryId,
    );
    if (!picked || !mounted) return;
    ref.read(_provider.notifier).changeCategory(category?.id);
    _dirty = true;
    _scheduleAutoSave();
  }

  Future<void> _onAddTag(Diary current) async {
    final tag = await MAlert.prompt(
      context,
      title: l10n.diary.addTag,
      hintText: l10n.diary.tagNameHint,
      confirmLabel: l10n.diary.add,
    );
    if (tag == null || tag.isEmpty || !mounted) return;
    if (current.tags.contains(tag)) return;
    ref.read(_provider.notifier).changeTags([...current.tags, tag]);
    _dirty = true;
    _scheduleAutoSave();
  }

  void _onRemoveTag(Diary current, int index) {
    final next = [...current.tags]..removeAt(index);
    ref.read(_provider.notifier).changeTags(next);
    _dirty = true;
    _scheduleAutoSave();
  }

  void _onChangeMood(DiaryMood mood) {
    _moodTouched = true;
    ref.read(_provider.notifier).changeMood(mood);
    _dirty = true;
    _scheduleAutoSave();
  }

  void _onChangeWeather(String code) {
    final option = ManualWeather.fromCode(code);
    if (option == null) return;
    _weatherTouched = true;
    ref
        .read(_provider.notifier)
        .changeWeather(
          DiaryWeather(icon: option.code, text: option.label(context)),
        );
    _dirty = true;
    _scheduleAutoSave();
  }

  void _onClearWeather() {
    _weatherTouched = true;
    ref.read(_provider.notifier).changeWeather(null);
    _dirty = true;
    _scheduleAutoSave();
  }

  Future<void> _onFetchWeather() async {
    _weatherTouched = true;
    final result = await ref.read(_provider.notifier).fetchWeather(context);
    if (!mounted) return;
    final weather = result.weather;
    if (weather == null) {
      toast.error(message: _geoFailureMessage(result.failure, weather: true));
      return;
    }
    toast.success(
      message: l10n.diary.weatherFetched(weather: weather.displayText),
    );
    _dirty = true;
    _scheduleAutoSave();
  }

  Future<void> _onFetchPosition() async {
    _placeTouched = true;
    final result = await ref.read(_provider.notifier).fetchPosition(context);
    if (!mounted) return;
    if (result.place == null) {
      toast.error(message: _geoFailureMessage(result.failure));
      return;
    }
    _dirty = true;
    _scheduleAutoSave();
  }

  Future<void> _onLocateForPlaces() async {
    final located = await ref.read(_provider.notifier).locate();
    final fix = located.coords;
    if (!mounted || fix == null) return;
    setState(() => _fix = fix);
  }

  void _onPickPlace(String id) {
    final places = ref.read(orderedPlacesProvider).value ?? const <Place>[];
    if (!places.any((p) => p.id == id)) return;
    _placeTouched = true;
    ref.read(_provider.notifier).changePlace(id);
    _dirty = true;
    _scheduleAutoSave();
  }

  void _onClearPosition() {
    _placeTouched = true;
    ref.read(_provider.notifier).changePlace(null);
    _dirty = true;
    _scheduleAutoSave();
  }

  Future<void> _onNewPlace() async {
    _placeTouched = true;
    final fix = _fix;
    final saved = await showPlaceEditor(
      context,
      latitude: fix?.latitude,
      longitude: fix?.longitude,
    );
    if (saved == null || !mounted) return;
    ref.read(_provider.notifier).changePlace(saved.id);
    _dirty = true;
    _scheduleAutoSave();
  }

  String _geoFailureMessage(GeoFailure? failure, {bool weather = false}) =>
      switch (failure) {
        .notConfigured => l10n.diary.qweatherNotConfigured,
        .permissionDenied => l10n.diary.positionPermissionDenied,
        .permissionDeniedForever => l10n.diary.positionPermissionForever,
        .serviceOff => l10n.diary.positionServiceOff,
        _ => weather ? l10n.diary.weatherFailed : l10n.diary.positionFailed,
      };

  Future<void> _maybeAutoFill() async {
    if (_autoFillTried || widget.diaryId != null) return;
    final current = ref.read(_provider).value;
    if (current == null) return;
    final wantPlace =
        MoodiaryKVs.autoNearestPlace.get() == true && _placeUntouched;
    final wantApi = MoodiaryKVs.autoPosition.get() == true && _placeUntouched;
    final wantWeather =
        MoodiaryKVs.autoWeather.get() == true && _weatherUntouched;
    if (!wantPlace && !wantApi && !wantWeather) return;
    final qweatherReady =
        (wantApi || wantWeather) && await qweatherCredentials() != null;
    if (!mounted) return;
    if (!wantPlace && !qweatherReady) return;
    _autoFillTried = true;
    final notifier = ref.read(_provider.notifier);
    final located = await notifier.locate();
    final fix = located.coords;
    if (!mounted || fix == null) return;
    _fix = fix;
    var changed = false;
    if (wantPlace && _placeUntouched) {
      final places = ref.read(orderedPlacesProvider).value ?? const <Place>[];
      final hit = places.matchAt(fix.latitude, fix.longitude);
      if (hit != null) {
        notifier.changePlace(hit.id);
        changed = true;
      }
    }
    if (wantApi && qweatherReady && !changed && _placeUntouched) {
      final result = await notifier.fetchPosition(
        context,
        coords: fix,
        onlyIfUnset: true,
      );
      if (!mounted) return;
      changed = result.place != null && _placeUntouched;
    }
    if (wantWeather && qweatherReady && _weatherUntouched) {
      final result = await notifier.fetchWeather(
        context,
        coords: fix,
        onlyIfUnset: true,
      );
      if (!mounted) return;
      changed = changed || (result.weather != null && _weatherUntouched);
    }
    if (!changed) return;
    _dirty = true;
    if (_mode == .edit) {
      _scheduleAutoSave();
    } else {
      unawaited(_flushAutoSave());
    }
  }

  bool get _placeUntouched =>
      !_placeTouched && ref.read(_provider).value?.placeId == null;

  bool get _weatherUntouched =>
      !_weatherTouched && ref.read(_provider).value?.weather == null;

  @override
  Widget build(BuildContext context) {
    final editAsync = ref.watch(_provider);
    if (editAsync.hasValue && _hopTarget?.id == widget.diaryId) {
      _hopTarget = null;
    }
    final diary = editAsync.value ?? _hopTarget;
    final headings = diary == null
        ? const <({int level, String text})>[]
        : _headingsOf(diary.content);
    return PopScope(
      canPop: _hops.atRoot,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goHistory(-1);
      },
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          centerTitle: true,
          leadingWidth: _hops.length > 1 ? 144 : null,
          leading: _hops.length > 1
              ? Row(
                  children: [
                    IconButton(
                      tooltip: context.l10n.diary.home,
                      icon: const Icon(LucideIcons.house),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    IconButton(
                      tooltip: context.l10n.diary.goBack,
                      icon: const Icon(LucideIcons.arrowLeft),
                      onPressed: _hops.atRoot ? null : () => _goHistory(-1),
                    ),
                    IconButton(
                      tooltip: context.l10n.diary.goForward,
                      icon: const Icon(LucideIcons.arrowRight),
                      onPressed: _hops.peek(1) == null
                          ? null
                          : () => _goHistory(1),
                    ),
                  ],
                )
              : null,
          title: (_mode == .edit && diary != null) ? _writingPill(diary) : null,
          actions: [
            if (diary != null && _mode == .edit)
              IconButton(
                tooltip: context.l10n.common.save,
                icon: const Icon(LucideIcons.check),
                onPressed: _saveAndExit,
              ),
            if (diary != null &&
                _mode == .read &&
                DiaryType.fromValue(diary.type).isEditable)
              IconButton(
                tooltip: context.l10n.diary.edit,
                icon: const Icon(LucideIcons.squarePen),
                onPressed: _enterEdit,
              ),
            if (diary != null && _mode == .read)
              IconButton(
                tooltip: context.l10n.diary.share,
                icon: const Icon(LucideIcons.share),
                onPressed: () => DiaryShare.open(context, diary.id),
              ),
            if (headings.isNotEmpty)
              IconButton(
                tooltip: context.l10n.diary.outline,
                icon: const Icon(LucideIcons.tableOfContents),
                onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
              ),
          ],
        ),
        endDrawer: headings.isEmpty
            ? null
            : _TocDrawer(
                headings: headings,
                activeHeading: _activeHeading,
                onTap: (i) {
                  _editorController.scrollToHeading(i);
                  _scaffoldKey.currentState?.closeEndDrawer();
                },
              ),
        body: diary != null
            ? SafeArea(child: _buildBody(diary))
            : editAsync.buildLoading(
                loading: () => const SizedBox.shrink(),
                data: (d) => SafeArea(child: _buildBody(d)),
              ),
      ),
    );
  }

  static String _fmtDuration(int totalSec) {
    final h = totalSec ~/ 3600;
    final m = (totalSec % 3600) ~/ 60;
    final s = totalSec % 60;
    return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Widget _writingPill(Diary diary) {
    final typo = context.theme.typography;
    final showWords = MoodiaryKVs.showWordCount.get() ?? true;
    final showTime = MoodiaryKVs.showWritingTime.get() ?? true;
    final segs = <Widget>[
      if (showWords)
        _pillSeg(
          LucideIcons.text,
          context.l10n.diary.wordCount(count: diary.contentText.runes.length),
          typo.bodySmall.onSurfaceVariant,
        ),
      if (showTime)
        ValueListenableBuilder<int>(
          valueListenable: _elapsed,
          builder: (_, sec, _) => _pillSeg(
            LucideIcons.timer,
            _fmtDuration(sec),
            typo.bodySmall.onSurfaceVariant,
          ),
        ),
      _saveSeg(),
    ];
    final children = <Widget>[];
    for (var i = 0; i < segs.length; i++) {
      if (i > 0) {
        children.add(Text(' · ', style: typo.bodySmall.outline));
      }
      children.add(segs[i]);
    }
    return FittedBox(
      fit: .scaleDown,
      child: Container(
        padding: const .symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: context.theme.colors.surfaceContainerHighest,
          borderRadius: .circular(20),
        ),
        child: Row(mainAxisSize: .min, children: children),
      ),
    );
  }

  Widget _pillSeg(IconData icon, String text, TextStyle style) {
    return Row(
      mainAxisSize: .min,
      children: [
        Icon(icon, size: 13, color: style.color),
        const SizedBox(width: 3),
        Text(
          text,
          style: style.copyWith(fontFeatures: const [.tabularFigures()]),
        ),
      ],
    );
  }

  Widget _saveSeg() {
    final typo = context.theme.typography;
    switch (_saveStatus) {
      case 'saving':
        return Row(
          mainAxisSize: .min,
          children: [
            const SizedBox(
              width: 11,
              height: 11,
              child: CircularProgressIndicator(strokeWidth: 1.6),
            ),
            const SizedBox(width: 4),
            Text(
              context.l10n.diary.saving,
              style: typo.bodySmall.onSurfaceVariant,
            ),
          ],
        );
      case 'saved':
        return _pillSeg(
          LucideIcons.circleCheck,
          context.l10n.diary.saved,
          typo.bodySmall.primary,
        );
      case 'failed':
        return _pillSeg(
          LucideIcons.circleAlert,
          context.l10n.diary.unsaved,
          typo.bodySmall.error,
        );
      default:
        return _pillSeg(
          LucideIcons.cloudCheck,
          context.l10n.diary.autoSaved,
          typo.bodySmall.onSurfaceVariant,
        );
    }
  }

  void _enterEdit() {
    setState(() => _mode = .edit);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _editorController.focus(),
    );
  }

  Future<void> _saveAndExit() async {
    if (_dirty) {
      await _flushAutoSave();
      if (!mounted) return;
      if (_saveStatus != 'saved') {
        toast.error(message: l10n.diary.saveFailed);
        return;
      }
      toast.success(message: l10n.diary.saved);
    }
    if (!mounted) return;
    setState(() => _mode = .read);
  }

  Widget _buildBody(Diary diary) {
    _ensureLinksLoaded(diary.id);
    return EditorBody(
      key: const ValueKey('diary-editor'),
      type: .fromValue(diary.type),
      initialContent: diary.content,
      initialTitle: diary.title,
      editable: _mode == .edit,
      saveStatus: _saveStatus,
      onChanged: _onContentChanged,
      onTitleChanged: _onTitleChanged,
      editorController: _editorController,
      onActiveHeadingChanged: (i) => _activeHeading.value = i,
      onOpenDiaryLink: _openLinkedDiary,
      metaJson: _metaJson(diary),
      linksJson: _linksJson(),
      onPickDate: () => _onPickDate(diary),
      onPickTime: () => _onPickTime(diary),
      onPickCategory: () => _onPickCategory(diary),
      onAddTag: () => _onAddTag(diary),
      onRemoveTag: (i) => _onRemoveTag(diary, i),
      onChangeMood: _onChangeMoodName,
      onChangeWeather: _onChangeWeather,
      onClearWeather: _onClearWeather,
      onFetchWeather: _onFetchWeather,
      onFetchPosition: _onFetchPosition,
      onLocateForPlaces: _onLocateForPlaces,
      onPickPlace: _onPickPlace,
      onNewPlace: _onNewPlace,
      onManagePlaces: () => const PlaceManagerRoute().push(context),
      onClearPosition: _onClearPosition,
      onOpenGraph: () => DiaryGraphRoute(diaryId: diary.id).push(context),
    );
  }

  void _onChangeMoodName(String name) {
    final mood = DiaryMood.values.where((m) => m.name == name).firstOrNull;
    if (mood == null) return;
    _onChangeMood(mood);
  }

  String _metaJson(Diary diary) {
    final weather = diary.weather;
    final categoryAsync = ref.watch(
      getCategoryProvider(id: diary.categoryId ?? ''),
    );
    final categoryLabel = diary.categoryId == null
        ? null
        : categoryAsync.maybeWhen(
            data: (c) => c?.categoryName ?? context.l10n.diary.unknownCategory,
            orElse: () => context.l10n.diary.loading,
          );
    final qweatherHost = MoodiaryKVs.qweatherApiHost.get();
    final qweatherKey = ref
        .watch(secretKvProvider(MoodiarySecureKVs.qweatherKey))
        .value;
    final qweatherReady =
        (qweatherHost?.isNotEmpty ?? false) &&
        (qweatherKey?.isNotEmpty ?? false);
    final places = ref.watch(orderedPlacesProvider).value ?? const <Place>[];
    final place = places.where((p) => p.id == diary.placeId).firstOrNull;
    final fix = _fix;
    final placeRows = [
      for (final p in places)
        (
          place: p,
          meters: fix == null
              ? null
              : distanceMeters(
                  fix.latitude,
                  fix.longitude,
                  p.latitude,
                  p.longitude,
                ),
        ),
    ];
    if (fix != null) {
      placeRows.sort((a, b) => a.meters!.compareTo(b.meters!));
    }
    final sub = TimeFormat.weekdayTimeHms(diary.time);
    final words = context.l10n.diary.wordCount(
      count: diary.contentText.runes.length,
    );
    return jsonEncode({
      'dateText': TimeFormat.anchorDate(diary.time),
      'subText': sub,
      'subTextRead': '$sub · $words',
      'mood': diary.mood.name,
      'moods': [
        for (final mood in DiaryMood.values)
          {
            'value': mood.name,
            'label': mood.label(context),
            'color': _hexColor(mood.color),
            'icon': mood.iconName,
          },
      ],
      'category': categoryLabel,
      'weather': weather == null
          ? null
          : {'icon': weather.icon, 'text': weather.displayText},
      'weatherOptions': [
        for (final w in ManualWeather.values)
          {'code': w.code, 'label': w.label(context)},
      ],
      'weatherAutoLabel': qweatherReady ? context.l10n.diary.weatherAuto : null,
      'weatherClearLabel': context.l10n.diary.weatherClear,
      'position': place?.name,
      'positionId': place?.id,
      'places': [
        for (final row in placeRows)
          {
            'id': row.place.id,
            'name': row.place.name,
            'icon': row.place.icon ?? 'map-pin',
            'distance': row.meters == null
                ? null
                : formatDistance(context, row.meters!),
          },
      ],
      'positionAutoLabel': qweatherReady
          ? context.l10n.diary.positionAuto
          : null,
      'positionNewPlaceLabel': context.l10n.diary.positionNewPlace,
      'positionManageLabel': context.l10n.diary.positionManagePlaces,
      'positionClearLabel': context.l10n.diary.positionClear,
      'tags': diary.tags,
      'deleteLabel': context.l10n.common.delete,
    });
  }

  static String _hexColor(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  String _linksJson() {
    Map<String, dynamic> item(Diary d) {
      final hasTitle = d.title.trim().isNotEmpty;
      final title = hasTitle ? d.title.trim() : TimeFormat.longDate(d.time);
      var snippet = d.contentText.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (snippet.length > 80) snippet = snippet.substring(0, 80);
      final subtitle = hasTitle && snippet.isNotEmpty
          ? '${TimeFormat.longDate(d.time)} · $snippet'
          : snippet;
      return {
        'id': d.id,
        'title': title,
        if (subtitle.isNotEmpty) 'subtitle': subtitle,
      };
    }

    return jsonEncode({
      'title': context.l10n.diary.graphLinks,
      'outgoingLabel': context.l10n.diary.graphOutgoing,
      'incomingLabel': context.l10n.diary.graphIncoming,
      'graphTip': context.l10n.diary.graphLocal,
      'outgoing': [for (final d in _outLinks) item(d)],
      'incoming': [for (final d in _inLinks) item(d)],
    });
  }

  void _ensureLinksLoaded(String id) {
    if (_linksFor == id) return;
    _linksFor = id;
    unawaited(_loadLinks());
  }

  Future<void> _loadLinks() async {
    final id = _linksFor;
    if (id == null) return;
    final token = ++_linksToken;
    final repo = getIt<DiaryRepository>();
    final results = await Future.wait([
      repo.getForwardLinks(id),
      repo.getBacklinks(id),
    ]);
    if (!mounted || token != _linksToken) return;
    setState(() {
      _outLinks = results[0];
      _inLinks = results[1];
    });
  }

  Future<void> _openLinkedDiary(String id) async {
    if (_hopping) return;
    if (id == _guardId) return;
    _hopping = true;
    try {
      final target = await getIt<DiaryRepository>().getDiaryByBusinessId(id);
      if (!mounted) return;
      if (target == null) {
        toast.error(message: context.l10n.diary.linkNotFound);
        return;
      }
      await _hopTo(target);
    } finally {
      _hopping = false;
    }
  }

  Future<void> _hopTo(Diary target) async {
    if (!await _flushBeforeHop()) return;
    if (_hops.isEmpty) {
      final seedId = _guardId;
      if (seedId == null) return;
      _hops.reset(seedId);
    }
    _hops.current?.scrollY = await _editorController.getScrollY();
    if (!mounted) return;
    _hops.push(target.id);
    await _showEntry(target, scrollY: 0);
  }

  Future<void> _goHistory(int delta) async {
    if (_hopping) return;
    _hopping = true;
    try {
      if (!await _flushBeforeHop()) return;
      _hops.current?.scrollY = await _editorController.getScrollY();
      if (!mounted) return;
      while (true) {
        final entry = _hops.peek(delta);
        if (entry == null) return;
        final target = await getIt<DiaryRepository>().getDiaryByBusinessId(
          entry.diaryId,
        );
        if (!mounted) return;
        if (target == null) {
          _hops.dropNext(delta);
          continue;
        }
        _hops.move(delta);
        await _showEntry(target, scrollY: entry.scrollY);
        return;
      }
    } finally {
      _hopping = false;
    }
  }

  Future<bool> _flushBeforeHop() async {
    if (!_dirty) return true;
    await _flushAutoSave();
    if (!mounted) return false;
    if (_saveStatus == 'failed') {
      toast.error(message: l10n.diary.saveFailed);
      return false;
    }
    return true;
  }

  Future<void> _showEntry(Diary target, {required double scrollY}) async {
    setState(() {
      _mode = .read;
      _hopTarget = target;
    });
    await _editorController.swapDocument(
      content: target.content,
      title: target.title,
      scrollY: scrollY,
    );
    if (!mounted) return;
    _selfReplace = true;
    DiaryRoute(
      type: DiaryType.fromValue(target.type).routeQuery,
      diaryId: target.id,
    ).replace(context);
  }
}

class _TocDrawer extends StatelessWidget {
  final List<({int level, String text})> headings;
  final ValueNotifier<int> activeHeading;
  final ValueChanged<int> onTap;

  const _TocDrawer({
    required this.headings,
    required this.activeHeading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final typo = context.theme.typography;
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: .stretch,
          children: [
            Padding(
              padding: const .fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.tableOfContents,
                    size: 20,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    context.l10n.diary.outline,
                    style: typo.titleMedium.emphasized.onSurface,
                  ),
                  const Spacer(),
                  Container(
                    padding: const .symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      borderRadius: .circular(999),
                    ),
                    child: Text(
                      '${headings.length}',
                      style: typo.labelSmall.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ValueListenableBuilder<int>(
                valueListenable: activeHeading,
                builder: (context, active, _) {
                  return ListView.builder(
                    padding: const .fromLTRB(8, 4, 8, 16),
                    itemCount: headings.length,
                    itemBuilder: (context, i) {
                      final h = headings[i];
                      final isActive = active == i;
                      final label = h.text.trim().isEmpty
                          ? context.l10n.common.untitled
                          : h.text;
                      final level1 = h.level <= 1;
                      final base = level1 ? typo.bodyMedium : typo.bodySmall;
                      final weighted = (isActive || level1)
                          ? base.emphasized
                          : base;
                      final labelStyle =
                          (isActive
                                  ? weighted.onSecondaryContainer
                                  : weighted.onSurface)
                              .copyWith(height: 1.3);
                      return Padding(
                        padding: .only(
                          left: (h.level - 1) * 14.0,
                          top: 1,
                          bottom: 1,
                        ),
                        child: MInkWell(
                          borderRadius: .circular(12),
                          onTap: () => onTap(i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOut,
                            padding: const .symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? colors.secondaryContainer
                                  : Colors.transparent,
                              borderRadius: .circular(12),
                            ),
                            child: Row(
                              children: [
                                if (h.level > 1) ...[
                                  Container(
                                    width: 5,
                                    height: 5,
                                    margin: const .only(right: 10),
                                    decoration: BoxDecoration(
                                      shape: .circle,
                                      color: isActive
                                          ? colors.onSecondaryContainer
                                          : colors.onSurfaceVariant.withValues(
                                              alpha: 0.5,
                                            ),
                                    ),
                                  ),
                                ],
                                Expanded(
                                  child: Text(
                                    label,
                                    maxLines: 2,
                                    overflow: .ellipsis,
                                    style: labelStyle,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

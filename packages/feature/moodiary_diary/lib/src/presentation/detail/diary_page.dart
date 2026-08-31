import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'hop_history.dart';

enum _Mode { read, edit }

/// 统一日记页：合并只读详情与编辑，支持原地编辑。阅读 ↔ 编辑复用同一 [EditorBody]
/// 实例（markdown 不重建 webview）。
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

  /// 压栈离页时记录的 webview 焦点位置，返回本页时按此恢复；none 表示离页时无焦点、不恢复。
  EditorFocusTarget _restoreFocusTarget = .none;

  _Mode _mode = .read;

  bool _dirty = false;

  /// 本次编辑会话内用户是否手动动过心情选择器；动过则自动建议永久让位。
  bool _moodTouched = false;

  /// 已建议过的正文快照，内容没变不重复打分。
  String? _suggestedForContent;

  Timer? _autoSaveTimer;

  /// 自动保存状态（驱动 AppBar 胶囊里的状态段）：idle / saving / saved / failed。
  String _saveStatus = 'idle';

  /// 写作计时（秒）：编辑器打开即开始。用 ValueNotifier 让胶囊里的时间段每秒单独刷新，
  /// 不触发整页（含 webview）重建。
  final ValueNotifier<int> _elapsed = ValueNotifier<int>(0);
  Timer? _writingTimer;

  /// 缓存 notifier：Riverpod 3.x 禁止在 dispose 里碰 ref；页内跳转换日记时随之刷新。
  late EditController _notifier;

  /// 已登记「打开中」的业务 id（新建日记打开后才解析出）。
  String? _guardId;

  ProviderSubscription<AsyncValue<Diary>>? _guardSub;

  // —— 页内双链跳转历史（浏览器语义：单页原地换日记 + 换 URL，返回键先走历史）——
  final HopHistory _hops = HopHistory();

  /// 防跳转双击 / 回退连按。
  bool _hopping = false;

  /// didUpdateWidget 区分自发 replace（页内跳转，内容已 swap）与外部导航。
  bool _selfReplace = false;

  /// provider 家族切换的加载间隙用于渲染的目标日记（跳转时已从仓库取到），
  /// 避免 body 短暂塌空导致 webview 被卸载重建。
  Diary? _hopTarget;

  // —— 文末双链面板数据（web 渲染，此处只负责取数与推送）——
  List<Diary> _outLinks = const [];
  List<Diary> _inLinks = const [];
  StreamSubscription<DiaryEvent>? _linksSub;
  Timer? _linksDebounce;

  /// 自增序号：只有最新一次加载的结果才允许写回，防日记间快速跳转时旧请求后到覆盖。
  int _linksToken = 0;

  /// 已加载链接的日记业务 id（build 中比对，换日记即重取）。
  String? _linksFor;

  // —— 目录（TOC）——
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  /// 编辑器命令句柄：目录点击 → scrollToHeading 反向驱动 webview 滚动。
  final _editorController = MoodiaryEditorController();

  /// 当前顶部可见标题下标（webview 滚动联动回传）；ValueNotifier 只重建目录高亮，不重建整页。
  final ValueNotifier<int> _activeHeading = ValueNotifier<int>(-1);

  // 大纲按 content 串缓存，避免每次 build（每次输入都会重建）重复解析。
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
    // 从打开编辑器起计时（秒）。
    _writingTimer = .periodic(
      const Duration(seconds: 1),
      (_) => _elapsed.value++,
    );
    _notifier = ref.read(_provider.notifier);
    // 既有日记默认只读预览，点击 AppBar 的编辑按钮才进编辑；仅新建 / 显式编辑入口
    // （startInEdit）直接进编辑态。旧格式（markdown / richText）不可编辑，恒为只读。
    _mode = widget.startInEdit ? .edit : .read;
    // 登记「打开中」，同步层据此跳过本篇（编辑期不上传半成品）。新建打开时尚无 id，
    // 待空模板解析出稳定 id 再登记。
    final id = widget.diaryId;
    if (id != null) {
      _guardId = id;
      OpenDiaryRegistry.instance.open(id);
      _hops.reset(id);
    } else {
      _guardSub = ref.listenManual(_provider, (_, next) {
        final diary = next.value;
        if (diary != null && _guardId == null) {
          _guardId = diary.id;
          OpenDiaryRegistry.instance.open(diary.id);
        }
      });
    }
    // 任意日记增删改都可能改双链关系；合并突发（如同步批量写）后再刷。
    _linksSub = DiaryRepository.get().diaryEvents.listen((_) {
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

  // —— 路由级焦点联动：压栈离页收键盘（记住焦点位置），返回时恢复，弹出本页放焦点 ——

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
    // 外部 replace（非页内跳转发起）：历史重置为单条，内容异步补换。
    if (!self) {
      _hops.reset(newId);
      unawaited(_applyExternalSwap(newId));
    }
    _onDiaryChanged(newId);
  }

  /// 换日记（页内跳转或外部 replace）后的 per-diary 状态重置；内容 swap 由跳转方处理。
  /// didUpdateWidget 期间本就要重建，字段直接赋值，不 setState。
  void _onDiaryChanged(String newId) {
    final oldId = _guardId;
    _guardSub?.close();
    _guardSub = null;
    if (oldId != null && oldId != newId) {
      OpenDiaryRegistry.instance.close(oldId);
    }
    _guardId = newId;
    if (oldId != newId) OpenDiaryRegistry.instance.open(newId);
    _notifier = ref.read(_provider.notifier);
    _mode = widget.startInEdit ? .edit : .read;
    _dirty = false;
    _saveStatus = 'idle';
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
    _elapsed.value = 0;
    _activeHeading.value = -1;
  }

  /// 外部 replace 到另一篇日记（当前无此入口，防御性兜底）：取库换文档。
  Future<void> _applyExternalSwap(String id) async {
    final target = await DiaryRepository.get().getDiaryByBusinessId(id);
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
    // 离开时 flush 自动保存（fire-and-forget；行与索引同事务落库，无队列要排空）。
    // 「打开中」标记保持到 flush 之后再解除：否则空白丢弃的无墓碑硬删可能被并发 push
    // 抢先上传，pull 时复活。
    // ignore: discarded_futures
    () async {
      try {
        if (_dirty) await _notifier.autoSave();
      } finally {
        guardSub?.close();
        if (guardId != null) OpenDiaryRegistry.instance.close(guardId);
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
    if (ok) unawaited(_maybeSuggestMood());
  }

  /// 自动保存成功后的心情建议：只对本次会话新建、且用户没动过选择器的日记生效，
  /// 用户一旦手动点选（[_moodTouched]）即永久让位。正文没变不重复打分；
  /// 建议值写回 state 后随下一轮自动保存落库。
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

  Future<void> _onFetchWeather() async {
    final notifier = ref.read(_provider.notifier);
    final result = await notifier.fetchWeather(context);
    if (!mounted) return;
    if (result == null) {
      toast.error(message: l10n.diary.weatherFailed);
    } else {
      toast.success(
        message: l10n.diary.weatherFetched(
          weather: result.text,
          temperature: result.temp,
        ),
      );
      _dirty = true;
      _scheduleAutoSave();
    }
  }

  Future<void> _onFetchPosition() async {
    final result = await ref.read(_provider.notifier).fetchPosition(context);
    if (!mounted) return;
    if (result == null) {
      toast.error(message: l10n.diary.positionFailed);
      return;
    }
    _dirty = true;
    _scheduleAutoSave();
  }

  @override
  Widget build(BuildContext context) {
    final editAsync = ref.watch(_provider);
    // 目标日记的 provider 已就绪即撤兜底（页内跳转的 URL replace 落地后家族才切过来，
    // 之前 hasValue 属于旧日记，不能撤）。
    if (editAsync.hasValue && _hopTarget?.id == widget.diaryId) {
      _hopTarget = null;
    }
    final diary = editAsync.value ?? _hopTarget;
    // 大纲来自当前正文（tiptap JSON）；空则不显示目录按钮 / 抽屉。
    final headings = diary == null
        ? const <({int level, String text})>[]
        : _headingsOf(diary.content);
    return PopScope(
      canPop: _hops.atRoot,
      // 返回键 / 预测性返回：跳转历史未走完先回退一步，走完才真正退出页面。
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goHistory(-1);
      },
      child: Scaffold(
        key: _scaffoldKey,
        // 返回键 + 居中写作胶囊（编辑态）+ 右侧动作。
        appBar: AppBar(
          centerTitle: true,
          // 发生过页内跳转（历史 >1 条）时换成浏览器式导航簇：主页 / 后退 / 前进。
          // 普通打开保持默认返回箭头；不可用方向置灰不隐藏，按钮不跳位。
          // 主页 = 绕过历史直接退出（Navigator.pop 不走 PopScope）；系统返回语义不变。
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
            // 编辑态：✓ 保存并退回只读预览（自动保存仍在，这个是显式入口）。
            if (diary != null && _mode == .edit)
              IconButton(
                tooltip: context.l10n.common.save,
                icon: const Icon(LucideIcons.check),
                onPressed: _saveAndExit,
              ),
            // 只读态 + 可编辑（tiptap）：✏️ 进入编辑。旧格式不可编辑，不显示。
            if (diary != null &&
                _mode == .read &&
                DiaryType.fromValue(diary.type).isEditable)
              IconButton(
                tooltip: context.l10n.diary.edit,
                icon: const Icon(LucideIcons.squarePen),
                onPressed: _enterEdit,
              ),
            // 分享仅在只读预览态显示（编辑态不出现）。
            if (diary != null && _mode == .read)
              IconButton(
                tooltip: context.l10n.diary.share,
                icon: const Icon(LucideIcons.share),
                onPressed: () => ShareRoute(diaryId: diary.id).push(context),
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
                // 不显示转圈，避免和编辑器 webview 加载遮罩形成「两次 loading」。
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

  /// AppBar 居中小胶囊：字数（可关）· 写作时长（可关）· 自动保存状态（常显不可关）。
  /// 前两项由日记偏好 [MoodiaryKVs.showWordCount] / [MoodiaryKVs.showWritingTime] 控制。
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
          // 等宽数字：秒数跳动 / 字数增减时宽度不抖。
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

  /// 进入编辑并聚焦编辑器（弹软键盘）。复用同一编辑器实例，见 [_buildBody] 的稳定 key。
  void _enterEdit() {
    setState(() => _mode = .edit);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _editorController.focus(),
    );
  }

  /// 保存并退回只读预览：有未存改动则先 flush；保存失败留在编辑态便于重试，成功/无改动则切 read。
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

  /// 页面 body 即编辑器整体：属性头 / 标题 / 正文 / 文末双链面板全在 webview 文档流里，
  /// 随正文一起滚动。此处只打包数据（metaJson / linksJson）与接线交互回调，
  /// 键与树位置恒定，切换阅读 / 编辑不重建 webview。
  Widget _buildBody(Diary diary) {
    _ensureLinksLoaded(diary.id);
    return EditorBody(
      key: const ValueKey('diary-editor'),
      type: .fromValue(diary.type),
      initialContent: diary.content,
      // 标题在 webview 编辑器顶部（映射 Diary.title，不进正文）。
      initialTitle: diary.title,
      editable: _mode == .edit,
      // 自动保存状态推给编辑器右下角气泡；_flushAutoSave 的 setState 重建即透传
      //（同 key，webview 不重建）。
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
      onFetchWeather: _onFetchWeather,
      onFetchPosition: _onFetchPosition,
      onOpenGraph: () => DiaryGraphRoute(diaryId: diary.id).push(context),
    );
  }

  /// web 侧心情菜单选定（入参为枚举名）。
  void _onChangeMoodName(String name) {
    final mood = DiaryMood.values.where((m) => m.name == name).firstOrNull;
    if (mood == null) return;
    _onChangeMood(mood);
  }

  /// 属性头数据：显示串（日期 / 分类名 / 字数 / 菜单文案）全部在此解析好，web 侧零本地化。
  String _metaJson(Diary diary) {
    final weather = diary.weather;
    final position = diary.position;
    final categoryAsync = ref.watch(
      getCategoryProvider(id: diary.categoryId ?? ''),
    );
    final categoryLabel = diary.categoryId == null
        ? null
        : categoryAsync.maybeWhen(
            data: (c) => c?.categoryName ?? context.l10n.diary.unknownCategory,
            orElse: () => context.l10n.diary.loading,
          );
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
          : {'icon': weather.icon, 'text': '${weather.text} ${weather.temp}°C'},
      'position': (position == null || position.name.isEmpty)
          ? null
          : position.name,
      'tags': diary.tags,
      'deleteLabel': context.l10n.common.delete,
    });
  }

  static String _hexColor(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  /// 文末双链面板数据。片段截短再上桥——长日记的 contentText 不该整篇跨进 webview。
  String _linksJson() {
    Map<String, dynamic> item(Diary d) {
      final hasTitle = d.title.trim().isNotEmpty;
      final title = hasTitle ? d.title.trim() : TimeFormat.longDate(d.time);
      var snippet = d.contentText.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (snippet.length > 80) snippet = snippet.substring(0, 80);
      // 有标题时副标题给「日期 · 片段」；无标题时标题已是日期，副标题只放片段。
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

  /// build 中比对目标日记，换日记即重取双链（结果异步 setState 推给 webview）。
  void _ensureLinksLoaded(String id) {
    if (_linksFor == id) return;
    _linksFor = id;
    unawaited(_loadLinks());
  }

  Future<void> _loadLinks() async {
    final id = _linksFor;
    if (id == null) return;
    final token = ++_linksToken;
    final repo = DiaryRepository.get();
    final results = await Future.wait([
      repo.getForwardLinks(id),
      repo.getBacklinks(id),
    ]);
    if (!mounted || token != _linksToken) return; // 过期响应丢弃
    setState(() {
      _outLinks = results[0];
      _inLinks = results[1];
    });
  }

  /// 点击双链 chip / 反链条目：按业务 id 解析目标日记，页内原地跳转（不存在则提示）。
  Future<void> _openLinkedDiary(String id) async {
    if (_hopping) return;
    if (id == _guardId) return; // 自链不跳
    _hopping = true;
    try {
      final target = await DiaryRepository.get().getDiaryByBusinessId(id);
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

  /// 前向跳转（浏览器语义）：截断前进分支后追加，落到目标顶部。
  Future<void> _hopTo(Diary target) async {
    if (!await _flushBeforeHop()) return;
    // 新建页首跳：首存后才有稳定 id 可入历史（有链接可点 ⇒ 非空白 ⇒ 上面已落库）。
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

  /// 历史走一步（delta ±1）；途中已被删除的日记（回收 / 同步硬删）从历史剔除跳过。
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
        final target = await DiaryRepository.get().getDiaryByBusinessId(
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

  /// 编辑态先落库再走，保存失败不跳（防丢字）。
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

  /// 把页面切到 [target]：先退回只读（rebuild 把 setEditable(false) 排进 JS 队列），
  /// swap 文档，最后 replace URL 对齐真相源（didUpdateWidget 收尾 per-diary 状态重置）。
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

/// 目录（TOC）右侧抽屉：按级别缩进列出正文标题，点击跳到对应标题，当前标题高亮。
/// 标题来自 [TiptapContent.headings]（文档序），下标即 `scrollToHeading(index)` 的 index。
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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:moodiary_editor/moodiary_editor.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_router/moodiary_router.dart';

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
    this.initialType = DiaryType.markdown,
    this.initialCategoryId,
    this.startInEdit = false,
  });

  @override
  ConsumerState<DiaryPage> createState() => _DiaryPageState();
}

class _DiaryPageState extends ConsumerState<DiaryPage>
    with WidgetsBindingObserver {
  static const _autoSaveDebounce = Duration(seconds: 2);

  _Mode _mode = _Mode.read;

  bool _dirty = false;

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
      _headings = TiptapContent.headings(content);
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
    _writingTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _elapsed.value++,
    );
    _notifier = ref.read(_provider.notifier);
    // 既有日记默认只读预览，点击 AppBar 的编辑按钮才进编辑；仅新建 / 显式编辑入口
    // （startInEdit）直接进编辑态。旧格式（markdown / richText）不可编辑，恒为只读。
    _mode = widget.startInEdit ? _Mode.edit : _Mode.read;
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
    _mode = widget.startInEdit ? _Mode.edit : _Mode.read;
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
    WidgetsBinding.instance.removeObserver(this);
    _activeHeading.dispose();
    _autoSaveTimer?.cancel();
    _writingTimer?.cancel();
    _elapsed.dispose();
    final guardSub = _guardSub;
    final guardId = _guardId;
    // 离开时 flush 自动保存 + 排空重索引队列（fire-and-forget，残留靠启动恢复兜底）。
    // 「打开中」标记保持到 flush 之后再解除：否则空白丢弃的无墓碑硬删可能被并发 push
    // 抢先上传，pull 时复活。
    // ignore: discarded_futures
    () async {
      try {
        if (_dirty) await _notifier.autoSave();
        await DiaryRepository.get().drainReindexQueue();
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
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden;
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
    if (_mode != _Mode.edit) return;
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(_autoSaveDebounce, _flushAutoSave);
  }

  Future<void> _flushAutoSave() async {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
    if (mounted) setState(() => _saveStatus = 'saving');
    final result = await ref.read(_provider.notifier).autoSave();
    final ok = result == DraftSaveResult.saved;
    if (ok) _dirty = false;
    if (!mounted) return;
    setState(() => _saveStatus = ok ? 'saved' : 'failed');
  }

  Future<void> _onPickDate(Diary current) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current.time.toLocal(),
      firstDate: DateTime(1949, 10, 1),
      lastDate: DateTime.now(),
    );
    if (picked == null || !mounted) return;
    ref.read(_provider.notifier).changeDate(picked);
    _dirty = true;
    _scheduleAutoSave();
  }

  Future<void> _onPickTime(Diary current) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current.time.toLocal()),
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
    final controller = TextEditingController();
    final tag = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加标签'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '标签名'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('添加'),
          ),
        ],
      ),
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

  void _onChangeMood(double mood) {
    ref.read(_provider.notifier).changeMood(mood);
    _dirty = true;
    _scheduleAutoSave();
  }

  Future<void> _onFetchWeather() async {
    final notifier = ref.read(_provider.notifier);
    final result = await notifier.fetchWeather(context);
    if (!mounted) return;
    if (result == null) {
      toast.error(message: '获取天气失败：请检查实验室内的和风天气配置');
    } else {
      toast.success(
        message:
            '已获取天气：${result.length >= 3 ? result[2] : ''} ${result.length >= 2 ? result[1] : ''}°C',
      );
      _dirty = true;
      _scheduleAutoSave();
    }
  }

  Future<void> _showDetails(Diary diary) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await showFloatingModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _DetailSheet(
        diary: diary,
        provider: _provider,
        onChangeMood: _onChangeMood,
        onPickDate: () {
          Navigator.of(context).pop();
          _onPickDate(diary);
        },
        onPickTime: () {
          Navigator.of(context).pop();
          _onPickTime(diary);
        },
        onPickCategory: () {
          Navigator.of(context).pop();
          _onPickCategory(diary);
        },
        onAddTag: () {
          Navigator.of(context).pop();
          _onAddTag(diary);
        },
        onRemoveTag: (i) => _onRemoveTag(diary, i),
        onFetchWeather: () {
          Navigator.of(context).pop();
          _onFetchWeather();
        },
      ),
    );
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
                      tooltip: '主页',
                      icon: const Icon(Icons.home_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    IconButton(
                      tooltip: '后退',
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: _hops.atRoot ? null : () => _goHistory(-1),
                    ),
                    IconButton(
                      tooltip: '前进',
                      icon: const Icon(Icons.arrow_forward_rounded),
                      onPressed: _hops.peek(1) == null
                          ? null
                          : () => _goHistory(1),
                    ),
                  ],
                )
              : null,
          title: (_mode == _Mode.edit && diary != null)
              ? _writingPill(diary)
              : null,
          actions: [
            // 编辑态：✓ 保存并退回只读预览（自动保存仍在，这个是显式入口）。
            if (diary != null && _mode == _Mode.edit)
              IconButton(
                tooltip: '保存',
                icon: const Icon(Icons.check_rounded),
                onPressed: _saveAndExit,
              ),
            // 只读态 + 可编辑（tiptap）：✏️ 进入编辑。旧格式不可编辑，不显示。
            if (diary != null &&
                _mode == _Mode.read &&
                DiaryType.fromValue(diary.type).isEditable)
              IconButton(
                tooltip: '编辑',
                icon: const Icon(Icons.edit_outlined),
                onPressed: _enterEdit,
              ),
            // 分享仅在只读预览态显示（编辑态不出现）。
            if (diary != null && _mode == _Mode.read)
              IconButton(
                tooltip: '分享',
                icon: const Icon(Icons.ios_share_rounded),
                onPressed: () => ShareRoute(diaryId: diary.id).push(context),
              ),
            if (headings.isNotEmpty)
              IconButton(
                tooltip: '目录',
                icon: const Icon(Icons.toc_rounded),
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
    final scheme = context.colorScheme;
    final showWords = MoodiaryKVs.showWordCount.get() ?? true;
    final showTime = MoodiaryKVs.showWritingTime.get() ?? true;
    final segs = <Widget>[
      if (showWords)
        _pillSeg(
          Icons.notes_rounded,
          '${diary.contentText.runes.length} 字',
          scheme.onSurfaceVariant,
        ),
      if (showTime)
        ValueListenableBuilder<int>(
          valueListenable: _elapsed,
          builder: (_, sec, _) => _pillSeg(
            Icons.timer_outlined,
            _fmtDuration(sec),
            scheme.onSurfaceVariant,
          ),
        ),
      _saveSeg(scheme),
    ];
    final children = <Widget>[];
    for (var i = 0; i < segs.length; i++) {
      if (i > 0) {
        children.add(
          Text(
            ' · ',
            style: TextStyle(color: scheme.outlineVariant, fontSize: 12),
          ),
        );
      }
      children.add(segs[i]);
    }
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }

  Widget _pillSeg(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: color,
            // 等宽数字：秒数跳动 / 字数增减时宽度不抖。
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _saveSeg(ColorScheme scheme) {
    switch (_saveStatus) {
      case 'saving':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 11,
              height: 11,
              child: CircularProgressIndicator(strokeWidth: 1.6),
            ),
            const SizedBox(width: 4),
            Text(
              '保存中',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
        );
      case 'saved':
        return _pillSeg(Icons.check_circle_rounded, '已保存', scheme.primary);
      case 'failed':
        return _pillSeg(Icons.error_rounded, '未保存', scheme.error);
      default:
        return _pillSeg(
          Icons.cloud_done_rounded,
          '自动保存',
          scheme.onSurfaceVariant,
        );
    }
  }

  /// 进入编辑并聚焦编辑器（弹软键盘）。复用同一编辑器实例，见 [_buildBody] 的稳定 key。
  void _enterEdit() {
    setState(() => _mode = _Mode.edit);
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
        toast.error(message: '保存失败');
        return;
      }
      toast.success(message: '已保存');
    }
    if (!mounted) return;
    setState(() => _mode = _Mode.read);
  }

  /// [EditorBody] 务必保持 Column 同一位置且 key 稳定，否则切换模式时编辑器实例
  /// （及其 webview）会被重建。
  Widget _buildBody(Diary diary) {
    final isEdit = _mode == _Mode.edit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!isEdit)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _meta(context, diary),
            ),
          ),
        Expanded(
          child: EditorBody(
            key: const ValueKey('diary-editor'),
            type: DiaryType.fromValue(diary.type),
            initialContent: diary.content,
            // 标题在 webview 编辑器顶部（映射 Diary.title，不进正文）。
            initialTitle: diary.title,
            editable: isEdit,
            // 自动保存状态推给编辑器右下角气泡；_flushAutoSave 的 setState 重建即透传
            //（同 key，webview 不重建）。
            saveStatus: _saveStatus,
            onChanged: _onContentChanged,
            onTitleChanged: _onTitleChanged,
            editorController: _editorController,
            onActiveHeadingChanged: (i) => _activeHeading.value = i,
            onShowDetails: () => _showDetails(diary),
            onOpenDiaryLink: _openLinkedDiary,
          ),
        ),
        if (!isEdit)
          _BacklinksPanel(diaryId: diary.id, onOpen: _openLinkedDiary),
      ],
    );
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
        toast.error(message: context.l10n.diaryLinkNotFound);
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
      toast.error(message: '保存失败');
      return false;
    }
    return true;
  }

  /// 把页面切到 [target]：先退回只读（rebuild 把 setEditable(false) 排进 JS 队列），
  /// swap 文档，最后 replace URL 对齐真相源（didUpdateWidget 收尾 per-diary 状态重置）。
  Future<void> _showEntry(Diary target, {required double scrollY}) async {
    setState(() {
      _mode = _Mode.read;
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

  List<Widget> _meta(BuildContext context, Diary diary) {
    final theme = Theme.of(context);
    return [
      Row(
        children: [
          Icon(
            Icons.access_time,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            TimeUtil.fullDateTime(diary.time),
            style: theme.textTheme.labelMedium,
          ),
          const Spacer(),
          _MoodChip(value: diary.mood),
        ],
      ),
      if (diary.tags.isNotEmpty) ...[
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final tag in diary.tags)
              Chip(
                label: Text(tag),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
          ],
        ),
      ],
      if (diary.weather.length >= 3) ...[
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              Icons.cloud_outlined,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              '${diary.weather[2]}  ${diary.weather[1]}°C',
              style: theme.textTheme.labelMedium,
            ),
          ],
        ),
      ],
    ];
  }
}

class _MoodChip extends StatelessWidget {
  final double value;
  const _MoodChip({required this.value});

  @override
  Widget build(BuildContext context) {
    final color = Color.lerp(Colors.redAccent, Colors.greenAccent, value);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color?.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.mood, size: 16, color: color),
          const SizedBox(width: 4),
          Text('${(value * 100).toStringAsFixed(0)}%'),
        ],
      ),
    );
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
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  Icon(Icons.toc_rounded, size: 20, color: scheme.primary),
                  const SizedBox(width: 10),
                  Text(
                    '目录',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${headings.length}',
                      style: textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
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
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
                    itemCount: headings.length,
                    itemBuilder: (context, i) {
                      final h = headings[i];
                      final isActive = active == i;
                      final label = h.text.trim().isEmpty ? '(无标题)' : h.text;
                      return Padding(
                        padding: EdgeInsets.only(
                          left: (h.level - 1) * 14.0,
                          top: 1,
                          bottom: 1,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => onTap(i),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOut,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? scheme.secondaryContainer
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  if (h.level > 1) ...[
                                    Container(
                                      width: 5,
                                      height: 5,
                                      margin: const EdgeInsets.only(right: 10),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isActive
                                            ? scheme.onSecondaryContainer
                                            : scheme.onSurfaceVariant
                                                  .withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ],
                                  Expanded(
                                    child: Text(
                                      label,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style:
                                          (h.level <= 1
                                                  ? textTheme.bodyMedium
                                                  : textTheme.bodySmall)
                                              ?.copyWith(
                                                color: isActive
                                                    ? scheme
                                                          .onSecondaryContainer
                                                    : scheme.onSurface,
                                                fontWeight:
                                                    isActive || h.level <= 1
                                                    ? FontWeight.w600
                                                    : FontWeight.w400,
                                                height: 1.3,
                                              ),
                                    ),
                                  ),
                                ],
                              ),
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

/// 反向链接面板（阅读态）：列出正文双链指向本条的日记，点击跳转。无反链时不占位；
/// 订阅 diaryEvents，任意日记增删改后刷新。
class _BacklinksPanel extends StatefulWidget {
  final String diaryId;
  final ValueChanged<String> onOpen;

  const _BacklinksPanel({required this.diaryId, required this.onOpen});

  @override
  State<_BacklinksPanel> createState() => _BacklinksPanelState();
}

class _BacklinksPanelState extends State<_BacklinksPanel> {
  List<Diary> _items = const [];
  StreamSubscription<DiaryEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _load();
    _sub = DiaryRepository.get().diaryEvents.listen((_) => _load());
  }

  @override
  void didUpdateWidget(covariant _BacklinksPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.diaryId != widget.diaryId) _load();
  }

  Future<void> _load() async {
    final list = await DiaryRepository.get().getBacklinks(widget.diaryId);
    if (mounted) setState(() => _items = list);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Card.filled(
      color: scheme.surfaceContainerLow,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头部：图标 + 标题 + 数量胶囊
            Row(
              children: [
                Icon(Icons.link_rounded, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  context.l10n.backlinks,
                  style: textTheme.titleSmall?.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${_items.length}',
                    style: textTheme.labelSmall?.copyWith(
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 264),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 2),
                itemBuilder: (_, i) {
                  final d = _items[i];
                  return _BacklinkTile(
                    diary: d,
                    onTap: () => widget.onOpen(d.id),
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

class _BacklinkTile extends StatelessWidget {
  final Diary diary;
  final VoidCallback onTap;

  const _BacklinkTile({required this.diary, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasTitle = diary.title.trim().isNotEmpty;
    final title = hasTitle
        ? diary.title.trim()
        : TimeUtil.longDate(diary.time);
    final snippet = diary.contentText.trim().replaceAll(RegExp(r'\s+'), ' ');
    // 有标题时副标题给「日期 · 片段」；无标题时标题已是日期，副标题只放片段。
    final subtitle = hasTitle && snippet.isNotEmpty
        ? '${TimeUtil.longDate(diary.time)} · $snippet'
        : snippet;
    return ListTile(
      onTap: onTap,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.symmetric(horizontal: 6),
      shape: const RoundedRectangleBorder(
        borderRadius: AppBorderRadius.smallBorderRadius,
      ),
      leading: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: AppBorderRadius.smallBorderRadius,
        ),
        child: Icon(
          Icons.subdirectory_arrow_left_rounded,
          size: 18,
          color: scheme.onSurfaceVariant,
        ),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: textTheme.bodyMedium?.copyWith(color: scheme.onSurface),
      ),
      subtitle: subtitle.isEmpty
          ? null
          : Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        size: 18,
        color: scheme.onSurfaceVariant,
      ),
    );
  }
}

class _DetailSheet extends ConsumerWidget {
  final Diary diary;

  /// 复用编辑页的同一 provider——另起实例会拿不到本页状态，且新建（无 id）时会抛错。
  final EditControllerProvider provider;
  final ValueChanged<double> onChangeMood;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;
  final VoidCallback onPickCategory;
  final VoidCallback onAddTag;
  final void Function(int index) onRemoveTag;
  final VoidCallback onFetchWeather;

  const _DetailSheet({
    required this.diary,
    required this.provider,
    required this.onChangeMood,
    required this.onPickDate,
    required this.onPickTime,
    required this.onPickCategory,
    required this.onAddTag,
    required this.onRemoveTag,
    required this.onFetchWeather,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateLabel = TimeUtil.fullDateTime(diary.time);
    final hasWeather = diary.weather.length >= 3;
    final categoryAsync = ref.watch(
      getCategoryProvider(id: diary.categoryId ?? ''),
    );
    final categoryLabel = diary.categoryId == null
        ? '不分类'
        : categoryAsync.maybeWhen(
            data: (c) => c?.categoryName ?? '未知分类',
            orElse: () => '加载中…',
          );
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        SettingListTile(
          isFirst: true,
          title: '日期与时间',
          subtitle: dateLabel,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton.filledTonal(
                onPressed: onPickDate,
                icon: const Icon(Icons.date_range),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: onPickTime,
                icon: const Icon(Icons.access_time),
              ),
            ],
          ),
        ),
        SettingListTile(
          title: '天气',
          subtitle: hasWeather
              ? '${diary.weather[2]} ${diary.weather[1]}°C'
              : '未获取',
          trailing: IconButton.filledTonal(
            onPressed: onFetchWeather,
            icon: const Icon(Icons.location_on),
          ),
        ),
        SettingListTile(
          title: '分类',
          subtitle: categoryLabel,
          trailing: IconButton.filledTonal(
            onPressed: onPickCategory,
            icon: const Icon(Icons.category),
          ),
        ),
        SettingListTile(
          title: '标签',
          subtitle: diary.tags.isEmpty
              ? null
              : Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (var i = 0; i < diary.tags.length; i++)
                        Chip(
                          label: Text(diary.tags[i]),
                          visualDensity: VisualDensity.compact,
                          onDeleted: () => onRemoveTag(i),
                        ),
                    ],
                  ),
                ),
          trailing: IconButton.filledTonal(
            onPressed: onAddTag,
            icon: const Icon(Icons.tag),
          ),
        ),
        SettingListTile(
          isLast: true,
          title: '心情',
          subtitle: _MoodSlider(provider: provider, onChanged: onChangeMood),
        ),
      ],
    );
  }
}

class _MoodSlider extends ConsumerWidget {
  final EditControllerProvider provider;
  final ValueChanged<double> onChanged;

  const _MoodSlider({required this.provider, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mood = ref.watch(
      provider.select((value) => value.value?.mood ?? 0.5),
    );
    return Row(
      children: [
        MoodIconComponent(value: mood),
        Expanded(
          child: Slider(
            value: mood,
            divisions: 10,
            label: '${(mood * 100).toStringAsFixed(0)}%',
            activeColor: Color.lerp(
              const Color(0xFFFA4659),
              const Color(0xFF2EB872),
              mood,
            ),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

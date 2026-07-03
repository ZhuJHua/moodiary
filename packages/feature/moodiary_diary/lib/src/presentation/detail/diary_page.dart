import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:moodiary_editor/moodiary_editor.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_router/moodiary_router.dart';

enum _Mode { read, edit }

/// 统一日记页：合并只读详情与编辑，支持原地编辑。阅读 ↔ 编辑复用同一 [EditorBody]
/// 实例（markdown 不重建 webview）。
class DiaryPage extends ConsumerStatefulWidget {
  final String? diaryId;

  final DiaryType initialType;

  final bool startInEdit;

  const DiaryPage({
    super.key,
    this.diaryId,
    this.initialType = DiaryType.markdown,
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

  /// 自动保存状态（驱动编辑器右下角气泡）：idle（不显示）/ saving / saved / failed。
  String _saveStatus = 'idle';

  /// 缓存 notifier：Riverpod 3.x 禁止在 dispose 里碰 ref。
  late final EditController _notifier;

  /// 已登记「打开中」的业务 id（新建日记打开后才解析出）。
  String? _guardId;

  ProviderSubscription<AsyncValue<Diary>>? _guardSub;

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

  EditControllerProvider get _provider =>
      editControllerProvider(widget.diaryId, defaultType: widget.initialType);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _notifier = ref.read(_provider.notifier);
    // 可编辑类型（tiptap）直接进编辑态——无独立「保存」，编辑即默认态；旧格式
    // （markdown / richText）只读，仍进 read。
    _mode = (widget.startInEdit || widget.initialType.isEditable)
        ? _Mode.edit
        : _Mode.read;
    // 登记「打开中」，同步层据此跳过本篇（编辑期不上传半成品）。新建打开时尚无 id，
    // 待空模板解析出稳定 id 再登记。
    final id = widget.diaryId;
    if (id != null) {
      _guardId = id;
      OpenDiaryRegistry.instance.open(id);
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
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _activeHeading.dispose();
    _autoSaveTimer?.cancel();
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
      initialDate: current.time,
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
      initialTime: TimeOfDay.fromDateTime(current.time),
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
    final diary = editAsync.value;
    // 大纲来自当前正文（tiptap JSON）；空则不显示目录按钮 / 抽屉。
    final headings = diary == null
        ? const <({int level, String text})>[]
        : _headingsOf(diary.content);
    return Scaffold(
      key: _scaffoldKey,
      // 返回键 +（有标题时）右侧目录按钮。
      appBar: AppBar(
        actions: [
          if (diary != null)
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
      body: editAsync.buildLoading(
        // 不显示转圈，避免和编辑器 webview 加载遮罩形成「两次 loading」。
        loading: () => const SizedBox.shrink(),
        data: (diary) => SafeArea(child: _buildBody(diary)),
      ),
    );
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

  /// 点击双链 chip：按业务 id 解析目标日记，再按其类型导航（不存在则提示）。
  Future<void> _openLinkedDiary(String id) async {
    final target = await DiaryRepository.get().getDiaryByBusinessId(id);
    if (!mounted) return;
    if (target == null) {
      toast.error(message: context.l10n.diaryLinkNotFound);
      return;
    }
    final route = DiaryRoute(
      type: DiaryType.fromValue(target.type).routeQuery,
      diaryId: target.id,
    );
    route.push(context);
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
            DateFormat.yMMMMEEEEd().add_Hm().format(diary.time),
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
                      final label = h.text.trim().isEmpty
                          ? '(无标题)'
                          : h.text;
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
                  style: textTheme.titleSmall?.copyWith(color: scheme.onSurface),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
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
        : DateFormat.yMMMMd().format(diary.time);
    final snippet = diary.contentText.trim().replaceAll(RegExp(r'\s+'), ' ');
    // 有标题时副标题给「日期 · 片段」；无标题时标题已是日期，副标题只放片段。
    final subtitle = hasTitle && snippet.isNotEmpty
        ? '${DateFormat.yMMMMd().format(diary.time)} · $snippet'
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
    final dateLabel = DateFormat.yMd().add_Hm().format(diary.time);
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

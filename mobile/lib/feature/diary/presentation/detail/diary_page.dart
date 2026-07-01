import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary/feature/diary/application/category_controller.dart';
import 'package:moodiary/feature/edit/application/edit_controller.dart';
import 'package:moodiary/feature/edit/presentation/widget/category_picker_sheet.dart';
import 'package:moodiary/feature/edit/presentation/widget/editor_body.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary/app/router/router.dart';

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

  EditControllerProvider get _provider =>
      editControllerProvider(widget.diaryId, defaultType: widget.initialType);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _notifier = ref.read(_provider.notifier);
    // 可编辑类型（tiptap）直接进编辑态——无独立「保存」、创建即落盘，编辑即默认态；
    // 旧格式（markdown / richText）只读，仍进 read。
    _mode = (widget.startInEdit || widget.initialType.isEditable)
        ? _Mode.edit
        : _Mode.read;
    // 标记「打开中」：同步层据此跳过本篇，编辑期不上传半成品（关闭后由 poll 收敛）。
    final id = widget.diaryId;
    if (id != null) OpenDiaryRegistry.instance.open(id);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // 关闭即解除「打开中」标记（不主动 kick 同步）。随后的 flush 若有改动会发出
    // 领域事件，此时已非「打开中」→ 自然触发去抖 push；无改动则由下一轮 poll 收敛。
    final id = widget.diaryId;
    if (id != null) OpenDiaryRegistry.instance.close(id);
    _autoSaveTimer?.cancel();
    // 离开时 flush 一次自动保存。只读快照 + get_it 仓储、写 state 前用 `ref.mounted`
    // 守卫，不会触碰已 autoDispose 的 ref。
    // ignore: discarded_futures
    () async {
      if (_dirty) await _notifier.autoSave();
      // 关闭即排空「待重索引」队列：把编辑期推迟的分词/倒排建好。崩溃/被杀时残留由启动
      // 恢复兜底，故 fire-and-forget 即可。
      await DiaryRepository.get().drainReindexQueue();
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
        diaryId: widget.diaryId,
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
    return Scaffold(
      // 仅一个返回键（无标题 / 动作）。
      appBar: AppBar(),
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
            editable: isEdit,
            // 自动保存状态推给编辑器右下角气泡；_flushAutoSave 的 setState 重建即透传
            //（同 key，webview 不重建）。
            saveStatus: _saveStatus,
            onChanged: _onContentChanged,
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
      type: DiaryType.fromValue(target.type),
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
  final String? diaryId;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;
  final VoidCallback onPickCategory;
  final VoidCallback onAddTag;
  final void Function(int index) onRemoveTag;
  final VoidCallback onFetchWeather;

  const _DetailSheet({
    required this.diary,
    required this.diaryId,
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
          subtitle: _MoodSlider(diaryId: diaryId),
        ),
      ],
    );
  }
}

class _MoodSlider extends ConsumerWidget {
  final String? diaryId;

  const _MoodSlider({required this.diaryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = editControllerProvider(diaryId);
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
            onChanged: (v) => ref.read(provider.notifier).changeMood(v),
          ),
        ),
      ],
    );
  }
}

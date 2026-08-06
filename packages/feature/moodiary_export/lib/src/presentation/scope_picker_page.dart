import 'package:flutter/material.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

import '../data/export_scope.dart';

enum _ScopeKind { all, category, dateRange, picked }

/// 选择要导出哪些日记。返回一个 [ExportScope]，取消返回 null。
class ScopePickerPage extends StatefulWidget {
  final ExportScope initial;

  const ScopePickerPage({super.key, required this.initial});

  @override
  State<ScopePickerPage> createState() => _ScopePickerPageState();
}

class _ScopePickerPageState extends State<ScopePickerPage> {
  late _ScopeKind _kind = switch (widget.initial) {
    AllDiariesScope() => _ScopeKind.all,
    CategoryScope() => _ScopeKind.category,
    DateRangeScope() => _ScopeKind.dateRange,
    PickedScope() => _ScopeKind.picked,
  };

  final Set<String?> _categoryIds = {};
  DateTimeRange? _range;
  final Set<String> _pickedIds = {};

  List<Category> _categories = const [];
  List<Diary> _diaries = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _restore();
    _load();
  }

  void _restore() {
    switch (widget.initial) {
      case CategoryScope(:final categoryIds):
        _categoryIds.addAll(categoryIds);
      case DateRangeScope(:final from, :final to):
        _range = DateTimeRange(start: from, end: to);
      case PickedScope(:final diaryIds):
        _pickedIds.addAll(diaryIds);
      case AllDiariesScope():
        break;
    }
  }

  Future<void> _load() async {
    final all = await DiaryRepository.get().getAllDiaries();
    final visible = all.where((d) => d.show).toList()
      ..sort((a, b) => b.time.compareTo(a.time));

    final ids = visible
        .map((d) => d.categoryId)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
    final repository = CategoryRepository.get();
    final categories = <Category>[];
    for (final id in ids) {
      final category = await repository.getCategoryById(id);
      if (category != null) categories.add(category);
    }
    categories.sort((a, b) => a.categoryName.compareTo(b.categoryName));

    if (!mounted) return;
    setState(() {
      _diaries = visible;
      _categories = categories;
      _loading = false;
    });
  }

  ExportScope? _build(AppLocalizations l10n) => switch (_kind) {
    _ScopeKind.all => const AllDiariesScope(),
    _ScopeKind.category =>
      _categoryIds.isEmpty
          ? null
          : CategoryScope({..._categoryIds}, _categoryLabel(l10n)),
    _ScopeKind.dateRange =>
      _range == null ? null : DateRangeScope(_range!.start, _range!.end),
    _ScopeKind.picked =>
      _pickedIds.isEmpty ? null : PickedScope({..._pickedIds}),
  };

  String _categoryLabel(AppLocalizations l10n) {
    final names = _categoryIds.map((id) {
      if (id == null || id.isEmpty) return l10n.exportUncategorized;
      return _categories
              .where((c) => c.id == id)
              .map((c) => c.categoryName)
              .firstOrNull ??
          l10n.exportDeletedCategory;
    }).toList();
    return names.length <= 2
        ? names.join('、')
        : l10n.exportCategoryCount(names.length);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.colorScheme;
    final built = _build(l10n);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.exportSelectDiaries)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              children: [
                Card.filled(
                  color: scheme.surfaceContainerLow,
                  margin: EdgeInsets.zero,
                  child: RadioGroup<_ScopeKind>(
                    groupValue: _kind,
                    onChanged: (v) => setState(() => _kind = v!),
                    child: Column(
                      children: [
                        for (final kind in _ScopeKind.values)
                          RadioListTile<_ScopeKind>(
                            value: kind,
                            title: Text(_kindLabel(l10n, kind)),
                            subtitle: _kindHint(l10n, kind),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                if (_kind == _ScopeKind.category) _categoryList(l10n),
                if (_kind == _ScopeKind.dateRange) _rangeTile(l10n),
                if (_kind == _ScopeKind.picked) _diaryList(l10n),
              ],
            ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          height: 50,
          child: FilledButton(
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: built == null
                ? null
                : () => Navigator.of(context).pop(built),
            child: Text(
              built == null ? l10n.exportNothingSelected : l10n.exportConfirm,
            ),
          ),
        ),
      ),
    );
  }

  String _kindLabel(AppLocalizations l10n, _ScopeKind kind) => switch (kind) {
    _ScopeKind.all => l10n.exportScopeAll,
    _ScopeKind.category => l10n.exportScopeByCategory,
    _ScopeKind.dateRange => l10n.exportScopeByDate,
    _ScopeKind.picked => l10n.exportScopePicked,
  };

  /// 只有「全部」需要带篇数，其余选项自解释。
  Widget? _kindHint(AppLocalizations l10n, _ScopeKind kind) =>
      kind == _ScopeKind.all
      ? Text(l10n.exportScopeAllHint(_diaries.length))
      : null;

  Widget _categoryList(AppLocalizations l10n) {
    final scheme = context.colorScheme;
    final uncategorized = _diaries.where((d) {
      final id = d.categoryId;
      return id == null || id.isEmpty;
    }).length;

    return Card.filled(
      color: scheme.surfaceContainerLow,
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          if (uncategorized > 0)
            CheckboxListTile(
              value: _categoryIds.contains(null),
              title: Text(l10n.exportUncategorized),
              subtitle: Text(l10n.exportEntryCount(uncategorized)),
              onChanged: (v) => setState(() {
                v == true ? _categoryIds.add(null) : _categoryIds.remove(null);
              }),
            ),
          for (final category in _categories)
            CheckboxListTile(
              value: _categoryIds.contains(category.id),
              title: Text(category.categoryName),
              subtitle: Text(
                l10n.exportEntryCount(
                  _diaries.where((d) => d.categoryId == category.id).length,
                ),
              ),
              onChanged: (v) => setState(() {
                v == true
                    ? _categoryIds.add(category.id)
                    : _categoryIds.remove(category.id);
              }),
            ),
        ],
      ),
    );
  }

  Widget _rangeTile(AppLocalizations l10n) {
    final scheme = context.colorScheme;
    final range = _range;
    return Card.filled(
      color: scheme.surfaceContainerLow,
      margin: EdgeInsets.zero,
      child: SettingListTile(
        isFirst: true,
        isLast: true,
        title: l10n.exportDateRange,
        subtitle: range == null
            ? l10n.exportTapToPick
            : l10n.exportDateRangeValue(_date(range.start), _date(range.end)),
        leading: const Icon(LucideIcons.calendarRange),
        trailing: const Icon(LucideIcons.chevronRight),
        onTap: _pickRange,
      ),
    );
  }

  static String _date(DateTime t) =>
      '${t.year}/${t.month.toString().padLeft(2, '0')}/${t.day.toString().padLeft(2, '0')}';

  Future<void> _pickRange() async {
    final now = DateTime.now();
    // 库里最早的一篇即可选下限；日记不会写在「第一篇之前」。
    final earliest = _diaries.isEmpty
        ? DateTime(now.year - 1)
        : _diaries.last.time.toLocal();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(earliest.year, earliest.month, earliest.day),
      lastDate: now,
      initialDateRange: _range,
    );
    if (picked != null) setState(() => _range = picked);
  }

  Widget _diaryList(AppLocalizations l10n) {
    final scheme = context.colorScheme;
    return Card.filled(
      color: scheme.surfaceContainerLow,
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          CheckboxListTile(
            value: _pickedIds.length == _diaries.length && _diaries.isNotEmpty,
            tristate: true,
            title: Text(l10n.exportSelectAll),
            onChanged: (_) => setState(() {
              if (_pickedIds.length == _diaries.length) {
                _pickedIds.clear();
              } else {
                _pickedIds
                  ..clear()
                  ..addAll(_diaries.map((d) => d.id));
              }
            }),
          ),
          const Divider(height: 1),
          for (final diary in _diaries)
            CheckboxListTile(
              value: _pickedIds.contains(diary.id),
              title: Text(
                diary.title.trim().isEmpty ? l10n.exportUntitled : diary.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(_date(diary.time.toLocal())),
              onChanged: (v) => setState(() {
                v == true
                    ? _pickedIds.add(diary.id)
                    : _pickedIds.remove(diary.id);
              }),
            ),
        ],
      ),
    );
  }
}

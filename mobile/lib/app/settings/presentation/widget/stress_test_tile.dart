import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_ui/moodiary_ui.dart';

/// 压测数据:批量生成 / 清除随机双链日记,用于知识图谱等极限性能测试。数量对话框内
/// 手动输入([_minTotal]–[_maxTotal]);生成的日记标题以 [_prefix] 开头,可一键清除。
/// 所有构建可见——性能须在 profile/release 下测。
class StressTestTile extends ConsumerStatefulWidget {
  final bool isFirst;
  final bool isLast;

  const StressTestTile({super.key, this.isFirst = false, this.isLast = false});

  @override
  ConsumerState<StressTestTile> createState() => _StressTestTileState();
}

class _StressTestTileState extends ConsumerState<StressTestTile> {
  static const _prefix = '『压测』';
  static const _defaultTotal = 10000;
  static const _minTotal = 2; // 至少 2 篇才可能互链
  static const _maxTotal = 100000;
  static const _chunk = 500;
  static const _minLinks = 1;
  static const _maxLinks = 5;

  bool _busy = false;
  BuildContext? _progressCtx;

  @override
  Widget build(BuildContext context) {
    return SettingListTile(
      isFirst: widget.isFirst,
      isLast: widget.isLast,
      leading: const Icon(LucideIcons.gauge),
      title: '压测数据（调试）',
      subtitle: '批量生成或清除随机双链日记，用于图谱性能测试',
      trailing: _busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(LucideIcons.chevronRight),
      onTap: _busy ? null : _openMenu,
    );
  }

  Future<void> _openMenu() async {
    final action = await showMoodiaryAlert<String>(
      context,
      title: '压测数据',
      message:
          '用于知识图谱等极限性能测试。每篇随机链接 $_minLinks–$_maxLinks 篇其它日记，'
          '标题以「$_prefix」开头，可一键清除。',
      actions: const [
        MoodiaryAction(label: '取消'),
        MoodiaryAction(label: '清除压测', value: 'clear'),
        MoodiaryAction(label: '生成', value: 'gen', isPrimary: true),
      ],
    );
    if (!mounted) return;
    if (action == 'clear') {
      await _clear();
      return;
    }
    if (action != 'gen') return;

    final input = await showMoodiaryPrompt(
      context,
      title: '生成数量',
      initialValue: '$_defaultTotal',
      hintText: '$_minTotal–$_maxTotal',
      confirmLabel: '生成',
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      validator: (value) {
        final total = int.tryParse(value);
        return (total == null || total < _minTotal || total > _maxTotal)
            ? '数量需在 $_minTotal–$_maxTotal 之间'
            : null;
      },
    );
    if (!mounted || input == null) return;
    await _generate(int.parse(input));
  }

  Future<void> _generate(int total) async {
    setState(() => _busy = true);
    final rng = Random();
    final base = DateTime.now().microsecondsSinceEpoch;
    final now = DateTime.now();
    String idFor(int i) => 'stress-$base-$i';
    final progress = ValueNotifier<double>(0);
    _showProgress(progress, '正在生成', total);
    var ok = true;
    try {
      for (var start = 0; start < total; start += _chunk) {
        final end = min(start + _chunk, total);
        final batch = <Diary>[
          for (var i = start; i < end; i++)
            _makeDiary(i, total, idFor, rng, now),
        ];
        await DiaryRepository.get().insertDiaries(batch);
        progress.value = end / total;
        await Future<void>.delayed(Duration.zero); // 让进度条刷新
      }
    } catch (e, s) {
      ok = false;
      logger.e('生成压测数据失败', error: e, stackTrace: s);
      if (mounted) toast.error(message: '生成失败');
    } finally {
      _dismissProgress();
      progress.dispose();
      if (mounted) setState(() => _busy = false);
    }
    if (ok && mounted) toast.success(message: '已生成 $total 篇双链日记');
  }

  Diary _makeDiary(
    int i,
    int total,
    String Function(int) idFor,
    Random rng,
    DateTime now,
  ) {
    // 目标数不能超过可选对象数(total-1),否则小数量时凑不满死循环。
    final k = min(
      _minLinks + rng.nextInt(_maxLinks - _minLinks + 1),
      total - 1,
    );
    final targets = <String>{};
    while (targets.length < k) {
      final t = rng.nextInt(total);
      if (t != i) targets.add(idFor(t));
    }
    final content = jsonEncode({
      'type': 'doc',
      'content': [
        {
          'type': 'paragraph',
          'content': [
            for (final t in targets)
              {
                'type': 'diaryLink',
                'attrs': {'id': t, 'label': '链接'},
              },
          ],
        },
      ],
    });
    final time = now.subtract(
      Duration(days: rng.nextInt(730), minutes: rng.nextInt(1440)),
    );
    return Diary(
      id: idFor(i),
      title: '$_prefix#$i',
      content: content,
      contentText: '',
      time: time,
      lastModified: time,
      show: true,
      mood: rng.nextDouble(),
      weather: const [],
      imageName: const [],
      audioName: const [],
      videoName: const [],
      tags: const [],
      position: const [],
      type: DiaryType.tiptap.value,
    );
  }

  Future<void> _clear() async {
    setState(() => _busy = true);
    final progress = ValueNotifier<double>(0);
    var count = 0;
    try {
      final all = await DiaryRepository.get().getAllDiaries();
      final ids = [
        for (final d in all)
          if (d.title.startsWith(_prefix)) d.isarId,
      ];
      count = ids.length;
      if (ids.isEmpty) {
        if (mounted) toast.info(message: '没有压测日记');
        return;
      }
      _showProgress(progress, '正在清除', ids.length);
      for (var start = 0; start < ids.length; start += _chunk) {
        final end = min(start + _chunk, ids.length);
        await DiaryRepository.get().deleteDiariesByIsarIds(
          ids.sublist(start, end),
        );
        progress.value = end / ids.length;
        await Future<void>.delayed(Duration.zero);
      }
    } catch (e, s) {
      logger.e('清除压测数据失败', error: e, stackTrace: s);
      if (mounted) toast.error(message: '清除失败');
      return;
    } finally {
      _dismissProgress();
      progress.dispose();
      if (mounted) setState(() => _busy = false);
    }
    if (mounted && count > 0) toast.success(message: '已清除 $count 篇压测日记');
  }

  void _showProgress(ValueNotifier<double> progress, String title, int total) {
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          _progressCtx = ctx;
          return AlertDialog(
            title: Text(title),
            content: ValueListenableBuilder<double>(
              valueListenable: progress,
              builder: (_, v, _) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(value: v == 0 ? null : v),
                  const SizedBox(height: 12),
                  Text(
                    '${(v * 100).round()}%  (${(v * total).round()}/$total)',
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _dismissProgress() {
    final ctx = _progressCtx;
    if (ctx != null && ctx.mounted) Navigator.of(ctx).pop();
    _progressCtx = null;
  }
}

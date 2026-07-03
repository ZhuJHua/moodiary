import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import 'templates/share_card_template.dart';

/// 分享页只需一次性快照（导出用），直接从仓库取，不依赖 diary 特性的流式 provider。
final _shareDiaryProvider = FutureProvider.family<Diary?, String?>((
  ref,
  id,
) async {
  if (id == null || id.isEmpty) return null;
  return DiaryRepository.get().getDiaryByBusinessId(id);
});

/// 分享页：选一个卡片模版 → 实时预览 → 复制文本 / 导出图片。
/// 模版见 [kShareTemplates]；新增风格只需往那个列表里加一项。
class SharePage extends ConsumerStatefulWidget {
  final String? diaryId;

  const SharePage({super.key, this.diaryId});

  @override
  ConsumerState<SharePage> createState() => _SharePageState();
}

class _SharePageState extends ConsumerState<SharePage> {
  final _boundaryKey = GlobalKey();
  bool _exporting = false;
  int _selected = 0;

  Future<void> _copy(Diary d) async {
    final text = [
      d.title,
      DateFormat.yMMMMd().add_Hm().format(d.time),
      '',
      d.contentText,
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    toast.success(message: '已复制到剪贴板');
  }

  Future<void> _exportImage() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final boundary = _boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();
      final dir = PlatformService.get().applicationCachePath;
      final filename =
          'moodiary_share_${DateTime.now().millisecondsSinceEpoch}.png';
      final filePath = p.join(dir, filename);
      await File(filePath).writeAsBytes(bytes);
      if (!mounted) return;
      try {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(filePath, mimeType: 'image/png')],
            text: '来自 Moodiary 的分享',
          ),
        );
      } catch (_) {
        await Clipboard.setData(ClipboardData(text: filePath));
        toast.info(message: '已生成图片：$filePath（路径已复制）');
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final diaryAsync = ref.watch(_shareDiaryProvider(widget.diaryId));
    return Scaffold(
      appBar: AppBar(title: const Text('分享')),
      body: diaryAsync.buildLoading(
        data: (diary) {
          if (diary == null) {
            return const Center(child: Text('没有可分享的日记'));
          }
          return SafeArea(
            child: Column(
              children: [
                Expanded(child: _preview(diary)),
                _templatePicker(),
                _actions(diary),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _preview(Diary diary) {
    return Container(
      width: double.infinity,
      color: context.colorScheme.surfaceContainerHighest,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: RepaintBoundary(
            key: _boundaryKey,
            child: kShareTemplates[_selected].builder(diary),
          ),
        ),
      ),
    );
  }

  Widget _templatePicker() {
    return SizedBox(
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: kShareTemplates.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final t = kShareTemplates[i];
          return ChoiceChip(
            label: Text(t.name),
            selected: _selected == i,
            onSelected: (_) => setState(() => _selected = i),
          );
        },
      ),
    );
  }

  Widget _actions(Diary diary) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        4,
        16,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.tonalIcon(
              onPressed: () => _copy(diary),
              icon: const Icon(Icons.copy),
              label: const Text('复制文本'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: _exporting ? null : _exportImage,
              icon: _exporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.image_outlined),
              label: const Text('导出图片'),
            ),
          ),
        ],
      ),
    );
  }
}

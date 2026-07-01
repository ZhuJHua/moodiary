import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:moodiary/feature/diary/application/diary_controller.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

class SharePage extends ConsumerStatefulWidget {
  final String? diaryId;

  const SharePage({super.key, this.diaryId});

  @override
  ConsumerState<SharePage> createState() => _SharePageState();
}

class _SharePageState extends ConsumerState<SharePage> {
  final _boundaryKey = GlobalKey();
  bool _exporting = false;

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

  Future<void> _exportImage(Diary d) async {
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
    final diaryAsync = ref.watch(getDiaryProvider(id: widget.diaryId));
    return Scaffold(
      appBar: AppBar(title: const Text('分享')),
      body: diaryAsync.buildLoading(
        data: (diary) {
          if (diary == null) {
            return const Center(child: Text('没有可分享的日记'));
          }
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: RepaintBoundary(
                        key: _boundaryKey,
                        child: _Card(diary: diary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _copy(diary),
                          icon: const Icon(Icons.copy),
                          label: const Text('复制文本'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed:
                              _exporting ? null : () => _exportImage(diary),
                          icon: _exporting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.image_outlined),
                          label: const Text('导出图片'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Diary diary;
  const _Card({required this.diary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              diary.title.isEmpty ? '(无标题)' : diary.title,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat.yMMMMd().add_Hm().format(diary.time),
              style: theme.textTheme.labelSmall,
            ),
            const SizedBox(height: 16),
            Text(
              diary.contentText,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Moodiary · 心情指数 ${(diary.mood * 100).toStringAsFixed(0)}%',
                style: theme.textTheme.labelSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

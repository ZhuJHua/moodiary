import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
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

/// 分享页：选模版 + 明暗主题 → 实时预览浮起卡片 → 复制文本 / 导出图片。
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

  /// 卡片明暗，null = 跟随 app 当前主题（首次进入的默认值）。
  Brightness? _brightness;

  Future<void> _copy(Diary d) async {
    final text = [
      d.title,
      TimeFormat.longDateTime(d.time),
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
      final boundary =
          _boundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: .png);
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
      appBar: AppBar(title: const Text('分享'), scrolledUnderElevation: 0),
      body: diaryAsync.buildLoading(
        data: (diary) {
          if (diary == null) {
            return const Center(child: Text('没有可分享的日记'));
          }
          final brightness = _brightness ?? Theme.of(context).brightness;
          return SafeArea(
            child: Column(
              children: [
                Expanded(child: _preview(diary, brightness)),
                _controls(),
                _actions(diary),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _preview(Diary diary, Brightness brightness) {
    final scheme = context.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: .topCenter,
          end: .bottomCenter,
          colors: [scheme.surfaceContainerHigh, scheme.surfaceContainerLow],
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const .symmetric(horizontal: 24, vertical: 28),
          // 阴影包在 RepaintBoundary 外层 —— 只让卡片本体入图，阴影/背景不导出。
          child: Container(
            decoration: BoxDecoration(
              borderRadius: .circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 32,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: RepaintBoundary(
              key: _boundaryKey,
              child: kShareTemplates[_selected].builder(diary, brightness),
            ),
          ),
        ),
      ),
    );
  }

  Widget _controls() {
    final brightness = _brightness ?? Theme.of(context).brightness;
    return Padding(
      padding: const .fromLTRB(12, 12, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: .horizontal,
                itemCount: kShareTemplates.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) => ChoiceChip(
                  label: Text(kShareTemplates[i].name),
                  selected: _selected == i,
                  onSelected: (_) => setState(() => _selected = i),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SegmentedButton<Brightness>(
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              visualDensity: .compact,
              tapTargetSize: .shrinkWrap,
            ),
            segments: const [
              ButtonSegment(
                value: Brightness.light,
                icon: Icon(LucideIcons.sun),
              ),
              ButtonSegment(
                value: Brightness.dark,
                icon: Icon(LucideIcons.moon),
              ),
            ],
            selected: {brightness},
            onSelectionChanged: (s) => setState(() => _brightness = s.first),
          ),
        ],
      ),
    );
  }

  Widget _actions(Diary diary) {
    ButtonStyle shape() => FilledButton.styleFrom(
      shape: RoundedRectangleBorder(borderRadius: .circular(14)),
    );
    return Padding(
      padding: .fromLTRB(16, 8, 16, 12 + MediaQuery.paddingOf(context).bottom),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 50,
              child: FilledButton.tonalIcon(
                onPressed: () => _copy(diary),
                style: shape(),
                icon: const Icon(LucideIcons.copy),
                label: const Text('复制文本'),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed: _exporting ? null : _exportImage,
                style: shape(),
                icon: _exporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(LucideIcons.share),
                label: const Text('导出图片'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

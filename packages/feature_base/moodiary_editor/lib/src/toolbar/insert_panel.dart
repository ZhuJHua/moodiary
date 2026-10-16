import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:mui/mui.dart';

import 'panel_parts.dart';

enum InsertItem {
  gallery(LucideIcons.images, media: true),
  camera(LucideIcons.camera, media: true),
  video(LucideIcons.video, media: true),
  record(LucideIcons.mic, media: true),
  audio(LucideIcons.fileAudio, media: true),
  attachment(LucideIcons.paperclip, media: true),
  table(LucideIcons.table),
  divider(LucideIcons.separatorHorizontal),
  quote(LucideIcons.textQuote),
  codeBlock(LucideIcons.squareCode),
  task(LucideIcons.listTodo),
  diaryLink(LucideIcons.bookOpen);

  final IconData icon;
  final bool media;

  const InsertItem(this.icon, {this.media = false});

  String label(BuildContext context) {
    final t = context.l10n.editor.toolbar;
    return switch (this) {
      gallery => t.gallery,
      camera => t.camera,
      video => t.video,
      record => t.record,
      audio => t.audio,
      attachment => t.attachment,
      table => t.table,
      divider => t.divider,
      quote => t.quote,
      codeBlock => t.codeBlock,
      task => t.task,
      diaryLink => t.diaryLink,
    };
  }
}

class InsertPanel extends StatelessWidget {
  final bool inTable;
  final ValueChanged<InsertItem> onInsert;

  const InsertPanel({super.key, required this.inTable, required this.onInsert});

  @override
  Widget build(BuildContext context) {
    final t = context.l10n.editor.toolbar;
    final blocks = [
      for (final item in InsertItem.values)
        if (!item.media && !(inTable && item == .table)) item,
    ];
    return PanelScroll(
      top: 20,
      gap: 22,
      children: [
        _Section(
          title: t.mediaAndFiles,
          items: [
            for (final item in InsertItem.values)
              if (item.media) item,
          ],
          onInsert: onInsert,
        ),
        _Section(title: t.blocks, items: blocks, onInsert: onInsert),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<InsertItem> items;
  final ValueChanged<InsertItem> onInsert;

  const _Section({
    required this.title,
    required this.items,
    required this.onInsert,
  });

  @override
  Widget build(BuildContext context) {
    final typo = context.theme.typography;
    return Column(
      crossAxisAlignment: .stretch,
      spacing: 12,
      children: [
        Padding(
          padding: const .only(left: 4),
          child: Text(title, style: typo.labelMedium.onSurfaceVariant),
        ),
        Row(
          children: [
            for (var i = 0; i < 6; i++)
              Expanded(
                child: i < items.length
                    ? _Tile(item: items[i], onTap: () => onInsert(items[i]))
                    : const SizedBox.shrink(),
              ),
          ],
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  final InsertItem item;
  final VoidCallback onTap;

  const _Tile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final label = item.label(context);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: MInkWell.fade(
        onTap: onTap,
        child: Column(
          spacing: 7,
          children: [
            Container(
              width: 50,
              height: 50,
              alignment: .center,
              decoration: BoxDecoration(
                color: colors.surfaceContainerLowest,
                borderRadius: .circular(16),
              ),
              child: Icon(item.icon, size: 22, color: colors.onSurface),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: .ellipsis,
              style: context.theme.typography.labelMedium.onSurface,
            ),
          ],
        ),
      ),
    );
  }
}

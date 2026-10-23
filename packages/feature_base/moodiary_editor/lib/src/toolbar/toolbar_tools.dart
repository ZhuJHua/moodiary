import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:mui/mui.dart';

enum ToolbarTool {
  insert(LucideIcons.plus, shownByDefault: true),
  format(LucideIcons.type, shownByDefault: true),
  task(LucideIcons.listTodo, shownByDefault: true),
  image(LucideIcons.image, shownByDefault: true),
  link(LucideIcons.link, shownByDefault: true),
  diaryLink(LucideIcons.bookOpen, shownByDefault: true),
  bold(LucideIcons.bold),
  italic(LucideIcons.italic),
  underline(LucideIcons.underline),
  strike(LucideIcons.strikethrough),
  highlight(LucideIcons.highlighter),
  inlineCode(LucideIcons.code),
  bulletList(LucideIcons.list),
  orderedList(LucideIcons.listOrdered),
  quote(LucideIcons.textQuote),
  codeBlock(LucideIcons.squareCode),
  table(LucideIcons.table),
  divider(LucideIcons.separatorHorizontal),
  camera(LucideIcons.camera),
  video(LucideIcons.video),
  record(LucideIcons.mic),
  audio(LucideIcons.fileAudio),
  attachment(LucideIcons.paperclip),
  clearFormat(LucideIcons.removeFormatting);

  final IconData icon;
  final bool shownByDefault;

  const ToolbarTool(this.icon, {this.shownByDefault = false});

  String label(BuildContext context) {
    final t = context.l10n.editor.toolbar;
    return switch (this) {
      insert => t.insert,
      format => t.format,
      task => t.task,
      image => t.image,
      link => t.link,
      diaryLink => t.diaryLink,
      bold => t.bold,
      italic => t.italic,
      underline => t.underline,
      strike => t.strike,
      highlight => t.highlight,
      inlineCode => t.inlineCode,
      bulletList => t.bulletList,
      orderedList => t.orderedList,
      quote => t.quote,
      codeBlock => t.codeBlock,
      table => t.table,
      divider => t.divider,
      camera => t.camera,
      video => t.video,
      record => t.record,
      audio => t.audio,
      attachment => t.attachment,
      clearFormat => t.clearFormat,
    };
  }

  static const selection = [
    bold,
    italic,
    underline,
    strike,
    highlight,
    link,
    format,
  ];

  static final defaults = [
    for (final tool in values)
      if (tool.shownByDefault) tool,
  ];
}

abstract final class ToolbarPrefs {
  static List<ToolbarTool> load() => resolveToolbar(
    MoodiaryKVs.editorToolbarOrder.get(),
    {...?MoodiaryKVs.editorToolbarHidden.get()},
  );

  static void save(List<ToolbarTool> shown) {
    MoodiaryKVs.editorToolbarOrder.set([for (final t in shown) t.name]);
    MoodiaryKVs.editorToolbarHidden.set([
      for (final t in ToolbarTool.defaults)
        if (!shown.contains(t)) t.name,
    ]);
  }

  static void reset() {
    MoodiaryKVs.editorToolbarOrder.remove();
    MoodiaryKVs.editorToolbarHidden.remove();
  }
}

@visibleForTesting
List<ToolbarTool> resolveToolbar(List<String>? saved, Set<String> hidden) {
  if (saved == null) return ToolbarTool.defaults;
  final byName = ToolbarTool.values.asNameMap();
  final merged = mergeOrder(
    [for (final t in ToolbarTool.defaults) t.name],
    saved.where(byName.containsKey).toList(),
    skip: hidden,
  );
  return [for (final name in merged) byName[name]!];
}

@visibleForTesting
List<String> mergeOrder(
  List<String> defaults,
  List<String> saved, {
  Set<String> skip = const {},
}) {
  final result = [...saved];
  for (var i = 0; i < defaults.length; i++) {
    final id = defaults[i];
    if (result.contains(id) || skip.contains(id)) continue;
    var at = 0;
    for (var j = i - 1; j >= 0; j--) {
      final prev = result.indexOf(defaults[j]);
      if (prev >= 0) {
        at = prev + 1;
        break;
      }
    }
    result.insert(at, id);
  }
  return result;
}

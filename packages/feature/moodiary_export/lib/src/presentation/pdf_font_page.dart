import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:mui/mui.dart';
import 'package:path/path.dart' as p;

/// 选一个用于 PDF 的字体，返回它的文件名；取消返回 null。
///
/// PDF 必须把字体嵌进文件才能显示中文，而本应用不内置任何字体 —— 用的是用户在
/// 「字体样式」页导入的那些。排版引擎换成 typst 之后 TTF / OTF / 字体集合都能读，
/// 不用再按格式挑拣（dart_pdf 时代只吃 TrueType，`.otf` 会静默产出结构非法的 PDF，
/// 所以那时这页要逐个判魔数、把不可用的置灰）。
class PdfFontPage extends StatefulWidget {
  final String selected;

  const PdfFontPage({super.key, required this.selected});

  @override
  State<PdfFontPage> createState() => _PdfFontPageState();
}

class _PdfFontPageState extends State<PdfFontPage> {
  List<Font> _fonts = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final fonts = await FontManager.getAllFonts();
    if (!mounted) return;
    setState(() {
      _fonts = fonts;
      _loading = false;
    });
  }

  Future<void> _import() async {
    final l10n = context.l10n;
    final picked = await FontManager.pickFont();
    if (picked == null) return;

    toast.loading(message: l10n.exportImportingFont);
    try {
      final name = await FontManager.getFontName(filePath: picked.path);
      if (name == null) {
        await toast.dismiss();
        toast.error(message: l10n.exportFontNameUnreadable);
        return;
      }
      final fileName = '$name${p.extension(picked.path)}';
      await picked.saveTo(AppFiles.getRealPath('font', fileName));
      await toast.dismiss();
      await _load();
      if (mounted) Navigator.of(context).pop(fileName);
    } catch (e) {
      await toast.dismiss();
      toast.error(message: l10n.exportImportFailed('$e'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = context.theme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.exportPdfFontPageTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const .symmetric(horizontal: 8, vertical: 8),
              children: [
                if (_fonts.isEmpty) _empty(),
                if (_fonts.isNotEmpty)
                  Column(
                    crossAxisAlignment: .stretch,
                    children: [
                      SettingTitleTile(title: l10n.exportImportedFonts),
                      Card.filled(
                        color: theme.colors.surfaceContainerLow,
                        margin: .zero,
                        child: Column(
                          children: [for (final font in _fonts) _tile(font)],
                        ),
                      ),
                    ],
                  ),
                Padding(
                  padding: const .only(top: 16),
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const .fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: .circular(14),
                      ),
                    ),
                    onPressed: _import,
                    icon: const Icon(LucideIcons.fileUp),
                    label: Text(l10n.exportImportFont),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _empty() {
    final l10n = context.l10n;
    final theme = context.theme;
    return Container(
      padding: const .symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: theme.colors.surfaceContainerLow,
        borderRadius: .circular(16),
        border: .all(color: theme.colors.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(LucideIcons.type, size: 30, color: theme.colors.primary),
          const SizedBox(height: 10),
          Text(
            l10n.exportNoPdfFontTitle,
            style: theme.typography.titleSmall.onSurface,
          ),
          const SizedBox(height: 6),
          Text(
            l10n.exportNoPdfFontMessage,
            textAlign: .center,
            style: theme.typography.bodySmall.onSurfaceVariant,
          ),
        ],
      ),
    );
  }

  Widget _tile(Font font) {
    final theme = context.theme;
    return ListTile(
      leading: const Icon(LucideIcons.type),
      title: Text(font.fontFamily),
      trailing: font.fontFileName == widget.selected
          ? Icon(LucideIcons.check, color: theme.colors.primary)
          : null,
      onTap: () => Navigator.of(context).pop(font.fontFileName),
    );
  }
}

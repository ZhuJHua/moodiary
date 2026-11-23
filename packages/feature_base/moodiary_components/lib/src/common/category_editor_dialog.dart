import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:mui/mui.dart';

class CategoryDraft {
  final String name;
  final int? color;

  const CategoryDraft({required this.name, required this.color});
}

Future<CategoryDraft?> showCategoryEditor(
  BuildContext context, {
  required String initialName,
  required int? initialColor,
}) async {
  final draft = _CategoryDraft(name: initialName, color: initialColor);
  final contentKey = GlobalKey<_CategoryEditorContentState>();
  final confirmed = await MAlert.show<bool>(
    context,
    content: _CategoryEditorContent(key: contentKey, draft: draft),
    actions: [
      MAction(label: context.l10n.common.cancel, value: false),
      MAction(
        label: context.l10n.common.ok,
        value: true,
        isPrimary: true,
        onIntercept: () => contentKey.currentState?.validate() ?? false,
      ),
    ],
  );
  if (confirmed != true) return null;
  return CategoryDraft(name: draft.name.trim(), color: draft.color);
}

class _CategoryDraft {
  String name;
  int? color;

  _CategoryDraft({required this.name, required this.color});
}

class _CategoryEditorContent extends StatefulWidget {
  final _CategoryDraft draft;

  const _CategoryEditorContent({super.key, required this.draft});

  @override
  State<_CategoryEditorContent> createState() => _CategoryEditorContentState();
}

class _CategoryEditorContentState extends State<_CategoryEditorContent> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.draft.name,
  );

  bool _edited = false;

  bool validate() {
    final ok = widget.draft.name.trim().isNotEmpty;
    if (!ok && !_edited) setState(() => _edited = true);
    return ok;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    OutlineInputBorder border([BorderSide side = .none]) => OutlineInputBorder(
      borderRadius: AppBorderRadius.mediumBorderRadius,
      borderSide: side,
    );

    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .start,
      children: [
        TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: .done,
          onChanged: (value) => setState(() {
            _edited = true;
            widget.draft.name = value;
          }),
          style: context.theme.typography.bodyLarge.onSurface,
          decoration: InputDecoration(
            hintText: context.l10n.diary.categoryNameHint,
            errorText: _edited && widget.draft.name.trim().isEmpty
                ? context.l10n.diary.categoryNameEmpty
                : null,
            filled: true,
            isDense: true,
            fillColor: colors.surfaceContainerHighest,
            contentPadding: const .symmetric(horizontal: 16, vertical: 13),
            border: border(),
            enabledBorder: border(),
            focusedBorder: border(
              BorderSide(color: colors.primary, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          context.l10n.diary.categoryColorLabel,
          style: context.theme.typography.labelMedium.onSurfaceVariant,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in kCategoryPalette)
              GestureDetector(
                key: ValueKey('category-swatch-${c.toARGB32()}'),
                onTap: () => setState(() => widget.draft.color = c.toARGB32()),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: c,
                    shape: .circle,
                    border: .all(
                      color: widget.draft.color == c.toARGB32()
                          ? colors.onSurface
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

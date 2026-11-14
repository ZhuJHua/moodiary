import 'dart:async';

import 'package:flutter/services.dart';

import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:mui/mui.dart';

import '../moodiary_editor.dart';
import 'toolbar_button.dart';

class EditorFindBar extends StatefulWidget {
  final MoodiaryEditorController controller;
  final bool editable;

  const EditorFindBar({
    super.key,
    required this.controller,
    required this.editable,
  });

  @override
  State<EditorFindBar> createState() => _EditorFindBarState();
}

class _EditorFindBarState extends State<EditorFindBar> {
  final _queryFocus = FocusNode();
  final _query = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _queryFocus.requestFocus();
    });
  }

  final _replacement = TextEditingController();
  Timer? _debounce;
  bool _replacing = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _queryFocus.dispose();
    _query.dispose();
    _replacement.dispose();
    super.dispose();
  }

  void _onQuery(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      widget.controller.exec(.search, {'query': value});
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n.editor.toolbar;
    final colors = context.theme.colors;
    final c = widget.controller;
    return Focus(
      onKeyEvent: (_, event) {
        final keyboard = HardwareKeyboard.instance;
        final next =
            event.logicalKey == LogicalKeyboardKey.f3 ||
            (event.logicalKey == LogicalKeyboardKey.keyG &&
                (keyboard.isMetaPressed || keyboard.isControlPressed));
        if (event.logicalKey != LogicalKeyboardKey.escape && !next) {
          return KeyEventResult.ignored;
        }
        if (event is KeyDownEvent) {
          if (next) {
            c.exec(keyboard.isShiftPressed ? .searchPrev : .searchNext);
          } else {
            c.closeSearch();
          }
        }
        return KeyEventResult.handled;
      },
      child: Container(
        padding: const .fromLTRB(12, 4, 4, 8),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(
            bottom: BorderSide(color: colors.outlineVariant, width: 1),
          ),
        ),
        child: Column(
          mainAxisSize: .min,
          spacing: 8,
          children: [
            Row(
              children: [
                Expanded(
                  child: MField(
                    controller: _query,
                    focusNode: _queryFocus,
                    hintText: t.findHint,
                    autofocus: true,
                    textInputAction: .search,
                    onChanged: _onQuery,
                    onSubmitted: (_) => c.exec(.searchNext),
                  ),
                ),
                ValueListenableBuilder(
                  valueListenable: c.search,
                  builder: (context, search, _) {
                    final total = search?.total ?? 0;
                    return Row(
                      mainAxisSize: .min,
                      children: [
                        if (search != null && search.query.isNotEmpty)
                          Padding(
                            padding: const .symmetric(horizontal: 8),
                            child: Text(
                              t.matchCount(
                                current: search.current,
                                total: total,
                              ),
                              style: context
                                  .theme
                                  .typography
                                  .labelMedium
                                  .onSurfaceVariant
                                  .tabular,
                            ),
                          ),
                        ToolbarIconButton(
                          icon: LucideIcons.chevronUp,
                          tooltip: t.previousMatch,
                          onTap: total > 0 ? () => c.exec(.searchPrev) : null,
                        ),
                        ToolbarIconButton(
                          icon: LucideIcons.chevronDown,
                          tooltip: t.nextMatch,
                          onTap: total > 0 ? () => c.exec(.searchNext) : null,
                        ),
                      ],
                    );
                  },
                ),
                if (widget.editable)
                  ToolbarIconButton(
                    icon: LucideIcons.replace,
                    tooltip: t.toggleReplace,
                    tone: _replacing ? .on : .plain,
                    onTap: () => setState(() => _replacing = !_replacing),
                  ),
                ToolbarIconButton(
                  icon: LucideIcons.x,
                  tooltip: t.closeFind,
                  onTap: c.closeSearch,
                ),
              ],
            ),
            if (_replacing && widget.editable)
              Row(
                spacing: 4,
                children: [
                  Expanded(
                    child: MField(
                      controller: _replacement,
                      hintText: t.replaceHint,
                      textInputAction: .done,
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        c.exec(.replace, {'text': _replacement.text}),
                    child: Text(t.replace),
                  ),
                  TextButton(
                    onPressed: () =>
                        c.exec(.replaceAll, {'text': _replacement.text}),
                    child: Text(t.replaceAll),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

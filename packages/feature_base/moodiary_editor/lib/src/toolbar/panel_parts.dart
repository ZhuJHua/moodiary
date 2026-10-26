import 'dart:math';

import 'package:mui/mui.dart';

import 'editor_command.dart';

typedef EditorExec = void Function(
  EditorCommand command, [
  Map<String, Object?>? args,
]);

Color panelGroupColor(BuildContext context) =>
    MSegmentGroup.trackColor(context);

Color panelSelectedColor(BuildContext context) =>
    MSegment.selectedColor(context);

Color panelSelectedForeground(BuildContext context) =>
    MSegment.selectedForeground(context);

class PanelScroll extends StatelessWidget {
  final double top;
  final double gap;
  final List<Widget> children;

  const PanelScroll({
    super.key,
    required this.top,
    required this.gap,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = max(16.0, MediaQuery.viewPaddingOf(context).bottom);
    return SingleChildScrollView(
      padding: .fromLTRB(16, top, 16, bottom),
      child: Column(
        crossAxisAlignment: .stretch,
        spacing: gap,
        children: children,
      ),
    );
  }
}

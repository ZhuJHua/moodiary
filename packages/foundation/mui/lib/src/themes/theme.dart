import 'package:material_ui/material_ui.dart';
import 'package:mui/src/themes/theme_data.dart';

final Expando<MuiThemeData> _views = Expando<MuiThemeData>('mui theme view');

class MuiTheme extends StatelessWidget {
  const MuiTheme({super.key, required this.data, required this.child});

  final ThemeData data;
  final Widget child;

  static MuiThemeData of(BuildContext context) => viewOf(Theme.of(context));

  static MuiThemeData viewOf(ThemeData raw) =>
      _views[raw] ??= MuiThemeData(raw);

  @override
  Widget build(BuildContext context) => Theme(data: data, child: child);
}

extension MuiThemeContext on BuildContext {
  MuiThemeData get theme => MuiTheme.of(this);

  double get safeBottom => MediaQuery.paddingOf(this).bottom;
}

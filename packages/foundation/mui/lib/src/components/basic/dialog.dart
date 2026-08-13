import 'package:mui/mui.dart';

class OptionDialog extends StatelessWidget {
  final String title;

  final Map<String, Function> options;

  const OptionDialog({super.key, required this.title, required this.options});

  Widget _buildOption({
    required String option,
    required Function onTap,
    required MuiThemeData theme,
  }) {
    return Padding(
      padding: const .symmetric(horizontal: 16, vertical: 8),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: MuiRadius.md,
          color: theme.colors.secondaryContainer,
        ),
        child: InkWell(
          borderRadius: MuiRadius.md,
          onTap: () {
            onTap.call();
          },
          child: Container(
            padding: const .symmetric(horizontal: 16, vertical: 8),
            child: Text(
              option,
              style: theme.typography.bodyMedium.onSecondaryContainer,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: Text(title),
      children: options.entries
          .map(
            (entry) => _buildOption(
              option: entry.key,
              onTap: entry.value,
              theme: context.theme,
            ),
          )
          .toList(),
    );
  }
}

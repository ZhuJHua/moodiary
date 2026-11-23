import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:mui/mui.dart';

class ManagerSearchField extends StatelessWidget {
  const ManagerSearchField({
    super.key,
    required this.hint,
    required this.onChanged,
  });

  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .fromLTRB(12, 12, 12, 6),
      child: TextField(
        onChanged: onChanged,
        textInputAction: .search,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(LucideIcons.search),
          filled: true,
          isDense: true,
          border: const OutlineInputBorder(
            borderRadius: AppBorderRadius.mediumBorderRadius,
            borderSide: .none,
          ),
        ),
      ),
    );
  }
}

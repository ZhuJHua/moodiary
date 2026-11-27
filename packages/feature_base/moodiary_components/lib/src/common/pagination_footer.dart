import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:mui/mui.dart';

class PaginationFooter extends StatelessWidget {
  final VoidCallback? onRetry;

  const PaginationFooter({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: Center(
      child: onRetry == null
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : TextButton(
              onPressed: onRetry,
              child: Text(context.l10n.common.retry),
            ),
    ),
  );
}

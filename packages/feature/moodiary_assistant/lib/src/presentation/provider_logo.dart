import 'package:moodiary_components/moodiary_components.dart';
import 'package:mui/mui.dart';

class ProviderLogo extends StatelessWidget {
  final String? logoUrl;
  final double size;

  const ProviderLogo({super.key, required this.logoUrl, this.size = 40});

  static String? urlOf(String presetId) =>
      presetId.isEmpty ? null : 'https://models.dev/logos/$presetId.svg';

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    final fallback = Center(
      child: Icon(
        LucideIcons.astroid,
        size: size * 0.6,
        color: scheme.onSurfaceVariant,
      ),
    );
    final url = logoUrl;
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: ColoredBox(
          color: scheme.surfaceContainerHighest,
          child: url == null || url.isEmpty
              ? fallback
              : Padding(
                  padding: .all(size * 0.18),
                  child: CachedImage(
                    url: url,
                    fit: .contain,
                    svgColor: scheme.onSurface,
                    placeholder: fallback,
                    errorWidget: fallback,
                  ),
                ),
        ),
      ),
    );
  }
}

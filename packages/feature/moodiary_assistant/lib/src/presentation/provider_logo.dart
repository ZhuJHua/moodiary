import 'package:moodiary_components/moodiary_components.dart';
import 'package:mui/mui.dart';

class ProviderLogo extends StatelessWidget {
  final String? logoUrl;
  final String name;
  final double size;

  const ProviderLogo({
    super.key,
    required this.logoUrl,
    required this.name,
    this.size = 40,
  });

  static String? urlOf(String presetId) =>
      presetId.isEmpty ? null : 'https://models.dev/logos/$presetId.svg';

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '#';
    final fallback = Center(
      child: Text(
        initial,
        style: context.theme.typography.titleMedium.onSurfaceVariant,
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

import 'package:flutter/material.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_ui/moodiary_ui.dart';

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

  static String? urlOf(String providerId) =>
      providerId.isEmpty ? null : 'https://models.dev/logos/$providerId.svg';

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '#';
    final fallback = Center(
      child: Text(
        initial,
        style: context.textTheme.titleMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
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
                  padding: EdgeInsets.all(size * 0.18),
                  child: CachedImage(
                    url: url,
                    fit: BoxFit.contain,
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

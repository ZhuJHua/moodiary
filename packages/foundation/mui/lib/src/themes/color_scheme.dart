import 'package:material_color_utilities/material_color_utilities.dart'
    show
        DynamicColor,
        DynamicScheme,
        Hct,
        MaterialDynamicColors,
        SchemeMonochrome,
        SchemeTonalSpot;
import 'package:material_ui/material_ui.dart';

@immutable
class MuiAccent {
  const MuiAccent.neutral() : seed = null;

  const MuiAccent.seeded(Color this.seed);

  final Color? seed;

  bool get isNeutral => seed == null;
}

ColorScheme resolveColorScheme(Brightness brightness, MuiAccent accent) {
  final seed = accent.seed;
  final scheme = seed == null
      ? SchemeMonochrome(
          sourceColorHct: Hct.fromInt(0xFF000000),
          isDark: brightness == Brightness.dark,
          contrastLevel: 0,
        )
      : SchemeTonalSpot(
          sourceColorHct: Hct.fromInt(seed.toARGB32()),
          isDark: brightness == Brightness.dark,
          contrastLevel: 0,
        );
  return _fromDynamicScheme(scheme, brightness);
}

ColorScheme _fromDynamicScheme(DynamicScheme scheme, Brightness brightness) {
  Color of(DynamicColor role) => Color(role.getArgb(scheme));
  final primary = of(MaterialDynamicColors.primary);
  return ColorScheme(
    brightness: brightness,

    primary: primary,
    onPrimary: of(MaterialDynamicColors.onPrimary),
    primaryContainer: of(MaterialDynamicColors.primaryContainer),
    onPrimaryContainer: of(MaterialDynamicColors.onPrimaryContainer),
    primaryFixed: of(MaterialDynamicColors.primaryFixed),
    primaryFixedDim: of(MaterialDynamicColors.primaryFixedDim),
    onPrimaryFixed: of(MaterialDynamicColors.onPrimaryFixed),
    onPrimaryFixedVariant: of(MaterialDynamicColors.onPrimaryFixedVariant),

    secondary: of(MaterialDynamicColors.secondary),
    onSecondary: of(MaterialDynamicColors.onSecondary),
    secondaryContainer: of(MaterialDynamicColors.secondaryContainer),
    onSecondaryContainer: of(MaterialDynamicColors.onSecondaryContainer),
    secondaryFixed: of(MaterialDynamicColors.secondaryFixed),
    secondaryFixedDim: of(MaterialDynamicColors.secondaryFixedDim),
    onSecondaryFixed: of(MaterialDynamicColors.onSecondaryFixed),
    onSecondaryFixedVariant: of(MaterialDynamicColors.onSecondaryFixedVariant),

    tertiary: of(MaterialDynamicColors.tertiary),
    onTertiary: of(MaterialDynamicColors.onTertiary),
    tertiaryContainer: of(MaterialDynamicColors.tertiaryContainer),
    onTertiaryContainer: of(MaterialDynamicColors.onTertiaryContainer),
    tertiaryFixed: of(MaterialDynamicColors.tertiaryFixed),
    tertiaryFixedDim: of(MaterialDynamicColors.tertiaryFixedDim),
    onTertiaryFixed: of(MaterialDynamicColors.onTertiaryFixed),
    onTertiaryFixedVariant: of(MaterialDynamicColors.onTertiaryFixedVariant),

    error: of(MaterialDynamicColors.error),
    onError: of(MaterialDynamicColors.onError),
    errorContainer: of(MaterialDynamicColors.errorContainer),
    onErrorContainer: of(MaterialDynamicColors.onErrorContainer),

    surface: of(MaterialDynamicColors.surface),
    onSurface: of(MaterialDynamicColors.onSurface),
    surfaceDim: of(MaterialDynamicColors.surfaceDim),
    surfaceBright: of(MaterialDynamicColors.surfaceBright),
    surfaceContainerLowest: of(MaterialDynamicColors.surfaceContainerLowest),
    surfaceContainerLow: of(MaterialDynamicColors.surfaceContainerLow),
    surfaceContainer: of(MaterialDynamicColors.surfaceContainer),
    surfaceContainerHigh: of(MaterialDynamicColors.surfaceContainerHigh),
    surfaceContainerHighest: of(MaterialDynamicColors.surfaceContainerHighest),
    onSurfaceVariant: of(MaterialDynamicColors.onSurfaceVariant),

    outline: of(MaterialDynamicColors.outline),
    outlineVariant: of(MaterialDynamicColors.outlineVariant),

    inverseSurface: of(MaterialDynamicColors.inverseSurface),
    onInverseSurface: of(MaterialDynamicColors.inverseOnSurface),
    inversePrimary: of(MaterialDynamicColors.inversePrimary),

    shadow: of(MaterialDynamicColors.shadow),
    scrim: of(MaterialDynamicColors.scrim),
    surfaceTint: primary,
    // ignore: deprecated_member_use
    surfaceVariant: of(MaterialDynamicColors.surfaceVariant),
  );
}

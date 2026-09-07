import 'package:cupertino_ui/cupertino_ui.dart'
    show CupertinoPageTransitionsBuilder;
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mui/src/themes/color_scheme.dart';
import 'package:mui/src/themes/mui_tokens.dart';
import 'package:mui/src/themes/page_transitions.dart';
import 'package:mui/src/themes/tokens.dart';
import 'package:mui/src/themes/typography.dart';

Widget _backIcon(BuildContext context) => const Icon(LucideIcons.arrowLeft);

Widget _closeIcon(BuildContext context) => const Icon(LucideIcons.x);

Widget _menuIcon(BuildContext context) => const Icon(LucideIcons.menu);

const ActionIconThemeData _actionIconTheme = ActionIconThemeData(
  backButtonIconBuilder: _backIcon,
  closeButtonIconBuilder: _closeIcon,
  drawerButtonIconBuilder: _menuIcon,
  endDrawerButtonIconBuilder: _menuIcon,
);

SystemUiOverlayStyle systemOverlayStyleOf(Brightness brightness) {
  final icons = brightness == Brightness.dark
      ? Brightness.light
      : Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: brightness,
    statusBarIconBrightness: icons,
    systemStatusBarContrastEnforced: false,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: icons,
    systemNavigationBarContrastEnforced: false,
  );
}

ThemeData buildMuiTheme({
  required Brightness brightness,
  MuiAccent accent = const MuiAccent.neutral(),
  MuiFontConfig font = const MuiFontConfig(),
  MuiRadii radii = const MuiRadii(),
  MuiSpacing spacing = const MuiSpacing(),
  MuiMotion motion = const MuiMotion(),
  MuiBorders borders = const MuiBorders(),
  MuiElevations? elevations,
  MuiStateTokens states = const MuiStateTokens(),
  Color onMedia = const Color(0xFFFFFFFF),
  Color? success,
}) {
  final cs = resolveColorScheme(brightness, accent);
  final text = buildTextTheme(font, cs.onSurface);

  final tokens = MuiTokens(
    onMedia: onMedia,
    success: success ?? MuiTokens.successFor(brightness),
    font: font,
    radii: radii,
    spacing: spacing,
    motion: motion,
    borders: borders,
    elevations: elevations ?? MuiElevations.of(brightness),
    states: states,
  );

  final pageTransitions = MuiPageTransitionsBuilder(
    motion: motion,
    scrim: cs.scrim,
    radius: radii.md,
  );

  final smRadius = BorderRadius.circular(radii.sm);
  final mdRadius = BorderRadius.circular(radii.md);
  final lgRadius = BorderRadius.circular(radii.lg);
  final xlRadius = BorderRadius.circular(radii.xl);

  final buttonShape = WidgetStatePropertyAll<OutlinedBorder>(
    RoundedRectangleBorder(borderRadius: mdRadius),
  );

  InputBorder fieldBorder(Color color, double width) => OutlineInputBorder(
    borderRadius: mdRadius,
    borderSide: color == Colors.transparent
        ? BorderSide.none
        : BorderSide(color: color, width: width),
  );

  return ThemeData(
    colorScheme: cs,
    brightness: brightness,
    fontFamily: font.family,
    typography: Typography.material2021(
      platform: defaultTargetPlatform,
      colorScheme: cs,
    ),
    textTheme: text,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    actionIconTheme: _actionIconTheme,
    extensions: [tokens],

    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        TargetPlatform.android: pageTransitions,
        TargetPlatform.iOS: const CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: const CupertinoPageTransitionsBuilder(),
      },
    ),

    iconTheme: IconThemeData(color: cs.onSurface),
    primaryIconTheme: IconThemeData(color: cs.onPrimary),
    dividerColor: cs.outlineVariant,
    hintColor: cs.onSurfaceVariant,
    unselectedWidgetColor: cs.onSurfaceVariant,
    disabledColor: cs.onSurface.withValues(alpha: states.disabledOpacity),
    shadowColor: cs.shadow,

    textSelectionTheme: TextSelectionThemeData(
      cursorColor: cs.primary,
      selectionColor: cs.primary.withValues(alpha: 0.25),
      selectionHandleColor: cs.primary,
    ),

    splashFactory: NoSplash.splashFactory,
    highlightColor: cs.onSurface.withValues(alpha: states.pressedOpacity),
    hoverColor: cs.onSurface.withValues(alpha: states.hoverOpacity),
    focusColor: cs.onSurface.withValues(alpha: states.focusOpacity),

    cardTheme: CardThemeData(
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: lgRadius),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(shape: buttonShape),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(shape: buttonShape),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(shape: buttonShape),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        shape: buttonShape,
        elevation: const WidgetStatePropertyAll(0),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(shape: buttonShape),
    ),

    segmentedButtonTheme: SegmentedButtonThemeData(
      selectedIcon: const Icon(LucideIcons.check),
      style: ButtonStyle(shape: buttonShape),
    ),

    chipTheme: ChipThemeData(
      shape: StadiumBorder(
        side: BorderSide(color: cs.outlineVariant, width: borders.hairline),
      ),
      elevation: 0,
      pressElevation: 0,
    ),

    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      isDense: true,
      fillColor: cs.surfaceContainerHighest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      border: fieldBorder(Colors.transparent, 0),
      enabledBorder: fieldBorder(Colors.transparent, 0),
      disabledBorder: fieldBorder(Colors.transparent, 0),
      focusedBorder: fieldBorder(cs.primary, borders.ring),
      errorBorder: fieldBorder(cs.error, borders.thin),
      focusedErrorBorder: fieldBorder(cs.error, borders.ring),
    ),

    appBarTheme: AppBarTheme(
      backgroundColor: cs.surface,
      scrolledUnderElevation: 0,
      systemOverlayStyle: systemOverlayStyleOf(brightness),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: cs.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black.withValues(alpha: 0.24),
      elevation: 8,
      barrierColor: cs.scrim.withValues(alpha: 0.32),
      shape: RoundedRectangleBorder(borderRadius: xlRadius),
      titleTextStyle: text.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: cs.onSurface,
      ),
      contentTextStyle: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: cs.surfaceContainer,
      modalBackgroundColor: cs.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      modalElevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(radii.xl)),
      ),
    ),

    menuTheme: MenuThemeData(
      style: MenuStyle(
        elevation: WidgetStateProperty.all(0),
        surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
        backgroundColor: WidgetStatePropertyAll(cs.surfaceContainer),
        shape: WidgetStatePropertyAll<OutlinedBorder>(
          RoundedRectangleBorder(
            borderRadius: lgRadius,
            side: BorderSide(color: cs.outlineVariant, width: borders.hairline),
          ),
        ),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: cs.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: lgRadius),
    ),

    datePickerTheme: DatePickerThemeData(
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: xlRadius),
    ),
    timePickerTheme: TimePickerThemeData(
      shape: RoundedRectangleBorder(borderRadius: xlRadius),
    ),
    searchBarTheme: SearchBarThemeData(
      elevation: WidgetStateProperty.all(0),
      shape: WidgetStatePropertyAll<OutlinedBorder>(
        RoundedRectangleBorder(borderRadius: mdRadius),
      ),
    ),
    searchViewTheme: SearchViewThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: lgRadius),
    ),

    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: cs.inverseSurface,
        borderRadius: smRadius,
      ),
      textStyle: text.bodySmall?.copyWith(color: cs.onInverseSurface),
    ),

    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(cs.secondary.withValues(alpha: 0.4)),
      thickness: const WidgetStatePropertyAll(4.0),
      radius: const Radius.circular(2.0),
      mainAxisMargin: 24.0,
    ),
  );
}

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mui/src/themes/color_scheme.dart';
import 'package:mui/src/themes/mui_tokens.dart';
import 'package:mui/src/themes/tokens.dart';
import 'package:mui/src/themes/typography.dart';

Widget _backIcon(BuildContext context) => const Icon(LucideIcons.arrowLeft);

Widget _closeIcon(BuildContext context) => const Icon(LucideIcons.x);

Widget _menuIcon(BuildContext context) => const Icon(LucideIcons.menu);

/// 框架自带 leading/actions 的图标（`AppBar` 隐式返回键、`Scaffold` 抽屉键、
/// `showDateRangePicker` 全屏关闭键）唯一的主题级替换入口 —— 全仓 60 个 `AppBar`
/// 都不写 `leading:`，靠这一处把 Material 字形换成 lucide。
/// 命中 builder 会短路掉 `_ActionIcon` 里的平台分支，iOS 的 `arrow_back_ios_new`
/// 与 Android 的 `arrow_back` 就此统一。
const ActionIconThemeData _actionIconTheme = ActionIconThemeData(
  backButtonIconBuilder: _backIcon,
  closeButtonIconBuilder: _closeIcon,
  drawerButtonIconBuilder: _menuIcon,
  endDrawerButtonIconBuilder: _menuIcon,
);

/// 状态栏与导航栏图标的明暗。**由主题亮度决定，不由背景色猜。**
///
/// 框架那条路只覆盖有 `AppBar` 的页面：`AppBar` 自带一层 `AnnotatedRegion`，
/// 缺省值来自 `estimateBrightnessForColor(背景色)`。没有 AppBar 的页面（日记详情、
/// 图片浏览、相机、视频全屏）不发任何注解，系统就沿用上一次设过的值 —— 症状是从
/// 深色页退回浅色页后状态栏图标仍是白的，看不见。所以这个值要同时喂给
/// [AppBarTheme.systemOverlayStyle] 与根部的 `AnnotatedRegion` 兜底。
///
/// iOS 与 Android 的字段语义相反：`statusBarBrightness` 说的是**背景**的明暗，
/// `statusBarIconBrightness` 说的是**图标**的明暗，所以两者必须写反。
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

/// 全仓唯一构造 [ThemeData] 的地方（由 `tool/check_layers.dart` 钉住）。
///
/// [ColorScheme] 与 [TextTheme] 就是配色与排版的真源；`ThemeData` 装不下的部分
/// 挂在 [MuiTokens] 扩展上。**深浅两档都必须挂**，否则 `ThemeData.lerp` 不会
/// 插值这些值，主题切换时会硬跳。
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
}) {
  final cs = resolveColorScheme(brightness, accent);
  final text = buildTextTheme(font, cs.onSurface);

  final tokens = MuiTokens(
    onMedia: onMedia,
    font: font,
    radii: radii,
    spacing: spacing,
    motion: motion,
    borders: borders,
    elevations: elevations ?? MuiElevations.of(brightness),
    states: states,
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

    // ── 色板漏点 ────────────────────────────────────────────────────
    // 下面这几个字段的 SDK 缺省值**完全绕开 colorScheme**：
    //   iconTheme             light 0xDD000000 / dark 纯白 —— 裸 Icon 从来不是 onSurface
    //   dividerColor          colorScheme.outline —— M3 规范里分隔线是 outlineVariant
    //   hintColor             black60 / white60
    //   unselectedWidgetColor black54 / white70
    //   disabledColor         black38 / white38
    //   shadowColor           Colors.black
    // 只投颜色不投尺寸：`IconTheme.of` 会用 `IconThemeData.fallback()` 补上 size 24。
    iconTheme: IconThemeData(color: cs.onSurface),
    primaryIconTheme: IconThemeData(color: cs.onPrimary),
    dividerColor: cs.outlineVariant,
    hintColor: cs.onSurfaceVariant,
    unselectedWidgetColor: cs.onSurfaceVariant,
    disabledColor: cs.onSurface.withValues(alpha: states.disabledOpacity),
    shadowColor: cs.shadow,

    // 光标与拖拽手柄用 primary，选中底色半透明（画在文字下方，要叠在任意背景上）。
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: cs.primary,
      selectionColor: cs.primary.withValues(alpha: 0.25),
      selectionHandleColor: cs.primary,
    ),

    // ── 一行式视觉收敛 ──────────────────────────────────────────────
    // 水波纹整个关掉：按压反馈是「状态驱动的色块变化」，不是从触点扩散的圆。
    // highlight/hover/focus **不能一起关**，否则 InkWell 完全没有按压反馈；
    // 这里把它们改成走 mui 的状态透明度档。
    //
    // 例外：`AssetPicker.themeData(...)` 是从零构造的 ThemeData，拿不到这里的设置，
    // 两个 wechat picker 因此保留原生水波纹 —— 那两个界面不归 mui 管。
    splashFactory: NoSplash.splashFactory,
    highlightColor: cs.onSurface.withValues(alpha: states.pressedOpacity),
    hoverColor: cs.onSurface.withValues(alpha: states.hoverOpacity),
    focusColor: cs.onSurface.withValues(alpha: states.focusOpacity),

    // 只动形状，**不动填充色** —— 在这里改底色会一次性重涂全仓每一张卡片。
    cardTheme: CardThemeData(
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: lgRadius,
        side: BorderSide(color: cs.outlineVariant, width: borders.hairline),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(shape: buttonShape),
    ),
    textButtonTheme: TextButtonThemeData(style: ButtonStyle(shape: buttonShape)),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(shape: buttonShape),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        shape: buttonShape,
        elevation: const WidgetStatePropertyAll(0),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(style: ButtonStyle(shape: buttonShape)),

    // SegmentedButton 选中态的 √（框架默认 Icons.check）。当前调用点都写了
    // showSelectedIcon: false，这里是给将来不写的那处兜底。
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

    // 圆角填充式、静息态无边框、聚焦态 1.5px 强调色环。
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

    // 内容滚到顶栏下方时不再有任何视觉变化。要关**两件事**，缺一个都还会跳：
    //   1. 底色：滚动态取的是 `colorScheme.surfaceContainer` 而非 `surface`；
    //   2. 阴影：scrolledUnderElevation 默认 3。
    // 注意**不是**改 surfaceTintColor —— M3 默认值本来就是 transparent。
    appBarTheme: AppBarTheme(
      backgroundColor: cs.surface,
      scrolledUnderElevation: 0,
      systemOverlayStyle: systemOverlayStyleOf(brightness),
    ),

    // 兜住尚未迁到 MAlert 的原生弹窗（选择列表、进度、日期选择器）。
    // 弹窗的 elevation **不归零**：它浮在遮罩上，投影是层级信息。
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
      decoration: BoxDecoration(color: cs.inverseSurface, borderRadius: smRadius),
      textStyle: text.bodySmall?.copyWith(color: cs.onInverseSurface),
    ),

    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(
        cs.secondary.withValues(alpha: 0.4),
      ),
      thickness: const WidgetStatePropertyAll(4.0),
      radius: const Radius.circular(2.0),
      mainAxisMargin: 24.0,
    ),
  );
}

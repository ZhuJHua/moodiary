import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mui/mui.dart';

/// 全仓唯一同时 import `material` 与 `mui` 的文件 —— 也是唯一构造 [ThemeData] 的地方。
///
/// 方向是**单向**的：[MuiThemeData] 是真源，material 的 [ThemeData] 是它的只读投影。
/// 没有反向读取，所以共存期两棵主题树不可能漂。
///
/// 投影必须**全覆盖显式赋值**，禁止 `ColorScheme.fromSeed(...).copyWith(...)`：
/// [ColorScheme] 的 46 个角色里只有 9 个是 required，其余漏填不会编译失败，而是
/// 坍塌式回退 —— `surfaceContainer* ?? surface`、`tertiary ?? secondary`、
/// `outlineVariant ?? onBackground`。症状是整条容器阶梯塌成同一个 surface
/// （卡片、弹窗、菜单和页面同色），发丝线塌成近黑。**编译器不是闸门**，
/// 闸门是 `mui_material_bridge_test.dart` 的逐角色对拍。

Widget _backIcon(BuildContext context) => const Icon(LucideIcons.arrowLeft);

Widget _closeIcon(BuildContext context) => const Icon(LucideIcons.x);

Widget _menuIcon(BuildContext context) => const Icon(LucideIcons.menu);

/// 框架自带 leading/actions 的图标（`AppBar` 隐式返回键、`Scaffold` 抽屉键、
/// `showDateRangePicker` 全屏关闭键）唯一的主题级替换入口 —— 全仓 30+ 个 `AppBar`
/// 都不写 `leading:`，靠这一处把 Material 字形换成 lucide。
/// 命中 builder 会短路掉 `_ActionIcon` 里的平台分支，iOS 的 `arrow_back_ios_new`
/// 与 Android 的 `arrow_back` 就此统一；代价是跳过 Android 专属的 semanticLabel，
/// 但 IconButton 的本地化 tooltip 还在，读屏不受影响。
const ActionIconThemeData _actionIconTheme = ActionIconThemeData(
  backButtonIconBuilder: _backIcon,
  closeButtonIconBuilder: _closeIcon,
  drawerButtonIconBuilder: _menuIcon,
  endDrawerButtonIconBuilder: _menuIcon,
);

/// 逐角色投影，47 个一个不落（46 个现役 + 1 个已废弃的 surfaceVariant）。顺序与 [MuiColorScheme] 的字段顺序一致，方便肉眼对齐。
ColorScheme materialColorSchemeFrom(MuiColorScheme c) => ColorScheme(
  brightness: c.brightness,
  primary: c.primary,
  onPrimary: c.onPrimary,
  primaryContainer: c.primaryContainer,
  onPrimaryContainer: c.onPrimaryContainer,
  primaryFixed: c.primaryFixed,
  primaryFixedDim: c.primaryFixedDim,
  onPrimaryFixed: c.onPrimaryFixed,
  onPrimaryFixedVariant: c.onPrimaryFixedVariant,
  secondary: c.secondary,
  onSecondary: c.onSecondary,
  secondaryContainer: c.secondaryContainer,
  onSecondaryContainer: c.onSecondaryContainer,
  secondaryFixed: c.secondaryFixed,
  secondaryFixedDim: c.secondaryFixedDim,
  onSecondaryFixed: c.onSecondaryFixed,
  onSecondaryFixedVariant: c.onSecondaryFixedVariant,
  tertiary: c.tertiary,
  onTertiary: c.onTertiary,
  tertiaryContainer: c.tertiaryContainer,
  onTertiaryContainer: c.onTertiaryContainer,
  tertiaryFixed: c.tertiaryFixed,
  tertiaryFixedDim: c.tertiaryFixedDim,
  onTertiaryFixed: c.onTertiaryFixed,
  onTertiaryFixedVariant: c.onTertiaryFixedVariant,
  error: c.error,
  onError: c.onError,
  errorContainer: c.errorContainer,
  onErrorContainer: c.onErrorContainer,
  surface: c.surface,
  onSurface: c.onSurface,
  surfaceDim: c.surfaceDim,
  surfaceBright: c.surfaceBright,
  surfaceContainerLowest: c.surfaceContainerLowest,
  surfaceContainerLow: c.surfaceContainerLow,
  surfaceContainer: c.surfaceContainer,
  surfaceContainerHigh: c.surfaceContainerHigh,
  surfaceContainerHighest: c.surfaceContainerHighest,
  onSurfaceVariant: c.onSurfaceVariant,
  outline: c.outline,
  outlineVariant: c.outlineVariant,
  inverseSurface: c.inverseSurface,
  onInverseSurface: c.onInverseSurface,
  inversePrimary: c.inversePrimary,
  shadow: c.shadow,
  scrim: c.scrim,
  surfaceTint: c.surfaceTint,
  // 已废弃但 SDK 仍在填；不投影就会坍塌成 surface。
  // ignore: deprecated_member_use
  surfaceVariant: c.surfaceVariant,
);

/// [MuiTypography] 的 15 级已带全套几何（M3 2021，字号已按 [MuiTextSize] 解析完）
/// 且 `inherit: false`，所以它会**整块替换**而不是 merge 掉默认排版 ——
/// `TextStyle.merge` 遇到 `inherit == false` 直接返回对方。连带地
/// `ThemeData.localize` 那条按 `ScriptCategory` 换几何的路径变成空操作，这是好事：
/// 实测 `englishLike2021 == dense2021 == tall2021`，本来就没有分档，
/// 显式钉死比隐式查表更可预期。
///
/// 取 `.onSurface` 是因为 material 的 `TextTheme` 只认一个颜色 —— 与
/// `Typography.material2021` 给 black/white 上色的结果一致。mui 侧的链式取色
/// （`typography.titleLarge.onSurfaceVariant`）在这条投影里表达不出来，
/// 那本来就是新 API 才有的表达力。
TextTheme materialTextThemeFrom(MuiTypography t) => TextTheme(
  displayLarge: t.displayLarge.onSurface,
  displayMedium: t.displayMedium.onSurface,
  displaySmall: t.displaySmall.onSurface,
  headlineLarge: t.headlineLarge.onSurface,
  headlineMedium: t.headlineMedium.onSurface,
  headlineSmall: t.headlineSmall.onSurface,
  titleLarge: t.titleLarge.onSurface,
  titleMedium: t.titleMedium.onSurface,
  titleSmall: t.titleSmall.onSurface,
  bodyLarge: t.bodyLarge.onSurface,
  bodyMedium: t.bodyMedium.onSurface,
  bodySmall: t.bodySmall.onSurface,
  labelLarge: t.labelLarge.onSurface,
  labelMedium: t.labelMedium.onSurface,
  labelSmall: t.labelSmall.onSurface,
);

/// 状态栏与导航栏图标的明暗。**由主题亮度决定，不由背景色猜。**
///
/// 框架那条路只覆盖有 `AppBar` 的页面：`AppBar` 自带一层
/// `AnnotatedRegion`，缺省值来自 `estimateBrightnessForColor(背景色)`
/// （app_bar.dart:1220）。没有 AppBar 的页面（日记详情、图片浏览、相机、
/// 视频全屏）不发任何注解，系统就沿用上一次设过的值 —— 症状是从深色页退回
/// 浅色页后状态栏图标仍是白的，看不见。所以这个值要同时喂给
/// [AppBarTheme.systemOverlayStyle] 与根部的 `AnnotatedRegion` 兜底。
///
/// iOS 与 Android 的字段语义相反：`statusBarBrightness` 说的是**背景**的明暗，
/// `statusBarIconBrightness` 说的是**图标**的明暗，所以两者必须写反。
SystemUiOverlayStyle systemOverlayStyleFrom(MuiThemeData t) {
  final dark = t.brightness == Brightness.dark;
  final icons = dark ? Brightness.light : Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: t.brightness,
    statusBarIconBrightness: icons,
    systemStatusBarContrastEnforced: false,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: icons,
    systemNavigationBarContrastEnforced: false,
  );
}

ThemeData materialThemeFrom(MuiThemeData t) {
  final cs = materialColorSchemeFrom(t.colors);
  final text = materialTextThemeFrom(t.typography);

  final smRadius = BorderRadius.circular(t.radii.sm);
  final mdRadius = BorderRadius.circular(t.radii.md);
  final lgRadius = BorderRadius.circular(t.radii.lg);
  final xlRadius = BorderRadius.circular(t.radii.xl);

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
    brightness: t.brightness,
    fontFamily: t.font.family,
    typography: Typography.material2021(
      platform: defaultTargetPlatform,
      colorScheme: cs,
    ),
    textTheme: text,
    materialTapTargetSize: .padded,
    actionIconTheme: _actionIconTheme,

    // ── 色板漏点 ────────────────────────────────────────────────────
    // 下面这几个字段的 SDK 缺省值**完全绕开 colorScheme**，是共存期最后几处
    // 「颜色不归 mui 管」的地方（行号为 theme_data.dart 3.44.8）：
    //   iconTheme            :526  light 0xDD000000 / dark 纯白 —— 所以裸 Icon
    //                              至今都不是 onSurface，只是碰巧接近
    //   dividerColor         :455  colorScheme.outline —— M3 规范里分隔线是
    //                              outlineVariant，outline 是给描边用的，重了一档
    //   hintColor            :487  black60 / white60
    //   unselectedWidgetColor:484  black54 / white70
    //   disabledColor        :500  black38 / white38
    //   shadowColor          :469  Colors.black
    // 只投颜色不投尺寸：`IconTheme.of` 会用 `IconThemeData.fallback()` 补上
    // size 24，material 组件的既有尺寸因此一动不动（mui 自己的 20/18/24
    // 三档留给将来的 MuiIcon）。
    iconTheme: IconThemeData(color: t.icons.color),
    primaryIconTheme: IconThemeData(color: cs.onPrimary),
    dividerColor: cs.outlineVariant,
    hintColor: cs.onSurfaceVariant,
    unselectedWidgetColor: cs.onSurfaceVariant,
    disabledColor: cs.onSurface.withValues(alpha: t.states.disabledOpacity),
    shadowColor: cs.shadow,

    // 选中底色是 mui 的自有槽位（半透明，画在文字下方），光标与拖拽手柄用 ring。
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: t.colors.ring,
      selectionColor: t.colors.selection,
      selectionHandleColor: t.colors.ring,
    ),

    // ── 一行式视觉收敛 ──────────────────────────────────────────────
    // 水波纹整个关掉。mui 的按压反馈是「状态驱动的色块变化」，不是从触点扩散的圆
    // （`nav_bar.dart:198` 早就写下过这个判断）。
    //
    // 注意 highlight/hover/focus **不能一起关**：关了 InkWell 就完全没有按压反馈，
    // 在 MuiTappable 落地之前会退化成「按下去没反应」。这里把它们改成走 mui 的
    // 状态透明度档，正好就是目标形态。
    //
    // 例外：`AssetPicker.themeData(...)` 是从零构造的 ThemeData（见
    // `mobile_file_picker.dart:62`），拿不到这里的设置，两个 wechat picker 因此
    // 保留原生水波纹 —— 这是对的，那两个界面不归 mui 管。
    splashFactory: NoSplash.splashFactory,
    highlightColor: cs.onSurface.withValues(alpha: t.states.pressedOpacity),
    hoverColor: cs.onSurface.withValues(alpha: t.states.hoverOpacity),
    focusColor: cs.onSurface.withValues(alpha: t.states.focusOpacity),

    // 圆角统一到 mui 的四档。只动形状，**不动填充色** —— 卡片的底色收敛归
    // MuiSurface（批次 2），在这里改会一次性重涂全仓每一张卡片。
    cardTheme: CardThemeData(
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: lgRadius,
        side: BorderSide(color: cs.outlineVariant, width: t.borders.hairline),
      ),
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
      style: ButtonStyle(shape: buttonShape, elevation: .all(0)),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(shape: buttonShape),
    ),

    // SegmentedButton 选中态的 √（框架默认 Icons.check）。当前调用点都写了
    // showSelectedIcon: false，这里是给将来不写的那处兜底。
    segmentedButtonTheme: SegmentedButtonThemeData(
      selectedIcon: const Icon(LucideIcons.check),
      style: ButtonStyle(shape: buttonShape),
    ),

    chipTheme: ChipThemeData(
      shape: StadiumBorder(
        side: BorderSide(color: cs.outlineVariant, width: t.borders.hairline),
      ),
      elevation: 0,
      pressElevation: 0,
    ),

    // 承接 `moodiary_ui/basic/form.dart:118-158` 那段已经达成目标视觉的装饰：
    // 圆角填充式、静息态无边框、聚焦态 1.5px 强调色环。搬进主题后
    // MoodiaryField 只需要留行为（清除按钮、密码切换、计数）。
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      isDense: true,
      fillColor: cs.surfaceContainerHighest,
      contentPadding: const .symmetric(horizontal: 16, vertical: 13),
      border: fieldBorder(Colors.transparent, 0),
      enabledBorder: fieldBorder(Colors.transparent, 0),
      disabledBorder: fieldBorder(Colors.transparent, 0),
      focusedBorder: fieldBorder(cs.primary, t.borders.ring),
      errorBorder: fieldBorder(cs.error, t.borders.thin),
      focusedErrorBorder: fieldBorder(cs.error, t.borders.ring),
    ),

    // 内容滚到顶栏下方时不再有任何视觉变化。要关的是**两件事**，缺一个都还会跳：
    //   1. 底色：滚动态取的是 `colorScheme.surfaceContainer` 而非 `surface`
    //      （app_bar.dart 的 scrolledUnderBackground）——把 backgroundColor 钉住，
    //      两种状态就都用它；
    //   2. 阴影：scrolledUnderElevation 默认 3，会投出一道影子。
    // 注意**不是**改 surfaceTintColor —— Flutter 3.44 的 M3 默认值本来就是
    // transparent（_AppBarDefaultsM3），设它等于没设。
    appBarTheme: AppBarTheme(
      backgroundColor: cs.surface,
      scrolledUnderElevation: 0,
      systemOverlayStyle: systemOverlayStyleFrom(t),
    ),

    // 兜住尚未迁到 showMoodiaryAlert 的原生弹窗（选择列表、进度、日期选择器），
    // 让它们的圆角/标题/遮罩与新组件一致 —— M3 默认是 28 圆角 + headlineSmall(24sp)
    // + black54。弹窗的 elevation **不归零**：它浮在遮罩上，投影是层级信息。
    dialogTheme: DialogThemeData(
      backgroundColor: cs.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black.withValues(alpha: 0.24),
      elevation: 8,
      barrierColor: cs.scrim.withValues(alpha: 0.32),
      shape: RoundedRectangleBorder(borderRadius: xlRadius),
      titleTextStyle: text.titleLarge?.copyWith(
        fontWeight: .w600,
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
        borderRadius: .vertical(top: Radius.circular(t.radii.xl)),
      ),
    ),

    menuTheme: MenuThemeData(
      style: MenuStyle(
        elevation: WidgetStateProperty.all(0),
        surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
        backgroundColor: .all(cs.surfaceContainer),
        shape: WidgetStatePropertyAll<OutlinedBorder>(
          RoundedRectangleBorder(
            borderRadius: lgRadius,
            side: BorderSide(
              color: cs.outlineVariant,
              width: t.borders.hairline,
            ),
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
      thumbColor: .all(cs.secondary.withValues(alpha: 0.4)),
      thickness: .all(4.0),
      radius: const .circular(2.0),
      mainAxisMargin: 24.0,
    ),
  );
}

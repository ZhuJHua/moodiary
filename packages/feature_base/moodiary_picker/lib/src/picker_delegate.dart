import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_picker/src/asset_thumb_image.dart';
import 'package:moodiary_picker/src/picker_route.dart';
import 'package:mui/mui.dart';
// picker 的状态用的是 provider，覆写点里要读它的 Consumer/Selector。
import 'package:provider/provider.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:wechat_picker_library/wechat_picker_library.dart';

/// Moodiary 风格的相册选择器。
///
/// **只重绘视觉件**：网格单元、序号角标、选中蒙层、确定按钮、相册胶囊与相册行、
/// 受限提示条、顶栏。资源分页、iCloud 回源、图库变更通知、受限授权、拖动多选
/// 全部沿用包里的实现 —— 那几层是「抄错了才出事」的活，本来就不该我们维护。
///
/// **这个文件是纯 mui 的，没有 legacy material**。material_ui 的 `Theme` 与
/// legacy 的 `Theme` 是两个不同的 widget 类型，所以 picker 内部那句
/// `Theme(data: pickerTheme)` 盖不住 mui 的取用链，这里 [mui] 拿到的仍是 App 的
/// 真主题。`pickerTheme` 只服务我们覆写不到的地方（见 `picker_theme.dart`）。
class MoodiaryPickerDelegate
    extends DefaultAssetPickerBuilderDelegate<DefaultAssetPickerProvider> {
  MoodiaryPickerDelegate({
    required super.provider,
    required super.initialPermission,
    required this.mui,
    required this.recentLabel,
    super.pickerTheme,
    super.textDelegate,
    super.specialItems,
    // iOS 默认会把整个网格翻转（新的在底）。关掉它有两个理由：相机格用的是
    // `prepend`，翻转后会被甩到视觉最后；两端排序不一致也没必要。
    super.shouldRevertGrid = false,
  }) : super(pathNameBuilder: _pathName(recentLabel));

  /// App 的真主题。构造时传进来，避免在 build 里依赖取用链的解析结果。
  final MuiThemeData mui;
  final String recentLabel;

  /// Android 的「全部照片」是个固定叫 `Recent` 的英文虚拟相册，不随系统语言。
  static PathNameBuilder<AssetPathEntity> _pathName(String recent) =>
      (path) => path.isAll ? recent : path.name;

  MuiThemeData get _t => mui;

  /// 角标固定 20dp，不按 `屏宽 / 列数 / 3` 算 —— 间距只有 2dp，按比例算出来的
  /// 角标之间会糊成一片。
  static const double _badgeSize = 20;

  // ——————————————————————————————— 网格单元 ——————————————————————————————— //

  /// 保留 [LocallyAvailableBuilder]（iCloud 未下载资源的那套状态机：先探
  /// `isLocallyAvailable`，为 false 才建 progress handler 并主动触发下载），
  /// 只把图源换成自家的 [AssetThumbImage]。
  ///
  /// 换图源是有理由的：包里默认的 `AssetEntityImageProvider` 有一张只增不删的
  /// 包级 Map（key 强引用 `AssetEntity`，滚过上万张就是上万条，`imageCache.clear()`
  /// 也清不掉），iOS 上每格还多一次 `titleAsync` 平台往返，而且它一个
  /// `PMCancelToken` 都不暴露 —— 滚出屏的请求撤不掉，Android 的原生线程池又是
  /// 无界队列。
  @override
  Widget imageAndVideoItemBuilder(
    BuildContext context,
    int index,
    AssetEntity asset,
  ) {
    final size = gridThumbnailSize;
    return LocallyAvailableBuilder(
      asset: asset,
      isOriginal: false,
      withSubtype: false,
      thumbnailOption: ThumbnailOption(size: size),
      builder: (context, asset) => Stack(
        fit: .expand,
        children: [
          ColoredBox(color: _t.colors.surfaceContainerHighest),
          RepaintBoundary(
            child: Image(
              image: AssetThumbImage(
                asset,
                width: size.width,
                height: size.height,
              ),
              fit: .cover,
              gaplessPlayback: true,
              errorBuilder: (context, _, _) => Center(
                child: Icon(
                  LucideIcons.imageOff,
                  size: 20,
                  color: _t.colors.outline,
                ),
              ),
            ),
          ),
          if (asset.type == AssetType.video) videoIndicator(context, asset),
        ],
      ),
    );
  }

  /// 选中只压一层暗遮罩，**不描边**：2dp 的间距下描边会把相邻格子连成一片，
  /// 而遮罩的明暗差本来就够读，序号角标还在上面再说一遍。
  @override
  Widget selectedBackdrop(BuildContext context, int index, AssetEntity asset) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: isPreviewEnabled ? () => viewAsset(context, index, asset) : null,
        child: Consumer<DefaultAssetPickerProvider>(
          builder: (context, p, _) {
            final selected = p.selectedAssets.contains(asset);
            if (!selected) return const SizedBox.expand();
            return ColoredBox(color: _t.colors.scrim.withValues(alpha: 0.38));
          },
        ),
      ),
    );
  }

  /// 选中 = 主色圆 + 序号（单选为对勾），未选 = 半透明底 + 白圈 —— 压在任何深浅
  /// 的照片上都读得出来。命中区靠 [ExpandTapWidget] 往**格子内部**扩到 44dp；
  /// 只能往内扩，往外那部分落在相邻格子里，父级不会把命中测试交过来。
  @override
  Widget selectIndicator(BuildContext context, int index, AssetEntity asset) {
    return Consumer<DefaultAssetPickerProvider>(
      builder: (context, p, _) {
        final order = p.selectedAssets.indexOf(asset) + 1;
        final selected = order > 0;
        final inner = Container(
          width: _badgeSize,
          height: _badgeSize,
          alignment: .center,
          decoration: BoxDecoration(
            shape: .circle,
            color: selected
                ? _t.colors.primary
                : _t.colors.scrim.withValues(alpha: 0.26),
            border: selected
                ? null
                : .all(color: _t.onMedia.withValues(alpha: 0.92), width: 1.4),
          ),
          child: selected
              ? (isSingleAssetMode
                    ? Icon(
                        LucideIcons.check,
                        size: 13,
                        color: _t.colors.onPrimary,
                      )
                    : Text(
                        '$order',
                        style: _t.typography.labelSmall.emphasized.onPrimary,
                        maxLines: 1,
                      ))
              : null,
        );
        return PositionedDirectional(
          top: 4,
          end: 4,
          child: Semantics(
            selected: selected,
            button: true,
            label: selected
                ? context.l10n.picker.a11yUnselect
                : context.l10n.picker.a11ySelect,
            child: ExpandTapWidget(
              onTap: () => selectAsset(context, asset, index, selected),
              tapPadding: const .only(left: 24, bottom: 24, top: 4, right: 4),
              child: inner,
            ),
          ),
        );
      },
    );
  }

  /// 视频时长条：渐变底 + `onMedia`，压在任何封面上都读得出来。
  /// 时长用自家的 `m:ss` 口径（包里那份是 `mm:ss`）。
  @override
  Widget videoIndicator(BuildContext context, AssetEntity asset) {
    return Align(
      alignment: .bottomCenter,
      child: Container(
        height: 22,
        padding: const .symmetric(horizontal: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: .bottomCenter,
            end: .topCenter,
            colors: [
              _t.colors.scrim.withValues(alpha: 0.5),
              _t.colors.scrim.withValues(alpha: 0),
            ],
          ),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.video, size: 13, color: _t.onMedia),
            const Spacer(),
            Text(
              formatAssetDuration(Duration(seconds: asset.duration)),
              style: _t.typography.labelSmall.onMedia,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  // ——————————————————————————————— 顶栏 ——————————————————————————————— //

  /// 顶栏左上角关闭键。默认实现写死 `Icons.close`，主题的 actionIconTheme 管不到
  /// （它不是 CloseButton，是裸 IconButton）。
  @override
  Widget backButton(BuildContext context) {
    return Padding(
      padding: const .symmetric(vertical: 4),
      child: IconButton(
        onPressed: () => Navigator.maybeOf(context)?.maybePop(),
        tooltip: context.muiL10n.cancel,
        icon: const Icon(LucideIcons.x),
      ),
    );
  }

  /// 相册切换胶囊。外面包一层 [DragDownToDismiss]：顶栏下拉关闭走的是与 Android
  /// 预测性返回**同一套** `PredictiveBackRoute` 接口，两种来源共用一条动画路径。
  @override
  Widget pathEntitySelector(BuildContext context) {
    return DragDownToDismiss(
      child: UnconstrainedBox(
        child: GestureDetector(
          onTap: () {
            if (isPermissionLimited && provider.isAssetsEmpty) {
              PhotoManager.presentLimited();
              return;
            }
            if (provider.currentPath == null) return;
            isSwitchingPath.value = !isSwitchingPath.value;
          },
          child: Container(
            height: appBarItemHeight,
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.5,
            ),
            padding: const EdgeInsetsDirectional.only(start: 14, end: 8),
            decoration: ShapeDecoration(
              shape: const StadiumBorder(),
              color: _t.colors.surfaceContainerHigh,
            ),
            child:
                Selector<
                  DefaultAssetPickerProvider,
                  PathWrapper<AssetPathEntity>?
                >(
                  selector: (_, p) => p.currentPath,
                  builder: (_, wrapper, child) {
                    final path = wrapper?.path;
                    final String? name;
                    if (path == null) {
                      name = isPermissionLimited
                          ? textDelegate.changeAccessibleLimitedAssets
                          : null;
                    } else if (isPermissionLimited && path.isAll) {
                      name = textDelegate.accessiblePathName;
                    } else {
                      name = pathNameBuilder?.call(path) ?? path.name;
                    }
                    return Row(
                      mainAxisSize: .min,
                      children: [
                        if (name != null)
                          Flexible(
                            child: Text(
                              name,
                              style:
                                  _t.typography.labelLarge.emphasized.onSurface,
                              maxLines: 1,
                              overflow: .ellipsis,
                            ),
                          ),
                        child!,
                      ],
                    );
                  },
                  child: ValueListenableBuilder<bool>(
                    valueListenable: isSwitchingPath,
                    builder: (_, switching, child) => AnimatedRotation(
                      duration: switchingPathDuration,
                      turns: switching ? 0.5 : 0,
                      child: child,
                    ),
                    child: Icon(
                      LucideIcons.chevronDown,
                      size: 20,
                      color: _t.colors.onSurfaceVariant,
                    ),
                  ),
                ),
          ),
        ),
      ),
    );
  }

  /// 相册面板行：方形缩略图 + 名称 + 数量灰字 + 选中对勾。
  @override
  Widget pathEntityWidget({
    required BuildContext context,
    required List<PathWrapper<AssetPathEntity>> list,
    required int index,
  }) {
    final wrapper = list[index];
    final path = wrapper.path;
    final data = wrapper.thumbnailData;
    final name = isPermissionLimited && path.isAll
        ? textDelegate.accessiblePathName
        : pathNameBuilder?.call(path) ?? path.name;
    final count = wrapper.assetCount?.toString();
    return Selector<DefaultAssetPickerProvider, PathWrapper<AssetPathEntity>?>(
      selector: (_, p) => p.currentPath,
      builder: (context, current, _) {
        final selected = current?.path == path;
        return Semantics(
          label: count == null ? name : '$name, $count',
          selected: selected,
          onTapHint: semanticsTextDelegate.sActionSwitchPathLabel,
          child: MInkWell(
            onTap: () {
              context.read<DefaultAssetPickerProvider>().switchPath(wrapper);
              isSwitchingPath.value = false;
              gridScrollController.jumpTo(0);
            },
            child: Padding(
              padding: const .symmetric(horizontal: 16, vertical: 8),
              child: Row(
                spacing: 14,
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: data != null
                        ? Image.memory(data, fit: .cover)
                        : ColoredBox(color: _t.colors.surfaceContainerHighest),
                  ),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: name,
                        style: _t.typography.bodyLarge.onSurface,
                        children: [
                          if (count != null)
                            TextSpan(
                              text: '  $count',
                              style: _t.typography.labelSmall.onSurfaceVariant,
                            ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: .ellipsis,
                    ),
                  ),
                  if (selected)
                    Icon(LucideIcons.check, color: _t.colors.primary, size: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ——————————————————————————————— 底部 ——————————————————————————————— //

  @override
  Widget confirmButton(BuildContext context) {
    return Consumer<DefaultAssetPickerProvider>(
      builder: (_, p, _) {
        final enabled =
            p.isSelectedNotEmpty || p.previousSelectedAssets.isNotEmpty;
        final l10n = context.l10n;
        return FilledButton(
          style: MButtonSize.small.style(context),
          onPressed: enabled
              ? () => Navigator.maybeOf(context)?.maybePop(p.selectedAssets)
              : null,
          child: Text(
            p.isSelectedNotEmpty && !isSingleAssetMode
                ? l10n.picker.doneCount(
                    count: p.selectedAssets.length,
                    max: p.maxAssets,
                  )
                : l10n.picker.done,
          ),
        );
      },
    );
  }

  /// 受限授权（仅选定照片）时的底部提示条。默认实现是 `Icons.warning` +
  /// `Icons.keyboard_arrow_right`，且底色写死 `primaryColor`。
  @override
  Widget accessLimitedBottomTip(BuildContext context) {
    final bottomPadding = hasBottomActions
        ? 0.0
        : MediaQuery.paddingOf(context).bottom;
    final l10n = context.l10n;
    return MInkWell(
      onTap: PhotoManager.openSetting,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14)
            .add(EdgeInsets.only(bottom: bottomPadding)),
        height: permissionLimitedBarHeight + bottomPadding,
        color: _t.colors.surfaceContainerHigh,
        child: Row(
          spacing: 10,
          children: [
            Icon(
              LucideIcons.triangleAlert,
              size: 18,
              color: _t.colors.tertiary,
            ),
            Expanded(
              child: Text(
                l10n.picker.limitedTip,
                style: _t.typography.bodySmall.onSurfaceVariant,
              ),
            ),
            Text(
              l10n.picker.limitedManage,
              style: _t.typography.labelMedium.emphasized.primary,
            ),
            Icon(
              LucideIcons.chevronRight,
              size: 16,
              color: _t.colors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// `m:ss` / `h:mm:ss`。是代码不是文案，不进 slang。
String formatAssetDuration(Duration duration) {
  String two(int n) => n.toString().padLeft(2, '0');
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  if (hours > 0) return '$hours:${two(minutes)}:${two(seconds)}';
  return '$minutes:${two(seconds)}';
}

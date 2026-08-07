import 'package:flutter/material.dart';
import 'package:moodiary_ui/moodiary_ui.dart' show LucideIcons;
import 'package:provider/provider.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

/// Moodiary 风格的相册选择器：只重绘视觉件（确定按钮、选中角标、选中蒙层、
/// 网格圆角与间距），资产分页加载/选择状态机/相册面板/权限处理全部沿用
/// wechat_assets_picker 默认实现。取色来自 [pickerTheme]（由 MobileFilePicker
/// 用 app ColorScheme 映射而来），明暗随 app。
class MoodiaryPickerDelegate
    extends DefaultAssetPickerBuilderDelegate<DefaultAssetPickerProvider> {
  MoodiaryPickerDelegate({
    required super.provider,
    required super.initialPermission,
    super.pickerTheme,
    super.textDelegate,
    super.pathNameBuilder,
  });

  static const double _itemRadius = 10;

  ColorScheme get _cs => theme.colorScheme;

  @override
  double get itemSpacing => 4;

  @override
  Widget assetGridItemBuilder({
    required BuildContext context,
    required int index,
    required List<AssetEntity> currentAssets,
    required List<SpecialItemFinalized> specialItemsFinalized,
  }) {
    return ClipRRect(
      borderRadius: .circular(_itemRadius),
      child: super.assetGridItemBuilder(
        context: context,
        index: index,
        currentAssets: currentAssets,
        specialItemsFinalized: specialItemsFinalized,
      ),
    );
  }

  /// 顶栏相册切换胶囊：surfaceContainerHigh 底 + 名称 + 旋转箭头（去掉默认的
  /// 半透明圆底箭头）。行为与默认一致：受限且空相册时改弹系统「管理可访问资源」。
  @override
  Widget pathEntitySelector(BuildContext context) {
    return UnconstrainedBox(
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
          decoration: BoxDecoration(
            borderRadius: .circular(999),
            color: _cs.surfaceContainerHigh,
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
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: .w500,
                              color: _cs.onSurface,
                            ),
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
                    size: 22,
                    color: _cs.onSurfaceVariant,
                  ),
                ),
              ),
        ),
      ),
    );
  }

  /// 相册面板行：圆角缩略图 + 名称 + 数量灰字 + 选中对勾。
  @override
  Widget pathEntityWidget({
    required BuildContext context,
    required List<PathWrapper<AssetPathEntity>> list,
    required int index,
  }) {
    final wrapper = list[index];
    final path = wrapper.path;
    final data = wrapper.thumbnailData;
    final String name = isPermissionLimited && path.isAll
        ? textDelegate.accessiblePathName
        : pathNameBuilder?.call(path) ?? path.name;
    final String? count = wrapper.assetCount?.toString();
    return Selector<DefaultAssetPickerProvider, PathWrapper<AssetPathEntity>?>(
      selector: (_, p) => p.currentPath,
      builder: (context, current, _) {
        final bool isSelected = current?.path == path;
        return Semantics(
          label: count == null ? name : '$name, $count',
          selected: isSelected,
          onTapHint: semanticsTextDelegate.sActionSwitchPathLabel,
          child: Material(
            type: .transparency,
            child: InkWell(
              onTap: () {
                Feedback.forTap(context);
                context.read<DefaultAssetPickerProvider>().switchPath(wrapper);
                isSwitchingPath.value = false;
                gridScrollController.jumpTo(0);
              },
              child: Padding(
                padding: const .symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: .circular(10),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: data != null
                            ? Image.memory(data, fit: .cover)
                            : ColoredBox(
                                color: _cs.primary.withValues(alpha: .12),
                              ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: name,
                          style: TextStyle(fontSize: 15, color: _cs.onSurface),
                          children: [
                            if (count != null)
                              TextSpan(
                                text: '  $count',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _cs.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: .ellipsis,
                      ),
                    ),
                    if (isSelected)
                      Icon(LucideIcons.check, color: _cs.primary, size: 22),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget confirmButton(BuildContext context) {
    return Consumer<DefaultAssetPickerProvider>(
      builder: (_, p, _) {
        final enabled =
            p.isSelectedNotEmpty || p.previousSelectedAssets.isNotEmpty;
        final label = p.isSelectedNotEmpty && !isSingleAssetMode
            ? '${textDelegate.confirm}'
                  ' (${p.selectedAssets.length}/${p.maxAssets})'
            : textDelegate.confirm;
        return FilledButton(
          style: FilledButton.styleFrom(
            visualDensity: .compact,
            padding: const .symmetric(horizontal: 16),
          ),
          onPressed: enabled
              ? () => Navigator.maybeOf(context)?.maybePop(p.selectedAssets)
              : null,
          child: Text(label),
        );
      },
    );
  }

  /// 顶栏左上角关闭键。默认实现写死 `Icons.close`，主题的 actionIconTheme 管不到
  /// （它不是 CloseButton，是裸 IconButton）。
  @override
  Widget backButton(BuildContext context) {
    return Padding(
      padding: const .symmetric(vertical: 4),
      child: IconButton(
        onPressed: () => Navigator.maybeOf(context)?.maybePop(),
        tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
        icon: const Icon(LucideIcons.x),
      ),
    );
  }

  /// 视频缩略图左下角的类型角标 + 时长。白色 + 渐变底，压在任何封面上都可读。
  @override
  Widget videoIndicator(BuildContext context, AssetEntity asset) {
    return Align(
      alignment: .bottomCenter,
      child: Container(
        width: double.maxFinite,
        height: 26,
        padding: const .symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: AlignmentDirectional.bottomCenter,
            end: AlignmentDirectional.topCenter,
            colors: [Colors.black.withValues(alpha: 0.45), Colors.transparent],
          ),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.video, size: 16, color: Colors.white),
            Expanded(
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: 4),
                child: Text(
                  textDelegate.durationIndicatorBuilder(
                    Duration(seconds: asset.duration),
                  ),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  maxLines: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 受限授权（仅选定照片）时的底部提示条。默认实现是 Icons.warning +
  /// Icons.keyboard_arrow_right，且底色写死 primaryColor。
  @override
  Widget accessLimitedBottomTip(BuildContext context) {
    final bottomPadding = hasBottomActions
        ? 0.0
        : MediaQuery.paddingOf(context).bottom;
    return GestureDetector(
      onTap: () {
        Feedback.forTap(context);
        PhotoManager.openSetting();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
        ).add(EdgeInsets.only(bottom: bottomPadding)),
        height: permissionLimitedBarHeight + bottomPadding,
        color: _cs.surfaceContainerHigh,
        child: Row(
          spacing: 12,
          children: [
            Icon(LucideIcons.triangleAlert, size: 20, color: _cs.tertiary),
            Expanded(
              child: Text(
                textDelegate.accessAllTip,
                style: TextStyle(fontSize: 14, color: _cs.onSurface),
              ),
            ),
            Icon(
              LucideIcons.chevronRight,
              size: 20,
              color: _cs.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  /// 选中 = 主色圆 + 选中序号（单选模式为对勾），未选 = 半透明黑底白圈——
  /// 无论压在深浅照片上都清晰。
  @override
  Widget selectIndicator(BuildContext context, int index, AssetEntity asset) {
    final double indicatorSize =
        MediaQuery.sizeOf(context).width / gridCount / 3;
    return Selector<DefaultAssetPickerProvider, String>(
      selector: (_, p) => p.selectedDescriptions,
      builder: (context, _, _) {
        final selectedAssets = context
            .read<DefaultAssetPickerProvider>()
            .selectedAssets;
        final int selectedIndex = selectedAssets.indexOf(asset);
        final bool selected = selectedIndex != -1;
        final double size = indicatorSize / (isAppleOS(context) ? 1.25 : 1.5);
        final Widget innerSelector = Container(
          width: size,
          height: size,
          alignment: .center,
          decoration: BoxDecoration(
            color: selected ? _cs.primary : Colors.black.withValues(alpha: .2),
            border: selected
                ? null
                : .all(color: Colors.white.withValues(alpha: .9), width: 1.8),
            shape: .circle,
          ),
          child: selected
              ? (isSingleAssetMode
                    ? Icon(
                        LucideIcons.check,
                        size: size * .66,
                        color: _cs.onPrimary,
                      )
                    : Text(
                        '${selectedIndex + 1}',
                        style: TextStyle(
                          color: _cs.onPrimary,
                          fontSize: size * .5,
                          fontWeight: .w600,
                          height: 1,
                        ),
                      ))
              : null,
        );
        final Widget selectorWidget = GestureDetector(
          behavior: .opaque,
          onTap: () => selectAsset(context, asset, index, selected),
          child: Container(
            margin: .all(indicatorSize / 4),
            width: isPreviewEnabled ? indicatorSize : null,
            height: isPreviewEnabled ? indicatorSize : null,
            alignment: .topEnd,
            child: (!isPreviewEnabled && isSingleAssetMode && !selected)
                ? const SizedBox.shrink()
                : innerSelector,
          ),
        );
        if (isPreviewEnabled) {
          return PositionedDirectional(top: 0, end: 0, child: selectorWidget);
        }
        return selectorWidget;
      },
    );
  }

  /// 选中蒙层：主色描边 + 轻蒙层。序号已并入右上角标，不再画大号数字。
  @override
  Widget selectedBackdrop(BuildContext context, int index, AssetEntity asset) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: isPreviewEnabled ? () => viewAsset(context, index, asset) : null,
        child: Selector<DefaultAssetPickerProvider, String>(
          selector: (_, p) => p.selectedDescriptions,
          builder: (context, _, _) {
            final bool selected = context
                .read<DefaultAssetPickerProvider>()
                .selectedAssets
                .contains(asset);
            return Container(
              decoration: BoxDecoration(
                borderRadius: .circular(_itemRadius),
                border: selected ? .all(color: _cs.primary, width: 2.5) : null,
                color: selected ? _cs.primary.withValues(alpha: .28) : null,
              ),
            );
          },
        ),
      ),
    );
  }
}

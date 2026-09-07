import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_picker/src/asset_thumb_image.dart';
import 'package:moodiary_picker/src/picker_route.dart';
import 'package:mui/mui.dart';
import 'package:provider/provider.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:wechat_picker_library/wechat_picker_library.dart';

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
    super.shouldRevertGrid = false,
  }) : super(pathNameBuilder: _pathName(recentLabel));

  final MuiThemeData mui;
  final String recentLabel;

  static PathNameBuilder<AssetPathEntity> _pathName(String recent) =>
      (path) => path.isAll ? recent : path.name;

  MuiThemeData get _t => mui;

  static const double _badgeSize = 20;

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

String formatAssetDuration(Duration duration) {
  String two(int n) => n.toString().padLeft(2, '0');
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  if (hours > 0) return '$hours:${two(minutes)}:${two(seconds)}';
  return '$minutes:${two(seconds)}';
}

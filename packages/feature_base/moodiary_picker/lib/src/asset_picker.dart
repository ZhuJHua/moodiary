import 'dart:async';

import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_picker/src/asset_file.dart';
import 'package:moodiary_picker/src/camera.dart';
import 'package:moodiary_picker/src/capture_tile.dart';
import 'package:moodiary_picker/src/picker_delegate.dart';
import 'package:moodiary_picker/src/picker_route.dart';
import 'package:moodiary_picker/src/picker_theme.dart';
import 'package:mui/mui.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

abstract final class MAssetPicker {
  static Future<List<XFile>> pickImages(
    BuildContext context, {
    int maxAssets = 9,
  }) async {
    final assets = await _push(context, .image, maxAssets: maxAssets);
    if (assets == null || assets.isEmpty) return const [];
    return _materialize(assets);
  }

  static Future<XFile?> pickVideo(BuildContext context) async {
    final assets = await _push(context, .video, maxAssets: 1);
    if (assets == null || assets.isEmpty) return null;
    final files = await _materialize(assets);
    return files.isEmpty ? null : files.first;
  }

  static Future<List<AssetEntity>?> _push(
    BuildContext context,
    RequestType type, {
    required int maxAssets,
  }) async {
    final requestOption = PermissionRequestOption(
      androidPermission: AndroidPermission(type: type, mediaLocation: false),
    );
    final permission = await _permission(context, requestOption);
    if (permission == null || !context.mounted) return null;

    final provider = DefaultAssetPickerProvider(
      maxAssets: maxAssets,
      requestType: type,
    );
    final video = type == RequestType.video;
    final delegate = MoodiaryPickerDelegate(
      provider: provider,
      initialPermission: permission,
      mui: context.theme,
      recentLabel: context.l10n.picker.recentAlbum,
      pickerTheme: buildPickerTheme(context.theme),
      textDelegate: assetPickerTextDelegateFromLocale(
        Localizations.maybeLocaleOf(context),
      ),
      specialItems: [
        SpecialItem<AssetPathEntity>(
          // shouldRevertGrid: false 时这格才会排在第一（iOS 默认会翻转网格）
          position: .prepend,
          builder: (itemContext, path, state) => path?.isAll != true
              ? null
              : CaptureTile(
                  video: video,
                  onTap: () => unawaited(
                    _captureInto(itemContext, provider, video: video),
                  ),
                ),
        ),
      ],
    );

    final navigator = Navigator.of(context, rootNavigator: true);
    final motion = context.theme.motion;
    final scrim = context.theme.colors.scrim;
    unawaited(
      MoodiaryCamera.retrieveLost().then((lost) {
        if (lost != null) _prepend(provider, lost);
      }),
    );
    final result = await navigator.push<List<AssetEntity>>(
      PickerPageRoute<List<AssetEntity>>(
        motion: motion,
        scrim: scrim,
        builder: (_) =>
            AssetPicker<AssetEntity, AssetPathEntity, MoodiaryPickerDelegate>(
              permissionRequestOption: requestOption,
              builder: delegate,
            ),
      ),
    );
    provider.dispose();
    return result;
  }

  static Future<void> _captureInto(
    BuildContext context,
    DefaultAssetPickerProvider provider, {
    required bool video,
  }) async {
    final entity = video
        ? await MoodiaryCamera.recordVideo()
        : await MoodiaryCamera.takePhoto();
    if (entity == null) {
      if (context.mounted) {
        toast.error(message: context.l10n.picker.captureFailed);
      }
      return;
    }
    _prepend(provider, entity);
    if (provider.maxAssets == 1 && context.mounted) {
      Navigator.maybeOf(context)?.maybePop(provider.selectedAssets);
    }
  }

  static void _prepend(
    DefaultAssetPickerProvider provider,
    AssetEntity entity,
  ) {
    final assets = provider.currentAssets.toList()
      ..removeWhere((e) => e.id == entity.id)
      ..insert(0, entity);
    provider
      ..currentAssets = assets
      ..totalAssetsCount = assets.length;
    provider.selectAsset(entity);
  }

  static Future<PermissionState?> _permission(
    BuildContext context,
    PermissionRequestOption requestOption,
  ) async {
    try {
      return await AssetPicker.permissionCheck(requestOption: requestOption);
    } catch (e) {
      logger.d('picker permission check failed: $e');
      if (context.mounted) {
        toast.error(message: context.l10n.picker.permissionDenied);
      }
      return null;
    }
  }

  static Future<List<XFile>> _materialize(List<AssetEntity> assets) async {
    toast.loading();
    try {
      return await assetsToFiles(assets);
    } finally {
      await toast.dismiss();
    }
  }
}

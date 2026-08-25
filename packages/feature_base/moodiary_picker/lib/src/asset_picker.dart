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

/// 相册选择器的对外入口。
///
/// 只出 [XFile] —— 压缩、选格式、落盘全在下游 `MediaManager`，相册句柄
/// （`AssetEntity`）不出本包。
///
/// **刻意不走 `AssetPicker.pickAssets`**：那个函数内部用它自己的
/// `AssetPickerPageRoute`（固定 250ms 上滑、没有手势）。而 `AssetPicker` 是公开的
/// StatefulWidget、全包零 `ModalRoute.of` 依赖，所以我们自己 push 进
/// [PickerPageRoute] 就能拿到自家的转场 + Android 预测性返回 + 顶栏下拉关闭。
abstract final class MAssetPicker {
  /// 相册多选图片，返回值**按用户的选择顺序**。
  static Future<List<XFile>> pickImages(
    BuildContext context, {
    int maxAssets = 9,
  }) async {
    final assets = await _push(context, .image, maxAssets: maxAssets);
    if (assets == null || assets.isEmpty) return const [];
    return _materialize(assets);
  }

  /// 相册选单个视频。
  static Future<XFile?> pickVideo(BuildContext context) async {
    final assets = await _push(context, .video, maxAssets: 1);
    if (assets == null || assets.isEmpty) return null;
    final files = await _materialize(assets);
    return files.isEmpty ? null : files.first;
  }

  /// 直接开系统相机（不经相册网格）。成片同样先落系统相册再交出文件。
  static Future<XFile?> capture(
    BuildContext context, {
    required bool video,
  }) async {
    final entity = video
        ? await MoodiaryCamera.recordVideo()
        : await MoodiaryCamera.takePhoto();
    if (entity == null) return null;
    final files = await _materialize([entity]);
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
          // 这一格在 iOS 上能真的排第一，靠的是 delegate 里钉死的
          // `shouldRevertGrid: false`（Apple 分支默认翻转整个网格）。
          position: .prepend,
          // 只在「全部照片」里出现 —— 在某个具体相册里给拍摄入口没有意义。
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

    // rootNavigator：选择器要盖住底栏，且不进 go_router 的 location ——
    // AppLockObserver 的跳过判据是按路径字面匹配的，多一个 `/picker` 就得同步改
    // 那张名单，而选图期间切后台被压上锁屏页是很难查的那类问题。
    final navigator = Navigator.of(context, rootNavigator: true);
    final motion = context.theme.motion;
    final scrim = context.theme.colors.scrim;
    // Android 的 MainActivity 在低内存下会被回收，上一次拍摄的结果只能事后捞。
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

  /// 拍完把新资源插到网格首位并选中。
  ///
  /// 官方 example 的做法是整条相册重载（`obtainForNewProperties` + `switchPath`），
  /// 那是一次全量平台往返、用户看得见闪一下。这里直接改 `currentAssets` ——
  /// 之所以安全，是因为 `shouldRevertGrid: false`：占位格数只在翻转网格时才按
  /// `assetCount` 算，不翻转就没有那条错位路径。
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
    // 单选（选视频、助手贴图）拍完就是要这一条，不必再点一次「完成」。
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

  /// 权限被拒时给一句 toast 并返回 null —— picker 自带的权限遮罩是「进去之后」
  /// 才有意义的，没进去就被拒的话页面会是空的。
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

  /// 取文件这一步可能很慢：iCloud 上没下载的资源要先拉回来，HEIC 要转码。
  /// 全程转圈，别让用户以为点了没反应。
  static Future<List<XFile>> _materialize(List<AssetEntity> assets) async {
    toast.loading();
    try {
      return await assetsToFiles(assets);
    } finally {
      await toast.dismiss();
    }
  }
}

import 'dart:io';

import 'package:file_picker/file_picker.dart' as fp;
// wechat 的两个 picker 仍是 legacy material。这一段专门给它们造 legacy
// ThemeData —— 靠根部的 MaterialUiCompatibilityBridge 把 App 配色映射过来。
import 'package:flutter/material.dart' as legacy;
import 'package:moodiary/app/picker/moodiary_camera_picker_state.dart';
import 'package:moodiary/app/picker/moodiary_picker_delegate.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_utils/moodiary_utils.dart' show uuidV7;
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:wechat_camera_picker/wechat_camera_picker.dart';

/// [IFilePicker] 移动端实现：相册/相机走应用内选择器（wechat_assets_picker /
/// wechat_camera_picker），音频与任意文件走 file_picker 系统入口。
/// 媒体一律取 originFile——原始文件不经系统转码，HEIC / 压缩交由下游管线处理。
/// 权限被拒时 toast 提示并返回空。
class MobileFilePicker implements IFilePicker {
  @override
  Future<List<XFile>> pickImages(BuildContext context, {int maxAssets = 9}) {
    return _pickAssets(context, .image, maxAssets: maxAssets);
  }

  @override
  Future<XFile?> pickVideo(BuildContext context) async {
    final files = await _pickAssets(context, .video, maxAssets: 1);
    return files.isEmpty ? null : files.first;
  }

  /// 拍照，成片经系统相册落库（保留原片），再取回文件。
  @override
  Future<XFile?> takePhoto(BuildContext context) {
    return _capture(context, recording: false);
  }

  /// 录像（轻触开始/结束，无时长上限）。
  @override
  Future<XFile?> recordVideo(BuildContext context) {
    return _capture(context, recording: true);
  }

  @override
  Future<XFile?> pickAudio() async {
    final res = await fp.FilePicker.pickFile(type: .audio);
    return res?.xFile;
  }

  @override
  Future<XFile?> pickFile({List<String>? allowedExtensions}) async {
    final res = await fp.FilePicker.pickFile(
      type: allowedExtensions == null ? .any : .custom,
      allowedExtensions: allowedExtensions,
    );
    return res?.xFile;
  }

  /// 把 app 主题映射成选择器主题（明暗随 app）。选择器按自有槽位取色：强调色 =
  /// colorScheme.secondary、网格底 = scaffoldBackground、相册面板 = canvasColor、
  /// 相册胶囊 = focusColor……以包内置灰黑模板为底，仅覆盖取色槽位；textTheme 一并
  /// 透传（自定义字体同款）。bodyLarge 例外：包内只有预览页确认按钮文字与它绑定，
  /// 该按钮底色是强调色，故置为 onPrimary。
  legacy.ThemeData _pickerTheme(BuildContext context) {
    final theme = legacy.Theme.of(context);
    final cs = theme.colorScheme;
    final base = AssetPicker.themeData(
      cs.primary,
      light: theme.brightness == .light,
    );
    return base.copyWith(
      // AssetPicker.themeData 是从零构造的，不带 app 的 actionIconTheme，
      // 不显式透传的话选择器内的返回/关闭键会掉回 Material 字形。
      actionIconTheme: theme.actionIconTheme,
      colorScheme: cs.copyWith(secondary: cs.primary),
      primaryColor: cs.surface,
      canvasColor: cs.surfaceContainer,
      scaffoldBackgroundColor: cs.surface,
      cardColor: cs.surface,
      dividerColor: theme.dividerColor,
      unselectedWidgetColor: cs.outline,
      focusColor: cs.surfaceContainerHigh,
      splashColor: cs.onSurface.withValues(alpha: .12),
      iconTheme: theme.iconTheme.copyWith(color: cs.onSurface),
      textTheme: theme.textTheme.copyWith(
        bodyLarge: theme.textTheme.bodyLarge?.copyWith(color: cs.onPrimary),
      ),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        iconTheme: legacy.IconThemeData(color: cs.onSurface),
      ),
      bottomAppBarTheme: base.bottomAppBarTheme.copyWith(
        color: cs.surfaceContainer,
      ),
    );
  }

  Future<List<XFile>> _pickAssets(
    BuildContext context,
    RequestType type, {
    required int maxAssets,
  }) async {
    final l10n = context.l10n;
    final PermissionState permission;
    try {
      permission = await AssetPicker.permissionCheck(
        requestOption: PermissionRequestOption(
          androidPermission: AndroidPermission(
            type: type,
            mediaLocation: false,
          ),
        ),
      );
    } on StateError {
      if (context.mounted) {
        toast.error(message: context.l10n.app.noticeEnablePhotoPermission);
      }
      return const [];
    }
    if (!context.mounted) return const [];
    final assets =
        await AssetPicker.pickAssetsWithDelegate<
          AssetEntity,
          AssetPathEntity,
          DefaultAssetPickerProvider,
          MoodiaryPickerDelegate
        >(
          context,
          delegate: MoodiaryPickerDelegate(
            provider: DefaultAssetPickerProvider(
              maxAssets: maxAssets,
              requestType: type,
            ),
            initialPermission: permission,
            pickerTheme: _pickerTheme(context),
            textDelegate: assetPickerTextDelegateFromLocale(
              Localizations.maybeLocaleOf(context),
            ),
            // Android 的「全部照片」虚拟相册固定叫 Recent，不随系统语言；按 app 语言本地化。
            pathNameBuilder: (path) =>
                path.isAll ? l10n.app.pickerRecentAlbum : path.name,
          ),
        );
    return _toXFiles(assets ?? const []);
  }

  Future<XFile?> _capture(
    BuildContext context, {
    required bool recording,
  }) async {
    final AssetEntity? entity;
    try {
      entity = await CameraPicker.pickFromCamera(
        context,
        createPickerState: MoodiaryCameraPickerState.new,
        pickerConfig: CameraPickerConfig(
          enableRecording: recording,
          onlyEnableRecording: recording,
          enableTapRecording: recording,
          maximumRecordingDuration: null,
          theme: CameraPicker.themeData(Theme.of(context).colorScheme.primary),
          textDelegate: cameraPickerTextDelegateFromLocale(
            Localizations.maybeLocaleOf(context),
          ),
        ),
      );
    } catch (e) {
      logger.d('CameraPicker failed: $e');
      if (context.mounted) {
        toast.error(message: context.l10n.app.noticeEnableCameraPermission);
      }
      return null;
    }
    if (entity == null) return null;
    final file = await entity.originFile;
    return file == null ? null : XFile(file.path);
  }

  /// 并行取文件（Future.wait 保序），失败的静默剔除。
  Future<List<XFile>> _toXFiles(List<AssetEntity> assets) async {
    final files = await Future.wait(assets.map(_assetToXFile));
    return files.whereType<XFile>().toList();
  }

  /// HEIF 图片不取 originFile：heif_converter 的 Android 实现在主线程同步解码 +
  /// 编码（整 app 冻住），这里改让 photo_manager 在原生后台线程按原始尺寸转出
  /// JPEG（q95，照片无 alpha 顾虑），下游管线从此见不到 HEIC。转换失败回落
  /// originFile（走 MediaManager 的旧 HEIC 兜底路径）。
  Future<XFile?> _assetToXFile(AssetEntity asset) async {
    if (asset.type == .image && await _isHeif(asset)) {
      final converted = await _heifToJpeg(asset);
      if (converted != null) return converted;
    }
    final file = await asset.originFile;
    return file == null ? null : XFile(file.path);
  }

  Future<bool> _isHeif(AssetEntity asset) async {
    final mime = asset.mimeType ?? await asset.mimeTypeAsync;
    return mime == 'image/heic' || mime == 'image/heif';
  }

  Future<XFile?> _heifToJpeg(AssetEntity asset) async {
    if (asset.width <= 0 || asset.height <= 0) return null;
    try {
      final data = await asset.thumbnailDataWithSize(
        ThumbnailSize(asset.width, asset.height),
        quality: 95,
      );
      if (data == null) return null;
      final path = AppFiles.getCachePath('picked-${uuidV7()}.jpg');
      await File(path).writeAsBytes(data);
      return XFile(path);
    } catch (e) {
      logger.d('HEIF -> JPEG via photo_manager failed: $e');
      return null;
    }
  }
}

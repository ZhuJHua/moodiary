import 'package:flutter/material.dart';
import 'package:moodiary_components/moodiary_components.dart' show LucideIcons;
import 'package:wechat_camera_picker/wechat_camera_picker.dart';

/// 只替换相机页顶栏三颗按钮的图标（切换镜头 / 闪光灯 / 关闭），其余取景、对焦、
/// 拍摄逻辑全部沿用 [CameraPickerState]。
///
/// 对焦点上的曝光滑块（太阳）与曝光锁（锁头）没有覆写：它们埋在
/// `buildFocusingPoint` 这个近百行的方法里，且引用了包内的库私有常量
/// （`_lockedColor` / `_kDuration`），照抄的维护成本高于收益。
class MoodiaryCameraPickerState extends CameraPickerState {
  @override
  Widget buildCameraSwitch(BuildContext context) {
    return MergeSemantics(
      child: IconButton(
        tooltip: textDelegate.sSwitchCameraLensDirectionLabel(
          nextCameraDescription.lensDirection,
        ),
        onPressed: switchCameras,
        icon: const Icon(LucideIcons.switchCamera, size: 24),
      ),
    );
  }

  /// lucide 没有「自动闪光」这一形，auto 档用 zap 叠一个角标 A 区分于 always。
  @override
  Widget buildFlashModeSwitch({
    required BuildContext context,
    required CameraValue cameraValue,
  }) {
    final mode = cameraValue.flashMode;
    final icon = switch (mode) {
      FlashMode.off => LucideIcons.zapOff,
      FlashMode.auto || FlashMode.always => LucideIcons.zap,
      FlashMode.torch => LucideIcons.flashlight,
    };
    final color = IconTheme.of(context).color;
    return IconButton(
      onPressed: () => switchFlashesMode(cameraValue),
      tooltip: textDelegate.sFlashModeLabel(mode),
      icon: Stack(
        clipBehavior: .none,
        children: [
          Icon(icon, size: 24),
          if (mode == .auto)
            PositionedDirectional(
              bottom: -2,
              end: -4,
              child: Text(
                'A',
                style: TextStyle(
                  fontSize: 11,
                  height: 1,
                  fontWeight: .w700,
                  color: color,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget buildBackButton(BuildContext context) {
    return IconButton(
      onPressed: () => Navigator.of(context).maybePop(),
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      icon: const Icon(LucideIcons.x),
    );
  }
}

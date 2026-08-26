/// moodiary_picker —— 相册选择器：骑 wechat_assets_picker 换皮（自建版试过又
/// 回退，见 tool/check_layers.dart 里同段历史注释）。对外只有 [MAssetPicker]，
/// 进出都是 `XFile`；`AssetEntity` 不出本包。
///
/// 相机（拍照 / 录像）在包内，走 image_picker 的系统相机（lib/src/camera.dart）。
library;

export 'src/asset_picker.dart' show MAssetPicker;

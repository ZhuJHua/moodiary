/// moodiary_picker —— 自建的相册选择器。
///
/// photo_manager 之上的一层 UI，替掉 wechat_assets_picker。对外只有
/// [MAssetPicker] 两个方法，进出都是 `XFile`；`AssetEntity` 不出本包。
///
/// 相机（拍照 / 录像）**不在本包内**：那半边还骑在 wechat_camera_picker 上，
/// 由 app 层的 `IFilePicker` 实现接着。
library;

export 'src/asset_picker.dart' show MAssetPicker;

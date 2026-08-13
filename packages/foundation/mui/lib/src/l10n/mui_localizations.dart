import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:material_ui/material_ui.dart';

/// mui 组件自己要用的那十来个通用词。
///
/// 仿 [MaterialLocalizations] 的形状，理由也一样：组件库不该反过来依赖宿主 App 的
/// 文案包（那会让 `mui` 从叶子包变成中间层）。App 自己的字串仍走 `moodiary_l10n`，
/// 两者互不相干。
///
/// 与 [MaterialLocalizations.of] 的唯一区别是**取不到时不抛**，回落到英文：
/// mui 组件会出现在第三方自建的 `Localizations` 子树里（wechat picker 等），
/// 为一句 "OK" 崩掉整页不划算。
abstract class MuiLocalizations {
  const MuiLocalizations();

  String get ok;
  String get cancel;
  String get back;
  String get colorPickerTitle;
  String get toastLoading;
  String get toastSuccess;
  String get toastError;

  static const LocalizationsDelegate<MuiLocalizations> delegate =
      _MuiLocalizationsDelegate();

  /// 支持的语种。未列出的语种回落到英文。
  static const List<Locale> supportedLocales = [Locale('en'), Locale('zh')];

  static MuiLocalizations of(BuildContext context) =>
      Localizations.of<MuiLocalizations>(context, MuiLocalizations) ??
      const MuiLocalizationsEn();
}

class MuiLocalizationsEn extends MuiLocalizations {
  const MuiLocalizationsEn();

  @override
  String get ok => 'OK';
  @override
  String get cancel => 'Cancel';
  @override
  String get back => 'Back';
  @override
  String get colorPickerTitle => 'Pick a color';
  @override
  String get toastLoading => 'Loading';
  @override
  String get toastSuccess => 'Success';
  @override
  String get toastError => 'Error';
}

class MuiLocalizationsZh extends MuiLocalizations {
  const MuiLocalizationsZh();

  @override
  String get ok => '确认';
  @override
  String get cancel => '取消';
  @override
  String get back => '返回';
  @override
  String get colorPickerTitle => '选择颜色';
  @override
  String get toastLoading => '加载中';
  @override
  String get toastSuccess => '成功';
  @override
  String get toastError => '出错了';
}

class _MuiLocalizationsDelegate extends LocalizationsDelegate<MuiLocalizations> {
  const _MuiLocalizationsDelegate();

  /// 一律接受：未支持的语种在 [load] 里回落到英文，而不是让整个 `Localizations`
  /// 少掉这一份、逼 [MuiLocalizations.of] 走兜底。
  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<MuiLocalizations> load(Locale locale) =>
      SynchronousFuture<MuiLocalizations>(
        locale.languageCode == 'zh'
            ? const MuiLocalizationsZh()
            : const MuiLocalizationsEn(),
      );

  @override
  bool shouldReload(_MuiLocalizationsDelegate old) => false;
}

extension MuiLocalizationsContext on BuildContext {
  /// mui 组件取通用词的入口。App 自己的字串仍用 `context.l10n`。
  MuiLocalizations get muiL10n => MuiLocalizations.of(this);
}

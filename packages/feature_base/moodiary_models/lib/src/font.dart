import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:path/path.dart';

part 'font.freezed.dart';

@freezed
abstract class Font with _$Font {
  const factory Font({
    required String fontFileName,
    required Map<String, dynamic> fontWghtAxisMap,
  }) = _Font;

  const Font._();

  String get fontFamily => basenameWithoutExtension(fontFileName);

  String get fontType => extension(fontFileName);
}

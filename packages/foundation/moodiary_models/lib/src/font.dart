import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:isar_plus/isar_plus.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:path/path.dart';

part 'font.freezed.dart';
part 'font.g.dart';

@freezed
@Collection(ignore: {'copyWith'})
abstract class Font with _$Font {
  const factory Font({
    required String fontFileName,
    required Map<String, dynamic> fontWghtAxisMap,
  }) = _Font;

  const Font._();

  @Id()
  int get id => fastHash(fontFamily);

  String get fontFamily => basenameWithoutExtension(fontFileName);

  String get fontType => extension(fontFileName);
}

// 2.8.0 之前的 Isar collection 定义（引擎搬迁的只读留底）。
// ⚠️ 逐字节冻结：schema 由「注册顺序 + 字段形状」决定（位置即地址），任何改动都会
// 让旧库被错误解读。新世界的模型在 moodiary_models，这里永不跟进。
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

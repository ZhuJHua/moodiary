// 字段顺序/形状即 isar 编码地址，改动会读坏旧库
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:isar_plus/isar_plus.dart';

part 'link_posting.freezed.dart';
part 'link_posting.g.dart';

@freezed
@Collection(ignore: {'copyWith'})
abstract class LinkPosting with _$LinkPosting {
  const factory LinkPosting({
    @Id() required int key,
    required List<int> fromIsarIds,
  }) = _LinkPosting;

  const LinkPosting._();
}

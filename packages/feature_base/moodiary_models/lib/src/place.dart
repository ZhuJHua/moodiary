import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

import 'utc_date_time_converter.dart';

part 'place.freezed.dart';
part 'place.g.dart';

/// 常用地点：用户自己起名的一个坐标（「公司」「家」）。写日记时按当前坐标就近匹配
/// （[matchRadius] 内），命中就用这个名字。
///
/// **日记不引用它**。`DiaryPosition.name` 存的是写入那一刻的名字**快照字符串**，
/// 不是外键——地点改名或删除都不该动历史日记（那是「当时在哪」的事实）。代价是
/// 「这个地点写过几篇」只能按坐标落在半径内统计，不能按名字数。
@freezed
abstract class Place with _$Place {
  const factory Place({
    required String id,
    required String name,
    required double latitude,
    required double longitude,

    /// lucide 图标名；null = 回退 `map-pin`。地点不给用户选颜色——图标已经承担了
    /// 辨识，方块底色按 id 自动取。
    String? icon,

    @UtcDateTimeConverter() required DateTime lastModified,
  }) = _Place;

  const Place._();

  factory Place.create({
    required String name,
    required double latitude,
    required double longitude,
    String? icon,
  }) => Place(
    id: uuidV7(),
    name: name,
    latitude: latitude,
    longitude: longitude,
    icon: icon,
    lastModified: .timestamp(),
  );

  factory Place.fromJson(Map<String, dynamic> json) => _$PlaceFromJson(json);

  /// 由地名派生、跨设备一致的地点。旧数据（2.8.0 的日记位置快照、2.7.x 的 Isar 定位、
  /// 远端还没换成 placeId 的日记对象）和和风反查出的行政区名都走这里：两台设备各自
  /// 把「杭州市 西湖区」变成地点时会得到**同一个 id**，同步后合并成一个而不是各留一份。
  factory Place.forName(
    String name, {
    required double latitude,
    required double longitude,
  }) => Place(
    id: idForName(name),
    name: name,
    latitude: latitude,
    longitude: longitude,
    lastModified: .timestamp(),
  );

  /// [forName] 用的 id：固定命名空间下的 uuid v5。
  static String idForName(String name) => uuidV5(_nameNamespace, name);

  static const String _nameNamespace = '3f0b6a2e-9c4d-5e1f-8a7b-6c5d4e3f2a1b';

  /// 没有地名的旧定位只能拿坐标当名字，四位小数 ≈ 11 m。
  static String coordinateName(double latitude, double longitude) =>
      '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';

  /// 就近命中半径（米），全部地点一个值、不给用户调：室内 GPS 误差常有 50–100 m，
  /// 200 兜得住误差又不至于把隔一条街的地方算进来。
  static const int matchRadius = 200;
}

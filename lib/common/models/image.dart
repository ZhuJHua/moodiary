import 'package:freezed_annotation/freezed_annotation.dart';

part 'image.freezed.dart';
part 'image.g.dart';

@freezed
abstract class BingImage with _$BingImage {
  const factory BingImage({List<Images>? images, Tooltips? tooltips}) =
      _BingImage;

  factory BingImage.fromJson(Map<String, dynamic> json) =>
      _$BingImageFromJson(json);
}

@freezed
abstract class Tooltips with _$Tooltips {
  const factory Tooltips({
    String? loading,
    String? previous,
    String? next,
    String? walle,
    String? walls,
  }) = _Tooltips;

  factory Tooltips.fromJson(Map<String, dynamic> json) =>
      _$TooltipsFromJson(json);
}

@freezed
abstract class Images with _$Images {
  const factory Images({
    String? startdate,
    String? fullstartdate,
    String? enddate,
    String? url,
    String? urlbase,
    String? copyright,
    String? copyrightlink,
    String? title,
    String? quiz,
    bool? wp,
    String? hsh,
    int? drk,
    int? top,
    int? bot,
    List<dynamic>? hs,
  }) = _Images;

  factory Images.fromJson(Map<String, dynamic> json) => _$ImagesFromJson(json);
}

// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'image.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$BingImage {

  List<Images>? get images;

  Tooltips? get tooltips;

  /// Create a copy of BingImage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $BingImageCopyWith<BingImage> get copyWith =>
      _$BingImageCopyWithImpl<BingImage>(this as BingImage, _$identity);

  /// Serializes this BingImage to a JSON map.
  Map<String, dynamic> toJson();


  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is BingImage &&
            const DeepCollectionEquality().equals(other.images, images) &&
            (identical(other.tooltips, tooltips) ||
                other.tooltips == tooltips));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(
          runtimeType, const DeepCollectionEquality().hash(images), tooltips);

  @override
  String toString() {
    return 'BingImage(images: $images, tooltips: $tooltips)';
  }


}

/// @nodoc
abstract mixin class $BingImageCopyWith<$Res> {
  factory $BingImageCopyWith(BingImage value,
      $Res Function(BingImage) _then) = _$BingImageCopyWithImpl;

  @useResult
  $Res call({
    List<Images>? images, Tooltips? tooltips
  });


  $TooltipsCopyWith<$Res>? get tooltips;

}

/// @nodoc
class _$BingImageCopyWithImpl<$Res>
    implements $BingImageCopyWith<$Res> {
  _$BingImageCopyWithImpl(this._self, this._then);

  final BingImage _self;
  final $Res Function(BingImage) _then;

  /// Create a copy of BingImage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? images = freezed, Object? tooltips = freezed,}) {
    return _then(_self.copyWith(
      images: freezed == images
          ? _self.images
          : images // ignore: cast_nullable_to_non_nullable
      as List<Images>?,
      tooltips: freezed == tooltips
          ? _self.tooltips
          : tooltips // ignore: cast_nullable_to_non_nullable
      as Tooltips?,
    ));
  }

  /// Create a copy of BingImage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $TooltipsCopyWith<$Res>? get tooltips {
    if (_self.tooltips == null) {
      return null;
    }

    return $TooltipsCopyWith<$Res>(_self.tooltips!, (value) {
      return _then(_self.copyWith(tooltips: value));
    });
  }
}


/// @nodoc
@JsonSerializable()
class _BingImage implements BingImage {
  const _BingImage({final List<Images>? images, this.tooltips})
      : _images = images;

  factory _BingImage.fromJson(Map<String, dynamic> json) =>
      _$BingImageFromJson(json);

  final List<Images>? _images;

  @override List<Images>? get images {
    final value = _images;
    if (value == null) return null;
    if (_images is EqualUnmodifiableListView) return _images;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override final Tooltips? tooltips;

  /// Create a copy of BingImage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$BingImageCopyWith<_BingImage> get copyWith =>
      __$BingImageCopyWithImpl<_BingImage>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$BingImageToJson(this,);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _BingImage &&
            const DeepCollectionEquality().equals(other._images, _images) &&
            (identical(other.tooltips, tooltips) ||
                other.tooltips == tooltips));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(
          runtimeType, const DeepCollectionEquality().hash(_images), tooltips);

  @override
  String toString() {
    return 'BingImage(images: $images, tooltips: $tooltips)';
  }


}

/// @nodoc
abstract mixin class _$BingImageCopyWith<$Res>
    implements $BingImageCopyWith<$Res> {
  factory _$BingImageCopyWith(_BingImage value,
      $Res Function(_BingImage) _then) = __$BingImageCopyWithImpl;

  @override
  @useResult
  $Res call({
    List<Images>? images, Tooltips? tooltips
  });


  @override $TooltipsCopyWith<$Res>? get tooltips;

}

/// @nodoc
class __$BingImageCopyWithImpl<$Res>
    implements _$BingImageCopyWith<$Res> {
  __$BingImageCopyWithImpl(this._self, this._then);

  final _BingImage _self;
  final $Res Function(_BingImage) _then;

  /// Create a copy of BingImage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({Object? images = freezed, Object? tooltips = freezed,}) {
    return _then(_BingImage(
      images: freezed == images
          ? _self._images
          : images // ignore: cast_nullable_to_non_nullable
      as List<Images>?,
      tooltips: freezed == tooltips
          ? _self.tooltips
          : tooltips // ignore: cast_nullable_to_non_nullable
      as Tooltips?,
    ));
  }

  /// Create a copy of BingImage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $TooltipsCopyWith<$Res>? get tooltips {
    if (_self.tooltips == null) {
      return null;
    }

    return $TooltipsCopyWith<$Res>(_self.tooltips!, (value) {
      return _then(_self.copyWith(tooltips: value));
    });
  }
}


/// @nodoc
mixin _$Tooltips {

  String? get loading;

  String? get previous;

  String? get next;

  String? get walle;

  String? get walls;

  /// Create a copy of Tooltips
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $TooltipsCopyWith<Tooltips> get copyWith =>
      _$TooltipsCopyWithImpl<Tooltips>(this as Tooltips, _$identity);

  /// Serializes this Tooltips to a JSON map.
  Map<String, dynamic> toJson();


  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is Tooltips &&
            (identical(other.loading, loading) || other.loading == loading) &&
            (identical(other.previous, previous) ||
                other.previous == previous) &&
            (identical(other.next, next) || other.next == next) &&
            (identical(other.walle, walle) || other.walle == walle) &&
            (identical(other.walls, walls) || other.walls == walls));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, loading, previous, next, walle, walls);

  @override
  String toString() {
    return 'Tooltips(loading: $loading, previous: $previous, next: $next, walle: $walle, walls: $walls)';
  }


}

/// @nodoc
abstract mixin class $TooltipsCopyWith<$Res> {
  factory $TooltipsCopyWith(Tooltips value,
      $Res Function(Tooltips) _then) = _$TooltipsCopyWithImpl;

  @useResult
  $Res call({
    String? loading, String? previous, String? next, String? walle, String? walls
  });


}

/// @nodoc
class _$TooltipsCopyWithImpl<$Res>
    implements $TooltipsCopyWith<$Res> {
  _$TooltipsCopyWithImpl(this._self, this._then);

  final Tooltips _self;
  final $Res Function(Tooltips) _then;

  /// Create a copy of Tooltips
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call(
      {Object? loading = freezed, Object? previous = freezed, Object? next = freezed, Object? walle = freezed, Object? walls = freezed,}) {
    return _then(_self.copyWith(
      loading: freezed == loading
          ? _self.loading
          : loading // ignore: cast_nullable_to_non_nullable
      as String?,
      previous: freezed == previous
          ? _self.previous
          : previous // ignore: cast_nullable_to_non_nullable
      as String?,
      next: freezed == next
          ? _self.next
          : next // ignore: cast_nullable_to_non_nullable
      as String?,
      walle: freezed == walle
          ? _self.walle
          : walle // ignore: cast_nullable_to_non_nullable
      as String?,
      walls: freezed == walls
          ? _self.walls
          : walls // ignore: cast_nullable_to_non_nullable
      as String?,
    ));
  }

}


/// @nodoc
@JsonSerializable()
class _Tooltips implements Tooltips {
  const _Tooltips(
      {this.loading, this.previous, this.next, this.walle, this.walls});

  factory _Tooltips.fromJson(Map<String, dynamic> json) =>
      _$TooltipsFromJson(json);

  @override final String? loading;
  @override final String? previous;
  @override final String? next;
  @override final String? walle;
  @override final String? walls;

  /// Create a copy of Tooltips
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$TooltipsCopyWith<_Tooltips> get copyWith =>
      __$TooltipsCopyWithImpl<_Tooltips>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$TooltipsToJson(this,);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _Tooltips &&
            (identical(other.loading, loading) || other.loading == loading) &&
            (identical(other.previous, previous) ||
                other.previous == previous) &&
            (identical(other.next, next) || other.next == next) &&
            (identical(other.walle, walle) || other.walle == walle) &&
            (identical(other.walls, walls) || other.walls == walls));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, loading, previous, next, walle, walls);

  @override
  String toString() {
    return 'Tooltips(loading: $loading, previous: $previous, next: $next, walle: $walle, walls: $walls)';
  }


}

/// @nodoc
abstract mixin class _$TooltipsCopyWith<$Res>
    implements $TooltipsCopyWith<$Res> {
  factory _$TooltipsCopyWith(_Tooltips value,
      $Res Function(_Tooltips) _then) = __$TooltipsCopyWithImpl;

  @override
  @useResult
  $Res call({
    String? loading, String? previous, String? next, String? walle, String? walls
  });


}

/// @nodoc
class __$TooltipsCopyWithImpl<$Res>
    implements _$TooltipsCopyWith<$Res> {
  __$TooltipsCopyWithImpl(this._self, this._then);

  final _Tooltips _self;
  final $Res Function(_Tooltips) _then;

  /// Create a copy of Tooltips
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call(
      {Object? loading = freezed, Object? previous = freezed, Object? next = freezed, Object? walle = freezed, Object? walls = freezed,}) {
    return _then(_Tooltips(
      loading: freezed == loading
          ? _self.loading
          : loading // ignore: cast_nullable_to_non_nullable
      as String?,
      previous: freezed == previous
          ? _self.previous
          : previous // ignore: cast_nullable_to_non_nullable
      as String?,
      next: freezed == next
          ? _self.next
          : next // ignore: cast_nullable_to_non_nullable
      as String?,
      walle: freezed == walle
          ? _self.walle
          : walle // ignore: cast_nullable_to_non_nullable
      as String?,
      walls: freezed == walls
          ? _self.walls
          : walls // ignore: cast_nullable_to_non_nullable
      as String?,
    ));
  }


}


/// @nodoc
mixin _$Images {

  String? get startdate;

  String? get fullstartdate;

  String? get enddate;

  String? get url;

  String? get urlbase;

  String? get copyright;

  String? get copyrightlink;

  String? get title;

  String? get quiz;

  bool? get wp;

  String? get hsh;

  int? get drk;

  int? get top;

  int? get bot;

  List<dynamic>? get hs;

  /// Create a copy of Images
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ImagesCopyWith<Images> get copyWith =>
      _$ImagesCopyWithImpl<Images>(this as Images, _$identity);

  /// Serializes this Images to a JSON map.
  Map<String, dynamic> toJson();


  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is Images &&
            (identical(other.startdate, startdate) ||
                other.startdate == startdate) &&
            (identical(other.fullstartdate, fullstartdate) ||
                other.fullstartdate == fullstartdate) &&
            (identical(other.enddate, enddate) || other.enddate == enddate) &&
            (identical(other.url, url) || other.url == url) &&
            (identical(other.urlbase, urlbase) || other.urlbase == urlbase) &&
            (identical(other.copyright, copyright) ||
                other.copyright == copyright) &&
            (identical(other.copyrightlink, copyrightlink) ||
                other.copyrightlink == copyrightlink) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.quiz, quiz) || other.quiz == quiz) &&
            (identical(other.wp, wp) || other.wp == wp) &&
            (identical(other.hsh, hsh) || other.hsh == hsh) &&
            (identical(other.drk, drk) || other.drk == drk) &&
            (identical(other.top, top) || other.top == top) &&
            (identical(other.bot, bot) || other.bot == bot) &&
            const DeepCollectionEquality().equals(other.hs, hs));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(
          runtimeType,
          startdate,
          fullstartdate,
          enddate,
          url,
          urlbase,
          copyright,
          copyrightlink,
          title,
          quiz,
          wp,
          hsh,
          drk,
          top,
          bot,
          const DeepCollectionEquality().hash(hs));

  @override
  String toString() {
    return 'Images(startdate: $startdate, fullstartdate: $fullstartdate, enddate: $enddate, url: $url, urlbase: $urlbase, copyright: $copyright, copyrightlink: $copyrightlink, title: $title, quiz: $quiz, wp: $wp, hsh: $hsh, drk: $drk, top: $top, bot: $bot, hs: $hs)';
  }


}

/// @nodoc
abstract mixin class $ImagesCopyWith<$Res> {
  factory $ImagesCopyWith(Images value,
      $Res Function(Images) _then) = _$ImagesCopyWithImpl;

  @useResult
  $Res call({
    String? startdate, String? fullstartdate, String? enddate, String? url, String? urlbase, String? copyright, String? copyrightlink, String? title, String? quiz, bool? wp, String? hsh, int? drk, int? top, int? bot, List<
        dynamic>? hs
  });


}

/// @nodoc
class _$ImagesCopyWithImpl<$Res>
    implements $ImagesCopyWith<$Res> {
  _$ImagesCopyWithImpl(this._self, this._then);

  final Images _self;
  final $Res Function(Images) _then;

  /// Create a copy of Images
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call(
      {Object? startdate = freezed, Object? fullstartdate = freezed, Object? enddate = freezed, Object? url = freezed, Object? urlbase = freezed, Object? copyright = freezed, Object? copyrightlink = freezed, Object? title = freezed, Object? quiz = freezed, Object? wp = freezed, Object? hsh = freezed, Object? drk = freezed, Object? top = freezed, Object? bot = freezed, Object? hs = freezed,}) {
    return _then(_self.copyWith(
      startdate: freezed == startdate
          ? _self.startdate
          : startdate // ignore: cast_nullable_to_non_nullable
      as String?,
      fullstartdate: freezed == fullstartdate
          ? _self.fullstartdate
          : fullstartdate // ignore: cast_nullable_to_non_nullable
      as String?,
      enddate: freezed == enddate
          ? _self.enddate
          : enddate // ignore: cast_nullable_to_non_nullable
      as String?,
      url: freezed == url
          ? _self.url
          : url // ignore: cast_nullable_to_non_nullable
      as String?,
      urlbase: freezed == urlbase
          ? _self.urlbase
          : urlbase // ignore: cast_nullable_to_non_nullable
      as String?,
      copyright: freezed == copyright
          ? _self.copyright
          : copyright // ignore: cast_nullable_to_non_nullable
      as String?,
      copyrightlink: freezed == copyrightlink
          ? _self.copyrightlink
          : copyrightlink // ignore: cast_nullable_to_non_nullable
      as String?,
      title: freezed == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
      as String?,
      quiz: freezed == quiz
          ? _self.quiz
          : quiz // ignore: cast_nullable_to_non_nullable
      as String?,
      wp: freezed == wp ? _self.wp : wp // ignore: cast_nullable_to_non_nullable
      as bool?,
      hsh: freezed == hsh
          ? _self.hsh
          : hsh // ignore: cast_nullable_to_non_nullable
      as String?,
      drk: freezed == drk
          ? _self.drk
          : drk // ignore: cast_nullable_to_non_nullable
      as int?,
      top: freezed == top
          ? _self.top
          : top // ignore: cast_nullable_to_non_nullable
      as int?,
      bot: freezed == bot
          ? _self.bot
          : bot // ignore: cast_nullable_to_non_nullable
      as int?,
      hs: freezed == hs ? _self.hs : hs // ignore: cast_nullable_to_non_nullable
      as List<dynamic>?,
    ));
  }

}


/// @nodoc
@JsonSerializable()
class _Images implements Images {
  const _Images(
      {this.startdate, this.fullstartdate, this.enddate, this.url, this.urlbase, this.copyright, this.copyrightlink, this.title, this.quiz, this.wp, this.hsh, this.drk, this.top, this.bot, final List<
          dynamic>? hs}) : _hs = hs;

  factory _Images.fromJson(Map<String, dynamic> json) => _$ImagesFromJson(json);

  @override final String? startdate;
  @override final String? fullstartdate;
  @override final String? enddate;
  @override final String? url;
  @override final String? urlbase;
  @override final String? copyright;
  @override final String? copyrightlink;
  @override final String? title;
  @override final String? quiz;
  @override final bool? wp;
  @override final String? hsh;
  @override final int? drk;
  @override final int? top;
  @override final int? bot;
  final List<dynamic>? _hs;

  @override List<dynamic>? get hs {
    final value = _hs;
    if (value == null) return null;
    if (_hs is EqualUnmodifiableListView) return _hs;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }


  /// Create a copy of Images
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ImagesCopyWith<_Images> get copyWith =>
      __$ImagesCopyWithImpl<_Images>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ImagesToJson(this,);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _Images &&
            (identical(other.startdate, startdate) ||
                other.startdate == startdate) &&
            (identical(other.fullstartdate, fullstartdate) ||
                other.fullstartdate == fullstartdate) &&
            (identical(other.enddate, enddate) || other.enddate == enddate) &&
            (identical(other.url, url) || other.url == url) &&
            (identical(other.urlbase, urlbase) || other.urlbase == urlbase) &&
            (identical(other.copyright, copyright) ||
                other.copyright == copyright) &&
            (identical(other.copyrightlink, copyrightlink) ||
                other.copyrightlink == copyrightlink) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.quiz, quiz) || other.quiz == quiz) &&
            (identical(other.wp, wp) || other.wp == wp) &&
            (identical(other.hsh, hsh) || other.hsh == hsh) &&
            (identical(other.drk, drk) || other.drk == drk) &&
            (identical(other.top, top) || other.top == top) &&
            (identical(other.bot, bot) || other.bot == bot) &&
            const DeepCollectionEquality().equals(other._hs, _hs));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(
          runtimeType,
          startdate,
          fullstartdate,
          enddate,
          url,
          urlbase,
          copyright,
          copyrightlink,
          title,
          quiz,
          wp,
          hsh,
          drk,
          top,
          bot,
          const DeepCollectionEquality().hash(_hs));

  @override
  String toString() {
    return 'Images(startdate: $startdate, fullstartdate: $fullstartdate, enddate: $enddate, url: $url, urlbase: $urlbase, copyright: $copyright, copyrightlink: $copyrightlink, title: $title, quiz: $quiz, wp: $wp, hsh: $hsh, drk: $drk, top: $top, bot: $bot, hs: $hs)';
  }


}

/// @nodoc
abstract mixin class _$ImagesCopyWith<$Res> implements $ImagesCopyWith<$Res> {
  factory _$ImagesCopyWith(_Images value,
      $Res Function(_Images) _then) = __$ImagesCopyWithImpl;

  @override
  @useResult
  $Res call({
    String? startdate, String? fullstartdate, String? enddate, String? url, String? urlbase, String? copyright, String? copyrightlink, String? title, String? quiz, bool? wp, String? hsh, int? drk, int? top, int? bot, List<
        dynamic>? hs
  });


}

/// @nodoc
class __$ImagesCopyWithImpl<$Res>
    implements _$ImagesCopyWith<$Res> {
  __$ImagesCopyWithImpl(this._self, this._then);

  final _Images _self;
  final $Res Function(_Images) _then;

  /// Create a copy of Images
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call(
      {Object? startdate = freezed, Object? fullstartdate = freezed, Object? enddate = freezed, Object? url = freezed, Object? urlbase = freezed, Object? copyright = freezed, Object? copyrightlink = freezed, Object? title = freezed, Object? quiz = freezed, Object? wp = freezed, Object? hsh = freezed, Object? drk = freezed, Object? top = freezed, Object? bot = freezed, Object? hs = freezed,}) {
    return _then(_Images(
      startdate: freezed == startdate
          ? _self.startdate
          : startdate // ignore: cast_nullable_to_non_nullable
      as String?,
      fullstartdate: freezed == fullstartdate
          ? _self.fullstartdate
          : fullstartdate // ignore: cast_nullable_to_non_nullable
      as String?,
      enddate: freezed == enddate
          ? _self.enddate
          : enddate // ignore: cast_nullable_to_non_nullable
      as String?,
      url: freezed == url
          ? _self.url
          : url // ignore: cast_nullable_to_non_nullable
      as String?,
      urlbase: freezed == urlbase
          ? _self.urlbase
          : urlbase // ignore: cast_nullable_to_non_nullable
      as String?,
      copyright: freezed == copyright
          ? _self.copyright
          : copyright // ignore: cast_nullable_to_non_nullable
      as String?,
      copyrightlink: freezed == copyrightlink
          ? _self.copyrightlink
          : copyrightlink // ignore: cast_nullable_to_non_nullable
      as String?,
      title: freezed == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
      as String?,
      quiz: freezed == quiz
          ? _self.quiz
          : quiz // ignore: cast_nullable_to_non_nullable
      as String?,
      wp: freezed == wp ? _self.wp : wp // ignore: cast_nullable_to_non_nullable
      as bool?,
      hsh: freezed == hsh
          ? _self.hsh
          : hsh // ignore: cast_nullable_to_non_nullable
      as String?,
      drk: freezed == drk
          ? _self.drk
          : drk // ignore: cast_nullable_to_non_nullable
      as int?,
      top: freezed == top
          ? _self.top
          : top // ignore: cast_nullable_to_non_nullable
      as int?,
      bot: freezed == bot
          ? _self.bot
          : bot // ignore: cast_nullable_to_non_nullable
      as int?,
      hs: freezed == hs
          ? _self._hs
          : hs // ignore: cast_nullable_to_non_nullable
      as List<dynamic>?,
    ));
  }


}

// dart format on

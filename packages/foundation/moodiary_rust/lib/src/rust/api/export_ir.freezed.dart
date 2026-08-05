// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'export_ir.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$IrBlock {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is IrBlock);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'IrBlock()';
}


}

/// @nodoc
class $IrBlockCopyWith<$Res>  {
$IrBlockCopyWith(IrBlock _, $Res Function(IrBlock) __);
}


/// Adds pattern-matching-related methods to [IrBlock].
extension IrBlockPatterns on IrBlock {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( IrBlock_Paragraph value)?  paragraph,TResult Function( IrBlock_Heading value)?  heading,TResult Function( IrBlock_List value)?  list,TResult Function( IrBlock_Quote value)?  quote,TResult Function( IrBlock_Code value)?  code,TResult Function( IrBlock_Divider value)?  divider,TResult Function( IrBlock_Image value)?  image,TResult Function( IrBlock_Media value)?  media,TResult Function( IrBlock_Table value)?  table,required TResult orElse(),}){
final _that = this;
switch (_that) {
case IrBlock_Paragraph() when paragraph != null:
return paragraph(_that);case IrBlock_Heading() when heading != null:
return heading(_that);case IrBlock_List() when list != null:
return list(_that);case IrBlock_Quote() when quote != null:
return quote(_that);case IrBlock_Code() when code != null:
return code(_that);case IrBlock_Divider() when divider != null:
return divider(_that);case IrBlock_Image() when image != null:
return image(_that);case IrBlock_Media() when media != null:
return media(_that);case IrBlock_Table() when table != null:
return table(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( IrBlock_Paragraph value)  paragraph,required TResult Function( IrBlock_Heading value)  heading,required TResult Function( IrBlock_List value)  list,required TResult Function( IrBlock_Quote value)  quote,required TResult Function( IrBlock_Code value)  code,required TResult Function( IrBlock_Divider value)  divider,required TResult Function( IrBlock_Image value)  image,required TResult Function( IrBlock_Media value)  media,required TResult Function( IrBlock_Table value)  table,}){
final _that = this;
switch (_that) {
case IrBlock_Paragraph():
return paragraph(_that);case IrBlock_Heading():
return heading(_that);case IrBlock_List():
return list(_that);case IrBlock_Quote():
return quote(_that);case IrBlock_Code():
return code(_that);case IrBlock_Divider():
return divider(_that);case IrBlock_Image():
return image(_that);case IrBlock_Media():
return media(_that);case IrBlock_Table():
return table(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( IrBlock_Paragraph value)?  paragraph,TResult? Function( IrBlock_Heading value)?  heading,TResult? Function( IrBlock_List value)?  list,TResult? Function( IrBlock_Quote value)?  quote,TResult? Function( IrBlock_Code value)?  code,TResult? Function( IrBlock_Divider value)?  divider,TResult? Function( IrBlock_Image value)?  image,TResult? Function( IrBlock_Media value)?  media,TResult? Function( IrBlock_Table value)?  table,}){
final _that = this;
switch (_that) {
case IrBlock_Paragraph() when paragraph != null:
return paragraph(_that);case IrBlock_Heading() when heading != null:
return heading(_that);case IrBlock_List() when list != null:
return list(_that);case IrBlock_Quote() when quote != null:
return quote(_that);case IrBlock_Code() when code != null:
return code(_that);case IrBlock_Divider() when divider != null:
return divider(_that);case IrBlock_Image() when image != null:
return image(_that);case IrBlock_Media() when media != null:
return media(_that);case IrBlock_Table() when table != null:
return table(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( List<IrSpan> spans)?  paragraph,TResult Function( int level,  List<IrSpan> spans)?  heading,TResult Function( bool ordered,  int start,  List<IrListItem> items)?  list,TResult Function( List<IrBlock> children)?  quote,TResult Function( String? language,  String text)?  code,TResult Function()?  divider,TResult Function( String path,  String? alt,  int? widthPercent,  bool external_)?  image,TResult Function( String kind,  String filename,  String path,  String? coverPath)?  media,TResult Function( List<List<IrCell>> rows)?  table,required TResult orElse(),}) {final _that = this;
switch (_that) {
case IrBlock_Paragraph() when paragraph != null:
return paragraph(_that.spans);case IrBlock_Heading() when heading != null:
return heading(_that.level,_that.spans);case IrBlock_List() when list != null:
return list(_that.ordered,_that.start,_that.items);case IrBlock_Quote() when quote != null:
return quote(_that.children);case IrBlock_Code() when code != null:
return code(_that.language,_that.text);case IrBlock_Divider() when divider != null:
return divider();case IrBlock_Image() when image != null:
return image(_that.path,_that.alt,_that.widthPercent,_that.external_);case IrBlock_Media() when media != null:
return media(_that.kind,_that.filename,_that.path,_that.coverPath);case IrBlock_Table() when table != null:
return table(_that.rows);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( List<IrSpan> spans)  paragraph,required TResult Function( int level,  List<IrSpan> spans)  heading,required TResult Function( bool ordered,  int start,  List<IrListItem> items)  list,required TResult Function( List<IrBlock> children)  quote,required TResult Function( String? language,  String text)  code,required TResult Function()  divider,required TResult Function( String path,  String? alt,  int? widthPercent,  bool external_)  image,required TResult Function( String kind,  String filename,  String path,  String? coverPath)  media,required TResult Function( List<List<IrCell>> rows)  table,}) {final _that = this;
switch (_that) {
case IrBlock_Paragraph():
return paragraph(_that.spans);case IrBlock_Heading():
return heading(_that.level,_that.spans);case IrBlock_List():
return list(_that.ordered,_that.start,_that.items);case IrBlock_Quote():
return quote(_that.children);case IrBlock_Code():
return code(_that.language,_that.text);case IrBlock_Divider():
return divider();case IrBlock_Image():
return image(_that.path,_that.alt,_that.widthPercent,_that.external_);case IrBlock_Media():
return media(_that.kind,_that.filename,_that.path,_that.coverPath);case IrBlock_Table():
return table(_that.rows);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( List<IrSpan> spans)?  paragraph,TResult? Function( int level,  List<IrSpan> spans)?  heading,TResult? Function( bool ordered,  int start,  List<IrListItem> items)?  list,TResult? Function( List<IrBlock> children)?  quote,TResult? Function( String? language,  String text)?  code,TResult? Function()?  divider,TResult? Function( String path,  String? alt,  int? widthPercent,  bool external_)?  image,TResult? Function( String kind,  String filename,  String path,  String? coverPath)?  media,TResult? Function( List<List<IrCell>> rows)?  table,}) {final _that = this;
switch (_that) {
case IrBlock_Paragraph() when paragraph != null:
return paragraph(_that.spans);case IrBlock_Heading() when heading != null:
return heading(_that.level,_that.spans);case IrBlock_List() when list != null:
return list(_that.ordered,_that.start,_that.items);case IrBlock_Quote() when quote != null:
return quote(_that.children);case IrBlock_Code() when code != null:
return code(_that.language,_that.text);case IrBlock_Divider() when divider != null:
return divider();case IrBlock_Image() when image != null:
return image(_that.path,_that.alt,_that.widthPercent,_that.external_);case IrBlock_Media() when media != null:
return media(_that.kind,_that.filename,_that.path,_that.coverPath);case IrBlock_Table() when table != null:
return table(_that.rows);case _:
  return null;

}
}

}

/// @nodoc


class IrBlock_Paragraph extends IrBlock {
  const IrBlock_Paragraph({required final  List<IrSpan> spans}): _spans = spans,super._();
  

 final  List<IrSpan> _spans;
 List<IrSpan> get spans {
  if (_spans is EqualUnmodifiableListView) return _spans;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_spans);
}


/// Create a copy of IrBlock
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$IrBlock_ParagraphCopyWith<IrBlock_Paragraph> get copyWith => _$IrBlock_ParagraphCopyWithImpl<IrBlock_Paragraph>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is IrBlock_Paragraph&&const DeepCollectionEquality().equals(other._spans, _spans));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_spans));

@override
String toString() {
  return 'IrBlock.paragraph(spans: $spans)';
}


}

/// @nodoc
abstract mixin class $IrBlock_ParagraphCopyWith<$Res> implements $IrBlockCopyWith<$Res> {
  factory $IrBlock_ParagraphCopyWith(IrBlock_Paragraph value, $Res Function(IrBlock_Paragraph) _then) = _$IrBlock_ParagraphCopyWithImpl;
@useResult
$Res call({
 List<IrSpan> spans
});




}
/// @nodoc
class _$IrBlock_ParagraphCopyWithImpl<$Res>
    implements $IrBlock_ParagraphCopyWith<$Res> {
  _$IrBlock_ParagraphCopyWithImpl(this._self, this._then);

  final IrBlock_Paragraph _self;
  final $Res Function(IrBlock_Paragraph) _then;

/// Create a copy of IrBlock
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? spans = null,}) {
  return _then(IrBlock_Paragraph(
spans: null == spans ? _self._spans : spans // ignore: cast_nullable_to_non_nullable
as List<IrSpan>,
  ));
}


}

/// @nodoc


class IrBlock_Heading extends IrBlock {
  const IrBlock_Heading({required this.level, required final  List<IrSpan> spans}): _spans = spans,super._();
  

 final  int level;
 final  List<IrSpan> _spans;
 List<IrSpan> get spans {
  if (_spans is EqualUnmodifiableListView) return _spans;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_spans);
}


/// Create a copy of IrBlock
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$IrBlock_HeadingCopyWith<IrBlock_Heading> get copyWith => _$IrBlock_HeadingCopyWithImpl<IrBlock_Heading>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is IrBlock_Heading&&(identical(other.level, level) || other.level == level)&&const DeepCollectionEquality().equals(other._spans, _spans));
}


@override
int get hashCode => Object.hash(runtimeType,level,const DeepCollectionEquality().hash(_spans));

@override
String toString() {
  return 'IrBlock.heading(level: $level, spans: $spans)';
}


}

/// @nodoc
abstract mixin class $IrBlock_HeadingCopyWith<$Res> implements $IrBlockCopyWith<$Res> {
  factory $IrBlock_HeadingCopyWith(IrBlock_Heading value, $Res Function(IrBlock_Heading) _then) = _$IrBlock_HeadingCopyWithImpl;
@useResult
$Res call({
 int level, List<IrSpan> spans
});




}
/// @nodoc
class _$IrBlock_HeadingCopyWithImpl<$Res>
    implements $IrBlock_HeadingCopyWith<$Res> {
  _$IrBlock_HeadingCopyWithImpl(this._self, this._then);

  final IrBlock_Heading _self;
  final $Res Function(IrBlock_Heading) _then;

/// Create a copy of IrBlock
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? level = null,Object? spans = null,}) {
  return _then(IrBlock_Heading(
level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as int,spans: null == spans ? _self._spans : spans // ignore: cast_nullable_to_non_nullable
as List<IrSpan>,
  ));
}


}

/// @nodoc


class IrBlock_List extends IrBlock {
  const IrBlock_List({required this.ordered, required this.start, required final  List<IrListItem> items}): _items = items,super._();
  

 final  bool ordered;
 final  int start;
 final  List<IrListItem> _items;
 List<IrListItem> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}


/// Create a copy of IrBlock
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$IrBlock_ListCopyWith<IrBlock_List> get copyWith => _$IrBlock_ListCopyWithImpl<IrBlock_List>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is IrBlock_List&&(identical(other.ordered, ordered) || other.ordered == ordered)&&(identical(other.start, start) || other.start == start)&&const DeepCollectionEquality().equals(other._items, _items));
}


@override
int get hashCode => Object.hash(runtimeType,ordered,start,const DeepCollectionEquality().hash(_items));

@override
String toString() {
  return 'IrBlock.list(ordered: $ordered, start: $start, items: $items)';
}


}

/// @nodoc
abstract mixin class $IrBlock_ListCopyWith<$Res> implements $IrBlockCopyWith<$Res> {
  factory $IrBlock_ListCopyWith(IrBlock_List value, $Res Function(IrBlock_List) _then) = _$IrBlock_ListCopyWithImpl;
@useResult
$Res call({
 bool ordered, int start, List<IrListItem> items
});




}
/// @nodoc
class _$IrBlock_ListCopyWithImpl<$Res>
    implements $IrBlock_ListCopyWith<$Res> {
  _$IrBlock_ListCopyWithImpl(this._self, this._then);

  final IrBlock_List _self;
  final $Res Function(IrBlock_List) _then;

/// Create a copy of IrBlock
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? ordered = null,Object? start = null,Object? items = null,}) {
  return _then(IrBlock_List(
ordered: null == ordered ? _self.ordered : ordered // ignore: cast_nullable_to_non_nullable
as bool,start: null == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as int,items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<IrListItem>,
  ));
}


}

/// @nodoc


class IrBlock_Quote extends IrBlock {
  const IrBlock_Quote({required final  List<IrBlock> children}): _children = children,super._();
  

 final  List<IrBlock> _children;
 List<IrBlock> get children {
  if (_children is EqualUnmodifiableListView) return _children;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_children);
}


/// Create a copy of IrBlock
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$IrBlock_QuoteCopyWith<IrBlock_Quote> get copyWith => _$IrBlock_QuoteCopyWithImpl<IrBlock_Quote>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is IrBlock_Quote&&const DeepCollectionEquality().equals(other._children, _children));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_children));

@override
String toString() {
  return 'IrBlock.quote(children: $children)';
}


}

/// @nodoc
abstract mixin class $IrBlock_QuoteCopyWith<$Res> implements $IrBlockCopyWith<$Res> {
  factory $IrBlock_QuoteCopyWith(IrBlock_Quote value, $Res Function(IrBlock_Quote) _then) = _$IrBlock_QuoteCopyWithImpl;
@useResult
$Res call({
 List<IrBlock> children
});




}
/// @nodoc
class _$IrBlock_QuoteCopyWithImpl<$Res>
    implements $IrBlock_QuoteCopyWith<$Res> {
  _$IrBlock_QuoteCopyWithImpl(this._self, this._then);

  final IrBlock_Quote _self;
  final $Res Function(IrBlock_Quote) _then;

/// Create a copy of IrBlock
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? children = null,}) {
  return _then(IrBlock_Quote(
children: null == children ? _self._children : children // ignore: cast_nullable_to_non_nullable
as List<IrBlock>,
  ));
}


}

/// @nodoc


class IrBlock_Code extends IrBlock {
  const IrBlock_Code({this.language, required this.text}): super._();
  

 final  String? language;
 final  String text;

/// Create a copy of IrBlock
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$IrBlock_CodeCopyWith<IrBlock_Code> get copyWith => _$IrBlock_CodeCopyWithImpl<IrBlock_Code>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is IrBlock_Code&&(identical(other.language, language) || other.language == language)&&(identical(other.text, text) || other.text == text));
}


@override
int get hashCode => Object.hash(runtimeType,language,text);

@override
String toString() {
  return 'IrBlock.code(language: $language, text: $text)';
}


}

/// @nodoc
abstract mixin class $IrBlock_CodeCopyWith<$Res> implements $IrBlockCopyWith<$Res> {
  factory $IrBlock_CodeCopyWith(IrBlock_Code value, $Res Function(IrBlock_Code) _then) = _$IrBlock_CodeCopyWithImpl;
@useResult
$Res call({
 String? language, String text
});




}
/// @nodoc
class _$IrBlock_CodeCopyWithImpl<$Res>
    implements $IrBlock_CodeCopyWith<$Res> {
  _$IrBlock_CodeCopyWithImpl(this._self, this._then);

  final IrBlock_Code _self;
  final $Res Function(IrBlock_Code) _then;

/// Create a copy of IrBlock
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? language = freezed,Object? text = null,}) {
  return _then(IrBlock_Code(
language: freezed == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String?,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class IrBlock_Divider extends IrBlock {
  const IrBlock_Divider(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is IrBlock_Divider);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'IrBlock.divider()';
}


}




/// @nodoc


class IrBlock_Image extends IrBlock {
  const IrBlock_Image({required this.path, this.alt, this.widthPercent, required this.external_}): super._();
  

 final  String path;
 final  String? alt;
/// 正文列宽百分比上限（25/50/75/100）。
 final  int? widthPercent;
/// 粘贴进来的外链图，导出时不下载、只当链接处理。
 final  bool external_;

/// Create a copy of IrBlock
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$IrBlock_ImageCopyWith<IrBlock_Image> get copyWith => _$IrBlock_ImageCopyWithImpl<IrBlock_Image>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is IrBlock_Image&&(identical(other.path, path) || other.path == path)&&(identical(other.alt, alt) || other.alt == alt)&&(identical(other.widthPercent, widthPercent) || other.widthPercent == widthPercent)&&(identical(other.external_, external_) || other.external_ == external_));
}


@override
int get hashCode => Object.hash(runtimeType,path,alt,widthPercent,external_);

@override
String toString() {
  return 'IrBlock.image(path: $path, alt: $alt, widthPercent: $widthPercent, external_: $external_)';
}


}

/// @nodoc
abstract mixin class $IrBlock_ImageCopyWith<$Res> implements $IrBlockCopyWith<$Res> {
  factory $IrBlock_ImageCopyWith(IrBlock_Image value, $Res Function(IrBlock_Image) _then) = _$IrBlock_ImageCopyWithImpl;
@useResult
$Res call({
 String path, String? alt, int? widthPercent, bool external_
});




}
/// @nodoc
class _$IrBlock_ImageCopyWithImpl<$Res>
    implements $IrBlock_ImageCopyWith<$Res> {
  _$IrBlock_ImageCopyWithImpl(this._self, this._then);

  final IrBlock_Image _self;
  final $Res Function(IrBlock_Image) _then;

/// Create a copy of IrBlock
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? path = null,Object? alt = freezed,Object? widthPercent = freezed,Object? external_ = null,}) {
  return _then(IrBlock_Image(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,alt: freezed == alt ? _self.alt : alt // ignore: cast_nullable_to_non_nullable
as String?,widthPercent: freezed == widthPercent ? _self.widthPercent : widthPercent // ignore: cast_nullable_to_non_nullable
as int?,external_: null == external_ ? _self.external_ : external_ // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class IrBlock_Media extends IrBlock {
  const IrBlock_Media({required this.kind, required this.filename, required this.path, this.coverPath}): super._();
  

 final  String kind;
 final  String filename;
 final  String path;
 final  String? coverPath;

/// Create a copy of IrBlock
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$IrBlock_MediaCopyWith<IrBlock_Media> get copyWith => _$IrBlock_MediaCopyWithImpl<IrBlock_Media>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is IrBlock_Media&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.filename, filename) || other.filename == filename)&&(identical(other.path, path) || other.path == path)&&(identical(other.coverPath, coverPath) || other.coverPath == coverPath));
}


@override
int get hashCode => Object.hash(runtimeType,kind,filename,path,coverPath);

@override
String toString() {
  return 'IrBlock.media(kind: $kind, filename: $filename, path: $path, coverPath: $coverPath)';
}


}

/// @nodoc
abstract mixin class $IrBlock_MediaCopyWith<$Res> implements $IrBlockCopyWith<$Res> {
  factory $IrBlock_MediaCopyWith(IrBlock_Media value, $Res Function(IrBlock_Media) _then) = _$IrBlock_MediaCopyWithImpl;
@useResult
$Res call({
 String kind, String filename, String path, String? coverPath
});




}
/// @nodoc
class _$IrBlock_MediaCopyWithImpl<$Res>
    implements $IrBlock_MediaCopyWith<$Res> {
  _$IrBlock_MediaCopyWithImpl(this._self, this._then);

  final IrBlock_Media _self;
  final $Res Function(IrBlock_Media) _then;

/// Create a copy of IrBlock
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? kind = null,Object? filename = null,Object? path = null,Object? coverPath = freezed,}) {
  return _then(IrBlock_Media(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,filename: null == filename ? _self.filename : filename // ignore: cast_nullable_to_non_nullable
as String,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,coverPath: freezed == coverPath ? _self.coverPath : coverPath // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc


class IrBlock_Table extends IrBlock {
  const IrBlock_Table({required final  List<List<IrCell>> rows}): _rows = rows,super._();
  

 final  List<List<IrCell>> _rows;
 List<List<IrCell>> get rows {
  if (_rows is EqualUnmodifiableListView) return _rows;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_rows);
}


/// Create a copy of IrBlock
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$IrBlock_TableCopyWith<IrBlock_Table> get copyWith => _$IrBlock_TableCopyWithImpl<IrBlock_Table>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is IrBlock_Table&&const DeepCollectionEquality().equals(other._rows, _rows));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_rows));

@override
String toString() {
  return 'IrBlock.table(rows: $rows)';
}


}

/// @nodoc
abstract mixin class $IrBlock_TableCopyWith<$Res> implements $IrBlockCopyWith<$Res> {
  factory $IrBlock_TableCopyWith(IrBlock_Table value, $Res Function(IrBlock_Table) _then) = _$IrBlock_TableCopyWithImpl;
@useResult
$Res call({
 List<List<IrCell>> rows
});




}
/// @nodoc
class _$IrBlock_TableCopyWithImpl<$Res>
    implements $IrBlock_TableCopyWith<$Res> {
  _$IrBlock_TableCopyWithImpl(this._self, this._then);

  final IrBlock_Table _self;
  final $Res Function(IrBlock_Table) _then;

/// Create a copy of IrBlock
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? rows = null,}) {
  return _then(IrBlock_Table(
rows: null == rows ? _self._rows : rows // ignore: cast_nullable_to_non_nullable
as List<List<IrCell>>,
  ));
}


}

// dart format on

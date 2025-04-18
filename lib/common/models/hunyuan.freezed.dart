// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'hunyuan.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PublicHeader {

  @JsonKey(name: 'X-TC-Action') String? get action;

  @JsonKey(name: 'X-TC-Timestamp') int? get timestamp;

  @JsonKey(name: 'X-TC-Version') String? get version;

  @JsonKey(name: 'Authorization') String? get authorization;

  /// Create a copy of PublicHeader
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $PublicHeaderCopyWith<PublicHeader> get copyWith =>
      _$PublicHeaderCopyWithImpl<PublicHeader>(
          this as PublicHeader, _$identity);

  /// Serializes this PublicHeader to a JSON map.
  Map<String, dynamic> toJson();


  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is PublicHeader &&
            (identical(other.action, action) || other.action == action) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp) &&
            (identical(other.version, version) || other.version == version) &&
            (identical(other.authorization, authorization) ||
                other.authorization == authorization));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, action, timestamp, version, authorization);

  @override
  String toString() {
    return 'PublicHeader(action: $action, timestamp: $timestamp, version: $version, authorization: $authorization)';
  }


}

/// @nodoc
abstract mixin class $PublicHeaderCopyWith<$Res> {
  factory $PublicHeaderCopyWith(PublicHeader value,
      $Res Function(PublicHeader) _then) = _$PublicHeaderCopyWithImpl;

  @useResult
  $Res call({
    @JsonKey(name: 'X-TC-Action') String? action, @JsonKey(
        name: 'X-TC-Timestamp') int? timestamp, @JsonKey(
        name: 'X-TC-Version') String? version, @JsonKey(
        name: 'Authorization') String? authorization
  });


}

/// @nodoc
class _$PublicHeaderCopyWithImpl<$Res>
    implements $PublicHeaderCopyWith<$Res> {
  _$PublicHeaderCopyWithImpl(this._self, this._then);

  final PublicHeader _self;
  final $Res Function(PublicHeader) _then;

  /// Create a copy of PublicHeader
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call(
      {Object? action = freezed, Object? timestamp = freezed, Object? version = freezed, Object? authorization = freezed,}) {
    return _then(_self.copyWith(
      action: freezed == action
          ? _self.action
          : action // ignore: cast_nullable_to_non_nullable
      as String?,
      timestamp: freezed == timestamp
          ? _self.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
      as int?,
      version: freezed == version
          ? _self.version
          : version // ignore: cast_nullable_to_non_nullable
      as String?,
      authorization: freezed == authorization
          ? _self.authorization
          : authorization // ignore: cast_nullable_to_non_nullable
      as String?,
    ));
  }

}


/// @nodoc
@JsonSerializable()
class _PublicHeader implements PublicHeader {
  const _PublicHeader({@JsonKey(name: 'X-TC-Action') this.action, @JsonKey(
      name: 'X-TC-Timestamp') this.timestamp, @JsonKey(
      name: 'X-TC-Version') this.version, @JsonKey(
      name: 'Authorization') this.authorization});

  factory _PublicHeader.fromJson(Map<String, dynamic> json) =>
      _$PublicHeaderFromJson(json);

  @override
  @JsonKey(name: 'X-TC-Action')
  final String? action;
  @override
  @JsonKey(name: 'X-TC-Timestamp')
  final int? timestamp;
  @override
  @JsonKey(name: 'X-TC-Version')
  final String? version;
  @override
  @JsonKey(name: 'Authorization')
  final String? authorization;

  /// Create a copy of PublicHeader
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$PublicHeaderCopyWith<_PublicHeader> get copyWith =>
      __$PublicHeaderCopyWithImpl<_PublicHeader>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$PublicHeaderToJson(this,);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _PublicHeader &&
            (identical(other.action, action) || other.action == action) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp) &&
            (identical(other.version, version) || other.version == version) &&
            (identical(other.authorization, authorization) ||
                other.authorization == authorization));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, action, timestamp, version, authorization);

  @override
  String toString() {
    return 'PublicHeader(action: $action, timestamp: $timestamp, version: $version, authorization: $authorization)';
  }


}

/// @nodoc
abstract mixin class _$PublicHeaderCopyWith<$Res>
    implements $PublicHeaderCopyWith<$Res> {
  factory _$PublicHeaderCopyWith(_PublicHeader value,
      $Res Function(_PublicHeader) _then) = __$PublicHeaderCopyWithImpl;

  @override
  @useResult
  $Res call({
    @JsonKey(name: 'X-TC-Action') String? action, @JsonKey(
        name: 'X-TC-Timestamp') int? timestamp, @JsonKey(
        name: 'X-TC-Version') String? version, @JsonKey(
        name: 'Authorization') String? authorization
  });


}

/// @nodoc
class __$PublicHeaderCopyWithImpl<$Res>
    implements _$PublicHeaderCopyWith<$Res> {
  __$PublicHeaderCopyWithImpl(this._self, this._then);

  final _PublicHeader _self;
  final $Res Function(_PublicHeader) _then;

  /// Create a copy of PublicHeader
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call(
      {Object? action = freezed, Object? timestamp = freezed, Object? version = freezed, Object? authorization = freezed,}) {
    return _then(_PublicHeader(
      action: freezed == action
          ? _self.action
          : action // ignore: cast_nullable_to_non_nullable
      as String?,
      timestamp: freezed == timestamp
          ? _self.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
      as int?,
      version: freezed == version
          ? _self.version
          : version // ignore: cast_nullable_to_non_nullable
      as String?,
      authorization: freezed == authorization
          ? _self.authorization
          : authorization // ignore: cast_nullable_to_non_nullable
      as String?,
    ));
  }


}


/// @nodoc
mixin _$Message {

  @JsonKey(name: 'Role') String get role;

  @JsonKey(name: 'Content') String get content;

  /// Create a copy of Message
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $MessageCopyWith<Message> get copyWith =>
      _$MessageCopyWithImpl<Message>(this as Message, _$identity);

  /// Serializes this Message to a JSON map.
  Map<String, dynamic> toJson();


  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is Message &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.content, content) || other.content == content));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, role, content);

  @override
  String toString() {
    return 'Message(role: $role, content: $content)';
  }


}

/// @nodoc
abstract mixin class $MessageCopyWith<$Res> {
  factory $MessageCopyWith(Message value,
      $Res Function(Message) _then) = _$MessageCopyWithImpl;

  @useResult
  $Res call({
    @JsonKey(name: 'Role') String role, @JsonKey(name: 'Content') String content
  });


}

/// @nodoc
class _$MessageCopyWithImpl<$Res>
    implements $MessageCopyWith<$Res> {
  _$MessageCopyWithImpl(this._self, this._then);

  final Message _self;
  final $Res Function(Message) _then;

  /// Create a copy of Message
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? role = null, Object? content = null,}) {
    return _then(_self.copyWith(
      role: null == role
          ? _self.role
          : role // ignore: cast_nullable_to_non_nullable
      as String,
      content: null == content
          ? _self.content
          : content // ignore: cast_nullable_to_non_nullable
      as String,
    ));
  }

}


/// @nodoc
@JsonSerializable()
class _Message implements Message {
  const _Message({@JsonKey(name: 'Role') required this.role, @JsonKey(
      name: 'Content') required this.content});

  factory _Message.fromJson(Map<String, dynamic> json) =>
      _$MessageFromJson(json);

  @override
  @JsonKey(name: 'Role')
  final String role;
  @override
  @JsonKey(name: 'Content')
  final String content;

  /// Create a copy of Message
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$MessageCopyWith<_Message> get copyWith =>
      __$MessageCopyWithImpl<_Message>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$MessageToJson(this,);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _Message &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.content, content) || other.content == content));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, role, content);

  @override
  String toString() {
    return 'Message(role: $role, content: $content)';
  }


}

/// @nodoc
abstract mixin class _$MessageCopyWith<$Res> implements $MessageCopyWith<$Res> {
  factory _$MessageCopyWith(_Message value,
      $Res Function(_Message) _then) = __$MessageCopyWithImpl;

  @override
  @useResult
  $Res call({
    @JsonKey(name: 'Role') String role, @JsonKey(name: 'Content') String content
  });


}

/// @nodoc
class __$MessageCopyWithImpl<$Res>
    implements _$MessageCopyWith<$Res> {
  __$MessageCopyWithImpl(this._self, this._then);

  final _Message _self;
  final $Res Function(_Message) _then;

  /// Create a copy of Message
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({Object? role = null, Object? content = null,}) {
    return _then(_Message(
      role: null == role
          ? _self.role
          : role // ignore: cast_nullable_to_non_nullable
      as String,
      content: null == content
          ? _self.content
          : content // ignore: cast_nullable_to_non_nullable
      as String,
    ));
  }


}


/// @nodoc
mixin _$HunyuanResponse {

  @JsonKey(name: 'Note') String? get note;

  @JsonKey(name: 'Choices') List<Choices>? get choices;

  @JsonKey(name: 'Created') int? get created;

  @JsonKey(name: 'Id') String? get id;

  @JsonKey(name: 'Usage') Usage? get usage;

  /// Create a copy of HunyuanResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $HunyuanResponseCopyWith<HunyuanResponse> get copyWith =>
      _$HunyuanResponseCopyWithImpl<HunyuanResponse>(
          this as HunyuanResponse, _$identity);

  /// Serializes this HunyuanResponse to a JSON map.
  Map<String, dynamic> toJson();


  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is HunyuanResponse &&
            (identical(other.note, note) || other.note == note) &&
            const DeepCollectionEquality().equals(other.choices, choices) &&
            (identical(other.created, created) || other.created == created) &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.usage, usage) || other.usage == usage));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(
          runtimeType, note, const DeepCollectionEquality().hash(choices),
          created,
          id, usage);

  @override
  String toString() {
    return 'HunyuanResponse(note: $note, choices: $choices, created: $created, id: $id, usage: $usage)';
  }


}

/// @nodoc
abstract mixin class $HunyuanResponseCopyWith<$Res> {
  factory $HunyuanResponseCopyWith(HunyuanResponse value,
      $Res Function(HunyuanResponse) _then) = _$HunyuanResponseCopyWithImpl;

  @useResult
  $Res call({
    @JsonKey(name: 'Note') String? note, @JsonKey(name: 'Choices') List<
        Choices>? choices, @JsonKey(name: 'Created') int? created, @JsonKey(
        name: 'Id') String? id, @JsonKey(name: 'Usage') Usage? usage
  });


  $UsageCopyWith<$Res>? get usage;

}

/// @nodoc
class _$HunyuanResponseCopyWithImpl<$Res>
    implements $HunyuanResponseCopyWith<$Res> {
  _$HunyuanResponseCopyWithImpl(this._self, this._then);

  final HunyuanResponse _self;
  final $Res Function(HunyuanResponse) _then;

  /// Create a copy of HunyuanResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call(
      {Object? note = freezed, Object? choices = freezed, Object? created = freezed, Object? id = freezed, Object? usage = freezed,}) {
    return _then(_self.copyWith(
      note: freezed == note
          ? _self.note
          : note // ignore: cast_nullable_to_non_nullable
      as String?,
      choices: freezed == choices
          ? _self.choices
          : choices // ignore: cast_nullable_to_non_nullable
      as List<Choices>?,
      created: freezed == created
          ? _self.created
          : created // ignore: cast_nullable_to_non_nullable
      as int?,
      id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
      as String?,
      usage: freezed == usage
          ? _self.usage
          : usage // ignore: cast_nullable_to_non_nullable
      as Usage?,
    ));
  }

  /// Create a copy of HunyuanResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $UsageCopyWith<$Res>? get usage {
    if (_self.usage == null) {
      return null;
    }

    return $UsageCopyWith<$Res>(_self.usage!, (value) {
      return _then(_self.copyWith(usage: value));
    });
  }
}


/// @nodoc
@JsonSerializable()
class _HunyuanResponse implements HunyuanResponse {
  const _HunyuanResponse(
      {@JsonKey(name: 'Note') this.note, @JsonKey(name: 'Choices') final List<
          Choices>? choices, @JsonKey(name: 'Created') this.created, @JsonKey(
          name: 'Id') this.id, @JsonKey(name: 'Usage') this.usage})
      : _choices = choices;

  factory _HunyuanResponse.fromJson(Map<String, dynamic> json) =>
      _$HunyuanResponseFromJson(json);

  @override
  @JsonKey(name: 'Note')
  final String? note;
  final List<Choices>? _choices;

  @override
  @JsonKey(name: 'Choices')
  List<Choices>? get choices {
    final value = _choices;
    if (value == null) return null;
    if (_choices is EqualUnmodifiableListView) return _choices;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  @JsonKey(name: 'Created')
  final int? created;
  @override
  @JsonKey(name: 'Id')
  final String? id;
  @override
  @JsonKey(name: 'Usage')
  final Usage? usage;

  /// Create a copy of HunyuanResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$HunyuanResponseCopyWith<_HunyuanResponse> get copyWith =>
      __$HunyuanResponseCopyWithImpl<_HunyuanResponse>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$HunyuanResponseToJson(this,);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _HunyuanResponse &&
            (identical(other.note, note) || other.note == note) &&
            const DeepCollectionEquality().equals(other._choices, _choices) &&
            (identical(other.created, created) || other.created == created) &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.usage, usage) || other.usage == usage));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(
          runtimeType, note, const DeepCollectionEquality().hash(_choices),
          created,
          id, usage);

  @override
  String toString() {
    return 'HunyuanResponse(note: $note, choices: $choices, created: $created, id: $id, usage: $usage)';
  }


}

/// @nodoc
abstract mixin class _$HunyuanResponseCopyWith<$Res>
    implements $HunyuanResponseCopyWith<$Res> {
  factory _$HunyuanResponseCopyWith(_HunyuanResponse value,
      $Res Function(_HunyuanResponse) _then) = __$HunyuanResponseCopyWithImpl;

  @override
  @useResult
  $Res call({
    @JsonKey(name: 'Note') String? note, @JsonKey(name: 'Choices') List<
        Choices>? choices, @JsonKey(name: 'Created') int? created, @JsonKey(
        name: 'Id') String? id, @JsonKey(name: 'Usage') Usage? usage
  });


  @override $UsageCopyWith<$Res>? get usage;

}

/// @nodoc
class __$HunyuanResponseCopyWithImpl<$Res>
    implements _$HunyuanResponseCopyWith<$Res> {
  __$HunyuanResponseCopyWithImpl(this._self, this._then);

  final _HunyuanResponse _self;
  final $Res Function(_HunyuanResponse) _then;

  /// Create a copy of HunyuanResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call(
      {Object? note = freezed, Object? choices = freezed, Object? created = freezed, Object? id = freezed, Object? usage = freezed,}) {
    return _then(_HunyuanResponse(
      note: freezed == note
          ? _self.note
          : note // ignore: cast_nullable_to_non_nullable
      as String?,
      choices: freezed == choices
          ? _self._choices
          : choices // ignore: cast_nullable_to_non_nullable
      as List<Choices>?,
      created: freezed == created
          ? _self.created
          : created // ignore: cast_nullable_to_non_nullable
      as int?,
      id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
      as String?,
      usage: freezed == usage
          ? _self.usage
          : usage // ignore: cast_nullable_to_non_nullable
      as Usage?,
    ));
  }

  /// Create a copy of HunyuanResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $UsageCopyWith<$Res>? get usage {
    if (_self.usage == null) {
      return null;
    }

    return $UsageCopyWith<$Res>(_self.usage!, (value) {
      return _then(_self.copyWith(usage: value));
    });
  }
}


/// @nodoc
mixin _$Usage {

  @JsonKey(name: 'PromptTokens') int? get promptTokens;

  @JsonKey(name: 'CompletionTokens') int? get completionTokens;

  @JsonKey(name: 'TotalTokens') int? get totalTokens;

  /// Create a copy of Usage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $UsageCopyWith<Usage> get copyWith =>
      _$UsageCopyWithImpl<Usage>(this as Usage, _$identity);

  /// Serializes this Usage to a JSON map.
  Map<String, dynamic> toJson();


  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is Usage &&
            (identical(other.promptTokens, promptTokens) ||
                other.promptTokens == promptTokens) &&
            (identical(other.completionTokens, completionTokens) ||
                other.completionTokens == completionTokens) &&
            (identical(other.totalTokens, totalTokens) ||
                other.totalTokens == totalTokens));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, promptTokens, completionTokens, totalTokens);

  @override
  String toString() {
    return 'Usage(promptTokens: $promptTokens, completionTokens: $completionTokens, totalTokens: $totalTokens)';
  }


}

/// @nodoc
abstract mixin class $UsageCopyWith<$Res> {
  factory $UsageCopyWith(Usage value,
      $Res Function(Usage) _then) = _$UsageCopyWithImpl;

  @useResult
  $Res call({
    @JsonKey(name: 'PromptTokens') int? promptTokens, @JsonKey(
        name: 'CompletionTokens') int? completionTokens, @JsonKey(
        name: 'TotalTokens') int? totalTokens
  });


}

/// @nodoc
class _$UsageCopyWithImpl<$Res>
    implements $UsageCopyWith<$Res> {
  _$UsageCopyWithImpl(this._self, this._then);

  final Usage _self;
  final $Res Function(Usage) _then;

  /// Create a copy of Usage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call(
      {Object? promptTokens = freezed, Object? completionTokens = freezed, Object? totalTokens = freezed,}) {
    return _then(_self.copyWith(
      promptTokens: freezed == promptTokens
          ? _self.promptTokens
          : promptTokens // ignore: cast_nullable_to_non_nullable
      as int?,
      completionTokens: freezed == completionTokens
          ? _self.completionTokens
          : completionTokens // ignore: cast_nullable_to_non_nullable
      as int?,
      totalTokens: freezed == totalTokens
          ? _self.totalTokens
          : totalTokens // ignore: cast_nullable_to_non_nullable
      as int?,
    ));
  }

}


/// @nodoc
@JsonSerializable()
class _Usage implements Usage {
  const _Usage({@JsonKey(name: 'PromptTokens') this.promptTokens, @JsonKey(
      name: 'CompletionTokens') this.completionTokens, @JsonKey(
      name: 'TotalTokens') this.totalTokens});

  factory _Usage.fromJson(Map<String, dynamic> json) => _$UsageFromJson(json);

  @override
  @JsonKey(name: 'PromptTokens')
  final int? promptTokens;
  @override
  @JsonKey(name: 'CompletionTokens')
  final int? completionTokens;
  @override
  @JsonKey(name: 'TotalTokens')
  final int? totalTokens;

  /// Create a copy of Usage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$UsageCopyWith<_Usage> get copyWith =>
      __$UsageCopyWithImpl<_Usage>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$UsageToJson(this,);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _Usage &&
            (identical(other.promptTokens, promptTokens) ||
                other.promptTokens == promptTokens) &&
            (identical(other.completionTokens, completionTokens) ||
                other.completionTokens == completionTokens) &&
            (identical(other.totalTokens, totalTokens) ||
                other.totalTokens == totalTokens));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, promptTokens, completionTokens, totalTokens);

  @override
  String toString() {
    return 'Usage(promptTokens: $promptTokens, completionTokens: $completionTokens, totalTokens: $totalTokens)';
  }


}

/// @nodoc
abstract mixin class _$UsageCopyWith<$Res> implements $UsageCopyWith<$Res> {
  factory _$UsageCopyWith(_Usage value,
      $Res Function(_Usage) _then) = __$UsageCopyWithImpl;

  @override
  @useResult
  $Res call({
    @JsonKey(name: 'PromptTokens') int? promptTokens, @JsonKey(
        name: 'CompletionTokens') int? completionTokens, @JsonKey(
        name: 'TotalTokens') int? totalTokens
  });


}

/// @nodoc
class __$UsageCopyWithImpl<$Res>
    implements _$UsageCopyWith<$Res> {
  __$UsageCopyWithImpl(this._self, this._then);

  final _Usage _self;
  final $Res Function(_Usage) _then;

  /// Create a copy of Usage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call(
      {Object? promptTokens = freezed, Object? completionTokens = freezed, Object? totalTokens = freezed,}) {
    return _then(_Usage(
      promptTokens: freezed == promptTokens
          ? _self.promptTokens
          : promptTokens // ignore: cast_nullable_to_non_nullable
      as int?,
      completionTokens: freezed == completionTokens
          ? _self.completionTokens
          : completionTokens // ignore: cast_nullable_to_non_nullable
      as int?,
      totalTokens: freezed == totalTokens
          ? _self.totalTokens
          : totalTokens // ignore: cast_nullable_to_non_nullable
      as int?,
    ));
  }


}


/// @nodoc
mixin _$Choices {

  @JsonKey(name: 'FinishReason') String? get finishReason;

  @JsonKey(name: 'Delta') Delta? get delta;

  /// Create a copy of Choices
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ChoicesCopyWith<Choices> get copyWith =>
      _$ChoicesCopyWithImpl<Choices>(this as Choices, _$identity);

  /// Serializes this Choices to a JSON map.
  Map<String, dynamic> toJson();


  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is Choices &&
            (identical(other.finishReason, finishReason) ||
                other.finishReason == finishReason) &&
            (identical(other.delta, delta) || other.delta == delta));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, finishReason, delta);

  @override
  String toString() {
    return 'Choices(finishReason: $finishReason, delta: $delta)';
  }


}

/// @nodoc
abstract mixin class $ChoicesCopyWith<$Res> {
  factory $ChoicesCopyWith(Choices value,
      $Res Function(Choices) _then) = _$ChoicesCopyWithImpl;

  @useResult
  $Res call({
    @JsonKey(name: 'FinishReason') String? finishReason, @JsonKey(
        name: 'Delta') Delta? delta
  });


  $DeltaCopyWith<$Res>? get delta;

}

/// @nodoc
class _$ChoicesCopyWithImpl<$Res>
    implements $ChoicesCopyWith<$Res> {
  _$ChoicesCopyWithImpl(this._self, this._then);

  final Choices _self;
  final $Res Function(Choices) _then;

  /// Create a copy of Choices
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? finishReason = freezed, Object? delta = freezed,}) {
    return _then(_self.copyWith(
      finishReason: freezed == finishReason
          ? _self.finishReason
          : finishReason // ignore: cast_nullable_to_non_nullable
      as String?,
      delta: freezed == delta
          ? _self.delta
          : delta // ignore: cast_nullable_to_non_nullable
      as Delta?,
    ));
  }

  /// Create a copy of Choices
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $DeltaCopyWith<$Res>? get delta {
    if (_self.delta == null) {
      return null;
    }

    return $DeltaCopyWith<$Res>(_self.delta!, (value) {
      return _then(_self.copyWith(delta: value));
    });
  }
}


/// @nodoc
@JsonSerializable()
class _Choices implements Choices {
  const _Choices({@JsonKey(name: 'FinishReason') this.finishReason, @JsonKey(
      name: 'Delta') this.delta});

  factory _Choices.fromJson(Map<String, dynamic> json) =>
      _$ChoicesFromJson(json);

  @override
  @JsonKey(name: 'FinishReason')
  final String? finishReason;
  @override
  @JsonKey(name: 'Delta')
  final Delta? delta;

  /// Create a copy of Choices
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ChoicesCopyWith<_Choices> get copyWith =>
      __$ChoicesCopyWithImpl<_Choices>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ChoicesToJson(this,);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _Choices &&
            (identical(other.finishReason, finishReason) ||
                other.finishReason == finishReason) &&
            (identical(other.delta, delta) || other.delta == delta));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, finishReason, delta);

  @override
  String toString() {
    return 'Choices(finishReason: $finishReason, delta: $delta)';
  }


}

/// @nodoc
abstract mixin class _$ChoicesCopyWith<$Res> implements $ChoicesCopyWith<$Res> {
  factory _$ChoicesCopyWith(_Choices value,
      $Res Function(_Choices) _then) = __$ChoicesCopyWithImpl;

  @override
  @useResult
  $Res call({
    @JsonKey(name: 'FinishReason') String? finishReason, @JsonKey(
        name: 'Delta') Delta? delta
  });


  @override $DeltaCopyWith<$Res>? get delta;

}

/// @nodoc
class __$ChoicesCopyWithImpl<$Res>
    implements _$ChoicesCopyWith<$Res> {
  __$ChoicesCopyWithImpl(this._self, this._then);

  final _Choices _self;
  final $Res Function(_Choices) _then;

  /// Create a copy of Choices
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({Object? finishReason = freezed, Object? delta = freezed,}) {
    return _then(_Choices(
      finishReason: freezed == finishReason
          ? _self.finishReason
          : finishReason // ignore: cast_nullable_to_non_nullable
      as String?,
      delta: freezed == delta
          ? _self.delta
          : delta // ignore: cast_nullable_to_non_nullable
      as Delta?,
    ));
  }

  /// Create a copy of Choices
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $DeltaCopyWith<$Res>? get delta {
    if (_self.delta == null) {
      return null;
    }

    return $DeltaCopyWith<$Res>(_self.delta!, (value) {
      return _then(_self.copyWith(delta: value));
    });
  }
}


/// @nodoc
mixin _$Delta {

  @JsonKey(name: 'Role') String? get role;

  @JsonKey(name: 'Content') String? get content;

  /// Create a copy of Delta
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $DeltaCopyWith<Delta> get copyWith =>
      _$DeltaCopyWithImpl<Delta>(this as Delta, _$identity);

  /// Serializes this Delta to a JSON map.
  Map<String, dynamic> toJson();


  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is Delta &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.content, content) || other.content == content));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, role, content);

  @override
  String toString() {
    return 'Delta(role: $role, content: $content)';
  }


}

/// @nodoc
abstract mixin class $DeltaCopyWith<$Res> {
  factory $DeltaCopyWith(Delta value,
      $Res Function(Delta) _then) = _$DeltaCopyWithImpl;

  @useResult
  $Res call({
    @JsonKey(name: 'Role') String? role, @JsonKey(
        name: 'Content') String? content
  });


}

/// @nodoc
class _$DeltaCopyWithImpl<$Res>
    implements $DeltaCopyWith<$Res> {
  _$DeltaCopyWithImpl(this._self, this._then);

  final Delta _self;
  final $Res Function(Delta) _then;

  /// Create a copy of Delta
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? role = freezed, Object? content = freezed,}) {
    return _then(_self.copyWith(
      role: freezed == role
          ? _self.role
          : role // ignore: cast_nullable_to_non_nullable
      as String?,
      content: freezed == content
          ? _self.content
          : content // ignore: cast_nullable_to_non_nullable
      as String?,
    ));
  }

}


/// @nodoc
@JsonSerializable()
class _Delta implements Delta {
  const _Delta({@JsonKey(name: 'Role') this.role, @JsonKey(
      name: 'Content') this.content});

  factory _Delta.fromJson(Map<String, dynamic> json) => _$DeltaFromJson(json);

  @override
  @JsonKey(name: 'Role')
  final String? role;
  @override
  @JsonKey(name: 'Content')
  final String? content;

  /// Create a copy of Delta
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$DeltaCopyWith<_Delta> get copyWith =>
      __$DeltaCopyWithImpl<_Delta>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$DeltaToJson(this,);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _Delta &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.content, content) || other.content == content));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, role, content);

  @override
  String toString() {
    return 'Delta(role: $role, content: $content)';
  }


}

/// @nodoc
abstract mixin class _$DeltaCopyWith<$Res> implements $DeltaCopyWith<$Res> {
  factory _$DeltaCopyWith(_Delta value,
      $Res Function(_Delta) _then) = __$DeltaCopyWithImpl;

  @override
  @useResult
  $Res call({
    @JsonKey(name: 'Role') String? role, @JsonKey(
        name: 'Content') String? content
  });


}

/// @nodoc
class __$DeltaCopyWithImpl<$Res>
    implements _$DeltaCopyWith<$Res> {
  __$DeltaCopyWithImpl(this._self, this._then);

  final _Delta _self;
  final $Res Function(_Delta) _then;

  /// Create a copy of Delta
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({Object? role = freezed, Object? content = freezed,}) {
    return _then(_Delta(
      role: freezed == role
          ? _self.role
          : role // ignore: cast_nullable_to_non_nullable
      as String?,
      content: freezed == content
          ? _self.content
          : content // ignore: cast_nullable_to_non_nullable
      as String?,
    ));
  }


}

// dart format on

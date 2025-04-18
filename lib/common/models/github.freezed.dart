// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'github.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$GithubRelease {

  String? get url;

  @JsonKey(name: 'assets_url') String? get assetsUrl;

  @JsonKey(name: 'upload_url') String? get uploadUrl;

  @JsonKey(name: 'html_url') String? get htmlUrl;

  int? get id;

  Author? get author;

  @JsonKey(name: 'node_id') String? get nodeId;

  @JsonKey(name: 'tag_name') String? get tagName;

  @JsonKey(name: 'target_commitish') String? get targetCommitish;

  String? get name;

  bool? get draft;

  bool? get prerelease;

  @JsonKey(name: 'created_at') String? get createdAt;

  @JsonKey(name: 'published_at') String? get publishedAt;

  List<Assets>? get assets;

  @JsonKey(name: 'tarball_url') String? get tarballUrl;

  @JsonKey(name: 'zipball_url') String? get zipballUrl;

  String? get body;

  /// Create a copy of GithubRelease
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $GithubReleaseCopyWith<GithubRelease> get copyWith =>
      _$GithubReleaseCopyWithImpl<GithubRelease>(
          this as GithubRelease, _$identity);

  /// Serializes this GithubRelease to a JSON map.
  Map<String, dynamic> toJson();


  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is GithubRelease &&
            (identical(other.url, url) || other.url == url) &&
            (identical(other.assetsUrl, assetsUrl) ||
                other.assetsUrl == assetsUrl) &&
            (identical(other.uploadUrl, uploadUrl) ||
                other.uploadUrl == uploadUrl) &&
            (identical(other.htmlUrl, htmlUrl) || other.htmlUrl == htmlUrl) &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.author, author) || other.author == author) &&
            (identical(other.nodeId, nodeId) || other.nodeId == nodeId) &&
            (identical(other.tagName, tagName) || other.tagName == tagName) &&
            (identical(other.targetCommitish, targetCommitish) ||
                other.targetCommitish == targetCommitish) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.draft, draft) || other.draft == draft) &&
            (identical(other.prerelease, prerelease) ||
                other.prerelease == prerelease) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.publishedAt, publishedAt) ||
                other.publishedAt == publishedAt) &&
            const DeepCollectionEquality().equals(other.assets, assets) &&
            (identical(other.tarballUrl, tarballUrl) ||
                other.tarballUrl == tarballUrl) &&
            (identical(other.zipballUrl, zipballUrl) ||
                other.zipballUrl == zipballUrl) &&
            (identical(other.body, body) || other.body == body));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(
          runtimeType,
          url,
          assetsUrl,
          uploadUrl,
          htmlUrl,
          id,
          author,
          nodeId,
          tagName,
          targetCommitish,
          name,
          draft,
          prerelease,
          createdAt,
          publishedAt,
          const DeepCollectionEquality().hash(assets),
          tarballUrl,
          zipballUrl,
          body);

  @override
  String toString() {
    return 'GithubRelease(url: $url, assetsUrl: $assetsUrl, uploadUrl: $uploadUrl, htmlUrl: $htmlUrl, id: $id, author: $author, nodeId: $nodeId, tagName: $tagName, targetCommitish: $targetCommitish, name: $name, draft: $draft, prerelease: $prerelease, createdAt: $createdAt, publishedAt: $publishedAt, assets: $assets, tarballUrl: $tarballUrl, zipballUrl: $zipballUrl, body: $body)';
  }


}

/// @nodoc
abstract mixin class $GithubReleaseCopyWith<$Res> {
  factory $GithubReleaseCopyWith(GithubRelease value,
      $Res Function(GithubRelease) _then) = _$GithubReleaseCopyWithImpl;

  @useResult
  $Res call({
    String? url, @JsonKey(name: 'assets_url') String? assetsUrl, @JsonKey(
        name: 'upload_url') String? uploadUrl, @JsonKey(
        name: 'html_url') String? htmlUrl, int? id, Author? author, @JsonKey(
        name: 'node_id') String? nodeId, @JsonKey(
        name: 'tag_name') String? tagName, @JsonKey(
        name: 'target_commitish') String? targetCommitish, String? name, bool? draft, bool? prerelease, @JsonKey(
        name: 'created_at') String? createdAt, @JsonKey(
        name: 'published_at') String? publishedAt, List<
        Assets>? assets, @JsonKey(
        name: 'tarball_url') String? tarballUrl, @JsonKey(
        name: 'zipball_url') String? zipballUrl, String? body
  });


  $AuthorCopyWith<$Res>? get author;

}

/// @nodoc
class _$GithubReleaseCopyWithImpl<$Res>
    implements $GithubReleaseCopyWith<$Res> {
  _$GithubReleaseCopyWithImpl(this._self, this._then);

  final GithubRelease _self;
  final $Res Function(GithubRelease) _then;

  /// Create a copy of GithubRelease
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call(
      {Object? url = freezed, Object? assetsUrl = freezed, Object? uploadUrl = freezed, Object? htmlUrl = freezed, Object? id = freezed, Object? author = freezed, Object? nodeId = freezed, Object? tagName = freezed, Object? targetCommitish = freezed, Object? name = freezed, Object? draft = freezed, Object? prerelease = freezed, Object? createdAt = freezed, Object? publishedAt = freezed, Object? assets = freezed, Object? tarballUrl = freezed, Object? zipballUrl = freezed, Object? body = freezed,}) {
    return _then(_self.copyWith(
      url: freezed == url
          ? _self.url
          : url // ignore: cast_nullable_to_non_nullable
      as String?,
      assetsUrl: freezed == assetsUrl
          ? _self.assetsUrl
          : assetsUrl // ignore: cast_nullable_to_non_nullable
      as String?,
      uploadUrl: freezed == uploadUrl
          ? _self.uploadUrl
          : uploadUrl // ignore: cast_nullable_to_non_nullable
      as String?,
      htmlUrl: freezed == htmlUrl
          ? _self.htmlUrl
          : htmlUrl // ignore: cast_nullable_to_non_nullable
      as String?,
      id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
      as int?,
      author: freezed == author
          ? _self.author
          : author // ignore: cast_nullable_to_non_nullable
      as Author?,
      nodeId: freezed == nodeId
          ? _self.nodeId
          : nodeId // ignore: cast_nullable_to_non_nullable
      as String?,
      tagName: freezed == tagName
          ? _self.tagName
          : tagName // ignore: cast_nullable_to_non_nullable
      as String?,
      targetCommitish: freezed == targetCommitish
          ? _self.targetCommitish
          : targetCommitish // ignore: cast_nullable_to_non_nullable
      as String?,
      name: freezed == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
      as String?,
      draft: freezed == draft
          ? _self.draft
          : draft // ignore: cast_nullable_to_non_nullable
      as bool?,
      prerelease: freezed == prerelease
          ? _self.prerelease
          : prerelease // ignore: cast_nullable_to_non_nullable
      as bool?,
      createdAt: freezed == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
      as String?,
      publishedAt: freezed == publishedAt
          ? _self.publishedAt
          : publishedAt // ignore: cast_nullable_to_non_nullable
      as String?,
      assets: freezed == assets
          ? _self.assets
          : assets // ignore: cast_nullable_to_non_nullable
      as List<Assets>?,
      tarballUrl: freezed == tarballUrl
          ? _self.tarballUrl
          : tarballUrl // ignore: cast_nullable_to_non_nullable
      as String?,
      zipballUrl: freezed == zipballUrl
          ? _self.zipballUrl
          : zipballUrl // ignore: cast_nullable_to_non_nullable
      as String?,
      body: freezed == body
          ? _self.body
          : body // ignore: cast_nullable_to_non_nullable
      as String?,
    ));
  }

  /// Create a copy of GithubRelease
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $AuthorCopyWith<$Res>? get author {
    if (_self.author == null) {
      return null;
    }

    return $AuthorCopyWith<$Res>(_self.author!, (value) {
      return _then(_self.copyWith(author: value));
    });
  }
}


/// @nodoc
@JsonSerializable()
class _GithubRelease implements GithubRelease {
  const _GithubRelease(
      {this.url, @JsonKey(name: 'assets_url') this.assetsUrl, @JsonKey(
          name: 'upload_url') this.uploadUrl, @JsonKey(
          name: 'html_url') this.htmlUrl, this.id, this.author, @JsonKey(
          name: 'node_id') this.nodeId, @JsonKey(
          name: 'tag_name') this.tagName, @JsonKey(
          name: 'target_commitish') this.targetCommitish, this.name, this.draft, this.prerelease, @JsonKey(
          name: 'created_at') this.createdAt, @JsonKey(
          name: 'published_at') this.publishedAt, final List<
          Assets>? assets, @JsonKey(
          name: 'tarball_url') this.tarballUrl, @JsonKey(
          name: 'zipball_url') this.zipballUrl, this.body}) : _assets = assets;

  factory _GithubRelease.fromJson(Map<String, dynamic> json) =>
      _$GithubReleaseFromJson(json);

  @override final String? url;
  @override
  @JsonKey(name: 'assets_url')
  final String? assetsUrl;
  @override
  @JsonKey(name: 'upload_url')
  final String? uploadUrl;
  @override
  @JsonKey(name: 'html_url')
  final String? htmlUrl;
  @override final int? id;
  @override final Author? author;
  @override
  @JsonKey(name: 'node_id')
  final String? nodeId;
  @override
  @JsonKey(name: 'tag_name')
  final String? tagName;
  @override
  @JsonKey(name: 'target_commitish')
  final String? targetCommitish;
  @override final String? name;
  @override final bool? draft;
  @override final bool? prerelease;
  @override
  @JsonKey(name: 'created_at')
  final String? createdAt;
  @override
  @JsonKey(name: 'published_at')
  final String? publishedAt;
  final List<Assets>? _assets;

  @override List<Assets>? get assets {
    final value = _assets;
    if (value == null) return null;
    if (_assets is EqualUnmodifiableListView) return _assets;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  @JsonKey(name: 'tarball_url')
  final String? tarballUrl;
  @override
  @JsonKey(name: 'zipball_url')
  final String? zipballUrl;
  @override final String? body;

  /// Create a copy of GithubRelease
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$GithubReleaseCopyWith<_GithubRelease> get copyWith =>
      __$GithubReleaseCopyWithImpl<_GithubRelease>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$GithubReleaseToJson(this,);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _GithubRelease &&
            (identical(other.url, url) || other.url == url) &&
            (identical(other.assetsUrl, assetsUrl) ||
                other.assetsUrl == assetsUrl) &&
            (identical(other.uploadUrl, uploadUrl) ||
                other.uploadUrl == uploadUrl) &&
            (identical(other.htmlUrl, htmlUrl) || other.htmlUrl == htmlUrl) &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.author, author) || other.author == author) &&
            (identical(other.nodeId, nodeId) || other.nodeId == nodeId) &&
            (identical(other.tagName, tagName) || other.tagName == tagName) &&
            (identical(other.targetCommitish, targetCommitish) ||
                other.targetCommitish == targetCommitish) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.draft, draft) || other.draft == draft) &&
            (identical(other.prerelease, prerelease) ||
                other.prerelease == prerelease) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.publishedAt, publishedAt) ||
                other.publishedAt == publishedAt) &&
            const DeepCollectionEquality().equals(other._assets, _assets) &&
            (identical(other.tarballUrl, tarballUrl) ||
                other.tarballUrl == tarballUrl) &&
            (identical(other.zipballUrl, zipballUrl) ||
                other.zipballUrl == zipballUrl) &&
            (identical(other.body, body) || other.body == body));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(
          runtimeType,
          url,
          assetsUrl,
          uploadUrl,
          htmlUrl,
          id,
          author,
          nodeId,
          tagName,
          targetCommitish,
          name,
          draft,
          prerelease,
          createdAt,
          publishedAt,
          const DeepCollectionEquality().hash(_assets),
          tarballUrl,
          zipballUrl,
          body);

  @override
  String toString() {
    return 'GithubRelease(url: $url, assetsUrl: $assetsUrl, uploadUrl: $uploadUrl, htmlUrl: $htmlUrl, id: $id, author: $author, nodeId: $nodeId, tagName: $tagName, targetCommitish: $targetCommitish, name: $name, draft: $draft, prerelease: $prerelease, createdAt: $createdAt, publishedAt: $publishedAt, assets: $assets, tarballUrl: $tarballUrl, zipballUrl: $zipballUrl, body: $body)';
  }


}

/// @nodoc
abstract mixin class _$GithubReleaseCopyWith<$Res>
    implements $GithubReleaseCopyWith<$Res> {
  factory _$GithubReleaseCopyWith(_GithubRelease value,
      $Res Function(_GithubRelease) _then) = __$GithubReleaseCopyWithImpl;

  @override
  @useResult
  $Res call({
    String? url, @JsonKey(name: 'assets_url') String? assetsUrl, @JsonKey(
        name: 'upload_url') String? uploadUrl, @JsonKey(
        name: 'html_url') String? htmlUrl, int? id, Author? author, @JsonKey(
        name: 'node_id') String? nodeId, @JsonKey(
        name: 'tag_name') String? tagName, @JsonKey(
        name: 'target_commitish') String? targetCommitish, String? name, bool? draft, bool? prerelease, @JsonKey(
        name: 'created_at') String? createdAt, @JsonKey(
        name: 'published_at') String? publishedAt, List<
        Assets>? assets, @JsonKey(
        name: 'tarball_url') String? tarballUrl, @JsonKey(
        name: 'zipball_url') String? zipballUrl, String? body
  });


  @override $AuthorCopyWith<$Res>? get author;

}

/// @nodoc
class __$GithubReleaseCopyWithImpl<$Res>
    implements _$GithubReleaseCopyWith<$Res> {
  __$GithubReleaseCopyWithImpl(this._self, this._then);

  final _GithubRelease _self;
  final $Res Function(_GithubRelease) _then;

  /// Create a copy of GithubRelease
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call(
      {Object? url = freezed, Object? assetsUrl = freezed, Object? uploadUrl = freezed, Object? htmlUrl = freezed, Object? id = freezed, Object? author = freezed, Object? nodeId = freezed, Object? tagName = freezed, Object? targetCommitish = freezed, Object? name = freezed, Object? draft = freezed, Object? prerelease = freezed, Object? createdAt = freezed, Object? publishedAt = freezed, Object? assets = freezed, Object? tarballUrl = freezed, Object? zipballUrl = freezed, Object? body = freezed,}) {
    return _then(_GithubRelease(
      url: freezed == url
          ? _self.url
          : url // ignore: cast_nullable_to_non_nullable
      as String?,
      assetsUrl: freezed == assetsUrl
          ? _self.assetsUrl
          : assetsUrl // ignore: cast_nullable_to_non_nullable
      as String?,
      uploadUrl: freezed == uploadUrl
          ? _self.uploadUrl
          : uploadUrl // ignore: cast_nullable_to_non_nullable
      as String?,
      htmlUrl: freezed == htmlUrl
          ? _self.htmlUrl
          : htmlUrl // ignore: cast_nullable_to_non_nullable
      as String?,
      id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
      as int?,
      author: freezed == author
          ? _self.author
          : author // ignore: cast_nullable_to_non_nullable
      as Author?,
      nodeId: freezed == nodeId
          ? _self.nodeId
          : nodeId // ignore: cast_nullable_to_non_nullable
      as String?,
      tagName: freezed == tagName
          ? _self.tagName
          : tagName // ignore: cast_nullable_to_non_nullable
      as String?,
      targetCommitish: freezed == targetCommitish
          ? _self.targetCommitish
          : targetCommitish // ignore: cast_nullable_to_non_nullable
      as String?,
      name: freezed == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
      as String?,
      draft: freezed == draft
          ? _self.draft
          : draft // ignore: cast_nullable_to_non_nullable
      as bool?,
      prerelease: freezed == prerelease
          ? _self.prerelease
          : prerelease // ignore: cast_nullable_to_non_nullable
      as bool?,
      createdAt: freezed == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
      as String?,
      publishedAt: freezed == publishedAt
          ? _self.publishedAt
          : publishedAt // ignore: cast_nullable_to_non_nullable
      as String?,
      assets: freezed == assets
          ? _self._assets
          : assets // ignore: cast_nullable_to_non_nullable
      as List<Assets>?,
      tarballUrl: freezed == tarballUrl
          ? _self.tarballUrl
          : tarballUrl // ignore: cast_nullable_to_non_nullable
      as String?,
      zipballUrl: freezed == zipballUrl
          ? _self.zipballUrl
          : zipballUrl // ignore: cast_nullable_to_non_nullable
      as String?,
      body: freezed == body
          ? _self.body
          : body // ignore: cast_nullable_to_non_nullable
      as String?,
    ));
  }

  /// Create a copy of GithubRelease
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $AuthorCopyWith<$Res>? get author {
    if (_self.author == null) {
      return null;
    }

    return $AuthorCopyWith<$Res>(_self.author!, (value) {
      return _then(_self.copyWith(author: value));
    });
  }
}


/// @nodoc
mixin _$Assets {

  String? get url;

  int? get id;

  @JsonKey(name: 'node_id') String? get nodeId;

  String? get name;

  dynamic get label;

  Uploader? get uploader;

  @JsonKey(name: 'content_type') String? get contentType;

  String? get state;

  int? get size;

  @JsonKey(name: 'download_count') int? get downloadCount;

  @JsonKey(name: 'created_at') String? get createdAt;

  @JsonKey(name: 'updated_at') String? get updatedAt;

  @JsonKey(name: 'browser_download_url') String? get browserDownloadUrl;

  /// Create a copy of Assets
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AssetsCopyWith<Assets> get copyWith =>
      _$AssetsCopyWithImpl<Assets>(this as Assets, _$identity);

  /// Serializes this Assets to a JSON map.
  Map<String, dynamic> toJson();


  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is Assets &&
            (identical(other.url, url) || other.url == url) &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.nodeId, nodeId) || other.nodeId == nodeId) &&
            (identical(other.name, name) || other.name == name) &&
            const DeepCollectionEquality().equals(other.label, label) &&
            (identical(other.uploader, uploader) ||
                other.uploader == uploader) &&
            (identical(other.contentType, contentType) ||
                other.contentType == contentType) &&
            (identical(other.state, state) || other.state == state) &&
            (identical(other.size, size) || other.size == size) &&
            (identical(other.downloadCount, downloadCount) ||
                other.downloadCount == downloadCount) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.browserDownloadUrl, browserDownloadUrl) ||
                other.browserDownloadUrl == browserDownloadUrl));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(
          runtimeType,
          url,
          id,
          nodeId,
          name,
          const DeepCollectionEquality().hash(label),
          uploader,
          contentType,
          state,
          size,
          downloadCount,
          createdAt,
          updatedAt,
          browserDownloadUrl);

  @override
  String toString() {
    return 'Assets(url: $url, id: $id, nodeId: $nodeId, name: $name, label: $label, uploader: $uploader, contentType: $contentType, state: $state, size: $size, downloadCount: $downloadCount, createdAt: $createdAt, updatedAt: $updatedAt, browserDownloadUrl: $browserDownloadUrl)';
  }


}

/// @nodoc
abstract mixin class $AssetsCopyWith<$Res> {
  factory $AssetsCopyWith(Assets value,
      $Res Function(Assets) _then) = _$AssetsCopyWithImpl;

  @useResult
  $Res call({
    String? url, int? id, @JsonKey(
        name: 'node_id') String? nodeId, String? name, dynamic label, Uploader? uploader, @JsonKey(
        name: 'content_type') String? contentType, String? state, int? size, @JsonKey(
        name: 'download_count') int? downloadCount, @JsonKey(
        name: 'created_at') String? createdAt, @JsonKey(
        name: 'updated_at') String? updatedAt, @JsonKey(
        name: 'browser_download_url') String? browserDownloadUrl
  });


  $UploaderCopyWith<$Res>? get uploader;

}

/// @nodoc
class _$AssetsCopyWithImpl<$Res>
    implements $AssetsCopyWith<$Res> {
  _$AssetsCopyWithImpl(this._self, this._then);

  final Assets _self;
  final $Res Function(Assets) _then;

  /// Create a copy of Assets
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call(
      {Object? url = freezed, Object? id = freezed, Object? nodeId = freezed, Object? name = freezed, Object? label = freezed, Object? uploader = freezed, Object? contentType = freezed, Object? state = freezed, Object? size = freezed, Object? downloadCount = freezed, Object? createdAt = freezed, Object? updatedAt = freezed, Object? browserDownloadUrl = freezed,}) {
    return _then(_self.copyWith(
      url: freezed == url
          ? _self.url
          : url // ignore: cast_nullable_to_non_nullable
      as String?,
      id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
      as int?,
      nodeId: freezed == nodeId
          ? _self.nodeId
          : nodeId // ignore: cast_nullable_to_non_nullable
      as String?,
      name: freezed == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
      as String?,
      label: freezed == label
          ? _self.label
          : label // ignore: cast_nullable_to_non_nullable
      as dynamic,
      uploader: freezed == uploader
          ? _self.uploader
          : uploader // ignore: cast_nullable_to_non_nullable
      as Uploader?,
      contentType: freezed == contentType
          ? _self.contentType
          : contentType // ignore: cast_nullable_to_non_nullable
      as String?,
      state: freezed == state
          ? _self.state
          : state // ignore: cast_nullable_to_non_nullable
      as String?,
      size: freezed == size
          ? _self.size
          : size // ignore: cast_nullable_to_non_nullable
      as int?,
      downloadCount: freezed == downloadCount
          ? _self.downloadCount
          : downloadCount // ignore: cast_nullable_to_non_nullable
      as int?,
      createdAt: freezed == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
      as String?,
      updatedAt: freezed == updatedAt
          ? _self.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
      as String?,
      browserDownloadUrl: freezed == browserDownloadUrl
          ? _self.browserDownloadUrl
          : browserDownloadUrl // ignore: cast_nullable_to_non_nullable
      as String?,
    ));
  }

  /// Create a copy of Assets
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $UploaderCopyWith<$Res>? get uploader {
    if (_self.uploader == null) {
      return null;
    }

    return $UploaderCopyWith<$Res>(_self.uploader!, (value) {
      return _then(_self.copyWith(uploader: value));
    });
  }
}


/// @nodoc
@JsonSerializable()
class _Assets implements Assets {
  const _Assets({this.url, this.id, @JsonKey(
      name: 'node_id') this.nodeId, this.name, this.label, this.uploader, @JsonKey(
      name: 'content_type') this.contentType, this.state, this.size, @JsonKey(
      name: 'download_count') this.downloadCount, @JsonKey(
      name: 'created_at') this.createdAt, @JsonKey(
      name: 'updated_at') this.updatedAt, @JsonKey(
      name: 'browser_download_url') this.browserDownloadUrl});

  factory _Assets.fromJson(Map<String, dynamic> json) => _$AssetsFromJson(json);

  @override final String? url;
  @override final int? id;
  @override
  @JsonKey(name: 'node_id')
  final String? nodeId;
  @override final String? name;
  @override final dynamic label;
  @override final Uploader? uploader;
  @override
  @JsonKey(name: 'content_type')
  final String? contentType;
  @override final String? state;
  @override final int? size;
  @override
  @JsonKey(name: 'download_count')
  final int? downloadCount;
  @override
  @JsonKey(name: 'created_at')
  final String? createdAt;
  @override
  @JsonKey(name: 'updated_at')
  final String? updatedAt;
  @override
  @JsonKey(name: 'browser_download_url')
  final String? browserDownloadUrl;

  /// Create a copy of Assets
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$AssetsCopyWith<_Assets> get copyWith =>
      __$AssetsCopyWithImpl<_Assets>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$AssetsToJson(this,);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _Assets &&
            (identical(other.url, url) || other.url == url) &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.nodeId, nodeId) || other.nodeId == nodeId) &&
            (identical(other.name, name) || other.name == name) &&
            const DeepCollectionEquality().equals(other.label, label) &&
            (identical(other.uploader, uploader) ||
                other.uploader == uploader) &&
            (identical(other.contentType, contentType) ||
                other.contentType == contentType) &&
            (identical(other.state, state) || other.state == state) &&
            (identical(other.size, size) || other.size == size) &&
            (identical(other.downloadCount, downloadCount) ||
                other.downloadCount == downloadCount) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.browserDownloadUrl, browserDownloadUrl) ||
                other.browserDownloadUrl == browserDownloadUrl));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(
          runtimeType,
          url,
          id,
          nodeId,
          name,
          const DeepCollectionEquality().hash(label),
          uploader,
          contentType,
          state,
          size,
          downloadCount,
          createdAt,
          updatedAt,
          browserDownloadUrl);

  @override
  String toString() {
    return 'Assets(url: $url, id: $id, nodeId: $nodeId, name: $name, label: $label, uploader: $uploader, contentType: $contentType, state: $state, size: $size, downloadCount: $downloadCount, createdAt: $createdAt, updatedAt: $updatedAt, browserDownloadUrl: $browserDownloadUrl)';
  }


}

/// @nodoc
abstract mixin class _$AssetsCopyWith<$Res> implements $AssetsCopyWith<$Res> {
  factory _$AssetsCopyWith(_Assets value,
      $Res Function(_Assets) _then) = __$AssetsCopyWithImpl;

  @override
  @useResult
  $Res call({
    String? url, int? id, @JsonKey(
        name: 'node_id') String? nodeId, String? name, dynamic label, Uploader? uploader, @JsonKey(
        name: 'content_type') String? contentType, String? state, int? size, @JsonKey(
        name: 'download_count') int? downloadCount, @JsonKey(
        name: 'created_at') String? createdAt, @JsonKey(
        name: 'updated_at') String? updatedAt, @JsonKey(
        name: 'browser_download_url') String? browserDownloadUrl
  });


  @override $UploaderCopyWith<$Res>? get uploader;

}

/// @nodoc
class __$AssetsCopyWithImpl<$Res>
    implements _$AssetsCopyWith<$Res> {
  __$AssetsCopyWithImpl(this._self, this._then);

  final _Assets _self;
  final $Res Function(_Assets) _then;

  /// Create a copy of Assets
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call(
      {Object? url = freezed, Object? id = freezed, Object? nodeId = freezed, Object? name = freezed, Object? label = freezed, Object? uploader = freezed, Object? contentType = freezed, Object? state = freezed, Object? size = freezed, Object? downloadCount = freezed, Object? createdAt = freezed, Object? updatedAt = freezed, Object? browserDownloadUrl = freezed,}) {
    return _then(_Assets(
      url: freezed == url
          ? _self.url
          : url // ignore: cast_nullable_to_non_nullable
      as String?,
      id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
      as int?,
      nodeId: freezed == nodeId
          ? _self.nodeId
          : nodeId // ignore: cast_nullable_to_non_nullable
      as String?,
      name: freezed == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
      as String?,
      label: freezed == label
          ? _self.label
          : label // ignore: cast_nullable_to_non_nullable
      as dynamic,
      uploader: freezed == uploader
          ? _self.uploader
          : uploader // ignore: cast_nullable_to_non_nullable
      as Uploader?,
      contentType: freezed == contentType
          ? _self.contentType
          : contentType // ignore: cast_nullable_to_non_nullable
      as String?,
      state: freezed == state
          ? _self.state
          : state // ignore: cast_nullable_to_non_nullable
      as String?,
      size: freezed == size
          ? _self.size
          : size // ignore: cast_nullable_to_non_nullable
      as int?,
      downloadCount: freezed == downloadCount
          ? _self.downloadCount
          : downloadCount // ignore: cast_nullable_to_non_nullable
      as int?,
      createdAt: freezed == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
      as String?,
      updatedAt: freezed == updatedAt
          ? _self.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
      as String?,
      browserDownloadUrl: freezed == browserDownloadUrl
          ? _self.browserDownloadUrl
          : browserDownloadUrl // ignore: cast_nullable_to_non_nullable
      as String?,
    ));
  }

  /// Create a copy of Assets
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $UploaderCopyWith<$Res>? get uploader {
    if (_self.uploader == null) {
      return null;
    }

    return $UploaderCopyWith<$Res>(_self.uploader!, (value) {
      return _then(_self.copyWith(uploader: value));
    });
  }
}


/// @nodoc
mixin _$Uploader {

  String? get login;

  int? get id;

  @JsonKey(name: 'node_id') String? get nodeId;

  @JsonKey(name: 'avatar_url') String? get avatarUrl;

  @JsonKey(name: 'gravatar_id') String? get gravatarId;

  String? get url;

  @JsonKey(name: 'html_url') String? get htmlUrl;

  @JsonKey(name: 'followers_url') String? get followersUrl;

  @JsonKey(name: 'following_url') String? get followingUrl;

  @JsonKey(name: 'gists_url') String? get gistsUrl;

  @JsonKey(name: 'starred_url') String? get starredUrl;

  @JsonKey(name: 'subscriptions_url') String? get subscriptionsUrl;

  @JsonKey(name: 'organizations_url') String? get organizationsUrl;

  @JsonKey(name: 'repos_url') String? get reposUrl;

  @JsonKey(name: 'events_url') String? get eventsUrl;

  @JsonKey(name: 'received_events_url') String? get receivedEventsUrl;

  String? get type;

  @JsonKey(name: 'user_view_type') String? get userViewType;

  @JsonKey(name: 'site_admin') bool? get siteAdmin;

  /// Create a copy of Uploader
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $UploaderCopyWith<Uploader> get copyWith =>
      _$UploaderCopyWithImpl<Uploader>(this as Uploader, _$identity);

  /// Serializes this Uploader to a JSON map.
  Map<String, dynamic> toJson();


  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is Uploader &&
            (identical(other.login, login) || other.login == login) &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.nodeId, nodeId) || other.nodeId == nodeId) &&
            (identical(other.avatarUrl, avatarUrl) ||
                other.avatarUrl == avatarUrl) &&
            (identical(other.gravatarId, gravatarId) ||
                other.gravatarId == gravatarId) &&
            (identical(other.url, url) || other.url == url) &&
            (identical(other.htmlUrl, htmlUrl) || other.htmlUrl == htmlUrl) &&
            (identical(other.followersUrl, followersUrl) ||
                other.followersUrl == followersUrl) &&
            (identical(other.followingUrl, followingUrl) ||
                other.followingUrl == followingUrl) &&
            (identical(other.gistsUrl, gistsUrl) ||
                other.gistsUrl == gistsUrl) &&
            (identical(other.starredUrl, starredUrl) ||
                other.starredUrl == starredUrl) &&
            (identical(other.subscriptionsUrl, subscriptionsUrl) ||
                other.subscriptionsUrl == subscriptionsUrl) &&
            (identical(other.organizationsUrl, organizationsUrl) ||
                other.organizationsUrl == organizationsUrl) &&
            (identical(other.reposUrl, reposUrl) ||
                other.reposUrl == reposUrl) &&
            (identical(other.eventsUrl, eventsUrl) ||
                other.eventsUrl == eventsUrl) &&
            (identical(other.receivedEventsUrl, receivedEventsUrl) ||
                other.receivedEventsUrl == receivedEventsUrl) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.userViewType, userViewType) ||
                other.userViewType == userViewType) &&
            (identical(other.siteAdmin, siteAdmin) ||
                other.siteAdmin == siteAdmin));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hashAll([
        runtimeType,
        login,
        id,
        nodeId,
        avatarUrl,
        gravatarId,
        url,
        htmlUrl,
        followersUrl,
        followingUrl,
        gistsUrl,
        starredUrl,
        subscriptionsUrl,
        organizationsUrl,
        reposUrl,
        eventsUrl,
        receivedEventsUrl,
        type,
        userViewType,
        siteAdmin
      ]);

  @override
  String toString() {
    return 'Uploader(login: $login, id: $id, nodeId: $nodeId, avatarUrl: $avatarUrl, gravatarId: $gravatarId, url: $url, htmlUrl: $htmlUrl, followersUrl: $followersUrl, followingUrl: $followingUrl, gistsUrl: $gistsUrl, starredUrl: $starredUrl, subscriptionsUrl: $subscriptionsUrl, organizationsUrl: $organizationsUrl, reposUrl: $reposUrl, eventsUrl: $eventsUrl, receivedEventsUrl: $receivedEventsUrl, type: $type, userViewType: $userViewType, siteAdmin: $siteAdmin)';
  }


}

/// @nodoc
abstract mixin class $UploaderCopyWith<$Res> {
  factory $UploaderCopyWith(Uploader value,
      $Res Function(Uploader) _then) = _$UploaderCopyWithImpl;

  @useResult
  $Res call({
    String? login, int? id, @JsonKey(name: 'node_id') String? nodeId, @JsonKey(
        name: 'avatar_url') String? avatarUrl, @JsonKey(
        name: 'gravatar_id') String? gravatarId, String? url, @JsonKey(
        name: 'html_url') String? htmlUrl, @JsonKey(
        name: 'followers_url') String? followersUrl, @JsonKey(
        name: 'following_url') String? followingUrl, @JsonKey(
        name: 'gists_url') String? gistsUrl, @JsonKey(
        name: 'starred_url') String? starredUrl, @JsonKey(
        name: 'subscriptions_url') String? subscriptionsUrl, @JsonKey(
        name: 'organizations_url') String? organizationsUrl, @JsonKey(
        name: 'repos_url') String? reposUrl, @JsonKey(
        name: 'events_url') String? eventsUrl, @JsonKey(
        name: 'received_events_url') String? receivedEventsUrl, String? type, @JsonKey(
        name: 'user_view_type') String? userViewType, @JsonKey(
        name: 'site_admin') bool? siteAdmin
  });


}

/// @nodoc
class _$UploaderCopyWithImpl<$Res>
    implements $UploaderCopyWith<$Res> {
  _$UploaderCopyWithImpl(this._self, this._then);

  final Uploader _self;
  final $Res Function(Uploader) _then;

  /// Create a copy of Uploader
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call(
      {Object? login = freezed, Object? id = freezed, Object? nodeId = freezed, Object? avatarUrl = freezed, Object? gravatarId = freezed, Object? url = freezed, Object? htmlUrl = freezed, Object? followersUrl = freezed, Object? followingUrl = freezed, Object? gistsUrl = freezed, Object? starredUrl = freezed, Object? subscriptionsUrl = freezed, Object? organizationsUrl = freezed, Object? reposUrl = freezed, Object? eventsUrl = freezed, Object? receivedEventsUrl = freezed, Object? type = freezed, Object? userViewType = freezed, Object? siteAdmin = freezed,}) {
    return _then(_self.copyWith(
      login: freezed == login
          ? _self.login
          : login // ignore: cast_nullable_to_non_nullable
      as String?,
      id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
      as int?,
      nodeId: freezed == nodeId
          ? _self.nodeId
          : nodeId // ignore: cast_nullable_to_non_nullable
      as String?,
      avatarUrl: freezed == avatarUrl
          ? _self.avatarUrl
          : avatarUrl // ignore: cast_nullable_to_non_nullable
      as String?,
      gravatarId: freezed == gravatarId
          ? _self.gravatarId
          : gravatarId // ignore: cast_nullable_to_non_nullable
      as String?,
      url: freezed == url
          ? _self.url
          : url // ignore: cast_nullable_to_non_nullable
      as String?,
      htmlUrl: freezed == htmlUrl
          ? _self.htmlUrl
          : htmlUrl // ignore: cast_nullable_to_non_nullable
      as String?,
      followersUrl: freezed == followersUrl
          ? _self.followersUrl
          : followersUrl // ignore: cast_nullable_to_non_nullable
      as String?,
      followingUrl: freezed == followingUrl
          ? _self.followingUrl
          : followingUrl // ignore: cast_nullable_to_non_nullable
      as String?,
      gistsUrl: freezed == gistsUrl
          ? _self.gistsUrl
          : gistsUrl // ignore: cast_nullable_to_non_nullable
      as String?,
      starredUrl: freezed == starredUrl
          ? _self.starredUrl
          : starredUrl // ignore: cast_nullable_to_non_nullable
      as String?,
      subscriptionsUrl: freezed == subscriptionsUrl
          ? _self.subscriptionsUrl
          : subscriptionsUrl // ignore: cast_nullable_to_non_nullable
      as String?,
      organizationsUrl: freezed == organizationsUrl
          ? _self.organizationsUrl
          : organizationsUrl // ignore: cast_nullable_to_non_nullable
      as String?,
      reposUrl: freezed == reposUrl
          ? _self.reposUrl
          : reposUrl // ignore: cast_nullable_to_non_nullable
      as String?,
      eventsUrl: freezed == eventsUrl
          ? _self.eventsUrl
          : eventsUrl // ignore: cast_nullable_to_non_nullable
      as String?,
      receivedEventsUrl: freezed == receivedEventsUrl
          ? _self.receivedEventsUrl
          : receivedEventsUrl // ignore: cast_nullable_to_non_nullable
      as String?,
      type: freezed == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
      as String?,
      userViewType: freezed == userViewType
          ? _self.userViewType
          : userViewType // ignore: cast_nullable_to_non_nullable
      as String?,
      siteAdmin: freezed == siteAdmin
          ? _self.siteAdmin
          : siteAdmin // ignore: cast_nullable_to_non_nullable
      as bool?,
    ));
  }

}


/// @nodoc
@JsonSerializable()
class _Uploader implements Uploader {
  const _Uploader(
      {this.login, this.id, @JsonKey(name: 'node_id') this.nodeId, @JsonKey(
          name: 'avatar_url') this.avatarUrl, @JsonKey(
          name: 'gravatar_id') this.gravatarId, this.url, @JsonKey(
          name: 'html_url') this.htmlUrl, @JsonKey(
          name: 'followers_url') this.followersUrl, @JsonKey(
          name: 'following_url') this.followingUrl, @JsonKey(
          name: 'gists_url') this.gistsUrl, @JsonKey(
          name: 'starred_url') this.starredUrl, @JsonKey(
          name: 'subscriptions_url') this.subscriptionsUrl, @JsonKey(
          name: 'organizations_url') this.organizationsUrl, @JsonKey(
          name: 'repos_url') this.reposUrl, @JsonKey(
          name: 'events_url') this.eventsUrl, @JsonKey(
          name: 'received_events_url') this.receivedEventsUrl, this.type, @JsonKey(
          name: 'user_view_type') this.userViewType, @JsonKey(
          name: 'site_admin') this.siteAdmin});

  factory _Uploader.fromJson(Map<String, dynamic> json) =>
      _$UploaderFromJson(json);

  @override final String? login;
  @override final int? id;
  @override
  @JsonKey(name: 'node_id')
  final String? nodeId;
  @override
  @JsonKey(name: 'avatar_url')
  final String? avatarUrl;
  @override
  @JsonKey(name: 'gravatar_id')
  final String? gravatarId;
  @override final String? url;
  @override
  @JsonKey(name: 'html_url')
  final String? htmlUrl;
  @override
  @JsonKey(name: 'followers_url')
  final String? followersUrl;
  @override
  @JsonKey(name: 'following_url')
  final String? followingUrl;
  @override
  @JsonKey(name: 'gists_url')
  final String? gistsUrl;
  @override
  @JsonKey(name: 'starred_url')
  final String? starredUrl;
  @override
  @JsonKey(name: 'subscriptions_url')
  final String? subscriptionsUrl;
  @override
  @JsonKey(name: 'organizations_url')
  final String? organizationsUrl;
  @override
  @JsonKey(name: 'repos_url')
  final String? reposUrl;
  @override
  @JsonKey(name: 'events_url')
  final String? eventsUrl;
  @override
  @JsonKey(name: 'received_events_url')
  final String? receivedEventsUrl;
  @override final String? type;
  @override
  @JsonKey(name: 'user_view_type')
  final String? userViewType;
  @override
  @JsonKey(name: 'site_admin')
  final bool? siteAdmin;

  /// Create a copy of Uploader
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$UploaderCopyWith<_Uploader> get copyWith =>
      __$UploaderCopyWithImpl<_Uploader>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$UploaderToJson(this,);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _Uploader &&
            (identical(other.login, login) || other.login == login) &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.nodeId, nodeId) || other.nodeId == nodeId) &&
            (identical(other.avatarUrl, avatarUrl) ||
                other.avatarUrl == avatarUrl) &&
            (identical(other.gravatarId, gravatarId) ||
                other.gravatarId == gravatarId) &&
            (identical(other.url, url) || other.url == url) &&
            (identical(other.htmlUrl, htmlUrl) || other.htmlUrl == htmlUrl) &&
            (identical(other.followersUrl, followersUrl) ||
                other.followersUrl == followersUrl) &&
            (identical(other.followingUrl, followingUrl) ||
                other.followingUrl == followingUrl) &&
            (identical(other.gistsUrl, gistsUrl) ||
                other.gistsUrl == gistsUrl) &&
            (identical(other.starredUrl, starredUrl) ||
                other.starredUrl == starredUrl) &&
            (identical(other.subscriptionsUrl, subscriptionsUrl) ||
                other.subscriptionsUrl == subscriptionsUrl) &&
            (identical(other.organizationsUrl, organizationsUrl) ||
                other.organizationsUrl == organizationsUrl) &&
            (identical(other.reposUrl, reposUrl) ||
                other.reposUrl == reposUrl) &&
            (identical(other.eventsUrl, eventsUrl) ||
                other.eventsUrl == eventsUrl) &&
            (identical(other.receivedEventsUrl, receivedEventsUrl) ||
                other.receivedEventsUrl == receivedEventsUrl) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.userViewType, userViewType) ||
                other.userViewType == userViewType) &&
            (identical(other.siteAdmin, siteAdmin) ||
                other.siteAdmin == siteAdmin));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hashAll([
        runtimeType,
        login,
        id,
        nodeId,
        avatarUrl,
        gravatarId,
        url,
        htmlUrl,
        followersUrl,
        followingUrl,
        gistsUrl,
        starredUrl,
        subscriptionsUrl,
        organizationsUrl,
        reposUrl,
        eventsUrl,
        receivedEventsUrl,
        type,
        userViewType,
        siteAdmin
      ]);

  @override
  String toString() {
    return 'Uploader(login: $login, id: $id, nodeId: $nodeId, avatarUrl: $avatarUrl, gravatarId: $gravatarId, url: $url, htmlUrl: $htmlUrl, followersUrl: $followersUrl, followingUrl: $followingUrl, gistsUrl: $gistsUrl, starredUrl: $starredUrl, subscriptionsUrl: $subscriptionsUrl, organizationsUrl: $organizationsUrl, reposUrl: $reposUrl, eventsUrl: $eventsUrl, receivedEventsUrl: $receivedEventsUrl, type: $type, userViewType: $userViewType, siteAdmin: $siteAdmin)';
  }


}

/// @nodoc
abstract mixin class _$UploaderCopyWith<$Res>
    implements $UploaderCopyWith<$Res> {
  factory _$UploaderCopyWith(_Uploader value,
      $Res Function(_Uploader) _then) = __$UploaderCopyWithImpl;

  @override
  @useResult
  $Res call({
    String? login, int? id, @JsonKey(name: 'node_id') String? nodeId, @JsonKey(
        name: 'avatar_url') String? avatarUrl, @JsonKey(
        name: 'gravatar_id') String? gravatarId, String? url, @JsonKey(
        name: 'html_url') String? htmlUrl, @JsonKey(
        name: 'followers_url') String? followersUrl, @JsonKey(
        name: 'following_url') String? followingUrl, @JsonKey(
        name: 'gists_url') String? gistsUrl, @JsonKey(
        name: 'starred_url') String? starredUrl, @JsonKey(
        name: 'subscriptions_url') String? subscriptionsUrl, @JsonKey(
        name: 'organizations_url') String? organizationsUrl, @JsonKey(
        name: 'repos_url') String? reposUrl, @JsonKey(
        name: 'events_url') String? eventsUrl, @JsonKey(
        name: 'received_events_url') String? receivedEventsUrl, String? type, @JsonKey(
        name: 'user_view_type') String? userViewType, @JsonKey(
        name: 'site_admin') bool? siteAdmin
  });


}

/// @nodoc
class __$UploaderCopyWithImpl<$Res>
    implements _$UploaderCopyWith<$Res> {
  __$UploaderCopyWithImpl(this._self, this._then);

  final _Uploader _self;
  final $Res Function(_Uploader) _then;

  /// Create a copy of Uploader
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call(
      {Object? login = freezed, Object? id = freezed, Object? nodeId = freezed, Object? avatarUrl = freezed, Object? gravatarId = freezed, Object? url = freezed, Object? htmlUrl = freezed, Object? followersUrl = freezed, Object? followingUrl = freezed, Object? gistsUrl = freezed, Object? starredUrl = freezed, Object? subscriptionsUrl = freezed, Object? organizationsUrl = freezed, Object? reposUrl = freezed, Object? eventsUrl = freezed, Object? receivedEventsUrl = freezed, Object? type = freezed, Object? userViewType = freezed, Object? siteAdmin = freezed,}) {
    return _then(_Uploader(
      login: freezed == login
          ? _self.login
          : login // ignore: cast_nullable_to_non_nullable
      as String?,
      id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
      as int?,
      nodeId: freezed == nodeId
          ? _self.nodeId
          : nodeId // ignore: cast_nullable_to_non_nullable
      as String?,
      avatarUrl: freezed == avatarUrl
          ? _self.avatarUrl
          : avatarUrl // ignore: cast_nullable_to_non_nullable
      as String?,
      gravatarId: freezed == gravatarId
          ? _self.gravatarId
          : gravatarId // ignore: cast_nullable_to_non_nullable
      as String?,
      url: freezed == url
          ? _self.url
          : url // ignore: cast_nullable_to_non_nullable
      as String?,
      htmlUrl: freezed == htmlUrl
          ? _self.htmlUrl
          : htmlUrl // ignore: cast_nullable_to_non_nullable
      as String?,
      followersUrl: freezed == followersUrl
          ? _self.followersUrl
          : followersUrl // ignore: cast_nullable_to_non_nullable
      as String?,
      followingUrl: freezed == followingUrl
          ? _self.followingUrl
          : followingUrl // ignore: cast_nullable_to_non_nullable
      as String?,
      gistsUrl: freezed == gistsUrl
          ? _self.gistsUrl
          : gistsUrl // ignore: cast_nullable_to_non_nullable
      as String?,
      starredUrl: freezed == starredUrl
          ? _self.starredUrl
          : starredUrl // ignore: cast_nullable_to_non_nullable
      as String?,
      subscriptionsUrl: freezed == subscriptionsUrl
          ? _self.subscriptionsUrl
          : subscriptionsUrl // ignore: cast_nullable_to_non_nullable
      as String?,
      organizationsUrl: freezed == organizationsUrl
          ? _self.organizationsUrl
          : organizationsUrl // ignore: cast_nullable_to_non_nullable
      as String?,
      reposUrl: freezed == reposUrl
          ? _self.reposUrl
          : reposUrl // ignore: cast_nullable_to_non_nullable
      as String?,
      eventsUrl: freezed == eventsUrl
          ? _self.eventsUrl
          : eventsUrl // ignore: cast_nullable_to_non_nullable
      as String?,
      receivedEventsUrl: freezed == receivedEventsUrl
          ? _self.receivedEventsUrl
          : receivedEventsUrl // ignore: cast_nullable_to_non_nullable
      as String?,
      type: freezed == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
      as String?,
      userViewType: freezed == userViewType
          ? _self.userViewType
          : userViewType // ignore: cast_nullable_to_non_nullable
      as String?,
      siteAdmin: freezed == siteAdmin
          ? _self.siteAdmin
          : siteAdmin // ignore: cast_nullable_to_non_nullable
      as bool?,
    ));
  }


}


/// @nodoc
mixin _$Author {

  String? get login;

  int? get id;

  @JsonKey(name: 'node_id') String? get nodeId;

  @JsonKey(name: 'avatar_url') String? get avatarUrl;

  @JsonKey(name: 'gravatar_id') String? get gravatarId;

  String? get url;

  @JsonKey(name: 'html_url') String? get htmlUrl;

  @JsonKey(name: 'followers_url') String? get followersUrl;

  @JsonKey(name: 'following_url') String? get followingUrl;

  @JsonKey(name: 'gists_url') String? get gistsUrl;

  @JsonKey(name: 'starred_url') String? get starredUrl;

  @JsonKey(name: 'subscriptions_url') String? get subscriptionsUrl;

  @JsonKey(name: 'organizations_url') String? get organizationsUrl;

  @JsonKey(name: 'repos_url') String? get reposUrl;

  @JsonKey(name: 'events_url') String? get eventsUrl;

  @JsonKey(name: 'received_events_url') String? get receivedEventsUrl;

  String? get type;

  @JsonKey(name: 'user_view_type') String? get userViewType;

  @JsonKey(name: 'site_admin') bool? get siteAdmin;

  /// Create a copy of Author
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AuthorCopyWith<Author> get copyWith =>
      _$AuthorCopyWithImpl<Author>(this as Author, _$identity);

  /// Serializes this Author to a JSON map.
  Map<String, dynamic> toJson();


  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is Author &&
            (identical(other.login, login) || other.login == login) &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.nodeId, nodeId) || other.nodeId == nodeId) &&
            (identical(other.avatarUrl, avatarUrl) ||
                other.avatarUrl == avatarUrl) &&
            (identical(other.gravatarId, gravatarId) ||
                other.gravatarId == gravatarId) &&
            (identical(other.url, url) || other.url == url) &&
            (identical(other.htmlUrl, htmlUrl) || other.htmlUrl == htmlUrl) &&
            (identical(other.followersUrl, followersUrl) ||
                other.followersUrl == followersUrl) &&
            (identical(other.followingUrl, followingUrl) ||
                other.followingUrl == followingUrl) &&
            (identical(other.gistsUrl, gistsUrl) ||
                other.gistsUrl == gistsUrl) &&
            (identical(other.starredUrl, starredUrl) ||
                other.starredUrl == starredUrl) &&
            (identical(other.subscriptionsUrl, subscriptionsUrl) ||
                other.subscriptionsUrl == subscriptionsUrl) &&
            (identical(other.organizationsUrl, organizationsUrl) ||
                other.organizationsUrl == organizationsUrl) &&
            (identical(other.reposUrl, reposUrl) ||
                other.reposUrl == reposUrl) &&
            (identical(other.eventsUrl, eventsUrl) ||
                other.eventsUrl == eventsUrl) &&
            (identical(other.receivedEventsUrl, receivedEventsUrl) ||
                other.receivedEventsUrl == receivedEventsUrl) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.userViewType, userViewType) ||
                other.userViewType == userViewType) &&
            (identical(other.siteAdmin, siteAdmin) ||
                other.siteAdmin == siteAdmin));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hashAll([
        runtimeType,
        login,
        id,
        nodeId,
        avatarUrl,
        gravatarId,
        url,
        htmlUrl,
        followersUrl,
        followingUrl,
        gistsUrl,
        starredUrl,
        subscriptionsUrl,
        organizationsUrl,
        reposUrl,
        eventsUrl,
        receivedEventsUrl,
        type,
        userViewType,
        siteAdmin
      ]);

  @override
  String toString() {
    return 'Author(login: $login, id: $id, nodeId: $nodeId, avatarUrl: $avatarUrl, gravatarId: $gravatarId, url: $url, htmlUrl: $htmlUrl, followersUrl: $followersUrl, followingUrl: $followingUrl, gistsUrl: $gistsUrl, starredUrl: $starredUrl, subscriptionsUrl: $subscriptionsUrl, organizationsUrl: $organizationsUrl, reposUrl: $reposUrl, eventsUrl: $eventsUrl, receivedEventsUrl: $receivedEventsUrl, type: $type, userViewType: $userViewType, siteAdmin: $siteAdmin)';
  }


}

/// @nodoc
abstract mixin class $AuthorCopyWith<$Res> {
  factory $AuthorCopyWith(Author value,
      $Res Function(Author) _then) = _$AuthorCopyWithImpl;

  @useResult
  $Res call({
    String? login, int? id, @JsonKey(name: 'node_id') String? nodeId, @JsonKey(
        name: 'avatar_url') String? avatarUrl, @JsonKey(
        name: 'gravatar_id') String? gravatarId, String? url, @JsonKey(
        name: 'html_url') String? htmlUrl, @JsonKey(
        name: 'followers_url') String? followersUrl, @JsonKey(
        name: 'following_url') String? followingUrl, @JsonKey(
        name: 'gists_url') String? gistsUrl, @JsonKey(
        name: 'starred_url') String? starredUrl, @JsonKey(
        name: 'subscriptions_url') String? subscriptionsUrl, @JsonKey(
        name: 'organizations_url') String? organizationsUrl, @JsonKey(
        name: 'repos_url') String? reposUrl, @JsonKey(
        name: 'events_url') String? eventsUrl, @JsonKey(
        name: 'received_events_url') String? receivedEventsUrl, String? type, @JsonKey(
        name: 'user_view_type') String? userViewType, @JsonKey(
        name: 'site_admin') bool? siteAdmin
  });


}

/// @nodoc
class _$AuthorCopyWithImpl<$Res>
    implements $AuthorCopyWith<$Res> {
  _$AuthorCopyWithImpl(this._self, this._then);

  final Author _self;
  final $Res Function(Author) _then;

  /// Create a copy of Author
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call(
      {Object? login = freezed, Object? id = freezed, Object? nodeId = freezed, Object? avatarUrl = freezed, Object? gravatarId = freezed, Object? url = freezed, Object? htmlUrl = freezed, Object? followersUrl = freezed, Object? followingUrl = freezed, Object? gistsUrl = freezed, Object? starredUrl = freezed, Object? subscriptionsUrl = freezed, Object? organizationsUrl = freezed, Object? reposUrl = freezed, Object? eventsUrl = freezed, Object? receivedEventsUrl = freezed, Object? type = freezed, Object? userViewType = freezed, Object? siteAdmin = freezed,}) {
    return _then(_self.copyWith(
      login: freezed == login
          ? _self.login
          : login // ignore: cast_nullable_to_non_nullable
      as String?,
      id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
      as int?,
      nodeId: freezed == nodeId
          ? _self.nodeId
          : nodeId // ignore: cast_nullable_to_non_nullable
      as String?,
      avatarUrl: freezed == avatarUrl
          ? _self.avatarUrl
          : avatarUrl // ignore: cast_nullable_to_non_nullable
      as String?,
      gravatarId: freezed == gravatarId
          ? _self.gravatarId
          : gravatarId // ignore: cast_nullable_to_non_nullable
      as String?,
      url: freezed == url
          ? _self.url
          : url // ignore: cast_nullable_to_non_nullable
      as String?,
      htmlUrl: freezed == htmlUrl
          ? _self.htmlUrl
          : htmlUrl // ignore: cast_nullable_to_non_nullable
      as String?,
      followersUrl: freezed == followersUrl
          ? _self.followersUrl
          : followersUrl // ignore: cast_nullable_to_non_nullable
      as String?,
      followingUrl: freezed == followingUrl
          ? _self.followingUrl
          : followingUrl // ignore: cast_nullable_to_non_nullable
      as String?,
      gistsUrl: freezed == gistsUrl
          ? _self.gistsUrl
          : gistsUrl // ignore: cast_nullable_to_non_nullable
      as String?,
      starredUrl: freezed == starredUrl
          ? _self.starredUrl
          : starredUrl // ignore: cast_nullable_to_non_nullable
      as String?,
      subscriptionsUrl: freezed == subscriptionsUrl
          ? _self.subscriptionsUrl
          : subscriptionsUrl // ignore: cast_nullable_to_non_nullable
      as String?,
      organizationsUrl: freezed == organizationsUrl
          ? _self.organizationsUrl
          : organizationsUrl // ignore: cast_nullable_to_non_nullable
      as String?,
      reposUrl: freezed == reposUrl
          ? _self.reposUrl
          : reposUrl // ignore: cast_nullable_to_non_nullable
      as String?,
      eventsUrl: freezed == eventsUrl
          ? _self.eventsUrl
          : eventsUrl // ignore: cast_nullable_to_non_nullable
      as String?,
      receivedEventsUrl: freezed == receivedEventsUrl
          ? _self.receivedEventsUrl
          : receivedEventsUrl // ignore: cast_nullable_to_non_nullable
      as String?,
      type: freezed == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
      as String?,
      userViewType: freezed == userViewType
          ? _self.userViewType
          : userViewType // ignore: cast_nullable_to_non_nullable
      as String?,
      siteAdmin: freezed == siteAdmin
          ? _self.siteAdmin
          : siteAdmin // ignore: cast_nullable_to_non_nullable
      as bool?,
    ));
  }

}


/// @nodoc
@JsonSerializable()
class _Author implements Author {
  const _Author(
      {this.login, this.id, @JsonKey(name: 'node_id') this.nodeId, @JsonKey(
          name: 'avatar_url') this.avatarUrl, @JsonKey(
          name: 'gravatar_id') this.gravatarId, this.url, @JsonKey(
          name: 'html_url') this.htmlUrl, @JsonKey(
          name: 'followers_url') this.followersUrl, @JsonKey(
          name: 'following_url') this.followingUrl, @JsonKey(
          name: 'gists_url') this.gistsUrl, @JsonKey(
          name: 'starred_url') this.starredUrl, @JsonKey(
          name: 'subscriptions_url') this.subscriptionsUrl, @JsonKey(
          name: 'organizations_url') this.organizationsUrl, @JsonKey(
          name: 'repos_url') this.reposUrl, @JsonKey(
          name: 'events_url') this.eventsUrl, @JsonKey(
          name: 'received_events_url') this.receivedEventsUrl, this.type, @JsonKey(
          name: 'user_view_type') this.userViewType, @JsonKey(
          name: 'site_admin') this.siteAdmin});

  factory _Author.fromJson(Map<String, dynamic> json) => _$AuthorFromJson(json);

  @override final String? login;
  @override final int? id;
  @override
  @JsonKey(name: 'node_id')
  final String? nodeId;
  @override
  @JsonKey(name: 'avatar_url')
  final String? avatarUrl;
  @override
  @JsonKey(name: 'gravatar_id')
  final String? gravatarId;
  @override final String? url;
  @override
  @JsonKey(name: 'html_url')
  final String? htmlUrl;
  @override
  @JsonKey(name: 'followers_url')
  final String? followersUrl;
  @override
  @JsonKey(name: 'following_url')
  final String? followingUrl;
  @override
  @JsonKey(name: 'gists_url')
  final String? gistsUrl;
  @override
  @JsonKey(name: 'starred_url')
  final String? starredUrl;
  @override
  @JsonKey(name: 'subscriptions_url')
  final String? subscriptionsUrl;
  @override
  @JsonKey(name: 'organizations_url')
  final String? organizationsUrl;
  @override
  @JsonKey(name: 'repos_url')
  final String? reposUrl;
  @override
  @JsonKey(name: 'events_url')
  final String? eventsUrl;
  @override
  @JsonKey(name: 'received_events_url')
  final String? receivedEventsUrl;
  @override final String? type;
  @override
  @JsonKey(name: 'user_view_type')
  final String? userViewType;
  @override
  @JsonKey(name: 'site_admin')
  final bool? siteAdmin;

  /// Create a copy of Author
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$AuthorCopyWith<_Author> get copyWith =>
      __$AuthorCopyWithImpl<_Author>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$AuthorToJson(this,);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _Author &&
            (identical(other.login, login) || other.login == login) &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.nodeId, nodeId) || other.nodeId == nodeId) &&
            (identical(other.avatarUrl, avatarUrl) ||
                other.avatarUrl == avatarUrl) &&
            (identical(other.gravatarId, gravatarId) ||
                other.gravatarId == gravatarId) &&
            (identical(other.url, url) || other.url == url) &&
            (identical(other.htmlUrl, htmlUrl) || other.htmlUrl == htmlUrl) &&
            (identical(other.followersUrl, followersUrl) ||
                other.followersUrl == followersUrl) &&
            (identical(other.followingUrl, followingUrl) ||
                other.followingUrl == followingUrl) &&
            (identical(other.gistsUrl, gistsUrl) ||
                other.gistsUrl == gistsUrl) &&
            (identical(other.starredUrl, starredUrl) ||
                other.starredUrl == starredUrl) &&
            (identical(other.subscriptionsUrl, subscriptionsUrl) ||
                other.subscriptionsUrl == subscriptionsUrl) &&
            (identical(other.organizationsUrl, organizationsUrl) ||
                other.organizationsUrl == organizationsUrl) &&
            (identical(other.reposUrl, reposUrl) ||
                other.reposUrl == reposUrl) &&
            (identical(other.eventsUrl, eventsUrl) ||
                other.eventsUrl == eventsUrl) &&
            (identical(other.receivedEventsUrl, receivedEventsUrl) ||
                other.receivedEventsUrl == receivedEventsUrl) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.userViewType, userViewType) ||
                other.userViewType == userViewType) &&
            (identical(other.siteAdmin, siteAdmin) ||
                other.siteAdmin == siteAdmin));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hashAll([
        runtimeType,
        login,
        id,
        nodeId,
        avatarUrl,
        gravatarId,
        url,
        htmlUrl,
        followersUrl,
        followingUrl,
        gistsUrl,
        starredUrl,
        subscriptionsUrl,
        organizationsUrl,
        reposUrl,
        eventsUrl,
        receivedEventsUrl,
        type,
        userViewType,
        siteAdmin
      ]);

  @override
  String toString() {
    return 'Author(login: $login, id: $id, nodeId: $nodeId, avatarUrl: $avatarUrl, gravatarId: $gravatarId, url: $url, htmlUrl: $htmlUrl, followersUrl: $followersUrl, followingUrl: $followingUrl, gistsUrl: $gistsUrl, starredUrl: $starredUrl, subscriptionsUrl: $subscriptionsUrl, organizationsUrl: $organizationsUrl, reposUrl: $reposUrl, eventsUrl: $eventsUrl, receivedEventsUrl: $receivedEventsUrl, type: $type, userViewType: $userViewType, siteAdmin: $siteAdmin)';
  }


}

/// @nodoc
abstract mixin class _$AuthorCopyWith<$Res> implements $AuthorCopyWith<$Res> {
  factory _$AuthorCopyWith(_Author value,
      $Res Function(_Author) _then) = __$AuthorCopyWithImpl;

  @override
  @useResult
  $Res call({
    String? login, int? id, @JsonKey(name: 'node_id') String? nodeId, @JsonKey(
        name: 'avatar_url') String? avatarUrl, @JsonKey(
        name: 'gravatar_id') String? gravatarId, String? url, @JsonKey(
        name: 'html_url') String? htmlUrl, @JsonKey(
        name: 'followers_url') String? followersUrl, @JsonKey(
        name: 'following_url') String? followingUrl, @JsonKey(
        name: 'gists_url') String? gistsUrl, @JsonKey(
        name: 'starred_url') String? starredUrl, @JsonKey(
        name: 'subscriptions_url') String? subscriptionsUrl, @JsonKey(
        name: 'organizations_url') String? organizationsUrl, @JsonKey(
        name: 'repos_url') String? reposUrl, @JsonKey(
        name: 'events_url') String? eventsUrl, @JsonKey(
        name: 'received_events_url') String? receivedEventsUrl, String? type, @JsonKey(
        name: 'user_view_type') String? userViewType, @JsonKey(
        name: 'site_admin') bool? siteAdmin
  });


}

/// @nodoc
class __$AuthorCopyWithImpl<$Res>
    implements _$AuthorCopyWith<$Res> {
  __$AuthorCopyWithImpl(this._self, this._then);

  final _Author _self;
  final $Res Function(_Author) _then;

  /// Create a copy of Author
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call(
      {Object? login = freezed, Object? id = freezed, Object? nodeId = freezed, Object? avatarUrl = freezed, Object? gravatarId = freezed, Object? url = freezed, Object? htmlUrl = freezed, Object? followersUrl = freezed, Object? followingUrl = freezed, Object? gistsUrl = freezed, Object? starredUrl = freezed, Object? subscriptionsUrl = freezed, Object? organizationsUrl = freezed, Object? reposUrl = freezed, Object? eventsUrl = freezed, Object? receivedEventsUrl = freezed, Object? type = freezed, Object? userViewType = freezed, Object? siteAdmin = freezed,}) {
    return _then(_Author(
      login: freezed == login
          ? _self.login
          : login // ignore: cast_nullable_to_non_nullable
      as String?,
      id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
      as int?,
      nodeId: freezed == nodeId
          ? _self.nodeId
          : nodeId // ignore: cast_nullable_to_non_nullable
      as String?,
      avatarUrl: freezed == avatarUrl
          ? _self.avatarUrl
          : avatarUrl // ignore: cast_nullable_to_non_nullable
      as String?,
      gravatarId: freezed == gravatarId
          ? _self.gravatarId
          : gravatarId // ignore: cast_nullable_to_non_nullable
      as String?,
      url: freezed == url
          ? _self.url
          : url // ignore: cast_nullable_to_non_nullable
      as String?,
      htmlUrl: freezed == htmlUrl
          ? _self.htmlUrl
          : htmlUrl // ignore: cast_nullable_to_non_nullable
      as String?,
      followersUrl: freezed == followersUrl
          ? _self.followersUrl
          : followersUrl // ignore: cast_nullable_to_non_nullable
      as String?,
      followingUrl: freezed == followingUrl
          ? _self.followingUrl
          : followingUrl // ignore: cast_nullable_to_non_nullable
      as String?,
      gistsUrl: freezed == gistsUrl
          ? _self.gistsUrl
          : gistsUrl // ignore: cast_nullable_to_non_nullable
      as String?,
      starredUrl: freezed == starredUrl
          ? _self.starredUrl
          : starredUrl // ignore: cast_nullable_to_non_nullable
      as String?,
      subscriptionsUrl: freezed == subscriptionsUrl
          ? _self.subscriptionsUrl
          : subscriptionsUrl // ignore: cast_nullable_to_non_nullable
      as String?,
      organizationsUrl: freezed == organizationsUrl
          ? _self.organizationsUrl
          : organizationsUrl // ignore: cast_nullable_to_non_nullable
      as String?,
      reposUrl: freezed == reposUrl
          ? _self.reposUrl
          : reposUrl // ignore: cast_nullable_to_non_nullable
      as String?,
      eventsUrl: freezed == eventsUrl
          ? _self.eventsUrl
          : eventsUrl // ignore: cast_nullable_to_non_nullable
      as String?,
      receivedEventsUrl: freezed == receivedEventsUrl
          ? _self.receivedEventsUrl
          : receivedEventsUrl // ignore: cast_nullable_to_non_nullable
      as String?,
      type: freezed == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
      as String?,
      userViewType: freezed == userViewType
          ? _self.userViewType
          : userViewType // ignore: cast_nullable_to_non_nullable
      as String?,
      siteAdmin: freezed == siteAdmin
          ? _self.siteAdmin
          : siteAdmin // ignore: cast_nullable_to_non_nullable
      as bool?,
    ));
  }


}

// dart format on

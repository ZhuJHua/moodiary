import 'package:freezed_annotation/freezed_annotation.dart';

part 'github.freezed.dart';
part 'github.g.dart';

@freezed
abstract class GithubRelease with _$GithubRelease {
  const factory GithubRelease({
    String? url,
    @JsonKey(name: 'assets_url') String? assetsUrl,
    @JsonKey(name: 'upload_url') String? uploadUrl,
    @JsonKey(name: 'html_url') String? htmlUrl,
    int? id,
    Author? author,
    @JsonKey(name: 'node_id') String? nodeId,
    @JsonKey(name: 'tag_name') String? tagName,
    @JsonKey(name: 'target_commitish') String? targetCommitish,
    String? name,
    bool? draft,
    bool? prerelease,
    @JsonKey(name: 'created_at') String? createdAt,
    @JsonKey(name: 'published_at') String? publishedAt,
    List<Assets>? assets,
    @JsonKey(name: 'tarball_url') String? tarballUrl,
    @JsonKey(name: 'zipball_url') String? zipballUrl,
    String? body,
  }) = _GithubRelease;

  factory GithubRelease.fromJson(Map<String, dynamic> json) =>
      _$GithubReleaseFromJson(json);
}

@freezed
abstract class Assets with _$Assets {
  const factory Assets({
    String? url,
    int? id,
    @JsonKey(name: 'node_id') String? nodeId,
    String? name,
    dynamic label,
    Uploader? uploader,
    @JsonKey(name: 'content_type') String? contentType,
    String? state,
    int? size,
    @JsonKey(name: 'download_count') int? downloadCount,
    @JsonKey(name: 'created_at') String? createdAt,
    @JsonKey(name: 'updated_at') String? updatedAt,
    @JsonKey(name: 'browser_download_url') String? browserDownloadUrl,
  }) = _Assets;

  factory Assets.fromJson(Map<String, dynamic> json) => _$AssetsFromJson(json);
}

@freezed
abstract class Uploader with _$Uploader {
  const factory Uploader({
    String? login,
    int? id,
    @JsonKey(name: 'node_id') String? nodeId,
    @JsonKey(name: 'avatar_url') String? avatarUrl,
    @JsonKey(name: 'gravatar_id') String? gravatarId,
    String? url,
    @JsonKey(name: 'html_url') String? htmlUrl,
    @JsonKey(name: 'followers_url') String? followersUrl,
    @JsonKey(name: 'following_url') String? followingUrl,
    @JsonKey(name: 'gists_url') String? gistsUrl,
    @JsonKey(name: 'starred_url') String? starredUrl,
    @JsonKey(name: 'subscriptions_url') String? subscriptionsUrl,
    @JsonKey(name: 'organizations_url') String? organizationsUrl,
    @JsonKey(name: 'repos_url') String? reposUrl,
    @JsonKey(name: 'events_url') String? eventsUrl,
    @JsonKey(name: 'received_events_url') String? receivedEventsUrl,
    String? type,
    @JsonKey(name: 'user_view_type') String? userViewType,
    @JsonKey(name: 'site_admin') bool? siteAdmin,
  }) = _Uploader;

  factory Uploader.fromJson(Map<String, dynamic> json) =>
      _$UploaderFromJson(json);
}

@freezed
abstract class Author with _$Author {
  const factory Author({
    String? login,
    int? id,
    @JsonKey(name: 'node_id') String? nodeId,
    @JsonKey(name: 'avatar_url') String? avatarUrl,
    @JsonKey(name: 'gravatar_id') String? gravatarId,
    String? url,
    @JsonKey(name: 'html_url') String? htmlUrl,
    @JsonKey(name: 'followers_url') String? followersUrl,
    @JsonKey(name: 'following_url') String? followingUrl,
    @JsonKey(name: 'gists_url') String? gistsUrl,
    @JsonKey(name: 'starred_url') String? starredUrl,
    @JsonKey(name: 'subscriptions_url') String? subscriptionsUrl,
    @JsonKey(name: 'organizations_url') String? organizationsUrl,
    @JsonKey(name: 'repos_url') String? reposUrl,
    @JsonKey(name: 'events_url') String? eventsUrl,
    @JsonKey(name: 'received_events_url') String? receivedEventsUrl,
    String? type,
    @JsonKey(name: 'user_view_type') String? userViewType,
    @JsonKey(name: 'site_admin') bool? siteAdmin,
  }) = _Author;

  factory Author.fromJson(Map<String, dynamic> json) => _$AuthorFromJson(json);
}

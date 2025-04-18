// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'github.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_GithubRelease _$GithubReleaseFromJson(Map<String, dynamic> json) =>
    _GithubRelease(
      url: json['url'] as String?,
      assetsUrl: json['assets_url'] as String?,
      uploadUrl: json['upload_url'] as String?,
      htmlUrl: json['html_url'] as String?,
      id: (json['id'] as num?)?.toInt(),
      author:
          json['author'] == null
              ? null
              : Author.fromJson(json['author'] as Map<String, dynamic>),
      nodeId: json['node_id'] as String?,
      tagName: json['tag_name'] as String?,
      targetCommitish: json['target_commitish'] as String?,
      name: json['name'] as String?,
      draft: json['draft'] as bool?,
      prerelease: json['prerelease'] as bool?,
      createdAt: json['created_at'] as String?,
      publishedAt: json['published_at'] as String?,
      assets:
          (json['assets'] as List<dynamic>?)
              ?.map((e) => Assets.fromJson(e as Map<String, dynamic>))
              .toList(),
      tarballUrl: json['tarball_url'] as String?,
      zipballUrl: json['zipball_url'] as String?,
      body: json['body'] as String?,
    );

Map<String, dynamic> _$GithubReleaseToJson(_GithubRelease instance) =>
    <String, dynamic>{
      if (instance.url case final value?) 'url': value,
      if (instance.assetsUrl case final value?) 'assets_url': value,
      if (instance.uploadUrl case final value?) 'upload_url': value,
      if (instance.htmlUrl case final value?) 'html_url': value,
      if (instance.id case final value?) 'id': value,
      if (instance.author case final value?) 'author': value,
      if (instance.nodeId case final value?) 'node_id': value,
      if (instance.tagName case final value?) 'tag_name': value,
      if (instance.targetCommitish case final value?) 'target_commitish': value,
      if (instance.name case final value?) 'name': value,
      if (instance.draft case final value?) 'draft': value,
      if (instance.prerelease case final value?) 'prerelease': value,
      if (instance.createdAt case final value?) 'created_at': value,
      if (instance.publishedAt case final value?) 'published_at': value,
      if (instance.assets case final value?) 'assets': value,
      if (instance.tarballUrl case final value?) 'tarball_url': value,
      if (instance.zipballUrl case final value?) 'zipball_url': value,
      if (instance.body case final value?) 'body': value,
    };

_Assets _$AssetsFromJson(Map<String, dynamic> json) => _Assets(
  url: json['url'] as String?,
  id: (json['id'] as num?)?.toInt(),
  nodeId: json['node_id'] as String?,
  name: json['name'] as String?,
  label: json['label'],
  uploader:
      json['uploader'] == null
          ? null
          : Uploader.fromJson(json['uploader'] as Map<String, dynamic>),
  contentType: json['content_type'] as String?,
  state: json['state'] as String?,
  size: (json['size'] as num?)?.toInt(),
  downloadCount: (json['download_count'] as num?)?.toInt(),
  createdAt: json['created_at'] as String?,
  updatedAt: json['updated_at'] as String?,
  browserDownloadUrl: json['browser_download_url'] as String?,
);

Map<String, dynamic> _$AssetsToJson(_Assets instance) => <String, dynamic>{
  if (instance.url case final value?) 'url': value,
  if (instance.id case final value?) 'id': value,
  if (instance.nodeId case final value?) 'node_id': value,
  if (instance.name case final value?) 'name': value,
  if (instance.label case final value?) 'label': value,
  if (instance.uploader case final value?) 'uploader': value,
  if (instance.contentType case final value?) 'content_type': value,
  if (instance.state case final value?) 'state': value,
  if (instance.size case final value?) 'size': value,
  if (instance.downloadCount case final value?) 'download_count': value,
  if (instance.createdAt case final value?) 'created_at': value,
  if (instance.updatedAt case final value?) 'updated_at': value,
  if (instance.browserDownloadUrl case final value?)
    'browser_download_url': value,
};

_Uploader _$UploaderFromJson(Map<String, dynamic> json) => _Uploader(
  login: json['login'] as String?,
  id: (json['id'] as num?)?.toInt(),
  nodeId: json['node_id'] as String?,
  avatarUrl: json['avatar_url'] as String?,
  gravatarId: json['gravatar_id'] as String?,
  url: json['url'] as String?,
  htmlUrl: json['html_url'] as String?,
  followersUrl: json['followers_url'] as String?,
  followingUrl: json['following_url'] as String?,
  gistsUrl: json['gists_url'] as String?,
  starredUrl: json['starred_url'] as String?,
  subscriptionsUrl: json['subscriptions_url'] as String?,
  organizationsUrl: json['organizations_url'] as String?,
  reposUrl: json['repos_url'] as String?,
  eventsUrl: json['events_url'] as String?,
  receivedEventsUrl: json['received_events_url'] as String?,
  type: json['type'] as String?,
  userViewType: json['user_view_type'] as String?,
  siteAdmin: json['site_admin'] as bool?,
);

Map<String, dynamic> _$UploaderToJson(_Uploader instance) => <String, dynamic>{
  if (instance.login case final value?) 'login': value,
  if (instance.id case final value?) 'id': value,
  if (instance.nodeId case final value?) 'node_id': value,
  if (instance.avatarUrl case final value?) 'avatar_url': value,
  if (instance.gravatarId case final value?) 'gravatar_id': value,
  if (instance.url case final value?) 'url': value,
  if (instance.htmlUrl case final value?) 'html_url': value,
  if (instance.followersUrl case final value?) 'followers_url': value,
  if (instance.followingUrl case final value?) 'following_url': value,
  if (instance.gistsUrl case final value?) 'gists_url': value,
  if (instance.starredUrl case final value?) 'starred_url': value,
  if (instance.subscriptionsUrl case final value?) 'subscriptions_url': value,
  if (instance.organizationsUrl case final value?) 'organizations_url': value,
  if (instance.reposUrl case final value?) 'repos_url': value,
  if (instance.eventsUrl case final value?) 'events_url': value,
  if (instance.receivedEventsUrl case final value?)
    'received_events_url': value,
  if (instance.type case final value?) 'type': value,
  if (instance.userViewType case final value?) 'user_view_type': value,
  if (instance.siteAdmin case final value?) 'site_admin': value,
};

_Author _$AuthorFromJson(Map<String, dynamic> json) => _Author(
  login: json['login'] as String?,
  id: (json['id'] as num?)?.toInt(),
  nodeId: json['node_id'] as String?,
  avatarUrl: json['avatar_url'] as String?,
  gravatarId: json['gravatar_id'] as String?,
  url: json['url'] as String?,
  htmlUrl: json['html_url'] as String?,
  followersUrl: json['followers_url'] as String?,
  followingUrl: json['following_url'] as String?,
  gistsUrl: json['gists_url'] as String?,
  starredUrl: json['starred_url'] as String?,
  subscriptionsUrl: json['subscriptions_url'] as String?,
  organizationsUrl: json['organizations_url'] as String?,
  reposUrl: json['repos_url'] as String?,
  eventsUrl: json['events_url'] as String?,
  receivedEventsUrl: json['received_events_url'] as String?,
  type: json['type'] as String?,
  userViewType: json['user_view_type'] as String?,
  siteAdmin: json['site_admin'] as bool?,
);

Map<String, dynamic> _$AuthorToJson(_Author instance) => <String, dynamic>{
  if (instance.login case final value?) 'login': value,
  if (instance.id case final value?) 'id': value,
  if (instance.nodeId case final value?) 'node_id': value,
  if (instance.avatarUrl case final value?) 'avatar_url': value,
  if (instance.gravatarId case final value?) 'gravatar_id': value,
  if (instance.url case final value?) 'url': value,
  if (instance.htmlUrl case final value?) 'html_url': value,
  if (instance.followersUrl case final value?) 'followers_url': value,
  if (instance.followingUrl case final value?) 'following_url': value,
  if (instance.gistsUrl case final value?) 'gists_url': value,
  if (instance.starredUrl case final value?) 'starred_url': value,
  if (instance.subscriptionsUrl case final value?) 'subscriptions_url': value,
  if (instance.organizationsUrl case final value?) 'organizations_url': value,
  if (instance.reposUrl case final value?) 'repos_url': value,
  if (instance.eventsUrl case final value?) 'events_url': value,
  if (instance.receivedEventsUrl case final value?)
    'received_events_url': value,
  if (instance.type case final value?) 'type': value,
  if (instance.userViewType case final value?) 'user_view_type': value,
  if (instance.siteAdmin case final value?) 'site_admin': value,
};

import 'dart:math';

import 'package:injectable/injectable.dart';
import 'package:moodiary_http/moodiary_http.dart';

class AppRelease {
  final String version;
  final String notes;
  final String pageUrl;

  const AppRelease({
    required this.version,
    required this.notes,
    required this.pageUrl,
  });
}

@lazySingleton
class AppUpdateRepository {
  AppUpdateRepository(this._http);

  final IHttpClient _http;

  static const String _releasesPage =
      'https://github.com/ZhuJHua/moodiary/releases/latest';

  static const String _latestReleaseApi =
      'https://api.github.com/repos/ZhuJHua/moodiary/releases/latest';

  static const Duration _timeout = Duration(seconds: 15);

  /// 返回比 [currentVersion] 新的发行版，已是最新时返回 null。
  Future<AppRelease?> checkForUpdate(String currentVersion) async {
    final response = await _http.get<Map<String, dynamic>>(
      _latestReleaseApi,
      headers: const {
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      },
      timeout: _timeout,
      silent: true,
    );
    final release = _parse(response.data);
    if (release == null) {
      throw const HttpException(.decode, 'unexpected release payload');
    }
    return _compare(release.version, currentVersion) > 0 ? release : null;
  }

  AppRelease? _parse(Map<String, dynamic>? json) {
    if (json == null) return null;
    final tag = (json['tag_name'] as String? ?? '').trim();
    final version = tag.startsWith('v') ? tag.substring(1) : tag;
    if (version.isEmpty) return null;
    return AppRelease(
      version: version,
      notes: (json['body'] as String? ?? '').trim(),
      pageUrl: json['html_url'] as String? ?? _releasesPage,
    );
  }
}

int _compare(String a, String b) {
  final (coreA, preA) = _split(a);
  final (coreB, preB) = _split(b);
  for (var i = 0; i < max(coreA.length, coreB.length); i++) {
    final left = i < coreA.length ? coreA[i] : 0;
    final right = i < coreB.length ? coreB[i] : 0;
    if (left != right) return left > right ? 1 : -1;
  }
  if (preA == preB) return 0;
  if (preA.isEmpty) return 1;
  if (preB.isEmpty) return -1;
  return preA.compareTo(preB);
}

(List<int>, String) _split(String version) {
  final core = version
      .trim()
      .replaceFirst(RegExp('^[vV]'), '')
      .split('+')
      .first;
  final dash = core.indexOf('-');
  final numbers = (dash < 0 ? core : core.substring(0, dash))
      .split('.')
      .map((part) => int.tryParse(part) ?? 0)
      .toList();
  return (numbers, dash < 0 ? '' : core.substring(dash + 1));
}

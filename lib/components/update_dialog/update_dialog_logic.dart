import 'package:mood_diary/common/models/github.dart';
import 'package:refreshed/refreshed.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateDialogLogic extends GetxController {
  Future<void> toDownload(GithubRelease githubRelease) async {
    await launchUrl(Uri.parse(githubRelease.htmlUrl!),
        mode: LaunchMode.platformDefault);
  }
}

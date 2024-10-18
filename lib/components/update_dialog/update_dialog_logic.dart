import 'package:get/get.dart';
import 'package:mood_diary/common/models/github.dart';
import 'package:url_launcher/url_launcher.dart';

import 'update_dialog_state.dart';

class UpdateDialogLogic extends GetxController {
  final UpdateDialogState state = UpdateDialogState();

  @override
  void onReady() {
    // TODO: implement onReady
    super.onReady();
  }

  @override
  void onClose() {
    // TODO: implement onClose
    super.onClose();
  }

  Future<void> toDownload(GithubRelease githubRelease) async {
    await launchUrl(Uri.parse(githubRelease.htmlUrl!), mode: LaunchMode.platformDefault);
  }
}

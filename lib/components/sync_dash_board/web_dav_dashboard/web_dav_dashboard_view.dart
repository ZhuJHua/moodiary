import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:moodiary/common/values/webdav.dart';
import 'package:moodiary/components/base/loading.dart';
import 'package:moodiary/components/tile/setting_tile.dart';
import 'package:moodiary/l10n/l10n.dart';
import 'package:moodiary/utils/webdav_util.dart';

import 'web_dav_dashboard_logic.dart';
import 'web_dav_dashboard_state.dart';

class WebDavDashboardComponent extends StatelessWidget {
  const WebDavDashboardComponent({super.key});

  Widget _buildError({required BuildContext context}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 8.0,
        children: [
          const FaIcon(FontAwesomeIcons.solidCircleXmark, size: 56),
          Text(context.l10n.webdavDashboardConnectionError),
        ],
      ),
    );
  }

  // 当前任务队列
  Widget _buildTaskQueue({
    required BuildContext context,
    required bool isUploading,
    required bool isDownloading,
  }) {
    String status;
    if (WebDavUtil().syncingDiaries.isNotEmpty) {
      status = context.l10n.webdavDashboardTaskSync;
    } else {
      status = context.l10n.webdavDashboardTaskEmpty;
    }
    return AdaptiveListTile(
      title: context.l10n.webdavDashboardCurrentTaskQueue,
      subtitle: status,
      trailing: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Visibility(
              visible: isUploading,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 8.0,
                children: [
                  const FaIcon(FontAwesomeIcons.arrowUp, size: 12),
                  Text(context.l10n.webdavDashboardUpload),
                ],
              ),
            ),
            Visibility(
              visible: isDownloading,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 8.0,
                children: [
                  const FaIcon(FontAwesomeIcons.arrowDown, size: 12),
                  Text(context.l10n.webdavDashboardDownload),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCloudCount({
    required BuildContext context,
    required String cloudCount,
    required Function() onTap,
  }) {
    return AdaptiveListTile(
      title: context.l10n.webdavDashboardRemoteDiaryCount,
      subtitle: cloudCount,
      trailing: FilledButton(
        onPressed: onTap,
        child: const FaIcon(FontAwesomeIcons.arrowsRotate),
      ),
    );
  }

  // 本地日记数量，包括待上传和待下载
  Widget _buildLocalDiaryCount({
    required BuildContext context,
    required String toUploadCount,
    required String toDownloadCount,
    required Function() onTap,
  }) {
    return AdaptiveListTile(
      title: context.l10n.webdavDashboardLocalDiaryCount,
      subtitle:
          '${context.l10n.webdavDashboardWaitingForUpload} $toUploadCount  ${context.l10n.webdavDashboardWaitingForDownload}$toDownloadCount',
      trailing: FilledButton(
        onPressed: WebDavUtil().syncingDiaries.isNotEmpty ? null : onTap,
        child: const FaIcon(FontAwesomeIcons.arrowRightArrowLeft),
      ),
    );
  }

  // 本地待上传的日记数量
  // Widget _buildLocalSyncCount(
  //     {required RxString localSyncCount, required Function() onTap}) {
  //   return AdaptiveListTile(
  //       title: const Text('待上传日记数量'),
  //       subtitle: Obx(() {
  //         return Text(localSyncCount.value);
  //       }),
  //       trailing: FilledButton(
  //           onPressed: onTap, child: const FaIcon(FontAwesomeIcons.upload)));
  // }

  //  本地待下载的日记数量
  // Widget _buildLocalUnSyncCount(
  //     {required RxString localUnSyncCount, required Function() onTap}) {
  //   return AdaptiveListTile(
  //       title: const Text('待下载日记数量'),
  //       subtitle: Obx(() {
  //         return Text(localUnSyncCount.value);
  //       }),
  //       trailing: FilledButton(
  //           onPressed: onTap, child: const FaIcon(FontAwesomeIcons.download)));
  // }

  Widget _buildToWebDavSetting({
    required BuildContext context,
    required WebDavConnectivityStatus state,
    required Function() onTap,
  }) {
    return AdaptiveListTile(
      title: Row(
        children: [
          Text(context.l10n.backupSyncWebDAVConnectivity),
          Icon(
            Icons.circle,
            color: switch (state) {
              WebDavConnectivityStatus.connected =>
                WebDavOptions.connectivityColor,
              WebDavConnectivityStatus.unconnected =>
                WebDavOptions.unConnectivityColor,
              WebDavConnectivityStatus.connecting =>
                WebDavOptions.connectingColor,
            },
            size: 16,
          ),
        ],
      ),
      trailing: TextButton(
        onPressed: onTap,
        child: Text(context.l10n.webdavDashboardSetting),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final WebDavDashboardLogic logic = Get.put(WebDavDashboardLogic());
    final WebDavDashboardState state = Bind.find<WebDavDashboardLogic>().state;

    return GetBuilder<WebDavDashboardLogic>(
      assignId: true,
      builder: (_) {
        return Stack(
          alignment: Alignment.center,
          children: [
            ListView(
              padding: EdgeInsets.zero,
              children: [
                Obx(() {
                  return _buildToWebDavSetting(
                    context: context,
                    onTap: logic.toWebDavPage,
                    state: state.connectivityStatus.value,
                  );
                }),
                if (state.connectivityStatus.value ==
                    WebDavConnectivityStatus.connected) ...[
                  Obx(() {
                    return _buildTaskQueue(
                      context: context,
                      isUploading: state.isUploading.value,
                      isDownloading: state.isDownloading.value,
                    );
                  }),
                  Obx(() {
                    return _buildCloudCount(
                      context: context,
                      cloudCount: state.webDavDiaryCount.value,
                      onTap: logic.fetchingWebDavSyncFlag,
                    );
                  }),
                  Obx(() {
                    return _buildLocalDiaryCount(
                      context: context,
                      toUploadCount: state.toUploadDiariesCount.value,
                      toDownloadCount: state.toDownloadIdsCount.value,
                      onTap: () {
                        logic.syncDiary(context: context);
                      },
                    );
                  }),
                ],
              ],
            ),
            if (state.isFetching) const MoodiaryLoading(),
            if (state.connectivityStatus.value ==
                WebDavConnectivityStatus.unconnected)
              _buildError(context: context),
          ],
        );
      },
    );
  }
}

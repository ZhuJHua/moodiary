import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:mood_diary/components/loading/loading.dart';

import '../../../common/values/webdav.dart';
import '../../../utils/webdav_util.dart';
import 'web_dav_dashboard_logic.dart';
import 'web_dav_dashboard_state.dart';

class WebDavDashboardComponent extends StatelessWidget {
  const WebDavDashboardComponent({super.key});

  Widget _buildError() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 8.0,
        children: [
          FaIcon(
            FontAwesomeIcons.solidCircleXmark,
            size: 56,
          ),
          Text('暂未配置或连接失败')
        ],
      ),
    );
  }

  // 当前任务队列
  Widget _buildTaskQueue(
      {required RxBool isUploading, required RxBool isDownloading}) {
    return ListTile(
      title: const Text('当前任务队列'),
      subtitle: Obx(() {
        String status;
        if (WebDavUtil().syncingDiaries.isNotEmpty) {
          return const Text('自动同步中');
        }
        if (isUploading.value && isDownloading.value) {
          status = '上传、下载中';
        } else if (isUploading.value) {
          status = '上传中';
        } else if (isDownloading.value) {
          status = '下载中';
        } else {
          status = '空闲';
        }
        return Text(status);
      }),
      trailing: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Obx(() {
              return isUploading.value
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 8.0,
                      children: [
                        FaIcon(
                          FontAwesomeIcons.arrowUp,
                          size: 12,
                        ),
                        Text('上传'),
                      ],
                    )
                  : const SizedBox.shrink();
            }),
            Obx(() {
              return isDownloading.value
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 8.0,
                      children: [
                        FaIcon(
                          FontAwesomeIcons.arrowDown,
                          size: 12,
                        ),
                        Text('下载'),
                      ],
                    )
                  : const SizedBox.shrink();
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildCloudCount(
      {required RxString cloudCount, required Function() onTap}) {
    return ListTile(
      title: const Text('云端日记数量'),
      subtitle: Obx(() {
        return Text(cloudCount.value);
      }),
      trailing: FilledButton(
          onPressed: onTap, child: const FaIcon(FontAwesomeIcons.arrowsRotate)),
    );
  }

  // 本地日记数量，包括待上传和待下载
  Widget _buildLocalDiaryCount(
      {required RxString toUploadCount,
      required RxString toDownloadCount,
      required Function() onTap}) {
    return ListTile(
      title: const Text('本地日记数量'),
      subtitle: Row(
        spacing: 8.0,
        children: [
          Obx(() {
            return Text('待上传 ${toUploadCount.value}');
          }),
          Obx(() {
            return Text('待下载 ${toDownloadCount.value}');
          }),
        ],
      ),
      trailing: Obx(() {
        return FilledButton(
            onPressed: WebDavUtil().syncingDiaries.isNotEmpty ? null : onTap,
            child: const FaIcon(FontAwesomeIcons.arrowRightArrowLeft));
      }),
    );
  }

  // 本地待上传的日记数量
  // Widget _buildLocalSyncCount(
  //     {required RxString localSyncCount, required Function() onTap}) {
  //   return ListTile(
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
  //   return ListTile(
  //       title: const Text('待下载日记数量'),
  //       subtitle: Obx(() {
  //         return Text(localUnSyncCount.value);
  //       }),
  //       trailing: FilledButton(
  //           onPressed: onTap, child: const FaIcon(FontAwesomeIcons.download)));
  // }

  Widget _buildToWebDavSetting(
      {required Rx<WebDavConnectivityStatus> state,
      required Function() onTap}) {
    return ListTile(
      title: Row(
        children: [
          const Text('服务连通性 '),
          Obx(() {
            return Icon(
              Icons.circle,
              color: switch (state.value) {
                WebDavConnectivityStatus.connected =>
                  WebDavOptions.connectivityColor,
                WebDavConnectivityStatus.unconnected =>
                  WebDavOptions.unConnectivityColor,
                WebDavConnectivityStatus.connecting =>
                  WebDavOptions.connectingColor,
              },
              size: 16,
            );
          })
        ],
      ),
      trailing: TextButton(onPressed: onTap, child: const Text('WebDav 设置')),
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
                  _buildToWebDavSetting(
                      onTap: logic.toWebDavPage,
                      state: state.connectivityStatus),
                  if (state.connectivityStatus.value ==
                      WebDavConnectivityStatus.connected) ...[
                    _buildTaskQueue(
                        isUploading: state.isUploading,
                        isDownloading: state.isDownloading),
                    _buildCloudCount(
                        cloudCount: state.webDavDiaryCount,
                        onTap: logic.fetchingWebDavSyncFlag),
                    _buildLocalDiaryCount(
                        toUploadCount: state.toUploadDiariesCount,
                        toDownloadCount: state.toDownloadIdsCount,
                        onTap: logic.syncDiary)
                  ],
                ],
              ),
              if (state.isFetching) const Center(child: Processing()),
              if (state.connectivityStatus.value ==
                  WebDavConnectivityStatus.unconnected)
                _buildError(),
            ],
          );
        });
  }
}

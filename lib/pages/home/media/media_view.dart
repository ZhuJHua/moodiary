import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:mood_diary/common/values/border.dart';
import 'package:mood_diary/common/values/media_type.dart';
import 'package:mood_diary/components/audio_player/audio_player_view.dart';
import 'package:mood_diary/components/lottie_modal/lottie_modal.dart';
import 'package:sliver_tools/sliver_tools.dart';

import 'media_logic.dart';

class MediaPage extends StatelessWidget {
  const MediaPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Get.put(MediaLogic());
    final state = Bind.find<MediaLogic>().state;
    final i18n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    final iconMap = {
      MediaType.image: FontAwesomeIcons.image,
      MediaType.audio: FontAwesomeIcons.compactDisc,
      MediaType.video: FontAwesomeIcons.video
    };

    final textMap = {
      MediaType.image: i18n.mediaTypeImage,
      MediaType.audio: i18n.mediaTypeAudio,
      MediaType.video: i18n.mediaTypeVideo
    };

    Widget buildImageView() {
      return SliverGrid.builder(
          key: UniqueKey(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 120,
            childAspectRatio: 1.0,
          ),
          itemBuilder: (context, index) {
            return InkWell(
              borderRadius: AppBorderRadius.mediumBorderRadius,
              onTap: () {
                logic.toPhotoView(index);
              },
              child: Card(
                clipBehavior: Clip.hardEdge,
                child: Image.file(
                  File(state.filePath[index]),
                  fit: BoxFit.cover,
                ),
              ),
            );
          },
          itemCount: state.filePath.length);
    }

    Widget buildAudioView() {
      return SliverList.builder(
          key: UniqueKey(),
          itemBuilder: (context, index) {
            return AudioPlayerComponent(path: state.filePath[index]);
          },
          itemCount: state.filePath.length);
    }

    //使用map
    Widget buildVideoView() {
      // 使用 SliverGrid.builder 构建视频缩略图的网格视图
      var thumbnailList = state.videoThumbnailMap.keys.toList();
      var videoList = state.videoThumbnailMap.values.toList();
      return SliverGrid.builder(
        key: UniqueKey(),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 120, // 网格的每一列的最大宽度
          childAspectRatio: 1.0, // 子元素的宽高比
        ),
        itemBuilder: (context, index) {
          return InkWell(
            borderRadius: AppBorderRadius.mediumBorderRadius,
            onTap: () {
              // 点击事件，传递视频路径到 toVideoView 方法
              logic.toVideoView(videoList, index);
            },
            child: Card(
              clipBehavior: Clip.hardEdge, // 修剪行为
              child: Image.file(
                File(thumbnailList[index]), // 使用缩略图文件路径显示图像
                fit: BoxFit.cover, // 让图像完全覆盖卡片
              ),
            ),
          );
        },
        itemCount: state.videoThumbnailMap.length, // 网格项的数量
      );
    }

    return GetBuilder<MediaLogic>(
      assignId: true,
      builder: (_) {
        return Stack(
          alignment: Alignment.center,
          children: [
            CustomScrollView(
              slivers: [
                SliverAppBar(
                  title: Text(i18n.homeNavigatorMedia),
                  actions: [
                    Obx(() {
                      return PopupMenuButton(
                        offset: const Offset(0, 46),
                        icon: FaIcon(iconMap[state.mediaType.value]!),
                        itemBuilder: (context) {
                          return MediaType.values.map((type) {
                            return CheckedPopupMenuItem(
                              checked: state.mediaType.value == type,
                              onTap: () async {
                                await logic.changeMediaType(type);
                              },
                              child: Text(textMap[type]!),
                            );
                          }).toList();
                        },
                      );
                    }),
                    PopupMenuButton(
                      offset: const Offset(0, 46),
                      itemBuilder: (context) {
                        return [
                          PopupMenuItem(
                            onTap: () async {
                              await logic.cleanFile();
                            },
                            child: Row(
                              spacing: 16.0,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [const Icon(Icons.delete_sweep), Text(i18n.mediaDeleteUseLessFile)],
                            ),
                          ),
                        ];
                      },
                    ),
                  ],
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  sliver: Obx(() {
                    return SliverAnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: switch (state.mediaType.value) {
                        MediaType.image => buildImageView(),
                        MediaType.audio => buildAudioView(),
                        MediaType.video => buildVideoView(),
                      },
                    );
                  }),
                ),
              ],
            ),
            GetBuilder<MediaLogic>(
                id: 'modal',
                builder: (_) {
                  return state.isCleaning ? const LottieModal(type: LoadingType.fileProcess) : const SizedBox.shrink();
                }),
          ],
        );
      },
    );
  }
}

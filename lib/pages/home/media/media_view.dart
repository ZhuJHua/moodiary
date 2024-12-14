import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:mood_diary/common/values/media_type.dart';
import 'package:mood_diary/components/loading/loading.dart';
import 'package:mood_diary/components/lottie_modal/lottie_modal.dart';
import 'package:mood_diary/components/media/media_audio_view.dart';
import 'package:mood_diary/components/media/media_video_view.dart';

import '../../../components/media/media_image_view.dart';
import '../../../main.dart';
import 'media_logic.dart';

class MediaPage extends StatelessWidget {
  const MediaPage({super.key});

  static final iconMap = {
    MediaType.image: FontAwesomeIcons.image,
    MediaType.audio: FontAwesomeIcons.compactDisc,
    MediaType.video: FontAwesomeIcons.video
  };

  static final textMap = {
    MediaType.image: l10n.mediaTypeImage,
    MediaType.audio: l10n.mediaTypeAudio,
    MediaType.video: l10n.mediaTypeVideo
  };

  @override
  Widget build(BuildContext context) {
    final logic = Get.put(MediaLogic());
    final state = Bind.find<MediaLogic>().state;
    final size = MediaQuery.sizeOf(context);

    Widget buildImageView() {
      final dateKeys = state.datetimeMediaMap.keys.toList();
      return ListView.builder(
        cacheExtent: size.height * 2,
        key: ValueKey(state.mediaType.value),
        itemBuilder: (context, index) {
          final datetime = dateKeys[index];
          final imageList = state.datetimeMediaMap[datetime]!;
          return MediaImageComponent(dateTime: datetime, imageList: imageList);
        },
        itemCount: dateKeys.length,
      );
    }

    Widget buildAudioView() {
      final dateKeys = state.datetimeMediaMap.keys.toList();
      return ListView.builder(
        cacheExtent: size.height * 2,
        key: ValueKey(state.mediaType.value),
        itemBuilder: (context, index) {
          final datetime = dateKeys[index];
          final audioList = state.datetimeMediaMap[datetime]!;
          return MediaAudioComponent(dateTime: datetime, audioList: audioList);
        },
        itemCount: dateKeys.length,
      );
    }

    //使用map
    Widget buildVideoView() {
      final dateKeys = state.datetimeMediaMap.keys.toList();
      return ListView.builder(
        cacheExtent: size.height * 2,
        key: ValueKey(state.mediaType.value),
        itemBuilder: (context, index) {
          final datetime = dateKeys[index];
          final videoList = state.datetimeMediaMap[datetime]!;
          return MediaVideoComponent(dateTime: datetime, videoList: videoList);
        },
        itemCount: dateKeys.length,
      );
    }

    return GetBuilder<MediaLogic>(
      assignId: true,
      builder: (_) {
        return SafeArea(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Column(
                children: [
                  AppBar(
                    title: Text(l10n.homeNavigatorMedia),
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
                                children: [const Icon(Icons.delete_sweep), Text(l10n.mediaDeleteUseLessFile)],
                              ),
                            ),
                          ];
                        },
                      ),
                    ],
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        child: state.isFetching
                            ? const Center(child: SearchLoading())
                            : switch (state.mediaType.value) {
                                MediaType.image => buildImageView(),
                                MediaType.audio => buildAudioView(),
                                MediaType.video => buildVideoView(),
                              },
                      ),
                    ),
                  ),
                ],
              ),
              GetBuilder<MediaLogic>(
                  id: 'modal',
                  builder: (_) {
                    return state.isCleaning
                        ? const LottieModal(type: LoadingType.fileProcess)
                        : const SizedBox.shrink();
                  }),
            ],
          ),
        );
      },
    );
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:mood_diary/common/values/border.dart';
import 'package:mood_diary/common/values/media_type.dart';
import 'package:sliver_tools/sliver_tools.dart';

import 'media_logic.dart';

class MediaPage extends StatelessWidget {
  const MediaPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Bind.find<MediaLogic>();
    final state = Bind.find<MediaLogic>().state;
    final i18n = AppLocalizations.of(context)!;

    final iconMap = {
      MediaType.image: FontAwesomeIcons.images,
      MediaType.audio: FontAwesomeIcons.compactDisc,
      MediaType.video: FontAwesomeIcons.film
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
              maxCrossAxisExtent: 120, childAspectRatio: 1.0, crossAxisSpacing: 4.0, mainAxisSpacing: 4.0),
          itemBuilder: (context, index) {
            return InkWell(
              borderRadius: AppBorderRadius.mediumBorderRadius,
              onTap: () {
                logic.toPhotoView(index);
              },
              child: Card(
                clipBehavior: Clip.hardEdge,
                margin: EdgeInsets.zero,
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
      return const SliverToBoxAdapter();
    }

    Widget buildVideoView() {
      return const SliverToBoxAdapter();
    }

    return GetBuilder<MediaLogic>(
      init: logic,
      assignId: true,
      builder: (logic) {
        return CustomScrollView(
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
                          if (context.mounted) {
                            showDialog(
                                context: context,
                                builder: (context) {
                                  return SimpleDialog(
                                    children: [Lottie.asset('lottie/file_ok.json')],
                                  );
                                });
                          }
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
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
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
        );
      },
    );
  }
}
